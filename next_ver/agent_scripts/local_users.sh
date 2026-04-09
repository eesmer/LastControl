#!/bin/bash
USER_LIST=""

# UID >= 1000
for user in $(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd); do
    LAST_LOG=$(lastlog -u "$user" | tail -n 1 | awk '{print $4, $5, $6, $9}')
    if [[ "$LAST_LOG" == *"**Never"* ]]; then
        LAST_LOG="Hiç girmedi"
    fi
    USER_LIST+="$user ($LAST_LOG), "
done

USER_LIST=$(echo "$USER_LIST" | sed 's/, $//')
jq -c -n --arg org "system_info_users" --arg hn "$(hostname)" --arg data "$USER_LIST" \
'{origin: $org, hostname: $hn, info_data: $data}'

