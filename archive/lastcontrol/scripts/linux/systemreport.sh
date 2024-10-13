#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

HOST_NAME=$(cat /etc/hostname)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

#----------------------------
# determine distro/repo
#----------------------------
cat /etc/*-release /etc/issue > "$RDIR/distrocheck"
if grep -qi "debian\|ubuntu" "$RDIR/distrocheck"; then
    REP=APT
elif grep -qi "centos\|rocky\|red hat" "$RDIR/distrocheck"; then
    REP=YUM
fi
rm $RDIR/distrocheck

#----------------------------
# System Information Report
#----------------------------
# OS Info
KERNEL_VER=$(uname -mrs)
OS_VER=$(cat /etc/os-release |grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)
LAST_BOOT=$(who -b | awk '{print $3,$4}')
UPTIME=$(uptime) && UPTIME_MIN=$(awk '{ print "up " $1 /60 " minutes"}' /proc/uptime)
UTC_TIME=$(date --utc "+%Y-%m-%d %T")
TIME_SYNC=$(timedatectl |grep "synchronized:" |cut -d ":" -f2 | xargs)
ping -c 1 google.com &> /dev/null && INTERNET="CONNECTED" || INTERNET="DISCONNECTED"

# Grub Control
if [ "$REP" = APT ]; then
        GRUB_EXIST=Fail
        dpkg -l |grep -w "grub" &>/dev/null && GRUB_EXIST=GRUB
        dpkg -l |grep -w "grub2" &>/dev/null && GRUB_EXIST=GRUB2

        if [ "$GRUB_EXIST" = "GRUB" ]; then
                GRUB_PACKAGE=$(dpkg -l |grep -w "grub" |grep "common")
        elif [ "$GRUB_EXIST" = "GRUB2" ]; then
                GRUB_PACKAGE=$(dpkg -l |grep -w "grub2" |grep "common")
        elif [ "$GRUB_EXIST" = "Fail" ]; then
                GRUB_PACKAGE="Fail"
        fi
        # GRUB Security
        GRUB_SEC=Fail
        grep "set superusers=" /etc/grub.d/* &>/dev/null && GRUB_SEC=Pass

elif [ "$REP" = YUM ]; then
        GRUB_EXIST=Fail
        rpm -qa |grep -w "grub" &>/dev/null && GRUB_EXIST=GRUB
        rpm -qa |grep -w "grub2" &>/dev/null && GRUB_EXIST=GRUB2

        if [ "$GRUB_EXIST" = "GRUB" ]; then
                GRUB_PACKAGE=$(rpm -qa |grep -w "grub" |grep "common")
        elif [ "$GRUB_EXIST" = "GRUB2" ]; then
                GRUB_PACKAGE=$(rpm -qa |grep -w "grub2" |grep "common")
        elif [ "$GRUB_EXIST" = "Fail" ]; then
                GRUB_PACKAGE="Fail"
        fi
        # GRUB Security
        GRUB_SEC=Fail
        grep "set superusers=" /etc/grub.d/* &>/dev/null && GRUB_SEC=Pass
fi

# Disk Usage Info
DISK_USAGE=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | awk '{ print $5" "$1"("$2"  "$3")" " --- "}'| grep -v "dev/loop")

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
                && UPDATE_COUNT=$(cat $RDIR/update_list.txt |grep "upgraded," | awk '{ print $1 }')
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

# Recently used commands list
#history | awk '{cmd[$2]++} END {for(elem in cmd) {print cmd[elem] " " elem}}' | sort -n -r | head -10 | cut -d " " -f2

cat > $RDIR/$HOST_NAME-systemreport.md << EOF

---
title: System Information Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

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

UTC Time :
 ~ $UTC_TIME

Time Sync :
 ~ $TIME_SYNC

---

Grub Exist :
 ~ $GRUB_EXIST

Grub Security :
 ~ $GRUB_SEC

---

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
|UTC TIME           | $UTC_TIME
|TIME SYNC          | $TIME_SYNC
|Internet Conn.     | $INTERNET
|----------------------------------------------------------------------------------------------------
|GRUB EXIST         | $GRUB_EXIST
|GRUB SECURITY      | $GRUB_SEC
|----------------------------------------------------------------------------------------------------
|DISK USAGE         | $DISK_USAGE
|----------------------------------------------------------------------------------------------------
|RAM USAGE          | %$RAM_USAGE_PERCENTAGE --- TotalRam:  $RAM_TOTAL
|SWAP USAGE         | %$SWP_USAGE_PERCENTAGE --- TotalSwap: $SWAP_TOTAL
|Out of Memory Logs | $OOM_LOGS 
|----------------------------------------------------------------------------------------------------
|SERVICE MANAGER    | $SERVICE_MANAGER
|SYSLOG USAGE       | Install: $SYSLOGINSTALL --- Service: $SYSLOGSERVICE --- Socket: $SYSLOGSOCKET --- LogSend: $SYSLOGSEND
|HTTP PROXY USAGE   | $HTTP_PROXY_USAGE
|----------------------------------------------------------------------------------------------------
|UPDATE CHECK       | $CHECK_UPDATE
|UPDATE COUNT       | $UPDATE_COUNT
|----------------------------------------------------------------------------------------------------
EOF

cat > $RDIR/$HOST_NAME-systemreport.json << EOF
{
    "SystemReport": {
        "DISTRO/OS": "$DISTRO - $OS_VER",
        "Kernel Version": "$KERNEL_VER",
        "Last Boot": "$LAST_BOOT",
        "Uptime": "$UPTIME - $UPTIME_MIN",
        "UTC Time": "$UTC_TIME",
        "Time Sync": "$TIME_SYNC",
        "Grub Exist": "$GRUB_EXIST",
        "Grub Security": "$GRUB_SEC",
        "Ram Usage": "Total Ram:$RAM_TOTAL - %$RAM_USAGE_PERCENTAGE",
        "Swap Usage": "Total Swap:$SWAP_TOTAL - %$SWP_USAGE_PERCENTAGE",
        "Out Of Memory": "$OOM_LOGS",
        "Service Manager": "$SERVICE_MANAGER",
        "Syslog Usage": "Install:$SYSLOGINSTALL - Service:$SYSLOGSERVICE - Socket:$SYSLOGSOCKET - LogSend:$SYSLOGSEND",
        "HTTP Proxy Usage": "$HTTP_PROXY_USAGE",
        "Update Check": "$CHECK_UPDATE",
        "Update Count": "$UPDATE_COUNT"
    }
}
EOF
