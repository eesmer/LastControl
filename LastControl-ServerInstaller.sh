#!/bin/bash

# -------------------------------------------------
# LastControl Server Installer
# build: 2026-05-10
# -------------------------------------------------

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

