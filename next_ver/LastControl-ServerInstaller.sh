#!/bin/bash

SERVER_IP=$(hostname -I | awk '{print $1}')
SERVER_WDIR="/usr/local/lastcontrol"
CERT_DIR="./certs"
AGENT_DIR="$SERVER_WDIR/dist"
PORT="4433"

rm -rf $CERT_DIR $AGENT_DIR
rm -rf "/etc/lastcontrol"
mkdir -p $CERT_DIR $AGENT_DIR

echo "--- LastControl: Installing Required Packages ---"
echo "--- LastControl: Creating Certificate and Security Infrastructure ---"
apt update
apt-get -y install socat jq sqlite3
apt-get -y install python3-venv python3-pip nginx
apt-get -y install rsyslog

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

echo "--- Agent Installer Preparing ---"
AGENT_PAYLOAD=$(tar -czf - -C ./agent_scripts . | base64 -w 0)
mkdir -p $AGENT_DIR
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

# LastControl Web directtory and files
mkdir -p $SERVER_WDIR/web/templates
cd $SERVER_WDIR/web
python3 -m venv venv
source venv/bin/activate
pip install flask

# Create DB
# Create INVENTORY Table
# 1. DB Dizinini ve Dosyasını Hazırla
mkdir -p "$SERVER_WDIR"

# 2. Hash Oluşturma İşlemini SQLite Bloğunun DIŞINDA Yap
VENV_PYTHON="/usr/local/lastcontrol/web/venv/bin/python3"
DEFAULT_HASH=$($VENV_PYTHON -c 'from werkzeug.security import generate_password_hash; print(generate_password_hash("lastcontrol"))')

# 3. SQLite Tablo Oluşturma ve Veri Ekleme Bloğu
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
EOF

cp /root/LCV3/lastcontrol-webapp.py /usr/local/lastcontrol/web/
cp /root/LCV3/change_password.html /usr/local/lastcontrol/web/templates/
cp /root/LCV3/index.html /usr/local/lastcontrol/web/templates/
cp /root/LCV3/details.html /usr/local/lastcontrol/web/templates/
cp /root/LCV3/layout.html /usr/local/lastcontrol/web/templates/
cp /root/LCV3/login.html /usr/local/lastcontrol/web/templates/
cp /root/LCV3/ports.html /usr/local/lastcontrol/web/templates/
cp /root/LCV3/disk.html /usr/local/lastcontrol/web/templates/
cp /root/LCV3/roles.html /usr/local/lastcontrol/web/templates/

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

cat <<'HANDLER' > /usr/local/bin/lastcontrol-handler.sh
#!/bin/bash
# /usr/local/bin/lastcontrol-handler.sh

DB_PATH="/usr/local/lastcontrol/lastcontrol.db"
ERROR_LOG="/tmp/handler_errors.log"

# Read Data
RAW_DATA=$(cat | tr -d '\r' | tr -d '[:cntrl:]')
[ -z "$RAW_DATA" ] && exit 0

# Detect Origin
ORIGIN=$(echo "$RAW_DATA" | jq -r '.origin // empty')

if [ -z "$ORIGIN" ]; then
    echo "$(date) - ERROR: Origin info Not Found. Data: $RAW_DATA" >> $ERROR_LOG
    exit 0
fi

# DB/Table Record
case "$ORIGIN" in
"inventory")
        eval $(echo "$RAW_DATA" | jq -r '
          "HNAME=\(.hostname|@sh); IIP=\(.internal_ip|@sh); EIP=\(.external_ip|@sh);
            ICONN=\(.internet_conn|@sh); CPU=\(.cpu_info|@sh); RAM=\(.ram_total|@sh);
            DSK=\(.disk_list|@sh); GPU=\(.gpu|@sh); WRLS=\(.wireless|@sh);
            DST=\(.distro|@sh); KERN=\(.kernel|@sh); UPT=\(.uptime|@sh);
            LBOOT=\(.last_boot|@sh); VRT=\(.virt_control|@sh); LDATE=\(.local_date|@sh);
            TSYNC=\(.time_sync|@sh); TZONE=\(.time_zone|@sh); B_VEND=\(.bios_vendor|@sh);
            B_INFO=\(.bios_info|@sh); B_VER=\(.bios_version|@sh); B_DATE=\(.bios_release_date|@sh);
            B_REV=\(.bios_revision|@sh); B_FW=\(.bios_firmware_revision|@sh); B_MODE=\(.bios_mode|@sh);
            MB=\(.mainboard|@sh); PNAME=\(.product_name|@sh); SN=\(.serial_number|@sh)"')

        H_SQL=$(echo "$HNAME" | sed "s/'/''/g")
        CPU_SQL=$(echo "$CPU" | sed "s/'/''/g")
        DSK_SQL=$(echo "$DSK" | sed "s/'/''/g")
        GPU_SQL=$(echo "$GPU" | sed "s/'/''/g")
        DST_SQL=$(echo "$DST" | sed "s/'/''/g")
        MB_SQL=$(echo "$MB" | sed "s/'/''/g")
        PNAME_SQL=$(echo "$PNAME" | sed "s/'/''/g")
        SN_SQL=$(echo "$SN" | sed "s/'/''/g")

        /usr/bin/sqlite3 "$DB_PATH" <<EOF
        INSERT INTO inventory (
            hostname, internal_ip, external_ip, internet_conn, cpu_info, ram_total,
            disk_list, gpu, wireless, distro, kernel, uptime, last_boot,
            virt_control, local_date, time_sync, time_zone, bios_vendor,
            bios_info, bios_version, bios_release_date, bios_revision,
            bios_firmware_revision, bios_mode, mainboard, product_name, serial_number
        ) VALUES (
            '$H_SQL', '$IIP', '$EIP', '$ICONN', '$CPU_SQL', '$RAM',
            '$DSK_SQL', '$GPU_SQL', '$WRLS', '$DST_SQL', '$KERN', '$UPT', '$LBOOT',
            '$VRT', '$LDATE', '$TSYNC', '$TZONE', '$B_VEND',
            '$B_INFO', '$B_VER', '$B_DATE', '$B_REV',
            '$B_FW', '$B_MODE', '$MB_SQL', '$PNAME_SQL', '$SN_SQL'
        );

        INSERT INTO agents (hostname, ip_address, os_name, last_seen)
        VALUES ('$H_SQL', '$IIP', '$DST_SQL', datetime('now','localtime'))
        ON CONFLICT(hostname) DO UPDATE SET
            ip_address=excluded.ip_address,
            os_name=excluded.os_name,
            last_seen=excluded.last_seen;
EOF
        ;;
"system_info_ports")
        HNAME=$(echo "$RAW_DATA" | jq -r '.hostname')
        DATA=$(echo "$RAW_DATA" | jq -r '.info_data')
        /usr/bin/sqlite3 "$DB_PATH" "INSERT INTO system_info (hostname, info_type, info_data) VALUES ('$HNAME', 'open_ports', '$DATA');"
        echo "DEBUG: Portlar yazıldı." >&2
        ;;
"system_info_disk")
        # Burayı daha esnek yapıyoruz:
        HNAME=$(echo "$RAW_DATA" | jq -r '.hostname')
        DATA=$(echo "$RAW_DATA" | jq -r '.info_data')
        if [ "$HNAME" != "null" ] && [ -n "$DATA" ]; then
            /usr/bin/sqlite3 "$DB_PATH" "INSERT INTO system_info (hostname, info_type, info_data) VALUES ('$HNAME', 'disk_usage', '$DATA');"
            echo "DEBUG: Disk verisi başarıyla yazıldı." >&2
        else
            echo "DEBUG: Disk verisi ayıklanamadı!" >&2
        fi
        ;;
"system_info_roles")
        HNAME=$(echo "$RAW_DATA" | jq -r '.hostname')
        DATA=$(echo "$RAW_DATA" | jq -r '.info_data')
        /usr/bin/sqlite3 "$DB_PATH" "INSERT INTO system_info (hostname, info_type, info_data) VALUES ('$HNAME', 'roles', '$DATA');"
        ;;
        *)
        echo "$(date) - ERROR: Invalid Origin: $ORIGIN" >> $ERROR_LOG
        ;;
esac
HANDLER
chmod +x /usr/local/bin/lastcontrol-handler.sh

# Server Listener Service
cat > "/etc/systemd/system/lastcontrol-listener.service" <<LCSSERVICE
[Unit]
Description=LastControl Listener
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/socat -T 30 OPENSSL-LISTEN:${PORT},reuseaddr,fork,verify=1,cafile=/etc/lastcontrol/certs/ca.crt,cert=/etc/lastcontrol/certs/server.crt,key=/etc/lastcontrol/certs/server.key EXEC:/usr/local/bin/lastcontrol-handler.sh
Restart=always
RestartSec=2

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
echo "Agent Installer: $AGENT_DIR/agent_installer.sh"

