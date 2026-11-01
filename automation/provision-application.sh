#!/usr/bin/env bash
# Invoked as root by cloud-init in a fresh Ubuntu VM.
set -euo pipefail
exec > >(tee -a /var/log/cen4025-provision.log) 2>&1
[[ $EUID -eq 0 ]] || { echo 'Run as root inside the guest.'; exit 1; }
echo 'Preparing application directories and permissions'
getent passwd reservation >/dev/null || useradd --system --home-dir /opt/reservation --shell /usr/sbin/nologin reservation
install -d -o student -g student -m 0755 /opt/reservation/source
install -d -o reservation -g reservation -m 0750 /opt/reservation/data
tar -xzf /var/lib/cen4025/application.tar.gz -C /opt/reservation/source
chown -R student:student /opt/reservation/source
java -version
mvn -version
runuser -u student -- mvn -B -f /opt/reservation/source/pom.xml package
install -o reservation -g reservation -m 0644 /opt/reservation/source/target/concurrent-reservation-service-0.0.1-SNAPSHOT.jar /opt/reservation/application.jar
cat > /etc/systemd/system/reservation.service <<'UNIT'
[Unit]
Description=CEN4025 reservation application
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=reservation
Group=reservation
WorkingDirectory=/opt/reservation
ExecStart=/usr/bin/java -jar /opt/reservation/application.jar --server.address=0.0.0.0 --server.port=8080
Restart=on-failure
RestartSec=5
UMask=0027
[Install]
WantedBy=multi-user.target
UNIT
ssh-keygen -A
systemctl restart ssh
systemctl enable --now qemu-guest-agent
systemctl daemon-reload
systemctl enable --now reservation
for attempt in {1..60}; do
  if curl --fail --silent --max-time 3 http://127.0.0.1:8080/api/appointments > /var/log/cen4025-appointments.json; then
    systemctl --no-pager --full status reservation
    echo 'CEN4025 PROVISIONING SUCCESS'
    touch /var/lib/cen4025/provisioned
    exit 0
  fi
  sleep 2
done
journalctl -u reservation --no-pager -n 80
exit 1
