#!/usr/bin/env bash
# Run inside the Ubuntu guest. Safe to rerun to ensure required packages exist.
set -euo pipefail
if [[ $(uname -s) != Linux || ! -f /etc/debian_version ]]; then
  echo 'Run this script inside the Ubuntu VM.' >&2
  exit 1
fi
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y openjdk-21-jdk-headless maven curl ca-certificates
printf '\nProvisioned runtime and build tools\n'
java -version
mvn -version
