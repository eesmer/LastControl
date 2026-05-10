#!/bin/bash

get_last_login() {
    local username=$1
    local raw_date=$(last -n 1 "$username" | head -n 1 | awk '{print $4,$5,$6,$7}')
    if [[ -z "$raw_date" || "$raw_date" == *"wtmp"* ]]; then
        echo "Giriş Yok"
    else
        local clean_date=$(date -d "$raw_date" "+%Y-%m-%d %H:%M" 2>/dev/null)
        echo "${clean_date:-$raw_date}"
    fi
}

USER_LIST=()
while IFS=: read -r username password uid gid info home shell; do
    if [ "$uid" -eq 0 ] || [ "$uid" -ge 1000 ]; then
        last_login=$(get_last_login "$username")
        USER_LIST+=("$username:$uid:$last_login")
    fi
done < /etc/passwd

USER_STRING=$(printf "%s," "${USER_LIST[@]}" | sed 's/,$//')
jq -c -n --arg org "local_users" --arg hn "$(hostname)" --arg data "$USER_STRING" '{origin: $org, hostname: $hn, info_data: $data}'

