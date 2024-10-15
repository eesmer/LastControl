#!/bin/bash

#---------------------------------------------
# LastControl Check root user
# This script checks if it is run as the root user
#---------------------------------------------

source ./common.sh

CHECK_RUNROOT() {
    $GREEN
    echo "Checking root user session"
    $NOCOL
    if [[ ! $EUID -eq 0 ]]; then
        $RED
        echo "This script must be run with root user"
	echo -e
        $NOCOL
        exit 1
else
        $GREEN
        echo "Root session check OK"
        $NOCOL
    fi
}
