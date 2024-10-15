#!/bin/bash

source ./common.sh

CHECK_UPDATE() {
	$BLUE
	echo "Checking for Updates"
	#$NOCOL
	if [ "$REP" = "APT" ]; then
		UPDATE_OUTPUT=$(apt update 2>&1)
		if echo "$UPDATE_OUTPUT" | grep -qE "(Failed to fetch|Temporary failure resolving|Could not resolve|Some index files failed to download)"; then
			UPDATE_COUNT="Some errors occurred during apt update. Please check internet or repository access."
		else
			UPDATE_COUNT=$(apt list --upgradable 2>&1 | grep -v "Listing" | wc -l)
		fi
	fi
	
	if [ "$REP" = "YUM" ]; then
		UPDATE_OUTPUT=$(yum update -y 2>&1)
		if echo "$UPDATE_OUTPUT" | grep -qE "(Failed to download|Could not resolve host|Temporary failure in name resolution|No more mirrors to try)"; then
			UPDATE_COUNT="Some errors occurred during yum update. Please check internet or repository access."
		else
			UPDATE_COUNT=$(echo N | yum update | grep "Upgrade" | awk '{print $2}')
			INSTALL_COUNT=$(echo N | yum update | grep "Install" | grep -v "Installing"| awk '{print $2}')
			UPDATE_COUNT=$(expr $UPDATE_COUNT + $INSTALL_COUNT)
		fi
	fi
}
