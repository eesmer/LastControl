#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

RDIR=/usr/local/lastcontrol-reports
rm -r $RDIR
mkdir -p $RDIR

#############################
# determine distro
#############################
cat /etc/redhat-release > $RDIR/distrocheck || cat /etc/*-release > $RDIR/distrocheck || cat /etc/issue > $RDIR/distrocheck
grep -i "debian" $RDIR/distrocheck &> /dev/null && REP=APT
grep -i "ubuntu" $RDIR/distrocheck &> /dev/null && REP=APT
grep -i "centos" $RDIR/distrocheck &> /dev/null && REP=YUM
grep -i "rocky" $RDIR/distrocheck &> /dev/null && REP=YUM
grep -i "red hat" $RDIR/distrocheck &> /dev/null && REP=YUM
#cat /etc/*-release | grep "NAME=" | grep -v "PRETTY_NAME" | grep -v "CPE_NAME" | cut -d "=" -f2
rm $RDIR/distrocheck

######################
# Create TXT Report File
######################
rm $RDIR/$HOST_NAME.txt
cat > $RDIR/$HOST_NAME.txt << EOF
$HOST_NAME LastControl Report $DATE
=======================================================================================================================================================================
--------------------------------------------------------------------------------------------------------------------------
| INVENTORY
--------------------------------------------------------------------------------------------------------------------------
|Hostname:          |$HOST_NAME
|IP Address:        |$INT_IPADDR | $EXT_IPADDR
|Internet Conn.     |$INTERNET   | Installation Check: $INSTALL_CHECK
--------------------------------------------------------------------------------------------------------------------------
|CPU Info:          |$CPUINFO
|RAM:               |Total:$RAM_TOTAL | Usage:$RAM_USAGE
|VGA Controller:    |$VGA_CONTROLLER
|HDD:               |$DISK_LIST
|Virtualization:    |$VIRT_CONTROL
|Operation System:  |$OS_KERNEL
|OS Version:        |$OS_VER
|Check Update:      |$CHECK_UPDATE
|Update Count:      |$SYSUPDATE_COUNT
|Last Boot:         |$LAST_BOOT
|Uptime             |$UPTIME | $UPTIME_MIN
|Kernel Version:    |$OS_KERNEL
--------------------------------------------------------------------------------------------------------------------------
|Date/Time Sync:    |System clock synchronized:$TIME_SYNC
|Proxy Usage:       |HTTP: $HTTPPROXY_USE
|SYSLOG Usage:      |$SYSLOGINSTALL | $SYSLOGSERVICE | Socket: $SYSLOGSOCKET | Send: $SYSLOGSEND
--------------------------------------------------------------------------------------------------------------------------
|Listening Conn.:   |$LISTENINGCONN
|Established Conn.: |$ESTABLISHEDCONN
--------------------------------------------------------------------------------------------------------------------------
| RESOURCE
--------------------------------------------------------------------------------------------------------------------------
|Ram  Usage:        |$RAM_USAGE_PERCENTAGE%
|Swap Usage:        |$SWAP_USAGE_PERCENTAGE%
|Disk Usage:        |$DISK_USAGE
--------------------------------------------------------------------------------------------------------------------------
| SERVICES
--------------------------------------------------------------------------------------------------------------------------
|Running Services:  |$NUM_SERVICES
|Services Info:     |Loaded: | Active: | Failed: | Inactive:
--------------------------------------------------------------------------------------------------------------------------
| PROCESS
--------------------------------------------------------------------------------------------------------------------------
|Process Info:      |Total:$TO_PROCESS | Running:$RU_PROCESS | Sleeping:$SL_PROCESS
|Stopping Process:  |$ST_PROCESS
|Zombie Process:    |$ZO_PROCESS
--------------------------------------------------------------------------------------------------------------------------
| USERS
--------------------------------------------------------------------------------------------------------------------------
|SUDO Member Count: |$SUDOMEMBERCOUNT
|Local User Count:  |$LOCALUSER_COUNT
--------------------------------------------------------------------------------------------------------------------------
| KERNEL
--------------------------------------------------------------------------------------------------------------------------
|CRAMFS             |$CRAMFS
|FREEVXFS           |$FREEVXFS
|JFFS2              |$JFFS2
|HFS                |$HFS
|HFSPLUS            |$HFSPLUS
|SQUASHFS           |$SQUASHFS
|UDF                |$UDF
--------------------------------------------------------------------------------------------------------------------------
| VULNERABILITY
--------------------------------------------------------------------------------------------------------------------------
|LOG4J/LOG4SHELL    |$LOG4J_EXIST
--------------------------------------------------------------------------------------------------------------------------
|Disk Quota Usage:  |$QUOTA_INSTALL | Usr_Quota: $USR_QUOTA | Grp_Quota: $GRP_QUOTA | Mount: $MNT_MOUNT
|Disk Encrypt Usage:|$CRYPT_INSTALL | $CRYPT_Usage
|LVM Usage:         |$LVM_Usage
--------------------------------------------------------------------------------------------------------------------------
| UPDATE
--------------------------------------------------------------------------------------------------------------------------
|Update             |$SYSUPDATE_COUNT
|Install Package    |$INSTALLPACK
|BugFix Update      |$BUGFIX
|Sec. Updated       |$SECUPDATE_COUNT
|Critical Update    |$CRITICALPACKAGE
|High-Medium-Low    |$IMMUPDATE_COUNT - $MODERATEPACKAGE - $LOWPACKAGE
|Total Download     |$TOTALDOWNLOAD
--------------------------------------------------------------------------------------------------------------------------
EOF
