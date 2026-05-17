#!/bin/bash

HOSTNAME=$(hostname)

# Detect distro family
if command -v apt >/dev/null 2>&1; then
    PKG_MANAGER="apt"
    DISTRO=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    apt-get update -qq >/dev/null 2>&1
    UPDATES=$(apt list --upgradable 2>/dev/null | tail -n +2)
    TOTAL_UPDATES=$(echo "$UPDATES" | grep -c .)
    UPDATE_LIST=$(echo "$UPDATES" | awk -F/ '{print $1}' | head -20 | paste -sd "," -)

    if [ -f /var/run/reboot-required ]; then
        REBOOT_REQUIRED="yes"
    else
        REBOOT_REQUIRED="no"
    fi

elif command -v dnf >/dev/null 2>&1; then
    PKG_MANAGER="dnf"
    DISTRO=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    UPDATES=$(dnf check-update 2>/dev/null)
    TOTAL_UPDATES=$(echo "$UPDATES" | awk '/^[a-zA-Z0-9]/ {count++} END {print count+0}')
    UPDATE_LIST=$(echo "$UPDATES" | awk '/^[a-zA-Z0-9]/ {print $1}' | head -20 | paste -sd "," -)

    if command -v needs-restarting >/dev/null 2>&1; then
        needs-restarting -r >/dev/null 2>&1
        if [ $? -ne 0 ]; then
            REBOOT_REQUIRED="yes"
        else
            REBOOT_REQUIRED="no"
        fi
    else
        REBOOT_REQUIRED="unknown"
    fi

elif command -v yum >/dev/null 2>&1; then
    PKG_MANAGER="yum"
    DISTRO=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
    UPDATES=$(yum check-update 2>/dev/null)
    TOTAL_UPDATES=$(echo "$UPDATES" | awk '/^[a-zA-Z0-9]/ {count++} END {print count+0}')
    UPDATE_LIST=$(echo "$UPDATES" | awk '/^[a-zA-Z0-9]/ {print $1}' | head -20 | paste -sd "," -)
    REBOOT_REQUIRED="unknown"

else
    PKG_MANAGER="unknown"
    DISTRO="unknown"
    TOTAL_UPDATES=0
    UPDATE_LIST=""
    REBOOT_REQUIRED="unknown"
fi

INFO_DATA=$(jq -c -n \
  --arg distro "$DISTRO" \
  --arg package_manager "$PKG_MANAGER" \
  --arg total_updates "$TOTAL_UPDATES" \
  --arg reboot_required "$REBOOT_REQUIRED" \
  --arg updates "$UPDATE_LIST" \
  '{
    distro: $distro,
    package_manager: $package_manager,
    total_updates: $total_updates,
    reboot_required: $reboot_required,
    updates: $updates
  }')

jq -c -n \
  --arg org "update_report" \
  --arg hn "$HOSTNAME" \
  --arg data "$INFO_DATA" \
  '{origin: $org, hostname: $hn, info_data: $data}'

