#!/bin/bash

#--------------------------------------------------------
# This script,
# It gives information about the kernel.
#--------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

# CHECK KERNEL and OS VERSION
KERNELVER=$(uname -r)
OSVER=$(cat /etc/os-release |grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)

# CHECK KERNEL MODULES
CRAMFS=FALSE
lsmod |grep cramfs > /tmp/kernel_modules.txt && CRAMFS=LOADED 
if [ "$CRAMFS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>CRAMFS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
FREEVXFS=FALSE
lsmod |grep freevxfs > /tmp/kernel_modules.txt && FREEVXFS=LOADED
if [ "$FREEVXFS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>FREEVXFS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
JFFS2=FALSE
lsmod |grep jffs2 > /tmp/kernel_modules.txt && JFFS2=LOADED
if [ "$JFFS2" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>JFFS2 Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
HFS=FALSE
lsmod |grep hfs > /tmp/kernel_modules.txt && HFS=LOADED
if [ "$HFS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>HFS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
HFSPLUS=FALSE
lsmod |grep hfsplus > /tmp/kernel_modules.txt && HFSPLUS=LOADED
if [ "$HFSPLUS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>HFSPLUS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
SQUASHFS=FALSE
lsmod |grep squashfs > /tmp/kernel_modules.txt && SQUASHFS=LOADED
if [ "$SQUASHFS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>HFSPLUS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
UDF=FALSE
lsmod |grep udf > /tmp/kernel_modules.txt && UDF=LOADED
if [ "$UDF" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>UDF Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi

cat > $RDIR/$HOST_NAME-kernelreport.md<< EOF

---
title: Kernel Information Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

### Kernel Information ###

Kernel Version :
 ~ $KERNELVER

OS Version :
 ~ $OSVER

 ---

### Kernel Modules Information ###

CRAMFS Module :
 ~ $CRAMFS

FREEVXFS Module :
 ~ $FREEVXFS

JFFS2 Module :
 ~ $JFFS2

HFS Module :
 ~ $HFS

HFSPLUS Module :
 ~ $HFSPLUS

SQUASH Module :
 ~ $SQUASHFS

UDF Module :
 ~ $UDF

---
EOF

cat > $RDIR/$HOST_NAME-kernelreport.txt << EOF
====================================================================================================
:::. $HOST_NAME KERNEL INFORMATION REPORT :::.
====================================================================================================
$DATE

----------------------------------------------------------------------------------------------------
|Kernel Version  |$KERNELVER
|OS Version      |$OSVER
|CRAMFS Module   |$CRAMFS
|FREEVXFS Module |$FREEVXFS
|JFFS2 Module    |$JFFS2
|HFS Module      |$HFS
|HFSPLUS Module  |$HFSPLUS
|SQUASHFS Module |$SQUASHFS
|UDF Module      |$UDF
----------------------------------------------------------------------------------------------------
EOF

cat > $RDIR/$HOST_NAME-kernelreport.json << EOF
{
    "KernelReport": {
    	"Kernel and OS Version:" "$KERNELVER - $OSVER"
        "CRAMFS Module": "$CRAMFS",
        "FREEVXFS Module": "$FREEVXFS",
        "JFFS2 Module": "$JFFS2",
        "HFS Module": "$HFS",
        "HFSPLUS Module": "$HFSPLUS",
        "SQUASHFS Module": "$SQUASHFS",
        "UDF Module": "$UDF"
    }
}
EOF
