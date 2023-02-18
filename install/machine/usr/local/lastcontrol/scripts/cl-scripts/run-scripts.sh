#!/bin/bash

#----------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#----------------------------------------------------------------------

WDIR=/usr/local/cl-scripts

bash $WDIR/00-install_reqpackages
bash $WDIR/01-create-inventory
bash $WDIR/02-create-systemreport
bash $WDIR/03-create-updatereport
bash $WDIR/04-create-diskreport
bash $WDIR/05-create-kernelreport
bash $WDIR/06-create-nwconfigreport
bash $WDIR/07-create-grubreport
bash $WDIR/08-create-servicereport
bash $WDIR/09-create-unsecurepackreport
bash $WDIR/10-create-firewallreport
bash $WDIR/11-create-localuserreport
bash $WDIR/12-create-suidsgidreport
bash $WDIR/13-create-vulnerabilityreport
bash $WDIR/14-create-sshreport
bash $WDIR/15-create-directoryreport
bash $WDIR/16-create-processreport
