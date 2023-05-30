#!/bin/bash

#------------------------------------------------------
# This script,
# Upload the Lastcontrol.pub key file to remote machine
# $1 Remote Machine
#------------------------------------------------------

LCKEY=/root/.ssh/lastcontrol

ssh-copy-id -fi $LCKEY.pub root@$1
