#!/bin/bash

#---------------------------------------------
# LastControl Required packages check
# This script checks if the packages required for LastControl checks are installed
#---------------------------------------------

source ./common.sh

CHECK_PACKAGE() {
    # netstat package control
    if ! command -v netstat &>/dev/null; then
	$RED
	echo -e "The netstat package must be installed for some checks"
	$NOCOL
        NETSTATP=FALSE
    fi
}
