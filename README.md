# CEN4025 Assignment 8 project resources

The application is Java 21 with Maven and Spring Boot. Host automation uses Bash, AppleScript and cloud-init. No Python code is part of this submission.

## Run from an extracted copy

Install UTM in /Applications, standalone QEMU with Homebrew (`brew install qemu`), and macOS command line tools. The host needs Bash, jq, curl and standard macOS utilities. Allow Terminal to control UTM when macOS asks. Internet access is required. Stop other 4 GiB guests on an 8 GB host.

From this directory:

```bash
mkdir -p evidence/logs
set -o pipefail
bash automation/create-vm.sh --source "$PWD/application" --name CEN4025-New-Run 2>&1 | tee evidence/logs/new-host.log
```

Use a unique name for every fresh run. Wait for provisioning, then find the DHCP address:

```bash
/Applications/UTM.app/Contents/MacOS/utmctl ip-address CEN4025-New-Run
ssh -i .generated/keys/cen4025_ed25519 student@NEW_VM_IP
```

In the guest, run `sudo cloud-init status --wait`, `sudo tail -n 40 /var/log/cen4025-provision.log`, and `systemctl status reservation --no-pager`. Require cloud-init done without errors, CEN4025 PROVISIONING SUCCESS, and an active service. Exit SSH and verify from macOS:

```bash
bash automation/verify-http.sh http://NEW_VM_IP:8080 2>&1 | tee evidence/logs/new-http.log
```

Open http://NEW_VM_IP:8080/api/appointments in a browser. The verifier creates and cancels its own test booking. Read automation/README.md for implementation details, clean repetition and limitations; its original source path records the observed run. Use the portable application path above for this archive.

## Contents and observed results

- application/: pom.xml and Java source/tests, unchanged from the tested source.
- automation/: VM creation, guest provisioning and host verification scripts.
- configuration/: observed VM manifest and source archive fingerprint.
- evidence/logs/: original build, troubleshooting, provisioning and verification logs.

The final VM was CEN4025-Reproduction-Shell-1 at DHCP address 192.168.64.7. All 13 Maven tests passed and all host HTTP checks passed. The evidence report is delivered separately. Historical logs may contain earlier helper commands and local paths; they are retained as actual run evidence.

VM disks, ISO images, caches, private keys and build output are excluded. New runs generate a local SSH key under .generated; do not submit that directory. External image/package repositories and available package versions can change; see the report's reproducibility evaluation.
