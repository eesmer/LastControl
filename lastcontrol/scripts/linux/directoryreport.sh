#!/bin/bash

HOST_NAME=$(cat /etc/hostname)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

# Create Directory Config Report
############################
# /tmp directory
mount | grep -E '\s/tmp\s' > /tmp/tmp_mount.txt
if [ "$?" = 0 ]; then
        TMPMOUNT=Pass
        egrep "size=" /tmp/tmp_mount.txt >> /dev/null && TMPSZIE=Pass
        egrep "noexec" /tmp/tmp_mount.txt >> /dev/null && TMPNOEXEC=Pass
else
        TMPMOUNT=Fail
        TMPSIZE=Fail
        TMPNOEXEC=Fail
fi
rm -f /tmp/tmp_mount.txt

# /var directory
mount | grep -E '\s/var\s' >> /dev/null
if [ "$?" = 0 ]; then
        VARMOUNT=Pass
else
        VARMOUNT=Fail
fi

mount | grep -E '\s/var/tmp\s' >> /dev/null
if [ "$?" = 0 ]; then
        VARTMPMOUNT=Pass
else
        VARTMPMOUNT=Fail
fi

mount | grep -E '\s\/var\/log\s' >> /dev/null
if [ "$?" = 0 ]; then
        VARLOGMOUNT=Pass
else
        VARLOGMOUNT=Fail
fi

cat > $RDIR/$HOST_NAME-directoryreport.md << EOF

---
title: Directory Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

### Directory Report ###

/tmp Mount:
 ~ $TMPMOUNT

/tmp Size:
 ~ $TMPSIZE

/tmp NoExec
 ~ $TMPNOEXEC

/var Mount:
 ~ $VARMOUNT

/var/tmp Mount:
 ~ $VARTMPMOUNT

/var/log Mount:
 ~ $VARLOGMOUNT

---
EOF

cat > $RDIR/$HOST_NAME-directoryreport.txt << EOF

|---------------------------------------------------------------------------------------------------
| ::. $HOST_NAME Directory Report .::
|---------------------------------------------------------------------------------------------------
|/tmp MOUNT      |$TMPMOUNT
|/tmp SIZE       |$TMPSIZE
|/tmp NOEXEC     |$TMPNOEXEC
|/var MOUNT      |$VARMOUNT
|/var/tmp MOUNT  |$VARTMPMOUNT
|/var/log MOUNT  |$VARLOGMOUNT
|----------------------------------------------------------------------------------------------------
EOF

cat > $RDIR/$HOST_NAME-directoryreport.json << EOF
{
    "UnsecurePackageReport": {
        "/tmp Mount": "$TMPMOUNT",
        "/tmp Size": "$TMPSIZE",
        "/tmp NoExec": "$TMPNOEXEC",
        "/var Mount": "$VARMOUNT",
        "/var/tmp Mount": "$VARTMPMOUNT",
        "/var/log Mount": "$VARLOGMOUNT"
    }
}
EOF
