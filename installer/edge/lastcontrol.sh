#!/bin/bash

#------------------
# Color Codes
#------------------
MAGENTA="tput setaf 1"
GREEN="tput setaf 2"
YELLOW="tput setaf 3"
DGREEN="tput setaf 4"
CYAN="tput setaf 6"
WHITE="tput setaf 7"
GRAY="tput setaf 8"
RED="tput setaf 9"
NOCOL="tput sgr0"

if [ "$1" = "" ]; then
	echo "Parameter missing.. Usage: lastcontrol --help"
	exit 98
fi

if [ "$1" = "--help" ]; then
	
	clear
	
	${CYAN}
	echo "LastControl CLI"
	${NOCOL}
	echo "---------------------"
	${WHITE}
	echo "Usage: lastcontrol [OPTION]"
	${NOCOL}
	echo "---------------------"
	echo "install             LastControl Install"
	echo "update              Update LastControl App."
	echo "version             Show LastControl Binary Version"
	${CYAN}
	echo "-----------------------------------------------------"
	${NOCOL}
	echo "create              Create all System Report"
	echo "disk                Show System Disk Report"
	echo "localuser           Show System Local User Report"
	echo "unsecurepack        Show Unsecure Package List"
	echo -e
	echo "(example: lastcontrol create)"
	echo "(example: lastcontrol disk)"
	echo "(example: lastcontrol localuser)"
	echo -e

	exit 1
fi

SYSTEM_MANAGER=$(ps --no-headers -o comm 1)
if [ ! "$SYSTEM_MANAGER" = "systemd" ]; then
	echo "This system is not LastControl compatible!!"
	exit 98
fi

#----------------------
# --install PARAMETER
#----------------------
if [ "$1" = "install" ]; then
systemctl stop lastcontrol.service
rm /etc/systemd/system/multi-user.target.wants/lastcontrol.service

cat >> /etc/systemd/system/lastcontrol.service << EOF
[Unit]
Description=LastControl Service

[Service]
User=root
Group=root
ExecStart=/sbin/lastcontrol --create
Restart=always
RestartSec=1hour

[Install]
WantedBy=multi-user.target
EOF

ln -s /etc/systemd/system/lastcontrol.service /etc/systemd/system/multi-user.target.wants/
######chmod -R 755 /usr/local/lastcontrol
######chmod +x /usr/local/lastcontrol/lastcontrol

wget -P /tmp/ -r -np -nH --cut-dirs=1 https://esmerkan.com/lastcontrol/edge/lastcontrol
wget -P /tmp/ -r -np -nH --cut-dirs=1 https://esmerkan.com/lastcontrol/edge/lc-binary/ && rm /tmp/edge/lc-binary/*index.*
cp -r /tmp/edge/lc-binary/* /sbin/
cp /tmp/edge/lastcontrol /sbin/
chmod +x /sbin/lc-*
chmod +x /sbin/lastcontrol

systemctl enable lastcontrol.service
systemctl start lastcontrol.service

fi

#----------------------
# --version PARAMETER
#----------------------
if [ "$1" = "version" ]; then
clear
cat << "EOF"
 _              _    ____            _             _
| |    __ _ ___| |_ / ___|___  _ __ | |_ _ __ ___ | |
| |   / _` / __| __| |   / _ \| '_ \| __| '__/ _ \| |
| |__| (_| \__ \ |_| |__| (_) | | | | |_| | | (_) | |
|_____\__,_|___/\__|\____\___/|_| |_|\__|_|  \___/|_|

V2 Update:27
------------
https://github.com/eesmer/LastControl
EOF
echo -e
exit 99
fi

#----------------------
# --create and show Report PARAMETER
#----------------------

RDIR=/usr/local/lcreports
HNAME=$(cat /etc/hostname)

if [ "$1" = "create" ]; then
	clear
	echo -e
	echo "Report Generating.."
	lc-appsreport
	lc-directoryreport
	lc-diskreport
	lc-inventoryreport
	lc-kernelreport
	lc-localuserreport
	lc-nwconfigreport
	lc-processreport
	lc-servicereport
	lc-sshreport
	lc-suidsgidreport
	lc-systemreport
	lc-unsecurepackreport
	lc-updatereport
	exit 99
elif [ "$1" = "disk" ]; then
	clear
	REPORT=lc-diskreport
	if [ ! -f "$RDIR/$HNAME/$HNAME-$REPORT.txt" ]; then
		echo "Report Not Found!! Please use create option"
		exit 98
	else
		cat $RDIR/$HNAME/$HNAME-$REPORT.txt
		exit 99
	fi
fi
