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
apt-get -y install socat jq sqlite3
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
#AGENT_PAYLOAD=$(tar -czf - -C ./agent_scripts . | base64 -w 0)
AGENT_PAYLOAD=$(tar -czf - -C "$TEMP_REPO"/client/agent_scripts . | base64 -w 0)
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
elif [ -f /etc/redhat-release ]; then
    yum -y install epel-release && yum -y install socat
    yum -y install rsyslog
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

cat <<'HANDLER' > /usr/local/bin/lastcontrol-handler.py
#!/usr/bin/env python3

import sys
import json
import sqlite3
import logging
from datetime import datetime

DB_PATH = "/usr/local/lastcontrol/lastcontrol.db"
LOG_PATH = "/var/log/lastcontrol-handler.log"
MAX_PAYLOAD_SIZE = 1024 * 1024  # 1 MB

logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

SYSTEM_INFO_MAP = {
    "system_info_ports": "open_ports",
    "system_info_disk": "disk_usage",
    "system_info_roles": "roles",
    "system_info_ram": "ram_usage",
    "local_users": "local_users",
    "update_report": "update_report",
    "disk_io_load": "disk_io_load",
}

INVENTORY_FIELDS = [
    "hostname",
    "internal_ip",
    "external_ip",
    "internet_conn",
    "cpu_info",
    "ram_total",
    "disk_list",
    "gpu",
    "wireless",
    "distro",
    "kernel",
    "uptime",
    "last_boot",
    "virt_control",
    "local_date",
    "time_sync",
    "time_zone",
    "bios_vendor",
    "bios_info",
    "bios_version",
    "bios_release_date",
    "bios_revision",
    "bios_firmware_revision",
    "bios_mode",
    "mainboard",
    "product_name",
    "serial_number",
]


def read_payload():
    raw = sys.stdin.buffer.read(MAX_PAYLOAD_SIZE + 1)

    if len(raw) > MAX_PAYLOAD_SIZE:
        logging.error("Payload too large")
        sys.exit(0)

    if not raw:
        sys.exit(0)

    try:
        text = raw.decode("utf-8", errors="replace").strip()
        return json.loads(text)
    except json.JSONDecodeError as e:
        logging.error("Invalid JSON: %s", e)
        sys.exit(0)


def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def clean_value(value):
    if value is None:
        return ""
    if isinstance(value, (dict, list)):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def handle_inventory(data):
    values = [clean_value(data.get(field, "")) for field in INVENTORY_FIELDS]

    hostname = clean_value(data.get("hostname", ""))
    internal_ip = clean_value(data.get("internal_ip", ""))
    distro = clean_value(data.get("distro", ""))

    if not hostname:
        logging.error("Inventory rejected: hostname missing")
        return

    placeholders = ", ".join(["?"] * len(INVENTORY_FIELDS))
    field_list = ", ".join(INVENTORY_FIELDS)

    with get_conn() as conn:
        conn.execute(
            f"""
            INSERT INTO inventory ({field_list})
            VALUES ({placeholders})
            """,
            values
        )

        conn.execute(
            """
            INSERT INTO agents (hostname, ip_address, os_name, last_seen)
            VALUES (?, ?, ?, datetime('now','localtime'))
            ON CONFLICT(hostname) DO UPDATE SET
                ip_address = excluded.ip_address,
                os_name = excluded.os_name,
                last_seen = excluded.last_seen
            """,
            (hostname, internal_ip, distro)
        )

        conn.commit()

    logging.info("Inventory recorded for hostname=%s", hostname)


def handle_system_info(data, info_type):
    hostname = clean_value(data.get("hostname", ""))
    info_data = clean_value(data.get("info_data", ""))

    if not hostname:
        logging.error("System info rejected: hostname missing")
        return

    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO system_info (hostname, info_type, info_data)
            VALUES (?, ?, ?)
            """,
            (hostname, info_type, info_data)
        )

        conn.execute(
            """
            UPDATE agents
            SET last_seen = datetime('now','localtime')
            WHERE hostname = ?
            """,
            (hostname,)
        )

        conn.commit()

    logging.info("System info recorded hostname=%s type=%s", hostname, info_type)

def handle_task_check(data):
    hostname = clean_value(data.get("hostname", ""))

    if not hostname:
        logging.error("Task check rejected: hostname missing")
        return

    with get_conn() as conn:
        task = conn.execute(
            """
            SELECT id, task_type, task_payload
            FROM tasks
            WHERE hostname = ?
              AND status = 'pending'
            ORDER BY created_at ASC
            LIMIT 1
            """,
            (hostname,)
        ).fetchone()

        if task is None:
            response = {
                "has_task": False
            }
        else:
            conn.execute(
                """
                UPDATE tasks
                SET status = 'assigned',
                    assigned_at = datetime('now','localtime')
                WHERE id = ?
                """,
                (task["id"],)
            )
            conn.commit()

            response = {
                "has_task": True,
                "task_id": task["id"],
                "task_type": task["task_type"],
                "task_payload": task["task_payload"] or ""
            }

    print(json.dumps(response, ensure_ascii=False))

def handle_task_result(data):
    hostname = clean_value(data.get("hostname", ""))
    try:
       task_id = int(data.get("task_id"))
    except Exception:
       logging.error("Invalid task_id")
       return
    result_status = clean_value(data.get("result_status", "unknown"))
    result_output = clean_value(data.get("result_output", ""))

    if not hostname or not task_id:
        logging.error("Task result rejected: hostname or task_id missing")
        return

    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO task_results (
                task_id,
                hostname,
                result_status,
                result_output
            )
            VALUES (?, ?, ?, ?)
            """,
            (task_id, hostname, result_status, result_output)
        )

        conn.execute(
            """
            UPDATE tasks
            SET status = 'completed',
                completed_at = datetime('now','localtime')
            WHERE id = ?
            """,
            (task_id,)
        )

        conn.commit()

    logging.info("Task result recorded hostname=%s task_id=%s", hostname, task_id)

def main():
    data = read_payload()
    origin = clean_value(data.get("origin", ""))

    if not origin:
        logging.error("Origin missing")
        return

    if origin == "inventory":
        handle_inventory(data)
    elif origin in SYSTEM_INFO_MAP:
        handle_system_info(data, SYSTEM_INFO_MAP[origin])
    elif origin == "task_check":
        handle_task_check(data)
    elif origin == "task_result":
        handle_task_result(data)
    else:
        logging.error("Unknown origin: %s", origin)
if __name__ == "__main__":
    main()
HANDLER
chmod +x /usr/local/bin/lastcontrol-handler.py
python3 -m py_compile /usr/local/bin/lastcontrol-handler.py
if [ $? -ne 0 ]; then
    echo "ERROR: lastcontrol-handler.py syntax check failed!"
    exit 1
fi
touch /var/log/lastcontrol-handler.log
chmod 640 /var/log/lastcontrol-handler.log

# Server Listener Service
cat > "/etc/systemd/system/lastcontrol-listener.service" <<LCSSERVICE
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
LCSSERVICE

# Server Web Service
cat > "/etc/systemd/system/lastcontrol-web.service" <<LCSWEB
[Unit]
Description=LastControl Web Service
After=network.target

[Service]
User=root
WorkingDirectory=/usr/local/lastcontrol/web
ExecStart=/usr/local/lastcontrol/web/venv/bin/python3 /usr/local/lastcontrol/web/lastcontrol-webapp.py
Restart=always

[Install]
WantedBy=multi-user.target
LCSWEB

systemctl daemon-reload
systemctl enable --now lastcontrol-listener.service
systemctl enable --now lastcontrol-web.service

echo "--- Installation Complete ---"
echo "Agent Installer: $AGENT_DIR/lastcontrol-agent_installer.sh"

