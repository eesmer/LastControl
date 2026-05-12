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

