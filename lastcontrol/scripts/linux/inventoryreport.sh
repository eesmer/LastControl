#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

#--------------------------------------------
# MACHINE INVENTORY
#--------------------------------------------
INTERNAL_IP=$(hostname -I)
EXTERNAL_IP=$(curl -4 icanhazip.com)
CPU_INFO=$(cat /proc/cpuinfo |grep "model name" |cut -d ":" -f2 > $RDIR/cpuinfooutput.txt \
	&& tail -n1 $RDIR/cpuinfooutput.txt > $RDIR/cpuinfo.txt \
	&& rm $RDIR/cpuinfooutput.txt && cat $RDIR/cpuinfo.txt) \
	&& rm $RDIR/cpuinfo.txt &>/dev/null
RAM_TOTAL=$(free -m |grep Mem |awk '{print $2}')
RAM_USAGE=$(free -m |grep Mem |awk '{print $3}')
GPU_INFO=$(lspci |grep VGA |cut -d ":" -f3);GPURAM=$(cardid=$(lspci |grep VGA |cut -d " " -f1);lspci -v -s $cardid |grep "prefetchable" |awk '{print $6}' |head -1)
VGA_CONTROLLER="$GPU $GPURAM"

#WIRELESS ADAPTER
update-pciids
lspci | egrep -i 'wifi|wireless' > $RDIR/$HOST_NAME.wifi
	if [ -s "$RDIR/$HOST_NAME.wifi" ];then
		WIRELESS_ADAPTER=EXIST
	else
		WIRELESS_ADAPTER=NONE
	fi
rm $RDIR/$HOST_NAME.wifi &>/dev/null

DISK_LIST=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | grep -v "dev/loop" | awk '{ print $5" "$1"("$2"  "$3")" " --- "}' | sed -e :a -e N -e 's/\n/ /' -e ta)
VIRT_SET=OFF
if [ -f "/dev/kvm" ]; then $VIRT_SET=ON; fi
OS_KERNEL=$(uname -a)
OS_VER=$(cat /etc/os-release |grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)
LAST_BOOT=$(who -b | awk '{print $3,$4}')
UPTIME=$(uptime) && UPTIME_MIN=$(awk '{ print "up " $1 /60 " minutes"}' /proc/uptime)

cat > $RDIR/$HOST_NAME-inventoryreport.md<< EOF

---
title: Hardware Inventory Information Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

Hostname :
 ~ $HOST_NAME

IP Address :
 ~ $INTERNAL_IP - $EXTERNAL_IP

Internet Connection : 
 ~ $INTERNET

CPU Info :
 ~ $CPU_INFO

Ram :
 ~ $RAM_TOTAL

VGA Controller :
 ~ $VGA_CONTROLLER

Wireless Adapter :
 ~ $WIRELESS_ADAPTER

HDD :
 ~ $DISK_LIST

Virtualization :
 ~ $VIRT_SET

Operation System :
 ~ $OS_KERNEL

OS Version :
 ~ $OS_VER

---

Last Boot :
 ~ $LAST_BOOT

Uptime :
 ~ $UPTIME - $UPTIME_MIN

---
EOF

cat > $RDIR/$HOST_NAME-inventoryreport.txt << EOF
====================================================================================================
:::. $HOST_NAME MACHINE INVENTORY REPORT :::.
====================================================================================================
$DATE
----------------------------------------------------------------------------------------------------
|Hostname:          |$HOST_NAME
|IP Address:        |$INTERNAL_IP | $EXTERNAL_IP
----------------------------------------------------------------------------------------------------
|CPU Info:          |$CPU_INFO
|RAM:               |Total:$RAM_TOTAL
|VGA Controller:    |$VGA_CONTROLLER
|Wireless Adapter:  |$WIRELESS_ADAPTER
|HDD:               |$DISK_LIST
|Virtualization:    |$VIRT_SET
|Operation System:  |$OS_KERNEL
|OS Version:        |$OS_VER
|Last Boot:         |$LAST_BOOT
|Uptime             |$UPTIME | $UPTIME_MIN
-----------------------------------------------------------------------------------------------------

===================================================================================================
EOF

cat > $RDIR/$HOST_NAME-inventoryreport.json << EOF
{
    "InventoryReport": {
        "Hostname": "$HOST_NAME",
        "IP Address": "$INTERNAL_IP - $EXTERNAL_IP",
        "Internet Conn.": "$INTERNET",
        "CPU": "$CPU_INFO",
        "Total Ram": "$RAM_TOTAL",
        "HDD": "$DISK_LIST",
        "VGA Controller": "$VGA_CONTROLLER",
        "Wireless Adaptor": "$WIRELESS_ADAPTER",
        "Virtualization": "$VIRT_SET",
        "Operation System": "$OS_KERNEL",
        "OS Version": "$OS_VER",
        "Last Boot": "$LAST_BOOT",
        "Uptime": "$UPTIME - $UPTIME_MIN"
    }
}
EOF
