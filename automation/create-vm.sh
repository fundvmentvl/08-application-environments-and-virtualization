#!/usr/bin/env bash
# macOS host: create a fresh UTM VM with a NoCloud seed and Java application.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
SOURCE=''
VM_NAME='CEN4025-Reproduction-Shell-1'
PREPARE_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) [[ $# -ge 2 ]] || exit 2; SOURCE=$2; shift 2 ;;
    --name) [[ $# -ge 2 ]] || exit 2; VM_NAME=$2; shift 2 ;;
    --prepare-only) PREPARE_ONLY=1; shift ;;
    *) echo "Usage: bash $0 --source PROJECT --name VM_NAME [--prepare-only]" >&2; exit 2 ;;
  esac
done
[[ "$VM_NAME" =~ ^[A-Za-z][A-Za-z0-9-]{0,50}$ ]] || { echo 'Invalid VM name.' >&2; exit 2; }
[[ -f "$SOURCE/pom.xml" && -d "$SOURCE/src" ]] || { echo '--source must contain pom.xml and src/.' >&2; exit 2; }
SOURCE=$(cd "$SOURCE" && pwd)
for tool in jq curl shasum tar base64 uuidgen ssh-keygen; do
  command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done
UTM='/Applications/UTM.app/Contents/MacOS/utmctl'
QEMU=$(command -v qemu-img || true)
[[ -n "$QEMU" ]] || QEMU='/opt/homebrew/bin/qemu-img'
if [[ "$PREPARE_ONLY" -eq 0 ]]; then
  [[ -x "$UTM" && -x "$QEMU" ]] || { echo 'Install UTM and standalone QEMU (brew install qemu).' >&2; exit 1; }
fi
WORK="$ROOT/.generated/$VM_NAME"
[[ ! -e "$WORK" ]] || { echo 'This output directory exists; choose a new name.' >&2; exit 1; }
KEYS="$ROOT/.generated/keys"
mkdir -p "$KEYS"
chmod 700 "$KEYS"
KEY="$KEYS/cen4025_ed25519"
if [[ ! -f "$KEY" ]]; then
  ssh-keygen -t ed25519 -N '' -C cen4025-local-development -f "$KEY"
fi
[[ -f "$KEY.pub" ]] || { echo 'The task SSH public key is missing.' >&2; exit 1; }
mkdir -p "$WORK/seed"
# Source only: no .git, build output, VM disks or caches.
COPYFILE_DISABLE=1 tar -czf "$WORK/application.tar.gz" -C "$SOURCE" pom.xml src
shasum -a 256 "$WORK/application.tar.gz" > "$WORK/source.sha256"
base64 < "$WORK/application.tar.gz" | tr -d '\r\n' > "$WORK/archive.b64"
base64 < "$HERE/provision-application.sh" | tr -d '\r\n' > "$WORK/provision.b64"
HOSTNAME=$(printf '%s' "$VM_NAME" | tr '[:upper:]' '[:lower:]')
# JSON is a YAML-compatible cloud-config representation, generated with jq.
printf '#cloud-config\n' > "$WORK/seed/user-data"
jq -n --arg hostname "$HOSTNAME" --rawfile pubkey "$KEY.pub" \
  --rawfile archive "$WORK/archive.b64" --rawfile provision "$WORK/provision.b64" '
  {hostname:$hostname, manage_etc_hosts:true,
   users:[{name:"student", shell:"/bin/bash", groups:["sudo"],
     sudo:"ALL=(ALL) NOPASSWD:ALL", lock_passwd:true,
     ssh_authorized_keys:[($pubkey | rtrimstr("\n"))]}],
   ssh_pwauth:false, ssh_deletekeys:true, ssh_genkeytypes:["rsa","ecdsa","ed25519"],
   package_update:true,
   packages:["openjdk-21-jdk-headless","maven","curl","ca-certificates","openssh-server","qemu-guest-agent"],
   growpart:{mode:"auto",devices:["/"],ignore_growroot_disabled:false}, resize_rootfs:true,
   write_files:[
     {path:"/var/lib/cen4025/application.tar.gz",owner:"root:root",permissions:"0644",encoding:"b64",content:$archive},
     {path:"/usr/local/sbin/cen4025-provision",owner:"root:root",permissions:"0755",encoding:"b64",content:$provision}],
   runcmd:[["bash","/usr/local/sbin/cen4025-provision"]],
   final_message:"CEN4025 cloud-init finished. Check /var/log/cen4025-provision.log."}' >> "$WORK/seed/user-data"
jq -n --arg instance "$(uuidgen)" --arg hostname "$HOSTNAME" \
  '{"instance-id":$instance,"local-hostname":$hostname}' > "$WORK/seed/meta-data"
jq -n '{version:2,ethernets:{ethernet:{match:{name:"en*"},dhcp4:true}}}' > "$WORK/seed/network-config"
echo "Generated NoCloud seed, application archive and source fingerprint in $WORK"
if [[ "$PREPARE_ONLY" -eq 1 ]]; then exit 0; fi
BASE_URL='https://cloud-images.ubuntu.com/releases/resolute/release/'
IMAGE='ubuntu-26.04-server-cloudimg-arm64.img'
CACHE="$ROOT/.generated/cache"
mkdir -p "$CACHE"
if [[ ! -f "$CACHE/$IMAGE" ]]; then
  curl --fail --location --retry 3 "$BASE_URL/SHA256SUMS" -o "$CACHE/SHA256SUMS"
  curl --fail --location --retry 3 "$BASE_URL/$IMAGE" -o "$CACHE/$IMAGE.partial"
  mv "$CACHE/$IMAGE.partial" "$CACHE/$IMAGE"
fi
[[ -f "$CACHE/SHA256SUMS" ]] || { echo 'Cached image has no checksum manifest.' >&2; exit 1; }
EXPECTED=$(awk -v image="$IMAGE" '{name=$2; sub(/^\*/,"",name); if(name==image) print $1}' "$CACHE/SHA256SUMS")
ACTUAL=$(shasum -a 256 "$CACHE/$IMAGE" | awk '{print $1}')
[[ "$EXPECTED" =~ ^[0-9a-fA-F]{64}$ && "$ACTUAL" == "$EXPECTED" ]] || { echo 'Image checksum mismatch; no VM created.' >&2; exit 1; }
echo "Cloud image SHA256 verified: $ACTUAL"
cp "$CACHE/$IMAGE" "$WORK/root.qcow2"
"$QEMU" resize "$WORK/root.qcow2" 30G
hdiutil makehybrid -o "$WORK/cidata.iso" -iso -joliet -default-volume-name CIDATA "$WORK/seed"
jq -n --arg vm "$VM_NAME" --arg url "$BASE_URL$IMAGE" --arg sha "$ACTUAL" --arg source "$SOURCE" \
 '{vm:$vm,cpus:2,memory_mib:4096,disk_gib:30,architecture:"aarch64",network:"shared DHCP",image_url:$url,image_sha256:$sha,source:$source,cloud_init:"seed/user-data",application_port:8080,automation:"shell"}' > "$WORK/manifest.json"
osascript "$HERE/create-vm.applescript" "$VM_NAME" "$WORK/root.qcow2" "$WORK/cidata.iso"
echo 'VM created and started. Allow several minutes for cloud-init and the Maven build.'
printf 'Find the guest IP: %s ip-address %s\n' "$UTM" "$VM_NAME"
echo 'Connect: ssh -i .generated/keys/cen4025_ed25519 student@NEW_VM_IP'
echo 'Guest checks: sudo cloud-init status --wait; systemctl status reservation --no-pager'
