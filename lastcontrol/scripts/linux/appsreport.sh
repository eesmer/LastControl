#!/bin/bash

#--------------------------------------------------------
# This script,
# It produces the report of Installed Applications
#--------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
DATE=$(date)

APPS=$(ls /usr/share/applications)

cat > $RDIR/$HOST_NAME-appsreport.md<< EOF

---
title: Installed Applications Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

Installed Applications
$APPS

---
EOF


cat > $RDIR/$HOST_NAME-appsreport.txt << EOF
====================================================================================================
:::. $HOST_NAME INSTALLED APPLICATIONS REPORT :::.
====================================================================================================
$DATE

----------------------------------------------------------------------------------------------------
INSTALLED APPLICATIONS
----------------------------------------------------------------------------------------------------
$APPS

====================================================================================================
EOF

cat > $RDIR/$HOST_NAME-appsreport.json << EOF
{
"AppsReport": {
"Installed Apps.": "$APPS"
}
}
EOF
