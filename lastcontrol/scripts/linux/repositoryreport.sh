#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

#----------------------------
# determine distro/repo
#----------------------------
cat /etc/*-release /etc/issue > "$RDIR/distrocheck"
if grep -qi "debian\|ubuntu" "$RDIR/distrocheck"; then
    REP=APT
elif grep -qi "centos\|rocky\|red hat" "$RDIR/distrocheck"; then
    REP=YUM
fi
rm $RDIR/distrocheck

# repository list
if [ "$REP" = "APT" ]; then
        #SYSREPO1=$(grep -hE '^\s*deb\s' /etc/apt/sources.list | grep -v '^#' | awk '{print $2}')
        #SYSREPO2=$(grep -hE '^\s*deb\s' /etc/apt/sources.list.d/* | grep -v '^#' | awk '{print $2}')
        grep -hE '^\s*deb\s' /etc/apt/sources.list | grep -v '^#' | awk '{print $2}' > $RDIR/$HOST_NAME-repositoryreport.txt
        grep -hE '^\s*deb\s' /etc/apt/sources.list.d/* | grep -v '^#' | awk '{print $2}' >> $RDIR/$HOST_NAME-repositoryreport.txt
fi
if [ "$REP" = "YUM" ]; then
        yum repolist all | grep enabled | awk '{print $1}' > $RDIR/$HOST_NAME-repositoryreport.txt
fi
