#!/bin/bash

SERVER_IP=$(hostname -I | awk '{print $1}')
CERT_DIR="./certs"
AGENT_DIR="./dist"
PORT="4433"
SERVER_WDIR="/usr/local/lastcontrol"

