#!/bin/bash

#--------------------------------------------------------
# This script,
# It produces the report of Active Process and CPU Load Controls.
#--------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

#############################
# Create System Load Report
#############################
NOC=$(nproc --all)
#LOAD_AVG=$(top -n 1 -b | grep "load average:" |awk -F: '{ print $4 $5 }')
LOAD_AVG=$(uptime |grep "load average:" |awk -F: '{print $5}')

############################
# Create Process Report
############################
#TO_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $2}')
#RU_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $4}')
#SL_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $6}')
ST_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $8}')
#ZO_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $10}')
ZO_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[Zz]' | wc -l)

cat > $RDIR/$HOST_NAME-processreport.md << EOF

---
title: Process Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

CPU Count :
 ~ $NOC

System Load Average :
 ~ $LOAD_AVG

Zombie Process :
 ~ $ZO_PROCESS

---
EOF

cat >> $RDIR/$HOST_NAME-processreport.txt << EOF

|---------------------------------------------------------------------------------------------------
|:::. Process Report .::: |
|---------------------------------------------------------------------------------------------------
|CPU Count:           |$NOC
|System Load Average: |$LOAD_AVG
|Zombie Process:      |$ZO_PROCESS
----------------------------------------------------------------------------------------------------
EOF
