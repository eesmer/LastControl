#!/bin/bash

OUTPUT_FILE="/var/www/html/update_report.json"

detect_package_manager() {
    if command -v apt &>/dev/null; then
        echo "APT"
    elif command -v yum &>/dev/null; then
        echo "YUM"
    elif command -v dnf &>/dev/null; then
        echo "DNF"
    else
        echo "UNKNOWN"
    fi
}
