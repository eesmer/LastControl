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

