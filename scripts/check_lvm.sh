#!/bin/bash

#-------------------------------------------------
# LastControl LVM Check
# This script checks if the disk configuration is lvm and shows the lvm details.
#-------------------------------------------------

CHECK_LVM() {
	$BLUE
	echo "Checking LVM Configuration"
	$NOCOL

	LVM_USAGE=FAIL
	if pvdisplay > /dev/null 2>&1; then
		LVM_USAGE=PASS
	fi
	
	if [[ $LVM_USAGE == PASS ]]; then
		LVMINFO=$(mktemp)
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
	 	echo "|LVM Information |" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
		echo "|Physical Volumes|" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
		pvdisplay | grep -E "PV Name|VG Name|PV Size|Free PE" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
		echo "|Volume Groups   |" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
		vgdisplay | grep -E "VG Name|VG Size|Free PE" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
		echo "|Logical Volumes |" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
		lvdisplay | grep -E "LV Name|VG Name|LV Size|LV Path" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
		echo "|Disk Usage      |" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
		df -hT | grep -E "^/dev/mapper|Filesystem|^/dev/sd" >> $LVMINFO
		echo "--------------------------------------------------------------------------------------------------------------------------" >> $LVMINFO
	fi
}
