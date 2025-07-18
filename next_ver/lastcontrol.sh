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

HOSTNAME=$(cat /etc/hostname)
INTERNALIP=$(hostname -I | cut -d " " -f1)
EXTERNALIP=$(curl -4 icanhazip.com 2>/dev/null)
GCPU=$(awk -F ':' '/model name/ {print $2}' /proc/cpuinfo | head -n 1 | xargs)
RAM=$(free -m | awk 'NR==2{print $2 " MB"}')
DISK_LIST=$(lsblk -o NAME,SIZE -d -e 11,2 | tail -n +2 | grep -v "loop")
GPU_INFO=$(lspci | grep -i vga | cut -d ':' -f3)
GPU_RAM=$(lspci -v | awk '/ prefetchable/{print $6}' | head -n 1)
WIRELESS=$(ip link show | grep -q "wl")
        if [[ -z $WIRELESS ]]; then
                lspci | grep -i "network" | grep -E -i "wireless|wi[-]?fi"
        fi
        if [[ ! -z $WIRELESS ]]; then WIRELESS_ADAPTER="Wireless Adapter Found"; else WIRELESS_ADAPTER="Wireless Adapter Not Found"; fi
        lspci | grep -i "network" | grep -E -i "wireless|wi[-]?fi"
ping -c 1 google.com &> /dev/null && INTERNET="CONNECTED" || INTERNET="DISCONNECTED"
DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f2)
KERNEL=$(uname -sr)
UPTIME=$(uptime | xargs) && UPTIME_MIN=$(awk '{print "up", $1/60, "minutes"}' /proc/uptime)
LAST_BOOT=$(uptime -s)
VIRT_CONTROL=NONE
[ -e "/dev/kvm" ] && VIRT_CONTROL=ON
LOCAL_DATE=$(timedatectl status | awk '/Local time:/ {print $3,$4,$5}')
TIME_SYNC=$(timedatectl status | awk '/synchronized:/ {print $4}')
TIME_ZONE=$(timedatectl status | awk -F ': ' '/Time zone:/ {print $2}')
HTTP_PROXY_USAGE=FALSE
{ env | grep -q "http_proxy"; } || { grep -q -e "export http" /etc/profile /etc/profile.d/*; } && HTTP_PROXY_USAGE=TRUE

# Out of Memory
OOM=0
grep -i -r 'out of memory' /var/log/ &>/dev/null && OOM=1
OOM_LOGS="None"
if [ "$OOM" = "1" ]; then OOM_LOGS="Out of Memory Log Found !!"; fi

# Quota Check
if command -v quotacheck &> /dev/null; then
        QUOTA_INSTALL=Pass
else
        QUOTA_INSTALL=Fail
fi
if grep -q -E 'usrquota|grpquota' /proc/mounts; then
        USR_QUOTA=Pass
        GRP_QUOTA=Pass
        MNT_QUOTA=Pass
else
        USR_QUOTA=Fail
        GRP_QUOTA=Fail
        MNT_QUOTA=Fail
fi

# LVM CRYPT Check
if lsblk --output type | grep -qw "lvm"; then
        LVM_USAGE=Pass
else
        LVM_USAGE=Fail
fi
if command -v cryptsetup &> /dev/null && lsblk --output type | grep -qw "crypt"; then
        CRYPT_INSTALL=Pass
        CRYPT_USAGE=Pass
else
        CRYPT_INSTALL=Fail
        CRYPT_USAGE=Fail
fi
