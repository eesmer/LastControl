#!/bin/bash

#---------------------------------------------
# LastControl Check Roles Script
#---------------------------------------------

source /root/LastControl/scripts/common.sh

CHECK_PACKAGE() {
    # netstat package control
    if ! command -v netstat &>/dev/null; then
	$RED
	echo -e "The netstat package must be installed for some checks"
	$NOCOL
        NETSTATP=FALSE
    fi
}
