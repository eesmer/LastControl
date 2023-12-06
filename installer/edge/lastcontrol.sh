#!/bin/bash

if [ "$1" = "" ]; then
	echo "Parameter missinig.. Usage: lastcontrol --create"
	exit 98
fi

if [ "$1" = "--help" ]; then
	
	clear

	echo "LastControl CLI"
	echo "---------------------"
	echo "Usage: lastcontrol [OPTION]"
	echo "---------------------"
	echo "--ver                 Show LastControl Binary Version"
	echo "--create              Create all System Report"
	echo "--disk                Show System Disk Report"
	echo "--localuser           Show System Local User Report"
	echo "--unsecurepack        Show Unsecure Package List"
	echo -e
	echo "(example: lastcontrol --create)"
	echo "(example: lastcontrol --disk)"
	echo "(example: lastcontrol --localuser)"

	exit 1
fi

SYSTEM_MANAGER=$(ps --no-headers -o comm 1)
if [ ! "$SYSTEM_MANAGER" = "systemd" ]; then
	echo "This system is not LastControl compatible!!"
	exit 98
fi

RDIR=/usr/local/lcreports
HNAME=$(cat /etc/hostname)

if [ "$1" = "--ver" ]; then
	clear
	echo -e
	echo "LastControl 2 Update:27"
	exit 99
fi

if [ "$1" = "--create" ]; then
	clear
	echo -e
	echo "Report Generating.."
	#systemctl restart lastcontrol.service
	diskreport
	unsecurepackreport
	localuserreport
	exit 99
elif [ "$1" = "--disk" ]; then
	clear
	REPORT=diskreport
	if [ ! -f "$RDIR/$HNAME/$HNAME-$REPORT.txt" ]; then
		echo "Report Not Found!! Please use --create option"
		exit 98
	else
		cat $RDIR/$HNAME/$HNAME-$REPORT.txt
		exit 99
	fi
fi
