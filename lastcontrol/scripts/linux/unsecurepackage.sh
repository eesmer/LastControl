#!/bin/bash

HOST_NAME=$(cat /etc/hostname)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

# Which Distro
cat /etc/redhat-release > $RDIR/distrocheck 2>/dev/null || cat /etc/*-release > $RDIR/distrocheck 2>/dev/null || cat /etc/issue > $RDIR/distrocheck 2>/dev/null
grep -i "debian" $RDIR/distrocheck &>/dev/null && REP=APT && DISTRO=Debian
grep -i "ubuntu" $RDIR/distrocheck &>/dev/null && REP=APT && DISTRO=Ubuntu
grep -i "centos" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=Centos
grep -i "red hat" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=RedHat
grep -i "rocky" /tmp/distrocheck &>/dev/null && REP=YUM && DISTRO=Rocky
rm $RDIR/distrocheck

# UNSECURE PACKAGE CONTROL
if [ "$REP" = APT ]; then
        FTP_INSTALL=FALSE
        dpkg -l |grep ftp |grep -v "sftp" &>/dev/null && FTP_INSTALL=TRUE
        TELNET_INSTALL=FALSE
        dpkg -l |grep telnet &>/dev/null && TELNET_INSTALL=TRUE
        RSH_INSTALL=FALSE
        dpkg -l |grep rsh &>/dev/null && RSH_INSTALL=TRUE
        NIS_INSTALL=FALSE
        dpkg -l |grep nis &>/dev/null && NIS_INSTALL=TRUE
        YPTOOLS_INSTALL=FALSE
        dpkg -l |grep yp-tools &>/dev/null && YPTOOLS_INSTALL=TRUE
        XINET_INSTALL=FALSE
        dpkg -l |grep xinet &>/dev/null && XINET_INSTALL=TRUE

elif [ "$REP" = YUM ]; then
        FTP_INSTALL=FALSE
        rpm -qa |grep ftp |grep -v "sftp" &>/dev/null && FTP_INSTALL=TRUE
        TELNET_INSTALL=FALSE
        rpm -qa |grep telnet &>/dev/null && TELNET_INSTALL=TRUE
        RSH_INSTALL=FALSE
        rpm -qa |grep rsh &>/dev/null && RSH_INSTALL=TRUE
        NIS_INSTALL=FALSE
        rpm -qa |grep nis &>/dev/null && NIS_INSTALL=TRUE
        YPTOOLS_INSTALL=FALSE
        rpm -qa |grep yp-tools &>/dev/null && YPTOOLS_INSTALL=TRUE
        XINET_INSTALL=FALSE
        rpm -qa |grep xinet &>/dev/null && XINET_INSTALL=TRUE
fi

cat > $RDIR/$HOST_NAME-unsecurepackreport.md << EOF

---
title: Unsecure Package Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

### Unsecure Packages ###

FTP INSTALL:
 ~ $FTP_INSTALL

TELNET INSTALL:
 ~ $TELNET_INSTALL

RSH INSTALL:
 ~ $RSH_INSTALL

NIS INSTALL:
 ~ $NIS_INSTALL

YPTOOLS INSTALL:
 ~ $YPTOOLS_INSTALL

XINET INSTALL:
 ~ $XINET_INSTALL

---
EOF

cat > $RDIR/$HOST_NAME-unsecurepackreport.txt << EOF

|---------------------------------------------------------------------------------------------------
| ::. Unsecure Package Report .::
|---------------------------------------------------------------------------------------------------
|FTP INSTALL:       |$FTP_INSTALL
|TELNET INSTALL:    |$TELNET_INSTALL
|RSH INSTALL:       |$RSH_INSTALL
|NIS INSTALL:       |$NIS_INSTALL
|YPTOOLS INSTALL:   |$YPTOOLS_INSTALL
|XINET INSTALL:     |$XINET_INSTALL
|----------------------------------------------------------------------------------------------------
EOF

cat > $RDIR/$HOST_NAME-unsecurepackreport.json << EOF
{
    "UnsecurePackageReport": {
        "FTP Install": "$FTP_INSTALL",
        "Telnet Install": "$TELNET_INSTALL",
        "RSH Install": "$RSH_INSTALL",
        "NIS Install": "$NIS_INSTALL",
        "YPTOOLS Install": "$YPTOOLS_INSTALL",
        "XINET Install": "$XINET_INSTALL"
    }
}
EOF
