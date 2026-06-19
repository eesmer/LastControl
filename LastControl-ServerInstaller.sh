#!/bin/bash

# -----------------------------------------------------
# LastControl Server Installer
# build: 05-06-2026
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
apt-get -y install rsyslog rrdtool

# Clone Repo
rm -rf "$TEMP_REPO"
git clone "$REPO_URL" "$TEMP_REPO"

# Server WDIR
rm -rf "$SERVER_WDIR"

mkdir -p $SERVER_WDIR//web/rrd
mkdir -p $SERVER_WDIR/web/graphs
mkdir -p $SERVER_WDIR/web/templates
touch "$SERVER_WDIR/readme.md"
TODAY=$(date)
echo "InstallDate: $TODAY" > $SERVER_WDIR/readme.md
[ -f "$TEMP_REPO/server/web/lastcontrol-webapp.py" ] || { echo "WebApp NotFound"; exit 1; }
cp $TEMP_REPO/server/web/lastcontrol-webapp.py "$SERVER_WDIR/web/"
[ -d "$TEMP_REPO/server/web/templates" ] || { echo "Templates Dir NotFound"; exit 1; }
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
[ -d "$TEMP_REPO/client/scripts" ] || { echo "AgentScripts Dir NotFound"; exit 1; }
AGENT_PAYLOAD=$(tar -czf - -C "$TEMP_REPO"/client/scripts . | base64 -w 0)
mkdir -p $AGENT_DIR

AGENT_VERSION="1.0.0"
# 4. Agent Installer - Generated Specifically for each installation
cat <<EOF > $AGENT_DIR/lastcontrol-agent_installer.sh
#!/bin/bash
# LastControl Agent Installer

# uninstall
systemctl stop lastcontrol.timer 2>/dev/null || true
systemctl disable lastcontrol.timer 2>/dev/null || true
systemctl stop lastcontrol.service 2>/dev/null || true
systemctl disable lastcontrol.service 2>/dev/null || true
rm -f /etc/systemd/system/lastcontrol.timer
rm -f /etc/systemd/system/lastcontrol.service
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true
rm -f /usr/local/bin/lastcontrol-report.sh
rm -rf /usr/local/lastcontrol
rm -rf /etc/lastcontrol

# LastControl Server Info
SERVER_ADDR="$SERVER_IP"
PORT="$PORT"
CERTS="/etc/lastcontrol/certs"

# Debian / Ubuntu
if [ -f /etc/debian_version ]; then
    apt-get update
    apt-get -y install socat rsyslog sysstat jq
# RHEL / Rocky / Alma / CentOS
elif [ -f /etc/redhat-release ]; then
    if command -v dnf >/dev/null 2>&1; then
        dnf -y install epel-release
        dnf -y install socat rsyslog sysstat jq
    elif command -v yum >/dev/null 2>&1; then
        yum -y install epel-release
        yum -y install socat rsyslog sysstat jq
    else
        echo "No supported package manager found!"
        exit 1
    fi
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
        "\$script_path" | /usr/bin/socat -T 10 - OPENSSL:\$SERVER_IP:\$PORT,verify=1,cafile=/etc/lastcontrol/certs/ca.crt,cert=/etc/lastcontrol/certs/client.pem
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
sleep 2
send_to_server "/usr/local/lastcontrol/scripts/rrd.sh"

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

mkdir -p /etc/lastcontrol
cat > /etc/lastcontrol/agent.conf <<ACONF
AGENT_VERSION="$AGENT_VERSION"
ACONF
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
    agent_version TEXT,
    socat_version TEXT,
    openssl_version TEXT,
    bash_version TEXT,
    systemd_version TEXT,
    jq_version TEXT,
    package_manager TEXT,
    agent_state TEXT,
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

CREATE TABLE IF NOT EXISTS cve_exposure (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hostname TEXT,
    distro_id TEXT,
    distro_version TEXT,
    distro_codename TEXT,
    package_name TEXT,
    installed_version TEXT,
    cve_id TEXT,
    debian_status TEXT,
    urgency TEXT,
    fixed_version TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

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
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# Server Handler Script (for listener service)
[ -f "$TEMP_REPO/server/usr/local/bin/lastcontrol-handler.py" ] || { echo "Listener/Handler script NotFound"; exit 1; }
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
[ -f "$TEMP_REPO/server/etc/systemd/system/lastcontrol-web.service" ] || { echo "WebService File NotFound"; exit 1; }
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
[ -f "$TEMP_REPO/server/usr/local/bin/lastcontrol-securitydata-update.sh" ] || { echo "SecurityData Update Script NotFound"; exit 1; }
cp $TEMP_REPO/server/usr/local/bin/lastcontrol-securitydata-update.sh /usr/local/bin/lastcontrol-securitydata-update.sh
[ -f "$TEMP_REPO/server/usr/local/bin/lastcontrol-securitydata-cve-matcher.sh" ] || { echo "SecurityData Matcher Script (sh) NotFound"; exit 1; }
cp $TEMP_REPO/server/usr/local/bin/lastcontrol-securitydata-cve-matcher.sh /usr/local/bin/lastcontrol-securitydata-cve-matcher.sh
[ -f "$TEMP_REPO/server/usr/local/bin/lastcontrol-debian-cve-matcher.py" ] || { echo "SecurityData Debian CVE Matcher Script NotFound"; exit 1; }
cp $TEMP_REPO/server/usr/local/bin/lastcontrol-debian-cve-matcher.py /usr/local/bin/lastcontrol-debian-cve-matcher.py
[ -f "$TEMP_REPO/server/usr/local/bin/lastcontrol-debian-cve-matcher.py" ] || { echo "SecurityData Ubuntu CVE Matcher Script NotFound"; exit 1; }
cp $TEMP_REPO/server/usr/local/bin/lastcontrol-ubuntu-cve-matcher.py /usr/local/bin/lastcontrol-ubuntu-cve-matcher.py
[ -f "$TEMP_REPO/server/usr/local/bin/lastcontrol-debian-cve-matcher.py" ] || { echo "SecurityData RHEL(Rocky/Alma) CVE Matcher Script NotFound"; exit 1; }
cp $TEMP_REPO/server/usr/local/bin/lastcontrol-rhel-cve-matcher.py /usr/local/bin/lastcontrol-rhel-cve-matcher.py
[ -f "$TEMP_REPO/server/etc/systemd/system/lastcontrol-securitydata-update.service" ] || { echo "SecurityData Update Service NotFound"; exit 1; }
cp $TEMP_REPO/server/etc/systemd/system/lastcontrol-securitydata-update.service /etc/systemd/system/lastcontrol-securitydata-update.service
[ -f "$TEMP_REPO/server/etc/systemd/system/lastcontrol-securitydata-update.timer" ] || { echo "SecurityData Update Timer NotFound"; exit 1; }
cp $TEMP_REPO/server/etc/systemd/system/lastcontrol-securitydata-update.timer /etc/systemd/system/lastcontrol-securitydata-update.timer
[ -f "$TEMP_REPO/server/etc/systemd/system/lastcontrol-securitydata-cve-matcher.service" ] || { echo "SecurityData CVE Matcher Service NotFound"; exit 1; }
cp $TEMP_REPO/server/etc/systemd/system/lastcontrol-securitydata-cve-matcher.service /etc/systemd/system/lastcontrol-securitydata-cve-matcher.service
[ -f "$TEMP_REPO/server/etc/systemd/system/lastcontrol-securitydata-cve-matcher.timer" ] || { echo "SecurityData CVE Matcher Timer NotFound"; exit 1; }
cp $TEMP_REPO/server/etc/systemd/system/lastcontrol-securitydata-cve-matcher.timer /etc/systemd/system/lastcontrol-securitydata-cve-matcher.timer

chmod +x /usr/local/bin/lastcontrol-securitydata-update.sh
chmod +x /usr/local/bin/lastcontrol-securitydata-cve-matcher.sh
chmod +x /usr/local/bin/lastcontrol-debian-cve-matcher.py
chmod +x /usr/local/bin/lastcontrol-ubuntu-cve-matcher.py
chmod +x /usr/local/bin/lastcontrol-rhel-cve-matcher.py
touch /var/log/lastcontrol-securitydata-update.log
touch /var/log/lastcontrol-securitydata-cve-matcher.log
chmod 640 /var/log/lastcontrol-securitydata-update.log
chmod 640 /var/log/lastcontrol-securitydata-cve-matcher.log

# RRD Graph
[ -f "$TEMP_REPO/server/usr/local/bin/lastcontrol-rrd.sh" ] || { echo "RRD Graph Script NotFound"; exit 1; }
cp $TEMP_REPO/server/usr/local/bin/lastcontrol-rrd.sh /usr/local/bin/lastcontrol-rrd.sh
chmod +x /usr/local/bin/lastcontrol-rrd.sh
chown -R www-data:www-data /usr/local/lastcontrol/web/rrd
chown -R www-data:www-data /usr/local/lastcontrol/web/graphs
chmod -R 755 /usr/local/lastcontrol/web/rrd
chmod -R 755 /usr/local/lastcontrol/web/graphs
#ln -s /usr/local/lastcontrol/web/graphs /var/www/html/lastcontrol/graphs

systemctl daemon-reload
systemctl enable --now lastcontrol-listener.service
systemctl enable --now lastcontrol-web.service
systemctl enable --now lastcontrol-securitydata-update.timer
systemctl enable --now lastcontrol-securitydata-cve-matcher.timer

echo "SecurityData Updater Services Initialize.."
/usr/local/bin/lastcontrol-securitydata-update.sh --download-only || true

echo "--- Installation Complete ---"
echo "Agent Installer: $AGENT_DIR/lastcontrol-agent_installer.sh"

