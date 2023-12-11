#!/bin/bash

#--------------------------------------------------------
# This script,
# It produces the report of System and Update checks.
#--------------------------------------------------------

HOST_NAME=$(cat /etc/hostname)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

# Which Distro
#cat /etc/redhat-release > $RDIR/distrocheck 2>/dev/null || cat /etc/*-release > $RDIR/distrocheck 2>/dev/null || cat /etc/issue > $RDIR/distrocheck 2>/dev/null
cat /etc/*-release > $RDIR/distrocheck 2>/dev/null
grep -i "debian" $RDIR/distrocheck &>/dev/null && REP=APT && DISTRO=Debian
grep -i "ubuntu" $RDIR/distrocheck &>/dev/null && REP=APT && DISTRO=Ubuntu
grep -i "centos" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=Centos
grep -i "red hat" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=RedHat
grep -i "oracle" $RDIR/distrocheck &>/dev/null && REP=YUM && DISTRO=Oracle
grep -i "rocky" /tmp/distrocheck &>/dev/null && REP=YUM && DISTRO=Rocky
rm $RDIR/distrocheck

#----------------------------
# System Update Report
#----------------------------
if [ "$REP" = APT ]; then
    apt list --upgradable | grep -v "Listing" > /tmp/updateinfo.txt
        UPGRADEPACK=$(cat /tmp/updateinfo.txt | wc -l)
	echo n | apt upgrade | grep "upgraded" | grep -v "The following packages will be" > /tmp/updateinfo.txt
	NEWINSTALL=$(cat /tmp/updateinfo.txt | cut -d "," -f2 | xargs | cut -d " " -f1)
fi
if [ "$REP" = YUM ]; then
	# check update for system
	echo N | yum update > /tmp/updatecheck.txt 2>/dev/null
	UPGRADEPACK=$(cat /tmp/updatecheck.txt | grep "Upgrade" | grep "Packages")
	NEWINSTALL=$(cat /tmp/updatecheck.txt | grep "Install" | grep "Packages")
	TOTALDOWNLOAD=$(cat /tmp/updatecheck.txt | grep "Total download size:" | cut -d ":" -f2 | xargs)
fi

cat > $RDIR/$HOST_NAME-updatereport.txt << EOF

|---------------------------------------------------------------------------------------------------
| ::. System Update Report .:: 
|---------------------------------------------------------------------------------------------------
|Packages to Update/Upgrade | $UPGRADEPACK
|Packages to New Install    | $NEWINSTALL
|Total Download             | $TOTALDOWNLOAD
|---------------------------------------------------------------------------------------------------
EOF

if [ "$DISTRO" = "Ubuntu" ]; then
	UNATTENDED_SERVICE=$(systemctl is-active unattended-upgrades)
	UNATTENDED_LIST=$(cat /etc/apt/apt.conf.d/20auto-upgrades | grep "Update-Package-Lists" | awk {'print $2'} | cut -d ";" -f1)
	UNATTENDED_UPGR=$(cat /etc/apt/apt.conf.d/20auto-upgrades | grep "Unattended-Upgrade" | awk {'print $2'} | cut -d ";" -f1)
	# security update check
	UNATTENDED_FETCH=$(unattended-upgrade --dry-run -d | grep "Fetched")
	UNATTENDED_BLACKLIST=$(unattended-upgrade --dry-run -d | grep "blacklist:")
	UNATTENDED_WHITELIST=$(unattended-upgrade --dry-run -d | grep "whitelist:")
	unattended-upgrade --dry-run -d > /tmp/secupdate.txt
	UNATTENDED_RESULT=$(cat /tmp/secupdate.txt | awk 'END { print }')
	#unattended-upgrade --dry-run -d | grep "Initial blacklisted packages:"
	#unattended-upgrade --dry-run -d | grep "Initial whitelisted packages:"

	echo "|Unattended Upgrade Service | $UNATTENDED_SERVICE" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Unattended Package List    | $UNATTENDED_LIST" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Unattended Upgrade         | $UNATTENDED_UPGR" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Fetch                      | $UNATTENDED_FETCH" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Blacklist                  | $UNATTENDED_BLACKLIST" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Whitelist                  | $UNATTENDED_WHITELIST" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Wttended Result            | $UNATTENDED_RESULT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|---------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-updatereport.txt
fi

if [ "$DISTRO" = "RedHat" ]; then
	yum updateinfo --installed > /tmp/updateinfo.txt
	IMPUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Important Security" | xargs)
	MODUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Moderate Security" | xargs)
	LOWUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Low Security" | xargs)
	BUGFIXCOUNT=$(cat /tmp/updateinfo.txt |grep "Bugfix" | xargs)
	
	echo "|Important Security Update  | $IMPUPDATECOUNT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Moderate  Security Update  | $MODUPDATECOUNT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Low       Security Update  | $LOWUPDATECOUNT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Bugfixes                   | $BUGFIXCOUNT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|---------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-updatereport.txt
fi

if [ "$DISTRO" = "Oracle" ]; then
	yum updateinfo > /tmp/updateinfo.txt
	IMPUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Important Security" | xargs)
	MODUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Moderate Security" | xargs)
	LOWUPDATECOUNT=$(cat /tmp/updateinfo.txt |grep "Low Security" | xargs)
	BUGFIXCOUNT=$(cat /tmp/updateinfo.txt |grep "Bugfix" | xargs)
	
	echo "|Important Security Update  | $IMPUPDATECOUNT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Moderate  Security Update  | $MODUPDATECOUNT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Low       Security Update  | $LOWUPDATECOUNT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|Bugfixes                   | $BUGFIXCOUNT" >> $RDIR/$HOST_NAME-updatereport.txt
	echo "|---------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-updatereport.txt
fi
