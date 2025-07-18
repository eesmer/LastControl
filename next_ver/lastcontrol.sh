#!/bin/bash

WDIR="/usr/local/lastcontrol"
RDIR="/usr/local/lastcontrol/reports"
report="/usr/local/lastcontrol/reports/$HOSTNAME-lastcontrol_report.txt"

mkdir -p $RDIR

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

SUPPORTED_OS=("ubuntu" "debian" "pardus")
if [[ ! " ${SUPPORTED_OS[*]} " =~ " ${DISTRO} " ]]; then
        echo "ERROR: '$DISTRO' OS/Distro Not Support" > $report
        exit 1
fi
if [[ "$SERVICEMAN" != "Systemd" ]]; then
        echo "ERROR: Systemd Not Use" > $report
        exit 1
fi
if ! command -v vnstat &>/dev/null; then
        echo "ERROR: Missing Install (vnstat)" > $report
        exit 1
fi
