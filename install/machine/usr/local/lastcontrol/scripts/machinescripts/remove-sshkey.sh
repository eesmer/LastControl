#!/bin/bash

#------------------------------------------------------
# This script,
# Delete $2 lines in authorized_keys file
# Deletes all $2 results found in authorized_keys file
# $1 Remote Machine
# $2 Lastcontrol Hostname
#------------------------------------------------------

LCKEY=/root/.ssh/lastcontrol

ssh -p22 -i $LCKEY -o "StrictHostKeyChecking no" root@$1 -- sed -i "/$2/d" /root/.ssh/authorized_keys
