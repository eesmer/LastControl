#!/bin/bash

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

