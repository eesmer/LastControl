#!/bin/bash

#--------------------------------------------------------
# This script,
# It produces the report of System and Update checks.
#--------------------------------------------------------

HOST_NAME=$(cat /etc/hostname)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
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
# System Update Report
#----------------------------
if [ "$REP" = APT ]; then
    apt list --upgradable | grep -v "Listing" > /tmp/updateinfo.txt
        UPGRADEPACK=$(cat /tmp/updateinfo.txt | wc -l)
	echo n | apt upgrade | grep "upgraded" | grep -v "The following packages will be" > /tmp/updateinfo.txt
	NEWINSTALL=$(cat /tmp/updateinfo.txt | cut -d "," -f2 | xargs | cut -d " " -f1)

	TOTALDOWNLOAD=$(cat /tmp/updatecheck.txt | grep "Total download size:" | cut -d ":" -f2 | xargs)
	IMPUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Important Security" | xargs)
        MODUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Moderate Security" | xargs)
        LOWUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Low Security" | xargs)
        BUGFIXCOUNT=$(cat /tmp/updateinfo.txt |grep "Bugfix" | xargs)
fi
if [ "$REP" = YUM ]; then
	# check update for system
	echo N | yum update > /tmp/updatecheck.txt 2>/dev/null
	UPGRADEPACK=$(cat /tmp/updatecheck.txt | grep "Upgrade" | grep "Packages")
	NEWINSTALL=$(cat /tmp/updatecheck.txt | grep "Install" | grep "Packages")
	TOTALDOWNLOAD=$(cat /tmp/updatecheck.txt | grep "Total download size:" | cut -d ":" -f2 | xargs)
	
	# check update for security packages
	yum updateinfo --installed > /tmp/updateinfo.txt
	IMPUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Important Security" | xargs)
	MODUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Moderate Security" | xargs)
	LOWUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Low Security" | xargs)
	BUGFIXCOUNT=$(cat /tmp/updateinfo.txt |grep "Bugfix" | xargs)
fi

cat > $RDIR/$HOST_NAME-updatereport.txt << EOF

|---------------------------------------------------------------------------------------------------
| ::. System Update Report .:: 
|---------------------------------------------------------------------------------------------------
|Packages to Update/Upgrade | $UPGRADEPACK
|Packages to New Install    | $NEWINSTALL
|---------------------------------------------------------------------------------------------------
| ::. Security Update Report .:: 
|---------------------------------------------------------------------------------------------------
|Important Security Update  | $IMPUPDATECOUNT
|Moderate  Security Update  | $MODUPDATECOUNT
|Low       Security Update  | $LOWUPDATECOUNT
|---------------------------------------------------------------------------------------------------
|Bugfixes                   | $BUGFIXCOUNT
|----------------------------------------------------------------------------------------------------
|Total Download Size        | $TOTALDOWNLOAD
|---------------------------------------------------------------------------------------------------

EOF

exit 1

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

### Unsecure Package Check ###

FTP INSTALL:
 ~ $FTP_INSTALL

TELNET INSTALL:
 ~ $TELNET_INSTALL

RSH INSTALL:
 ~ $RSH_INSTALL

NIS INSTALL:
 ~ $NIS_INSTALL

YPTOOLS INSTALL:
 ~ $YPTOOLS_INSTALL

XINET INSTALL:
 ~ $XINET_INSTALL

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
|FTP INSTALL:       |$FTP_INSTALL
|TELNET INSTALL:    |$TELNET_INSTALL
|RSH INSTALL:       |$RSH_INSTALL
|NIS INSTALL:       |$NIS_INSTALL
|YPTOOLS INSTALL:   |$YPTOOLS_INSTALL
|XINET INSTALL:     |$XINET_INSTALL
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
