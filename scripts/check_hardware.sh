#!/bin/bash

#---------------------------------------------
# LastControl Check Roles
# This script creates hardware inventory.
#---------------------------------------------

source ./common.sh

CHECK_HARDWARE() {
$BLUE
echo "Checking Hardware Inventory"
$NOCOL

INTERNAL_IP=$(hostname -I | cut -d " " -f1)
EXTERNAL_IP=$(curl -4 icanhazip.com 2>/dev/null)
CPU_INFO=$(awk -F ':' '/model name/ {print $2}' /proc/cpuinfo | head -n 1 | xargs)
RAM_TOTAL=$(free -m | awk 'NR==2{print $2 " MB"}')
RAM_USAGE=$(free -m | awk 'NR==2{print $3 " MB"}')
GPU_INFO=$(lspci | grep -i vga | cut -d ':' -f3)
GPU_RAM=$(lspci -v | awk '/ prefetchable/{print $6}' | head -n 1)
DISK_LIST=$(lsblk -o NAME,SIZE -d -e 11,2 | tail -n +2 | grep -v "loop")
###DISK_INFO=$(df -h --total | awk 'END{print}')
###DISK_USAGE=$(fdisk -lu | grep "Disk" | grep -v "Disklabel" | grep -v "dev/loop" | grep -v "Disk identifier")
DISK=$(lsblk | grep "disk" | awk {'print $1'})
DISK_USAGE=$(df -lh | grep "$DISK" | awk {'print $5'})
WIRELESS=$(ip link show | grep -q "wl")

if [[ -z $WIRELESS ]]; then
	lspci | grep -i "network" | grep -E -i "wireless|wi[-]?fi"
fi

if [[ ! -z $WIRELESS ]]; then WIRELESS_ADAPTER="Wireless Adapter Found"; else WIRELESS_ADAPTER="Wireless Adapter Not Found"; fi
lspci | grep -i "network" | grep -E -i "wireless|wi[-]?fi"
ping -c 1 google.com &> /dev/null && INTERNET="CONNECTED" || INTERNET="DISCONNECTED"
}
