#!/bin/bash

DISKS_TO_CHECK=("/home" "/var")
QUOTAREPORT=$(mktemp)
LOCALUSERS=$(mktemp)

CHECK_QUOTA() {
	trap "rm -f $QUOTAREPORT $LOCALUSERS" EXIT
	
	$BLUE
	echo "Checking Disk Quota Configuration"
	$NOCOL
	QUOTA_USAGE=FAIL
	NONQUOTA_DISK=FAIL
	
	for disk in "${DISKS_TO_CHECK[@]}"; do
		if mount | grep -q "$disk" && quotaon -p "$disk" > /dev/null 2>&1; then
			echo "Disk quota is configured for disk $disk" > "$QUOTAREPORT"
			QUOTA_USAGE=PASS
		else
			echo "Warning: Disk quota is not configured for disk $disk" >> "$QUOTAREPORT"
			NONQUOTA_DISK=PASS
		fi
	done

	awk -F':' '{ if ($3 >= 1000 && $3 < 65534) print $1 }' /etc/passwd > "$LOCALUSERS"

	if command -v quota &> /dev/null; then
		"$LOCALUSERS" | while read -r user; do
		echo "$user Disk Quota Information" >> "$QUOTAREPORT"
		quota -u "$user" >> "$QUOTAREPORT"
		echo "----------------------------" >> "$QUOTAREPORT"
	done
	fi
}
