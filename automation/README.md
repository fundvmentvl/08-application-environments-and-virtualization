# Assignment 8 environment automation

The original installer VM demonstrates configuration experiments. This automation creates a separate fresh UTM VM from an official Ubuntu 26.04 ARM64 cloud image, then uses a NoCloud seed to install dependencies, build the application, configure permissions and start a systemd service. It never clones the manually configured disk.

## Host prerequisites and execution

Use an Apple Silicon Mac, UTM 5.0.8 in `/Applications`, Apple's command line tools including Bash, curl and jq, standalone QEMU (`brew install qemu`) and internet access. Allow Terminal to control UTM if macOS requests it. Stop the original VM to free memory before starting a new 4 GiB guest.

From the workspace root, run:

```bash
bash automation/create-vm.sh --source /Users/zerocool/IdeaProjects/08-application-environments-and-virtualization --name CEN4025-Reproduction-1 2>&1 | tee evidence/logs/reproduction-1-host.log
```

The script creates a dedicated local SSH key under ignored `.generated/keys`, downloads and verifies a SHA256 checksum for the ARM64 cloud image, copies and expands the disk to 30 GiB, creates a CIDATA ISO using macOS `hdiutil`, and calls UTM AppleScript to create and start an ARM64 VM with two cores, 4096 MiB RAM and shared networking. NoCloud sets DHCP, the hostname and a key-authenticated student account. Password login is disabled in the new VM. The student account has passwordless sudo for this local development environment; the application runs as the separate unprivileged reservation service account.

Wait several minutes for package downloads and the Maven build. Find the new address with:

```bash
/Applications/UTM.app/Contents/MacOS/utmctl ip-address CEN4025-Reproduction-1
```

QEMU guest agent supplies IP discovery after it is installed. If the command initially has no address, wait and retry; check the UTM serial console for cloud-init progress. Use the new address, not necessarily the original VM's address.

```bash
ssh -i .generated/keys/cen4025_ed25519 student@NEW_VM_IP
```

Inside the new VM:

```bash
sudo cloud-init status --wait
sudo tail -n 40 /var/log/cen4025-provision.log
systemctl status reservation --no-pager
```

Require cloud-init completion, `CEN4025 PROVISIONING SUCCESS`, and an active reservation service before calling provisioning successful. The service runs `/opt/reservation/application.jar`, with working directory `/opt/reservation`, binding `0.0.0.0:8080`. CSV records are stored in `/opt/reservation/data`, owned by the service account. SSH keys are generated before SSH is restarted. Source is built as student; the application runs as reservation.

From a Mac terminal outside SSH, run the functional checks and retain output:

```bash
bash automation/verify-http.sh http://NEW_VM_IP:8080 2>&1 | tee evidence/logs/reproduction-1-http.log
```

This creates a test reservation, retrieves it, cancels it, and confirms the slot is available again. The test affects only a booking it creates. Preserve complete guest logs with scp using the task SSH key: `/var/log/cen4025-provision.log`, `/var/log/cloud-init-output.log`, and `/opt/reservation/source/target/surefire-reports/`. Do not copy disks or private keys into the submission.

## Clean repeat

Shut down reproduction 1 normally and run the same create command using `--name CEN4025-Reproduction-2`. Each new name produces a fresh disk copied from the cached unmodified cloud image, a unique instance ID, a newly created VM and first-boot provisioning. Repeat guest checks and Mac HTTP verification, recording new log filenames. Existing output directories and VM names are rejected to protect previous runs.

## Validation and limits

Shell syntax and AppleScript compilation have been checked locally. The shell-created VM completed cloud-init provisioning, passed 13 Maven tests and passed all host HTTP checks; full logs are stored in evidence/logs/reproduction-shell-1-*.log. The initial manually built app log shows 13 tests with zero failures, errors or skips.

Manual prerequisites are installation of UTM and developer tools, macOS automation approval, invoking the scripts, obtaining the DHCP address and capturing results. The VM creation, hardware/network definition, guest initialization, dependencies, source transfer through the seed, build, permissions and service deployment are automated. The base image is cached with its SHA256SUMS and every run writes a manifest and source archive fingerprint. The checksum is downloaded over HTTPS; detached signature verification is not implemented. Image release aliases, APT packages and Maven artifacts can change; retain the checksum/manifest and record observed versions. Internet and external repositories are required. Reproduction may show a different Ubuntu patch/kernel version from the original ISO installation; record the actual guest version. Generated disks, seeds containing public keys, private SSH keys and caches are excluded via `.gitignore`.

References: [UTM scripting](https://docs.getutm.app/scripting/cheat-sheet/), [NoCloud](https://docs.cloud-init.io/en/latest/reference/datasources/nocloud.html), [Ubuntu ARM64 cloud images](https://cloud-images.ubuntu.com/releases/resolute/release/).

## First run correction

The first attempt downloaded and verified the Ubuntu image, then failed before VM creation because the bundled UTM qemu-img framework is a shared library rather than an executable CLI. The corrected script uses standalone qemu-img from Homebrew. Reuse the verified cache and choose a fresh VM name for the retry; keep the first log as troubleshooting evidence.

## Shell automation validation

The final host helpers are `create-vm.sh` and `verify-http.sh`. They use Bash, curl, jq, tar, base64, shasum and standard macOS utilities. No Python source is required in the submitted project. JSON generated by jq is used as a YAML-compatible cloud-init configuration. The existing provisioning shell scripts, AppleScript and Java application remain part of the environment resources.

The shell seed generation was checked with `--prepare-only`, including package configuration and source archive contents. A fresh VM was created with the shell entry point and successfully provisioned and verified at 192.168.64.7. Obtain the actual DHCP address when repeating it. The preliminary reproduction VM and its logs remain valid historical evidence of the initial creation attempt; do not relabel that execution as a shell run.
