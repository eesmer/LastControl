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

    # Sudo Check
    sudo_access="No"

    # SUDO Control: sudo group member, /etc/sudoers.d/ and sudo -lU control
    if groups "$user" | grep &>/dev/null '\bsudo\b'; then
        sudo_access="Yes"
    elif [ -f "/etc/sudoers.d/$user" ]; then
        sudo_access="Yes"
    elif sudo -lU "$user" 2>/dev/null | grep -q "(ALL : ALL)"; then
        sudo_access="Yes"
    fi

    # Account Expiry Control
    account_expires=$(chage -l "$user" | grep 'Account expires' | cut -d: -f2 | xargs)
    if [ -z "$account_expires" ]; then
        account_expires="Never"
    fi
    
    # Create JSON Report File
    echo "  {" >> "$output_file"
    echo "    \"username\": \"$user\"," >> "$output_file"
    echo "    \"shell\": \"$shell\"," >> "$output_file"
    echo "    \"type\": \"$user_type\"," >> "$output_file"
    echo "    \"sudo_access\": \"$sudo_access\"," >> "$output_file"
    echo "    \"account_expires\": \"$account_expires\"" >> "$output_file"
    echo "  }," >> "$output_file"
done

sed -i '$ s/,$//' "$output_file"
echo "]" >> "$output_file"
