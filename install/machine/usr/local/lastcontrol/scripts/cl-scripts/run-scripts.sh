#!/bin/bash

#----------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#----------------------------------------------------------------------

#WDIR=/tmp/cl-scripts
WDIR=/usr/local/cl-scripts

chmod +x $WDIR/*
run-parts $WDIR

#rm -r $WDIR
