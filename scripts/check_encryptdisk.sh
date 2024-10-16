#!/bin/bash

#-------------------------------------------------
# LastControl Check Encrypted Disk
# This script checks the encrypted disk for LUKS
#-------------------------------------------------

ENCRYPT_DISK() {
	ENCRYPTED_DISK=$(lsblk -o NAME,FSTYPE | grep "crypto_LUKS")
	ENCRYPT_USAGE=FAIL
	if [[ -n $ENCRYPTED_DISK ]]; then
		ENCRYPT_USAGE=PASS
	fi
	
	if [[ $ENCRYPTED_USAGE == PASS ]]; then
		while read -r DISK; do
			DEVICENAME=$(echo $DISK | awk '{print $1}')
			echo "--------------------------------------------------------------------------------------------------------------------------" >> $ENCRYPTINFO
			echo "|ENCRYPTED DISK INFORMATION |" >> $ENCRYPTINFO
			echo "--------------------------------------------------------------------------------------------------------------------------" >> $ENCRYPTINFO
			echo "Disk: /dev/$DEVICENAME" >> $ENCRYPTINFO
			cryptsetup luksDump /dev/$DEVICENAME | grep -E "Version|Cipher name|UUID" >> $ENCRYPTINFO
			echo "--------------------------------------------------------------------------------------------------------------------------" >> $ENCRYPTINFO
		done <<< "$ENCRYPTED_DISK"
	fi
}
