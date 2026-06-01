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

# Ubuntu OVAL
echo "$(date '+%F %T') - Ubuntu OVAL update started" >> "$LOG_FILE"
UBUNTU_RELEASES=("focal" "jammy" "noble")
for rel in "${UBUNTU_RELEASES[@]}"; do
    URL="https://security-metadata.canonical.com/oval/com.ubuntu.${rel}.cve.oval.xml.bz2"
    OUT="$UBUNTU_DIR/${rel}.cve.oval.xml.bz2"

    if curl -fsSL "$URL" -o "$OUT.tmp"; then
        mv "$OUT.tmp" "$OUT"
        echo "$(date '+%F %T') - Ubuntu OVAL updated: $rel" >> "$LOG_FILE"
    else
        rm -f "$OUT.tmp"
        echo "$(date '+%F %T') - Ubuntu OVAL update failed: $rel" >> "$LOG_FILE"
    fi
done

# RHEL / Rocky / Alma compatible Red Hat Security Data
echo "$(date '+%F %T') - Red Hat Security Data update started" >> "$LOG_FILE"
CURRENT_YEAR=$(date +%Y)
AFTER_YEAR=$((CURRENT_YEAR - 2))
AFTER_DATE="${AFTER_YEAR}-01-01"
curl -fsSL \
  "https://access.redhat.com/hydra/rest/securitydata/cve.json?after=${AFTER_DATE}" \
  -o "$RHEL_DIR/cve-recent.json.tmp"
if jq empty "$RHEL_DIR/cve-recent.json.tmp"; then
    mv "$RHEL_DIR/cve-recent.json.tmp" "$RHEL_DIR/cve-recent.json"
    echo "$(date '+%F %T') - Red Hat CVE recent data updated successfully" >> "$LOG_FILE"
else
    rm -f "$RHEL_DIR/cve-recent.json.tmp"
    echo "$(date '+%F %T') - Red Hat CVE recent JSON validation failed" >> "$LOG_FILE"
fi

echo "$(date '+%F %T') - Security data update finished" >> "$LOG_FILE"

