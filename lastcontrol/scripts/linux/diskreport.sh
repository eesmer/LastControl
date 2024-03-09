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

# DISK USAGE INFORMATION
DISK_USAGE=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | awk '{ print $5" "$1"("$2"  "$3")" " --- "}' | grep -v "none" |grep -v "loop")
DISK_USAGE=$(fdisk -lu | grep "Disk" | grep -v "Disklabel" | grep -v "dev/loop" | grep -v "Disk identifier")

# CHECK USAGE DISK QUOTA
QUOTA_INSTALL=Installed
if ! [ "$(command -v quotacheck)" ]; then
	     QUOTA_INSTALL=Not_Installed
fi
USR_QUOTA=Fail
grep -i "usrquota" /etc/fstab >> /dev/null && USR_QUOTA=Active
GRP_QUOTA=Fail
grep -i "grpquota" /etc/fstab >> /dev/null && GRP_QUOTA=Active
MNT_QUOTA=Not_Found
mount |grep "quota" >> /dev/null && MNT_QUOTA=Found

# CHECK USAGE LVM
LVM_USAGE=FALSE
lsblk --output type |grep -w "lvm" && LVM_USAGE=TRUE

# CHECK USAGE DISK ENCRYPT
CRYPT_INSTALL=Not_Installed
if [ -x "$(command -v cryptsetup)" ]; then CRYPT_INSTALL=Installed; fi
CRYPT_USAGE=FALSE
lsblk --output type |grep -w "crypt" && CRYPT_USAGE=TRUE

## S.M.A.R.T CHECK
#df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev|mapper' |cut -d " " -f1 > /tmp/disklist.txt
#NUMDISK=$(cat /tmp/disklist.txt | wc -l)
#SMART_SCORE=0
#i=1
#
#while [ "$i" -le "$NUMDISK" ]; do
#	DISK=$(ls -l |sed -n $i{p} /tmp/disklist.txt)
#	smartctl -i -x $DISK >> /dev/null > /tmp/DISK$i.txt
#	smartctl -i -x $DISK >> /dev/null > /tmp/DISK$i.txt
#	SMART_SUPPORT=0
#	egrep "SMART support is: Available - device has SMART capability." /tmp/DISK$i.txt >> /dev/null && SMART_SUPPORT=1 
#if [ "$SMART_SUPPORT" = 1 ]; then
#	SMART_SUPPORT="Available - device has SMART capability."
#	SMART_RESULT=$(cat /tmp/DISK$i.txt |grep "SMART overall-health self-assessment test result:" |cut -d ":" -f2 |cut -d " " -f2)
#else
#	SMART_SUPPORT="Unavailable - device lacks SMART capability."
#	SMART_RESULT="Not Passed"
#fi
#
#echo "-> $DISK" >> /tmp/smartcheck-result.txt
#echo "Support: $SMART_SUPPORT" >> /tmp/smartcheck-result.txt
#echo "Result: $SMART_RESULT" >> /tmp/smartcheck-result.txt
#echo  "" >> /tmp/smartcheck-result.txt
#
#i=$(( i + 1 ))
#SMART=$(cat /tmp/smartcheck-result.txt)
#done


cat > $RDIR/$HOST_NAME-diskreport.md<< EOF

---
title: Local Disk Information Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

Disk Usage
$DISK_USAGE

---

### Disk Quota Usage Information ###
Disk Quota Install :
 ~ $QUOTA_INSTALL

User Quota Usage :
 ~ $USR_QUOTA

Group Quota Usage :
 ~ $GRP_QUOTA

All Mount Disk Quota Usage :
$MNT_QUOTA

---

### Disk Encrypt Usage Information ###
Disk Encrypt Install :
 ~ $CRYPT_INSTALL

Disk Encrypt Usage :
 ~ $CRYPT_USAGE

### LVM Usage Information ###
LVM Usage :
 ~ $LVM_USAGE

---
EOF


cat > $RDIR/$HOST_NAME-diskreport.txt << EOF
====================================================================================================
:::. $HOST_NAME DISK INFORMATION REPORT :::.
====================================================================================================
$DATE

----------------------------------------------------------------------------------------------------
DISK USAGE CONTROL
----------------------------------------------------------------------------------------------------
$DISK_USAGE

----------------------------------------------------------------------------------------------------
DISK QUOTA USAGE CONTROL
----------------------------------------------------------------------------------------------------
Disk Quota Usage:    | Install: $QUOTA_INSTALL | User Quota: $USR_QUOTA | Group Quota: $GRP_QUOTA | Mount Check: $MNT_QUOTA

----------------------------------------------------------------------------------------------------
DISK ENCRYPT USAGE CONTROL
----------------------------------------------------------------------------------------------------
Disk Encrypt Usage:  | Install: $CRYPT_INSTALL | Usage: $CRYPT_USAGE

----------------------------------------------------------------------------------------------------
LVM CONFIG CONTROL
----------------------------------------------------------------------------------------------------
LVM Usage:           | $LVM_USAGE

====================================================================================================
EOF

cat > $RDIR/$HOST_NAME-diskreport.json << EOF
{
"DiskReport": {
"Quota Install": "$QUOTA_INSTALL",
"User Quota": "$USR_QUOTA",
"Group Quota": "$GRP_QUOTA",
"Mount Info": "$MNT_QUOTA",
"Disk Encrypt": "$CRYPT_INSTALL",
"Encrypt Usage": "$CRYPT_USAGE",
"LVM Usage": "$LVM_USAGE"
}
}
EOF

rm -f /tmp/disklist.txt
