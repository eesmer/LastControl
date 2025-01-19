#!/bin/bash
#----------------------------------------------------------------------------------------
# This script,
# checks Local User accounts and System/Service user accounts.
# Produces outputs regarding passwords, activities and authorizations of the accounts.
#----------------------------------------------------------------------------------------

# User List
list_users() {
    echo -e "\n${YELLOW}--- Local User Accounts ---${RESET}"
    getent passwd | awk -F: '{print $1}'
}

# Real User List
real_user_details() {
    username=$1
    echo -e "\n${CYAN}--- User Details: $username ---${RESET}"
    chage -l "$username"
    echo -e "${CYAN}Last Login:${RESET} $(last -n 1 "$username" | awk '{print $4, $5, $6, $7}')"
    echo -e "${CYAN}Last 10 Login:${RESET}"
    last -n 10 "$username" | awk '{print $4, $5, $6, $7}'
    echo -e "\n${CYAN}Bash History (${username}):${RESET}"
    if [ -f "/home/$username/.bash_history" ]; then
        tail -n 10 "/home/$username/.bash_history"
    else
        echo "Bash History Not Found.."
    fi
}
