#!/bin/bash

#---------------------------------------------
# LastControl Check Roles
# This script finds Server Roles by listing the roles and services on the machine it is running on
#---------------------------------------------

source /root/LastControl/scripts/common.sh

CHECK_ROLES() {
$BLUE
echo "Discovering server roles.."
$NOCOL
ROLES=()
SERVICES=$(systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}')
if [[ ! $NETSTATP == FALSE ]]; then
        LISTENING_PORTS=$(netstat -tuln | awk '/LISTEN/ {print $4}' | awk -F':' '{print $NF}')
fi

# Web Server
if echo "$SERVICES" | grep -qE "nginx\.service|apache2\.service"; then
        ROLES+=("WebServer_Detected")
elif echo "$LISTENING_PORTS" | grep -qE "^80$|^443$"; then
	ROLES+=("Port_80/443_Detected(WebService)")
fi

# Database Server
if echo "$SERVICES" | grep -qE "mysql\.service|postgresql\.service|mariadb\.service"; then
        ROLES+=("DatabaseServer_Detected")
elif echo "$LISTENING_PORTS" | grep -qE "^3306$|^5432$"; then
        ROLES+=("Port_3306/5432_Detected(DBServer)")
fi

# SSH Server
if echo "$SERVICES" | grep -qE "sshd\.service"; then
    ROLES+=("SSHServer_Detected")
elif echo "$LISTENING_PORTS" | grep -qE "^22$"; then
	ROLES+=("Port_22_Detected(SSHServer)")
fi

# FTP Server
if echo "$SERVICES" | grep -qE "vsftpd\.service|proftpd\.service|pure-ftpd\.service"; then
    ROLES+=("FTPServer_Detected")
elif echo "$LISTENING_PORTS" | grep -qE "^21$"; then
	ROLES+=("Port_21_Detected(FTPServer)")
fi

# Docker Host
DOCKERHOST=FALSE
DOCKERSERVICE=FALSE
if echo "$SERVICES" | grep -qE "docker\.service"; then
        DOCKERHOST=TRUE
        ROLES+=("DockerServer_Detected")
elif echo "$LISTENING_PORTS" | grep -qE "^2375$|^2376$"; then
        DOCKERSERVICE=TRUE
        ROLES+=("Port_2357/2376_Detected(DockerHost")
fi

if [ ${#ROLES[@]} -eq 0 ]; then
    ROLES+=("No Role Detected")
fi
}
