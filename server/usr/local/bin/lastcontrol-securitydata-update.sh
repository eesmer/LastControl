#!/bin/bash

BASE_DIR="/var/lib/lastcontrol/security-data"
LOG_FILE="/var/log/lastcontrol-securitydata-update.log"
DEBIAN_DIR="$BASE_DIR/debian"
UBUNTU_DIR="$BASE_DIR/ubuntu"
RHEL_DIR="$BASE_DIR/rhel"

mkdir -p "$DEBIAN_DIR" "$UBUNTU_DIR" "$RHEL_DIR"
echo "$(date '+%F %T') - Security data update started" >> "$LOG_FILE"

# Debian
echo "$(date '+%F %T') - Debian Security Tracker update started" >> "$LOG_FILE"
curl -fsSL \
  "https://security-tracker.debian.org/tracker/data/json" \
  -o "$DEBIAN_DIR/security-tracker.json.tmp"
if jq empty "$DEBIAN_DIR/security-tracker.json.tmp"; then
    mv "$DEBIAN_DIR/security-tracker.json.tmp" "$DEBIAN_DIR/security-tracker.json"
    echo "$(date '+%F %T') - Debian Security Tracker updated successfully" >> "$LOG_FILE"
else
    rm -f "$DEBIAN_DIR/security-tracker.json.tmp"
    echo "$(date '+%F %T') - Debian Security Tracker JSON validation failed" >> "$LOG_FILE"
fi

# Ubuntu
echo "$(date '+%F %T') - Ubuntu security data update not implemented yet" >> "$LOG_FILE"

# RHEL
echo "$(date '+%F %T') - RHEL security data update not implemented yet" >> "$LOG_FILE"

echo "$(date '+%F %T') - Security data update finished" >> "$LOG_FILE"


#if [ -x /usr/local/bin/lastcontrol-debian-cve-matcher.py ]; then
#    /usr/local/bin/lastcontrol-debian-cve-matcher.py >> "$LOG_FILE" 2>&1
#    echo "$(date '+%F %T') - Debian CVE matcher completed" >> "$LOG_FILE"
#else
#    echo "$(date '+%F %T') - Debian CVE matcher not found or not executable" >> "$LOG_FILE"
#fi
