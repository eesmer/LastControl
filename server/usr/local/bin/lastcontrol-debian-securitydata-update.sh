#!/bin/bash

set -e

BASE_DIR="/var/lib/lastcontrol/security-data"
DEBIAN_DIR="$BASE_DIR/debian"
LOG_FILE="/var/log/lastcontrol-security-data-update.log"

mkdir -p "$DEBIAN_DIR"
echo "$(date '+%F %T') - Security data update started" >> "$LOG_FILE"
curl -fsSL \
  "https://security-tracker.debian.org/tracker/data/json" \
  -o "$DEBIAN_DIR/security-tracker.json.tmp"
jq empty "$DEBIAN_DIR/security-tracker.json.tmp"
mv "$DEBIAN_DIR/security-tracker.json.tmp" "$DEBIAN_DIR/security-tracker.json"
echo "$(date '+%F %T') - Debian Security Tracker updated successfully" >> "$LOG_FILE"

