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

# CHECK KERNEL and OS VERSION
KERNELVER=$(uname -r)
OSVER=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | cut -d '"' -f2)

# CHECK KERNEL MODULES
modules=("cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "squashfs" "udf")

# Initialize a variable to hold the module statuses
declare -A module_statuses

# Loop through the modules array and check their status
for module in "${modules[@]}"; do
    module_statuses["$module"]="FALSE"
    if lsmod | grep -q "$module"; then
        module_statuses["$module"]="LOADED"
        echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>$module Filesystem loaded</a>" >> "/tmp/the.hardeningsys"
    fi
done

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
 ~ ${module_statuses["cramfs"]}

FREEVXFS Module :
 ~ ${module_statuses["freevxfs"]}

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

cat > "/tmp/the_kernelreport.txt" << EOF
====================================================================================================
:::. $HOST_NAME KERNEL INFORMATION REPORT :::.
====================================================================================================
$DATE

----------------------------------------------------------------------------------------------------
|Kernel Version  |$KERNELVER
|OS Version      |$OSVER
|CRAMFS Module   |${module_statuses["cramfs"]}
|FREEVXFS Module |${module_statuses["freevxfs"]}
|JFFS2 Module    |${module_statuses["jffs2"]}
|HFS Module      |${module_statuses["hfs"]}
|HFSPLUS Module  |${module_statuses["hfsplus"]}
|SQUASHFS Module |${module_statuses["squashfs"]}
|UDF Module      |${module_statuses["udf"]}
----------------------------------------------------------------------------------------------------
EOF

cat > $RDIR/$HOST_NAME-kernelreport.json << EOF
{
    "KernelReport": {
    	"Kernel and OS Version": "$KERNELVER - $OSVER",
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
