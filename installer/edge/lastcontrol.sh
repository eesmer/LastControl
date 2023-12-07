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

function help(){
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
	echo "appsreport          Show Application List"
	echo "directoryreport     Show System Directory Report"
	echo "diskreport          Show System Disk Report"
	echo "inventoryreport     Show Inventory Report"
	echo "kernelreport        Show Kernel Report"
	echo "localuserreport     Show Local User Report"
	echo "nwconfigreport      Show Network Config Report"
	echo "processreport       Show Process Report"
	echo "servicereport       Show Service Report"
	echo "sshreport           Show SSH Config Report"
	echo "suidsgidreport      Show SUID/SGID Report"
	echo "systemreport        Show System Report"
	echo "unsecurepackreport  Show UnSecure Pack. List"
	echo "updatereport        Show Update Report"

	echo -e
	echo "(example: lastcontrol create)"
	echo "(example: lastcontrol disk)"
	echo "(example: lastcontrol localuser)"
	echo -e

	exit 1
}

if [ "$1" = "" ]; then
	${RED}
	echo "Parameter missing.."
	${GRAY}
	echo "Usage: lastcontrol --help"
	${NOCOL}
	exit 98
fi

if [ "$1" = "--help" ]; then
	help
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

cat > /etc/systemd/system/lastcontrol.service << EOF
[Unit]
Description=LastControl Service

[Service]
User=root
Group=root
ExecStart=/sbin/lastcontrol create
Restart=always
RestartSec=1hour

[Install]
WantedBy=multi-user.target
EOF

ln -s /etc/systemd/system/lastcontrol.service /etc/systemd/system/multi-user.target.wants/
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
elif [ "$1" = "appsreport" ]; then
	clear
	REPORT=appsreport
	if [ ! -f "$RDIR/$HNAME/$HNAME-$REPORT.txt" ]; then
		echo "Report Not Found!! Please use create option"
		exit 98
	else
		cat $RDIR/$HNAME/$HNAME-$REPORT.txt
		exit 99
	fi
elif [ "$1" = "directoryreport" ]; then
	clear
	REPORT=directoryreport
	if [ ! -f "$RDIR/$HNAME/$HNAME-$REPORT.txt" ]; then
		echo "Report Not Found!! Please use create option"
		exit 98
	else
		cat $RDIR/$HNAME/$HNAME-$REPORT.txt
		exit 99
	fi
elif [ "$1" = "diskreport" ]; then
	clear
	REPORT=diskreport
	if [ ! -f "$RDIR/$HNAME/$HNAME-$REPORT.txt" ]; then
		echo "Report Not Found!! Please use create option"
		exit 98
	else
		cat $RDIR/$HNAME/$HNAME-$REPORT.txt
		exit 99
	fi
elif [ "$1" = "inventoryreport" ]; then
	clear
	REPORT=inventoryreport
	if [ ! -f "$RDIR/$HNAME/$HNAME-$REPORT.txt" ]; then
		echo "Report Not Found!! Please use create option"
		exit 98
	else
		cat $RDIR/$HNAME/$HNAME-$REPORT.txt
		exit 99
	fi
elif [ "$1" = "kernelreport" ]; then
	clear
	REPORT=kernelreport
	if [ ! -f "$RDIR/$HNAME/$HNAME-$REPORT.txt" ]; then
		echo "Report Not Found!! Please use create option"
		exit 98
	else
		cat $RDIR/$HNAME/$HNAME-$REPORT.txt
		exit 99
	fi
elif [ "$1" = "localuserreport" ]; then
	clear
	REPORT=localuserreport
	if [ ! -f "$RDIR/$HNAME/$HNAME-$REPORT.txt" ]; then
		echo "Report Not Found!! Please use create option"
		exit 98
	else
		cat $RDIR/$HNAME/$HNAME-$REPORT.txt
		exit 99
	fi
else
	help
fi
