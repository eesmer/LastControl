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

mkdir -p $RDIR

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
DATE=$(date)

SUID=$(find / -perm /2000)
SGID=$(find / -perm /4000)
UIDGID=$(find / -perm /6000)

cat > $RDIR/$HOST_NAME-suidsgidreport.md<< EOF

---
title: SUID and SGID Files Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

SUID File List
$SUID

---

SGID File List
$SGID

---

SUID and SGID File List
$UIDGID

---
EOF

cat > $RDIR/$HOST_NAME-suidsgidreport.txt << EOF
====================================================================================================
:::. $HOST_NAME SUID and SGID FILES REPORT :::.
====================================================================================================
$DATE

----------------------------------------------------------------------------------------------------
SUID Files
echo $SUID
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
SGID Files
echo $SGID
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
SUID and SGID Files
echo $UIDGID
----------------------------------------------------------------------------------------------------

====================================================================================================
EOF

cat > $RDIR/$HOST_NAME-suidgidreport.json << EOF
{
"AppsReport": {
"SUID Files": "$SUID"
"SGID Files": "$SGID"
"SUID and SGID Files": "$UIDGID"
}
}
EOF
