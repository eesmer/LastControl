#!/bin/bash

RDIR=/usr/local/lcreports
HNAME=$(cat /etc/hostname)

if [ "$1" = "--help" ]; then

        clear

        echo "LastControl CLI"
        echo "---------------------"
        echo "Usage: lastcontrol [OPTION]"
        echo "---------------------"
        echo "--create               Create all System Report"
        echo "--disk                 Show System Disk Report"
        echo "--localuser            Show System Local User Report"
        echo "--unsecurepack         Show Unsecure Package List"
        echo -e
        echo "(example: lastcontrol --create)"
        echo "(example: lastcontrol --disk)"
        echo "(example: lastcontrol --localuser)"

        exit 1
fi
