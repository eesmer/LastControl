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

