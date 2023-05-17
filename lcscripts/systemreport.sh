#!/bin/bash

#--------------------------------------------------------
# This script,
# It produces the report of System and Update checks.
#--------------------------------------------------------

HOST_NAME=$(cat /etc/hostname)
RDIR=/usr/local/lcreports/$HOST_NAME
DATE=$(date)

mkdir -p $RDIR

# Which Distro
cat /etc/redhat-release > $RDIR/distrocheck 2>/dev/null || cat /etc/*-release > $RDIR/distrocheck 2>/dev/null || cat /etc/issue > $RDIR/distrocheck 2>/dev/null
grep -i "debian" $RDIR/distrocheck &>/dev/null && REP=APT && DISTRO=Debian
grep -i "ubuntu" $RDIR/distrocheck &>/dev/null && REP=APT && DISTRO=Ubuntu
grep -i "centos" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=Centos
grep -i "red hat" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=RedHat
grep -i "rocky" /tmp/distrocheck &>/dev/null && REP=YUM && DISTRO=Rocky
rm $RDIR/distrocheck

#----------------------------
# System Information Report
#----------------------------
# OS Info
KERNEL_VER=$(uname -mrs)
OS_VER=$(cat /etc/os-release |grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)
LAST_BOOT=$(who -b | awk '{print $3,$4}')
UPTIME=$(uptime) && UPTIME_MIN=$(awk '{ print "up " $1 /60 " minutes"}' /proc/uptime)

# Disk Usage Info
DISK_USAGE=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | awk '{ print $5" "$1"("$2"  "$3")" " --- "}')

# Ram & Swap Usage Info
RAM_TOTAL=$(free -m |grep Mem |awk '{print $2}')
RAM_USAGE_PERCENTAGE=$(free -m |grep Mem |awk '{print $3/$2 * 100}' |cut -d "." -f1)
OOM=0
grep -i -r 'out of memory' /var/log/ &>/dev/null && OOM=1
if [ "$OOM" = 1 ]; then OOM_LOGS="Out of Memory Log Found !!"; fi

SWAP_TOTAL=$(free -m |grep Swap |awk '{print $2}')
SWP_USAGE_PERCENTAGE=$(free -m |grep Swap |awk '{print $3/$2 * 100}' |cut -d "." -f1)

# Check Service Manager
SERVICE_MANAGER="$(ps --no-headers -o comm 1)"

# Check Time sync
TIME_SYNC=$(timedatectl |grep "synchronized:" |cut -d ":" -f2 |cut -d " " -f2)

# Check Syslog Settings
SYSLOGINSTALL=Not_Installed
if [ "$REP" = APT ]; then
	dpkg -l |grep rsyslog >> /dev/null && SYSLOGINSTALL=Installed
fi
if [ "$REP" = YUM ]; then
	rpm -qa rsyslog >> /dev/null && SYSLOGINSTALL=Installed
fi

if [ "$SYSLOGINSTALL" = Installed ]; then
	SYSLOGSERVICE=Inactive
	systemctl status rsyslog.service |grep "active (running)" >> /dev/null && SYSLOGSERVICE=Active
	SYSLOGSOCKET=Inactive
	systemctl status syslog.socket |grep "active (running)" >> /dev/null && SYSLOGSOCKET=Active
	SYSLOGSEND=No
	cat /etc/rsyslog.conf |grep "@" |grep -v "#" >> /dev/null && SYSLOGSEND=Yes        #??? i will check it
fi

# Check Proxy Settings
HTTP_PROXY_USAGE=FALSE
env |grep "http_proxy" >> /dev/null && HTTP_PROXY_USAGE=TRUE
grep -e "export http" /etc/profile |grep -v "#" >> /dev/null && HTTP_PROXY_USAGE=TRUE
grep -e "export http" /etc/profile.d/* |grep -v "#" >> /dev/null && HTTP_PROXY_USAGE=TRUE

if [ "$REP" = APT ]; then
	grep -e "Acquire::http" /etc/apt/apt.conf.d/* |grep -v "#" >> /dev/null && HTTP_PROXY_USAGE=TRUE
elif [ "$REP" = YUM ]; then
	grep -e "proxy=" /etc/yum.conf |grep -v "#" >> /dev/null && HTTP_PROXY_USAGE=TRUE
fi

# Update Check
CHECK_UPDATE=NONE
UPDATE_COUNT=0

if [ "$REP" = APT ]; then
        echo "n" |apt-get upgrade > $RDIR/update_list.txt
        cat $RDIR/update_list.txt |grep "The following packages will be upgraded:" &>/dev/null && CHECK_UPDATE=EXIST \
                && UPDATE_COUNT=$(cat $RDIR/update_list.txt |grep "upgraded," |cut -d " " -f1)
elif [ "$REP" = YUM ]; then
        yum check-update > $RDIR/update_list.txt
        sed -i '/Loaded/d' $RDIR/update_list.txt
        sed -i '/Loading/d' $RDIR/update_list.txt
        sed -i '/*/d' $RDIR/update_list.txt
        sed -i '/Last metadata/d' $RDIR/update_list.txt
        sed -i '/^$/d' $RDIR/update_list.txt
        UPDATE_COUNT=$(cat $RDIR/update_list.txt |wc -l)
        #rm $RDIR/update_list.txt &>/dev/null

        if [ "$UPDATE_COUNT" -gt 0 ]; then
                CHECK_UPDATE=EXIST
        else
                CHECK_UPDATE=NONE
        fi
fi

# BROKEN PACKAGE CONTROL
BROKEN_COUNT=0
if [ "$REP" = APT ];then
        dpkg -l | grep -v "^ii" &>/dev/null > $RDIR/broken_package.txt
        sed -i -e '1d;2d;3d;4d;5d' $RDIR/broken_package.txt
        BROKEN_COUNT=$(wc -l $RDIR/broken_package.txt |cut -d " " -f1)

        ### ALLOWUNAUTH=$(grep -v "^#" /etc/apt/ -r | grep -c "AllowUnauthenticated")
        ### if [ $ALLOWUNAUTH = 0 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
        ### DEBSIG=$(grep -v "^#" /etc/dpkg/dpkg.cfg |grep -c no-debsig)
        ### if [ $DEBSIG = 1 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
fi

if [ "$REP" = YUM ];then
        rpm -Va >> /dev/null > $RDIR/broken_package.txt
        BROKEN_COUNT=$(wc -l $RDIR/broken_package.txt |cut -d " " -f1)
fi

rm $RDIR/$HOST_NAME-systemreport.*

cat > $RDIR/$HOST_NAME-systemreport.md<< EOF

---
title: System Information Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![](/tmp/lastcontrol_logo.png){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

### Distro / OS ###
* $DISTRO
- $OS_VER

### Kernel Version ###
* $KERNEL_VER

---

Last Boot :
 ~ $LAST_BOOT

Uptime :
 ~ $UPTIME $UPTIME_MIN

Disk Usage :
 ~ $DISK_USAGE

---

Total Ram & Usage :
 ~ $RAM_TOTAL MB - %$RAM_USAGE_PERCENTAGE

Total Swap & Usage : 
 ~ $SWAP_TOTAL MB - %$SWP_USAGE_PERCENTAGE

Out of Memory Logs :
 ~ $OOM_LOGS

---

Service Manager :
 ~ $SERVICE_MANAGER

Time Sync :
 ~ $TIME_SYNC

Syslog Usage :
 ~ $SYSLOGINSTALL - Service: $SYSLOGSERVICE - Socket: $SYSLOGSOCKET - LogSend: $SYSLOGSEND

HTTP Proxy Usage :
 ~ $HTTP_PROXY_USAGE

---

Update Check :
 ~ $CHECK_UPDATE

Update Count : 
 ~ $UPDATE_COUNT

---
EOF

cat > $RDIR/$HOST_NAME-systemreport.txt << EOF

|---------------------------------------------------------------------------------------------------
| ::. System Information Report .:: 
|---------------------------------------------------------------------------------------------------
|DISTRO / OS        | $DISTRO | $OS_VER
|KERNEL VERSION     | $KERNEL_VER
|LAST BOOT          | $LAST_BOOT
|UPTIME             | $UPTIME | $UPTIME_MIN
|----------------------------------------------------------------------------------------------------
|DISK USAGE         | $DISK_USAGE
|----------------------------------------------------------------------------------------------------
|RAM USAGE          | %$RAM_USAGE_PERCENTAGE --- TotalRam:  $RAM_TOTAL
|SWAP USAGE         | %$SWP_USAGE_PERCENTAGE --- TotalSwap: $SWAP_TOTAL
|Out of Memory Logs | $OOM_LOGS 
|----------------------------------------------------------------------------------------------------
|SERVICE MANAGER    | $SERVICE_MANAGER
|TIME SYNC          | $TIME_SYNC
|SYSLOG USAGE       | Install: $SYSLOGINSTALL --- Service: $SYSLOGSERVICE --- Socket: $SYSLOGSOCKET --- LogSend: $SYSLOGSEND
|HTTP PROXY USAGE   | $HTTP_PROXY_USAGE
|----------------------------------------------------------------------------------------------------

EOF

if [ ! "$BROKEN_COUNT" = 0 ];then
        sed -i '$d' $RDIR/$HOST_NAME-systemreport.txt
	echo "" >> $RDIR/$HOST_NAME-systemreport.md
        echo "Broken Package Count :" >> $RDIR/$HOST_NAME-systemreport.md
	echo " ~ $BROKEN_COUNT" >> $RDIR/$HOST_NAME-systemreport.md
	echo "" >> $RDIR/$HOST_NAME-systemreport.md
	echo "---" >> $RDIR/$HOST_NAME-systemreport.md

	echo "| BROKEN PACKAGES" >> $RDIR/$HOST_NAME-systemreport.txt
	echo "|----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-systemreport.txt
        cat $RDIR/broken_package.txt >> $RDIR/$HOST_NAME-systemreport.txt
        echo "----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-systemreport.txt
fi
