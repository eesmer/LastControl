#!/bin/bash

report="Usr/local/lastcontrol/reports/lastcontrol-report.txt"

# DISTRO CHECK
if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    DISTRO="$ID"
else
    DISTRO="unknown"
fi

# SYSTEMD CHECK
if systemctl list-units --type=service --state=running &>/dev/null; then
    SERVICEMAN="Systemd"
else
    SERVICEMAN="Unknown"
fi

SUPPORTED_OS=("ubuntu" "debian" "centos" "rhel" "rocky" "suse")
if [[ ! " ${SUPPORTED_OS[*]} " =~ " ${DISTRO} " ]]; then
    echo "ERROR: '$DISTRO' OS/Distro Not Support"
    exit 1
fi
if [[ "$SERVICEMAN" != "Systemd" ]]; then
    echo "ERROR: Systemd Not Use"
    exit 1
fi
