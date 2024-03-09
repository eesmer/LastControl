#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

SERVICE_MAN="$(ps --no-headers -o comm 1)"

if [ "$SERVICE_MAN" = systemd ]; then
	systemctl list-units --type service |grep running > $RDIR/runningservices.txt
	RUNNING_SERVICE=$(wc -l $RDIR/runningservices.txt |cut -d ' ' -f1)
	LOADED_SERVICE=$(systemctl list-units --type service |grep "units." |cut -d "." -f1)
fi

ACTIVE_CONN=$(netstat -s |grep "active connection openings")
PASSIVE_CONN=$(netstat -s |grep "passive connection openings")
FAILED_CONN=$(netstat -s |grep "failed connection attempts")
ESTAB_CONN=$(netstat -s |grep "connections established")

cat > $RDIR/$HOST_NAME-servicereport.md<< EOF

---
title: Service Information Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

### Service Manager ###
* $SERVICE_MAN

Running Service :
 ~ $RUNNING_SERVICE

Loaded Service :
 ~ $LOADED_SERVICE

---

### Connections Information ###

Active Connection :
 ~ $ACTIVE_CONN

Passive Connection :
 ~ $PASSIVE_CONN

Failed Connection :
 ~ $FAILED_CONN

Established Connection :
 ~ $ESTAB_CONN

---
EOF

netstat -tl |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" >> $RDIR/$HOST_NAME-listeningservice.txt
netstat -tn |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" |grep "ESTABLISHED" >> $RDIR/$HOST_NAME-establishedservice.txt

cat > $RDIR/$HOST_NAME-servicereport.txt << EOF
====================================================================================================
:::. $HOST_NAME SERVICE INFORMATION REPORT :::.
====================================================================================================
$DATE

----------------------------------------------------------------------------------------------------
|Service Management: |$SERVICE_MAN
|Running Service:    |$RUNNING_SERVICE
|Loaded Service:     |$LOADED_SERVICE
----------------------------------------------------------------------------------------------------
|Active Connection:  |$ACTIVE_CONN
|Passive Connection: |$PASSIVE_CONN
|Failed Connection:  |$FAILED_CONN
|Established Conn.:  |$ESTAB_CONN
----------------------------------------------------------------------------------------------------

EOF

echo "|----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-servicereport.txt
echo "|LISTENING SERVICE LIST" >> $RDIR/$HOST_NAME-servicereport.txt
echo "|----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-servicereport.txt
netstat -tl |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" \
	>> $RDIR/$HOST_NAME-servicereport.txt

echo "" >> $RDIR/$HOST_NAME-servicereport.txt

echo "|----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-servicereport.txt
echo "|ESTABLISHED SERVICE LIST" >> $RDIR/$HOST_NAME-servicereport.txt
echo "|----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-servicereport.txt
netstat -tn |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" \
	|grep "ESTABLISHED" >> $RDIR/$HOST_NAME-servicereport.txt

echo "" >> $RDIR/$HOST_NAME-servicereport.txt
echo "=====================================================================================================" >> $RDIR/$HOST_NAME-servicereport.txt

systemctl list-units --type=service | awk ' {print $1}' | cut -d "." -f1 | grep -v "UNIT" > $RDIR/$HOST_NAME-loadedservices.txt
echo "|----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-servicereport.txt
echo "|LOADED SERVICES" >> $RDIR/$HOST_NAME-servicereport.txt
echo "|----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-servicereport.txt
cat $RDIR/$HOST_NAME-loadedservices.txt >> $RDIR/$HOST_NAME-servicereport.txt
echo "=====================================================================================================" >> $RDIR/$HOST_NAME-servicereport.txt
