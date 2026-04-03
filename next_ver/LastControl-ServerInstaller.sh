#!/bin/bash

SERVER_IP=$(hostname -I | awk '{print $1}')
CERT_DIR="./certs"
AGENT_DIR="./dist"
PORT="4433"
SERVER_WDIR="/usr/local/lastcontrol"

rm -rf $CERT_DIR $AGENT_DIR
rm -rf "/etc/lastcontrol"
mkdir -p $CERT_DIR $AGENT_DIR

echo "--- LastControl: Creating Certificate and Security Infrastructure ---"
echo "--- LastControl: Installing Required Packages ---"
apt update
apt-get -y install socat jq sqlite3

# CA & Certs / Server
openssl genrsa -out $CERT_DIR/ca.key 4096
openssl req -x509 -new -nodes -key $CERT_DIR/ca.key -sha256 -days 3650 -out $CERT_DIR/ca.crt -subj "/CN=LastControl-CA"
openssl genrsa -out $CERT_DIR/server.key 2048
openssl req -new -key $CERT_DIR/server.key -out $CERT_DIR/server.csr -subj "/CN=$SERVER_IP"
openssl x509 -req -in $CERT_DIR/server.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key -CAcreateserial -out $CERT_DIR/server.crt -days 3650 -sha256

# Certs / Client
openssl genrsa -out $CERT_DIR/client.key 2048
openssl req -new -key $CERT_DIR/client.key -out $CERT_DIR/client.csr -subj "/CN=LastControl-Agent"
openssl x509 -req -in $CERT_DIR/client.csr -CA $CERT_DIR/ca.crt -CAkey $CERT_DIR/ca.key -CAcreateserial -out $CERT_DIR/client.crt -days 3650 -sha256

# Merge PEM for socat packages
cat $CERT_DIR/server.key $CERT_DIR/server.crt > $CERT_DIR/server.pem
cat $CERT_DIR/client.key $CERT_DIR/client.crt > $CERT_DIR/client.pem

mkdir -p /etc/lastcontrol/
cp -r "$CERT_DIR" /etc/lastcontrol/

# Server WDIR
rm -rf "$SERVER_WDIR"
mkdir -p "$SERVER_WDIR"
touch "$SERVER_WDIR/readme.md"
TODAY=$(date)
echo "InstallDate: $TODAY" > $SERVER_WDIR/readme.md

# Create DB
# Create INVENTORY Table
sqlite3 $SERVER_WDIR/lastcontrol.db <<EOF
CREATE TABLE IF NOT EXISTS inventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT,
    internal_ip TEXT,
    external_ip TEXT,
    internet_conn TEXT,
    cpu_info TEXT,
    ram_total TEXT,
    disk_list TEXT,
    gpu TEXT,
    wireless TEXT,
    distro TEXT,
    kernel TEXT,
    uptime TEXT,
    last_boot TEXT,
    virt_control TEXT,
    local_date TEXT,
    time_sync TEXT,
    time_zone TEXT,
    bios_vendor TEXT,
    bios_info TEXT,
    bios_version TEXT,
    bios_release_date TEXT,
    bios_revision TEXT,
    bios_firmware_revision TEXT,
    bios_mode TEXT,
    mainboard TEXT,
    product_name TEXT,
    serial_number TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
EOF

echo "--- Agent Installer Preparing ---"
AGENT_PAYLOAD=$(tar -czf - -C ./agent_scripts . | base64 -w 0)
# 4. Agent Installer - Generated Specifically for each installation
cat <<EOF > $AGENT_DIR/agent_installer.sh
#!/bin/bash
# LastControl Agent Installer

# LastControl Server Info
SERVER_ADDR="$SERVER_IP"
PORT="$PORT"
CERTS="/etc/lastcontrol/certs"

# Debian & RHEL
if [ -f /etc/debian_version ]; then
    apt-get update && apt-get install -y socat
elif [ -f /etc/redhat-release ]; then
    yum install -y epel-release && yum install -y socat
fi

mkdir -p /usr/local/lastcontrol/scripts
echo "$AGENT_PAYLOAD" | base64 -d | tar -xzf - -C /usr/local/lastcontrol/scripts/
chmod +x /usr/local/lastcontrol/scripts/*.sh

mkdir -p /etc/lastcontrol/certs
echo "$(cat $CERT_DIR/ca.crt)" > /etc/lastcontrol/certs/ca.crt
echo "$(cat $CERT_DIR/client.pem)" > /etc/lastcontrol/certs/client.pem

cat <<'CERT_EOF' > /etc/lastcontrol/certs/ca.crt
$(cat $CERT_DIR/ca.crt)
CERT_EOF

cat <<'CERT_EOF' > /etc/lastcontrol/certs/client.pem
$(cat $CERT_DIR/client.pem)
CERT_EOF

# Client Report Script
cat <<'REPORT' > /usr/local/bin/lastcontrol-report.sh
#!/bin/bash

SERVER_IP="$SERVER_IP"
PORT="$PORT"

send_to_server() {
    # \$1 yaparak Bash'in bunu kurulum anında yorumlamasını engelliyoruz
    local script_path=\$1
    if [ -x "\$script_path" ]; then
        "\$script_path" | /usr/bin/socat -T 10 - OPENSSL:\$SERVER_IP:\$PORT,verify=1,cafile=/etc/lastcontrol/certs/ca.crt,cert=/etc/lastcontrol/certs/client.pem,snihost=0
    fi
}

# Send Inventory
send_to_server "/usr/local/lastcontrol/scripts/inventory.sh"

sleep 3

REPORT
chmod +x /usr/local/bin/lastcontrol-report.sh

# Systemd Service
cat <<SERVICE > /etc/systemd/system/lastcontrol.service
[Unit]
Description=LastControl System Report Agent

[Service]
ExecStart=/usr/local/bin/lastcontrol-report.sh
SERVICE

cat <<TIMER > /etc/systemd/system/lastcontrol.timer
[Unit]
Description=Run LastControl Report Randomly between 23:00-05:00

[Timer]
OnCalendar=*-*-* 23:00:00
RandomizedDelaySec=21600
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now lastcontrol.timer
echo "LastControl Agent was successfully installed"
EOF

chmod +x $AGENT_DIR/agent_installer.sh
