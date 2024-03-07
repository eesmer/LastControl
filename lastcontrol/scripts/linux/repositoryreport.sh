#!/bin/bash

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

# Determine Rep and Distro
if [ -f /etc/redhat-release ]; then
    cat /etc/redhat-release > $RDIR/distrocheck 2>/dev/null
elif [ -f /etc/*-release ]; then
    cat /etc/*-release > $RDIR/distrocheck 2>/dev/null
elif [ -f /etc/issue ]; then
    cat /etc/issue > $RDIR/distrocheck 2>/dev/null
fi

if grep -qi "debian" $RDIR/distrocheck; then
    REP=APT
    DISTRO=Debian
elif grep -qi "ubuntu" $RDIR/distrocheck; then
    REP=APT
    DISTRO=Ubuntu
elif grep -qi "centos" $RDIR/distrocheck; then
    REP=YUM
    DISTRO=Centos
elif grep -qi "red hat" $RDIR/distrocheck; then
    REP=YUM
    DISTRO=RedHat
elif grep -qi "rocky" $RDIR/distrocheck; then
    REP=YUM
    DISTRO=Rocky
fi

## Which Distro
#cat /etc/redhat-release > $RDIR/distrocheck 2>/dev/null || cat /etc/*-release > $RDIR/distrocheck 2>/dev/null || cat /etc/issue > $RDIR/distrocheck 2>/dev/null
#grep -i "debian" $RDIR/distrocheck &>/dev/null && REP=APT && DISTRO=Debian
#grep -i "ubuntu" $RDIR/distrocheck &>/dev/null && REP=APT && DISTRO=Ubuntu
#grep -i "centos" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=Centos
#grep -i "red hat" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=RedHat
#grep -i "rocky" /tmp/distrocheck &>/dev/null && REP=YUM && DISTRO=Rocky
#rm $RDIR/distrocheck
#
##----------------------------
## determine distro
##----------------------------
#cat /etc/*-release /etc/issue > "$RDIR/distrocheck"
#if grep -qi "debian\|ubuntu" "$RDIR/distrocheck"; then
#    REP=APT
#elif grep -qi "centos\|rocky\|red hat" "$RDIR/distrocheck"; then
#    REP=YUM
#fi
#rm $RDIR/distrocheck


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
