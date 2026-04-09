#!/bin/bash
ROLES=()
SERVICES=$(systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}')
LISTENING_PORTS=$(ss -tuln | awk '/LISTEN/ {print $4}' | awk -F':' '{print $NF}')

# Web Server
[[ "$SERVICES" =~ nginx\.service|apache2\.service ]] && ROLES+=("WebServer")
# Database
[[ "$SERVICES" =~ mysql\.service|postgresql\.service|mariadb\.service ]] && ROLES+=("DatabaseServer")
[[ "$LISTENING_PORTS" =~ (3306|5432) ]] && [[ ! " ${ROLES[@]} " =~ " DatabaseServer " ]] && ROLES+=("DatabasePort")
# SSH
[[ "$SERVICES" =~ ssh\.service ]] && ROLES+=("SSHServer")
# Docker
[[ "$SERVICES" =~ docker\.service ]] && ROLES+=("DockerHost")

[[ ${#ROLES[@]} -eq 0 ]] && ROLES+=("GenericNode")
ROLE_DATA=$(echo "${ROLES[@]}" | tr ' ' ',')

jq -c -n --arg org "system_info_roles" --arg hn "$(hostname)" --arg data "$ROLE_DATA" \
'{origin: $org, hostname: $hn, info_data: $data}'

