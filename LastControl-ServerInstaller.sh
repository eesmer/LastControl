#!/bin/bash

# -----------------------------------------------------
# LastControl Server Installer
# build: 2026-05-10
# -----------------------------------------------------

SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_WDIR="/usr/local/lastcontrol"
CERT_DIR="/etc/lastcontrol/certs"
AGENT_DIR="$SERVER_WDIR/dist"
PORT="4433"
REPO_URL="https://github.com/eesmer/LastControl.git"
TEMP_REPO="/tmp/LastControl_Repo"

rm -rf "/etc/lastcontrol"
rm -rf "$AGENT_DIR"
mkdir -p "$CERT_DIR" "$AGENT_DIR"

echo "--- LastControl: Installing Required Packages ---"
echo "--- LastControl: Creating Certificate and Security Infrastructure ---"
apt update
apt-get -y install git
apt-get -y install socat jq curl sqlite3
apt-get -y install python3-venv python3-pip nginx
apt-get -y install rsyslog

# Clone Repo
rm -rf "$TEMP_REPO"
git clone "$REPO_URL" "$TEMP_REPO"

# Server WDIR
rm -rf "$SERVER_WDIR"
mkdir -p $SERVER_WDIR/web/templates
touch "$SERVER_WDIR/readme.md"
TODAY=$(date)
echo "InstallDate: $TODAY" > $SERVER_WDIR/readme.md
cp $TEMP_REPO/server/web/lastcontrol-webapp.py "$SERVER_WDIR/web/"
cp -r "$TEMP_REPO/server/web/templates/"* "$SERVER_WDIR/web/templates/"
cd $SERVER_WDIR/web
python3 -m venv venv
source venv/bin/activate
pip install flask

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

echo "--- Agent Installer Preparing ---"
AGENT_PAYLOAD=$(tar -czf - -C "$TEMP_REPO"/client/scripts . | base64 -w 0)
mkdir -p $AGENT_DIR
# 4. Agent Installer - Generated Specifically for each installation
cat <<EOF > $AGENT_DIR/lastcontrol-agent_installer.sh
#!/bin/bash
# LastControl Agent Installer

# LastControl Server Info
SERVER_ADDR="$SERVER_IP"
PORT="$PORT"
CERTS="/etc/lastcontrol/certs"

# Debian & RHEL
if [ -f /etc/debian_version ]; then
    apt-get update && apt-get -y install socat
    apt-get -y install rsyslog
    apt-get -y install sysstat
elif [ -f /etc/redhat-release ]; then
    yum -y install epel-release && yum -y install socat
    yum -y install rsyslog
    yum -y install sysstat
fi

mkdir -p /usr/local/lastcontrol/scripts
echo "$AGENT_PAYLOAD" | base64 -d | tar -xzf - -C /usr/local/lastcontrol/scripts/
chmod +x /usr/local/lastcontrol/scripts/*.sh

mkdir -p /etc/lastcontrol/certs
cat > /etc/lastcontrol/certs/ca.crt <<'CERT_EOF'
$(cat $CERT_DIR/ca.crt)
CERT_EOF
cat > /etc/lastcontrol/certs/client.pem <<'CERT_EOF'
$(cat $CERT_DIR/client.pem)
CERT_EOF

# Client Report Script
cat <<'REPORT' > /usr/local/bin/lastcontrol-report.sh
#!/bin/bash
SERVER_IP="$SERVER_IP"
PORT="$PORT"
send_to_server() {
    local script_path=\$1
    if [ -x "\$script_path" ]; then
        "\$script_path" | /usr/bin/socat -T 10 - OPENSSL:\$SERVER_IP:\$PORT,verify=1,cafile=/etc/lastcontrol/certs/ca.crt,cert=/etc/lastcontrol/certs/client.pem,snihost=0
    fi
}
# Send Data
send_to_server "/usr/local/lastcontrol/scripts/inventory.sh"
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/open_ports.sh"
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/disk_usage.sh"
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/roles.sh"
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/ram_usage.sh"
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/local_users.sh"
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/update_report.sh"
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/disk_io_load.sh"
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/package_inventory.sh"

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
Description=Run LastControl Report Randomly between 01:00-06:00

[Timer]
OnCalendar=*-*-* 01:00:00
RandomizedDelaySec=18000
Persistent=true

[Install]
WantedBy=timers.target
TIMER

systemctl daemon-reload
systemctl enable --now lastcontrol.timer
echo "LastControl Agent was successfully installed"
EOF
chmod +x $AGENT_DIR/lastcontrol-agent_installer.sh

# Create DB
# Create INVENTORY Table
#mkdir -p "$SERVER_WDIR"

VENV_PYTHON="/usr/local/lastcontrol/web/venv/bin/python3"
DEFAULT_HASH=$($VENV_PYTHON -c 'from werkzeug.security import generate_password_hash; print(generate_password_hash("lastcontrol"))')

sqlite3 "$SERVER_WDIR/lastcontrol.db" <<EOF
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
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT
);
CREATE TABLE IF NOT EXISTS system_info (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT,
    info_type TEXT,
    info_data TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS agents (
    hostname TEXT PRIMARY KEY,
    ip_address TEXT,
    os_name TEXT,
    last_seen DATETIME
);
INSERT OR IGNORE INTO users (username, password) VALUES ('admin', '$DEFAULT_HASH');

CREATE TABLE IF NOT EXISTS tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT NOT NULL,
    task_type TEXT NOT NULL,
    task_payload TEXT,
    status TEXT DEFAULT 'pending',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    assigned_at DATETIME,
    completed_at DATETIME
);

CREATE TABLE IF NOT EXISTS task_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    task_id INTEGER,
    hostname TEXT NOT NULL,
    result_status TEXT,
    result_output TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(task_id) REFERENCES tasks(id)
);
EOF

sqlite3 "$SERVER_WDIR/lastcontrol.db" "PRAGMA journal_mode=WAL;"
sqlite3 "$SERVER_WDIR/lastcontrol.db" "PRAGMA synchronous=NORMAL;"

cat <<'WEBCONF' > /etc/nginx/sites-available/lastcontrol
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
WEBCONF
ln -s /etc/nginx/sites-available/lastcontrol /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
systemctl restart nginx

cp $TEMP_REPO/server/usr/local/bin/lastcontrol-handler.py /usr/local/bin/
chmod +x /usr/local/bin/lastcontrol-handler.py
python3 -m py_compile /usr/local/bin/lastcontrol-handler.py
if [ $? -ne 0 ]; then
    echo "ERROR: lastcontrol-handler.py syntax check failed!"
    exit 1
fi
touch /var/log/lastcontrol-handler.log
chmod 640 /var/log/lastcontrol-handler.log

# Server Web Service
cp $TEMP_REPO/server/etc/systemd/system/lastcontrol-web.service /etc/systemd/system/
chmod 644 /etc/systemd/system/lastcontrol-web.service

# Server Listener Service
cat > "/etc/systemd/system/lastcontrol-listener.service" <<LCLISTENER
[Unit]
Description=LastControl Listener
After=network-online.target
Wants=network-online.target

[Service]
Type=simple

ExecStart=/usr/bin/socat -T 30 OPENSSL-LISTEN:${PORT},reuseaddr,fork,verify=1,cafile=/etc/lastcontrol/certs/ca.crt,cert=/etc/lastcontrol/certs/server.crt,key=/etc/lastcontrol/certs/server.key EXEC:/usr/local/bin/lastcontrol-handler.py

Restart=always
RestartSec=2

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/usr/local/lastcontrol /var/log

[Install]
WantedBy=multi-user.target
LCLISTENER

# CVE Data Services
# Debian SecurityData Update Service
cp $TEMP_REPO/server/usr/local/bin/lastcontrol-debian-securitydata-update.sh /usr/local/bin/
chmod +x /usr/local/bin/lastcontrol-debian-securitydata-update.sh
touch /var/log/lastcontrol-debian-securitydata-update.sh
chmod 640 /var/log/lastcontrol-debian-securitydata-update.sh
cp $TEMP_REPO/server/etc/systemd/system/lastcontrol-debian-securitydata-update.service /etc/systemd/system/
cp $TEMP_REPO/server/etc/systemd/system/lastcontrol-debian-securitydata-update.timer /etc/systemd/system/

systemctl daemon-reload
systemctl enable --now lastcontrol-listener.service
systemctl enable --now lastcontrol-web.service
systemctl enable --now lastcontrol-debian-securitydata-update.timer

echo "--- Installation Complete ---"
echo "Agent Installer: $AGENT_DIR/lastcontrol-agent_installer.sh"

