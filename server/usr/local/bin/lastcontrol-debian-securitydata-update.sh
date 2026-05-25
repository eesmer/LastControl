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

if [ -x /usr/local/bin/lastcontrol-debian-cve-matcher.py ]; then
    /usr/local/bin/lastcontrol-debian-cve-matcher.py >> "$LOG_FILE" 2>&1
    echo "$(date '+%F %T') - Debian CVE matcher completed" >> "$LOG_FILE"
else
    echo "$(date '+%F %T') - Debian CVE matcher not found or not executable" >> "$LOG_FILE"
fi

