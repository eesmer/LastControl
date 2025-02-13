#!/bin/bash

mkdir -p /usr/local/lastcontrol/reports
report_file="/usr/local/lastcontrol/reports/user_status.json"

echo "[" > "$output_file"

for user in $(getent passwd | awk -F: '{print $1}'); do
    shell=$(getent passwd "$user" | cut -d: -f7)

    # User Type
    if [[ "$shell" != "/usr/sbin/nologin" && "$shell" != "/bin/false" ]]; then
        user_type="Real User"
    else
        user_type="System User"
    fi

