#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

#--------------------------
# determine distro
#--------------------------
cat /etc/redhat-release > /tmp/distrocheck || cat /etc/*-release > /tmp/distrocheck || cat /etc/issue > /tmp/distrocheck
grep -i debian /tmp/distrocheck 2>/dev/null && REP=APT
grep -i ubuntu /tmp/distrocheck 2>/dev/null && REP=APT
grep -i centos /tmp/distrocheck 2>/dev/null && REP=YUM
grep -i "red hat" /tmp/distrocheck 2>/dev/null && REP=YUM
rm /tmp/distrocheck

#--------------------------
# install packages
#--------------------------
if [ $REP = APT ]; then
	apt-get -y install net-tools rsync
fi
if [ $REP = YUM ]; then
	yum -y install net-tools rsync perl
fi

DATE=$(date)
HOST_NAME=$(hostnamectl --static)

#---------------------------
# Inventory
#---------------------------
ip a |grep "inet " > /tmp/ipoutput && sed -i '/127.0/d' /tmp/ipoutput
IPADDRESS=$(cat /tmp/ipoutput) && rm /tmp/ipoutput
CPUINFO=$(cat /proc/cpuinfo |grep "model name" |cut -d ':' -f2 > /tmp/cpuinfooutput.txt && tail -n1 /tmp/cpuinfooutput.txt > /tmp/cpuinfo.txt && rm /tmp/cpuinfooutput.txt && cat /tmp/cpuinfo.txt) && rm /tmp/cpuinfo.txt
RAM_TOTAL=$(free -m |awk 'NR == 2 {print "" $2*1.024}' |cut -d "." -f1)
RAM_USAGE=$(free -m |awk 'NR == 2 {print "" $3*1.024}' |cut -d "." -f1)
GPU=$(lspci | grep VGA | cut -d ":" -f3);GPURAM=$(cardid=$(lspci | grep VGA |cut -d " " -f1);lspci -v -s $cardid | grep " prefetchable"| awk '{print $6}' | head -1)
VGA_CONTROLLER="$GPU $GPURAM"
DISK_LIST=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | awk '{ print $5" "$1"("$2"  "$3")" " --- "}' | sed -e :a -e N -e 's/\n/ /' -e ta)
VIRT_CONTROL=NONE               
if [ -f "/dev/kvm" ]; then $VIRT_CONTROL=ON; fi
OS_KERNEL=$(uname -a)
OS_VER=$(cat /etc/os-release |grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)
LAST_BOOT=$(who -b | awk '{print $3,$4}')
UPTIME=$(uptime) && UPTIME_MIN=$(awk '{ print "up " $1 /60 " minutes"}' /proc/uptime)

#---------------------------
# System conf. check
#---------------------------
SYS_SCORE=0
RAM_FREE=$( expr $RAM_TOTAL - $RAM_USAGE)
RAM_FREE_PERCENTAGE=$((100 * $RAM_FREE/$RAM_TOTAL))
RAM_USE_PERCENTAGE=$(expr 100 - $RAM_FREE_PERCENTAGE) && if [ $RAM_USE_PERCENTAGE -lt 40 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
DISK_USAGE=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | awk '{ print $5" "$1"("$2"  "$3")" " --- "}' | sed -e :a -e N -e 's/\n/ /' -e ta |cut -d "%" -f1) && if [ $DISK_USAGE -lt 40 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
SWAP_VALUE=$(free -m |grep Swap: |cut -d ":" -f2)
SWAP_TOTAL=$(echo $SWAP_VALUE |cut -d " " -f1)
SWAP_USE=$(echo $SWAP_VALUE |cut -d " " -f2)
SWAP_USE_PERCENTAGE=$((100 * $SWAP_USE/$SWAP_TOTAL)) && if [ $SWAP_USE_PERCENTAGE = 0 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
#--------------------------
# check load
#--------------------------
top -b -n1 | head -17 | tail -11 > /tmp/systemload.txt
sed -i '1d' /tmp/systemload.txt
MOSTPROCESS=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f3)
MOSTRAM=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f2)
MOSTCPU=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f1)
#--------------------------
# Check Update
#--------------------------
if [ $REP = APT ]; then
	apt-get update 2>/dev/null |grep upgradable |cut -d '.' -f1 > /tmp/update_list.txt
	UPDATE_COUNT=$(cat /tmp/update_list.txt |wc -l)
		
	CHECK_UPDATE=EXIST
	if [ $UPDATE_COUNT = 0 ];then
		CHECK_UPDATE=NONE
		SYS_SCORE=$(($SYS_SCORE + 10))
	fi

elif [ $REP = YUM ]; then
	yum check-update > /tmp/update_list.txt
	sed -i '/Loaded/d' /tmp/update_list.txt
	sed -i '/Loading/d' /tmp/update_list.txt
	sed -i '/*/d' /tmp/update_list.txt
	sed -i '/Last metadata/d' /tmp/update_list.txt
	sed -i '/^$/d' /tmp/update_list.txt
	UPDATE_COUNT=$(cat /tmp/update_list.txt |wc -l)

	CHECK_UPDATE=EXIST
	if [ $UPDATE_COUNT = 0 ]; then
		CHECK_UPDATE=NONE
		SYS_SCORE=$(($SYS_SCORE + 10))
	fi
fi
#------------------------------
# broken package list for APT
#------------------------------
if [ $REP = APT ];then
	dpkg -l | grep -v "^ii" >> /dev/null && BROKEN_PACK=EXIST

	if [ $BROKEN_PACK = EXIST ]; then
		dpkg -l | grep -v "^ii" > /tmp/broken_pack_list.txt
		sed -i -e '1d;2d;3d' /tmp/broken_pack_list.txt
		SYS_SCORE=$(($SYS_SCORE + 10))
	fi
	ALLOWUNAUTH=$(grep -v "^#" /etc/apt/ -r | grep -c "AllowUnauthenticated")
	if [ $ALLOWUNAUTH = 0 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
	DEBSIG=$(grep -v "^#" /etc/dpkg/dpkg.cfg |grep -c no-debsig)
	if [ $DEBSIG = 1 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
fi

#--------------------------
# max. login check
#--------------------------
OPTIONS='maxsyslogins'
SETMAXLOGINS=$(sed -e '/^#/d' -e '/^[ \t][ \t]*#/d' -e 's/#.*$//' -e '/^$/d' /etc/security/limits.conf | grep "${OPTIONS}" | wc -l)
if [ ! $SETMAXLOGINS = 0 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
#--------------------------
# passwd, shadow, group file
#--------------------------
PASSWDFILEPERMS=$(ls -l /etc/passwd |cut -d ' ' -f1) && PASSWDFILEOWNER=$(ls -l /etc/passwd |cut -d ' ' -f3) && PASSWDFILEGRP=$(ls -l /etc/passwd |cut -d ' ' -f4)
SHADOWFILEPERMS=$(ls -l /etc/shadow |cut -d ' ' -f1) && SHADOWFILEOWNER=$(ls -l /etc/shadow |cut -d ' ' -f3) && SHADOWFILEGRP=$(ls -l /etc/shadow |cut -d ' ' -f4)
GROUPFILEPERMS=$(ls -l /etc/group |cut -d ' ' -f1) && GROUPFILEOWNER=$(ls -l /etc/group |cut -d ' ' -f3) && GROUPFILEGRP=$(ls -l /etc/group |cut -d ' ' -f4)
GSHADOWFILEPERMS=$(ls -l /etc/gshadow |cut -d ' ' -f1) && GSHADOWFILEOWNER=$(ls -l /etc/gshadow |cut -d ' ' -f3) && GSHADOWFILEGRP=$(ls -l /etc/gshadow |cut -d ' ' -f4)

#--------------------------
# checking empty password
#--------------------------
EMPTYPASSOUTPUT=$(cat /etc/passwd | awk -F: '($2 == "" ) { print $1 }')
if [ ! -z "$EMPTYPASSOUTPUT" ]; then
	CHECKEMPTYPASS="Some accounts have an empty password"
else
	CHECKEMPTYPASS="All accounts have a password"
	SYS_SCORE=$(($SYS_SCORE + 10))
fi

#--------------------------
# find local users
#--------------------------
getent passwd {1000..6000} > /tmp/localusers.txt
LOCALUSERCOUNT=$(wc -l /tmp/localusers.txt |cut -d " " -f1)
if [ $LOCALUSERCOUNT = 0 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi

#--------------------------
# sudo members check
#--------------------------
if [ -f /etc/sudoers ]; then
	cat /etc/sudoers |grep ALL= |grep -v % |grep -v root > /tmp/sudomembers.txt
	SUDOMEMBERCOUNT=$(wc -l /tmp/sudomembers.txt |cut -d " " -f1)
	if [ $SUDOMEMBERCOUNT = 0 ]; then
		SYS_SCORE=$(($SYS_SCORE + 10))
	fi
fi
SYS_SCORE="$SYS_SCORE/80"

#--------------------------
# FS Conf. check
#--------------------------
part_check () {
if [ "$#" != "1" ]; then
		options="$(echo $@ | awk 'BEGIN{FS="[()]"}{print $2}')"
	echo "[+]$@"
else
	echo "[-]\"$1\" not in separated partition. -Ref. CIS-"
fi
}
parts=(/tmp /var /var/tmp /var/log /var/log/audit /home /dev/shm)
for part in ${parts[*]}; do
	out="$(mount | grep $part)"
	part_check $part $out >> /tmp/fs_conf.txt
done

#---------------------------
# Network conf. check
#---------------------------
NW_SCORE=0
NWCONF1=$(sysctl net.ipv4.ip_forward |cut -d "=" -f2) && if [ $NWCONF1 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF2=$(sysctl net.ipv4.conf.all.send_redirects |cut -d "=" -f2) && if [ $NWCONF2 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF3=$(sysctl net.ipv4.conf.all.accept_source_route |cut -d "=" -f2) && if [ $NWCONF3 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF4=$(sysctl net.ipv4.conf.default.accept_source_route |cut -d "=" -f2) && if [ $NWCONF4 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF5=$(sysctl net.ipv4.conf.all.accept_redirects |cut -d "=" -f2) && if [ $NWCONF5 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF6=$(sysctl net.ipv4.conf.default.accept_redirects |cut -d "=" -f2) && if [ $NWCONF6 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF7=$(sysctl net.ipv4.conf.all.secure_redirects |cut -d "=" -f2) && if [ $NWCONF7 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF8=$(sysctl net.ipv4.conf.default.secure_redirects |cut -d "=" -f2) && if [ $NWCONF8 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF9=$(sysctl net.ipv4.icmp_echo_ignore_broadcasts |cut -d "=" -f2) && if [ $NWCONF9 = 1 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF10=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses |cut -d "=" -f2) && if [ $NWCONF10 = 1 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF11=$(sysctl net.ipv4.conf.all.rp_filter |cut -d "=" -f2) && if [ $NWCONF11 = 1 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF12=$(sysctl net.ipv4.tcp_syncookies |cut -d "=" -f2) && if [ $NWCONF12 = 1 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NWCONF13=$(sysctl net.ipv6.conf.all.accept_ra |cut -d "=" -f2) && if [ $NWCONF13 = 0 ]; then NW_SCORE=$(($NW_SCORE + 10)); fi
NW_SCORE="$NW_SCORE/130"

#---------------------------
# SSH conf. check
#---------------------------
# PRIVATE HOST KEY
SSH_SCORE=0
SSHCONF1=$(stat /etc/ssh/sshd_config |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ $SSHCONF1 = 0600 ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF2=$(stat /etc/ssh/ssh_host_rsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ $SSHCONF2 = 0600 ]; then SSHS_CORE=$(($SSHS_CORE + 10)); fi
SSHCONF3=$(stat /etc/ssh/ssh_host_ecdsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ $SSHCONF3 = 0600 ]; then SSHS_CORE=$(($SSH_SCORE + 10)); fi
SSHCONF4=$(stat /etc/ssh/ssh_host_ed25519_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ $SSHCONF4 = 0600 ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
# PUBLIC HOST KEY
SSHCONF5=$(stat /etc/ssh/ssh_host_rsa_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ $SSHCONF5 = 0644 ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF6=$(stat /etc/ssh/ssh_host_ed25519_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ $SSHCONF6 = 0644 ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF7=$(stat /etc/ssh/ssh_host_ed25519_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ $SSHCONF7 = 0644 ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
grep ^Protocol /etc/ssh/sshd_config > /dev/null && if [ "$?= 0" ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF8=$(sshd -T | grep loglevel |cut -d " " -f2) && if [ $SSHCONF8 = INFO ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF9=$(sshd -T | grep x11forwarding |cut -d " " -f2) && if [ $SSHCONF9 = no ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF10=$(sshd -T | grep maxauthtries |cut -d " " -f2) && if [ $SSHCONF10 -lt 4 ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF11=$(sshd -T | grep ignorerhosts |cut -d " " -f2) && if [ $SSHCONF11 = yes ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF12=$(sshd -T | grep hostbasedauthentication |cut -d " " -f2) && if [ $SSHCONF12 = no ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF13=$(sshd -T | grep permitrootlogin |cut -d " " -f2) && if [ $SSHCONF13 = no ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF14=$(sshd -T | grep permitemptypasswords |cut -d " " -f2) && if [ $SSHCONF14 = no ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSHCONF15=$(sshd -T | grep permituserenvironment |cut -d " " -f2) && if [ $SSHCONF15 = no ]; then SSH_SCORE=$(($SSH_SCORE + 10)); fi
SSH_SCORE="$SSH_SCORE/150"


#--------------------------
# CVE Check
#--------------------------
KERNELVER=$(uname -a |cut -d " " -f3 |cut -d "-" -f1)
perl /tmp/cve_check -k $KERNELVER > /tmp/cve_list
CVELIST=$(cat /tmp/cve_list |grep CVE) && echo $CVELIST > /tmp/cve_list && CVELIST=$(cat /tmp/cve_list) && rm /tmp/cve_list && rm /tmp/cve_check

#--------------------------
# Rootkit Check
#--------------------------
bash /tmp/chkrootkit > /tmp/rootkit.txt
cat /tmp/rootkit.txt |grep "INFECTED" > /tmp/rootkit_result.txt
cat /tmp/rootkit.txt |grep "Warning" >> /tmp/rootkit_result.txt
ROOTKITCHECK=$(wc -l /tmp/rootkit_result.txt |cut -d " " -f1)
ROOTKITLIST=$(cat /tmp/rootkit_result.txt)
rm /tmp/rootkit.txt /tmp/rootkit_result.txt

#--------------------------
# for notification
#--------------------------
#--------------------------
# repo list
#--------------------------
if [ $REP = APT ]; then
	cat /etc/apt/sources.list > /tmp/repo_list.txt
	shopt -s nullglob dotglob
	files=(/etc/apt/sources.list.d/*)
	DIRC=EMPTY
	if [ ${#files[@]} -gt 0 ]; then DIRC=FULL; fi
	if [ $DIRC = "FULL" ]; then
	echo "----------------------------------------------" >> /tmp/repo_list.txt
	cat /etc/apt/sources.list.d/* >> /tmp/repo_list.txt
	fi
elif [ $REP = YUM ]; then
	yum repolist > /tmp/repo_list.txt
fi
#--------------------------
# running services
#--------------------------
rm /tmp/runningservices.txt
systemctl list-units --type service |grep running > /tmp/runningservices.txt && NUMPROCESS=$(wc -l /tmp/runningservices.txt |cut -d ' ' -f1)

#--------------------------
# listening,established conn.
#--------------------------
rm /tmp/listeningconn.txt
rm /tmp/establishedconn.txt
netstat -tupl > /tmp/listeningconn.txt
netstat -tup | grep ESTABLISHED > /tmp/establishedconn.txt
sed -i '1d' /tmp/establishedconn.txt && sed -i '1d' /tmp/listeningconn.txt
ESTABLISHEDCONN=$(wc -l /tmp/establishedconn.txt |cut -d " " -f1)
LISTENINGCONN=$(wc -l /tmp/listeningconn.txt |cut -d " " -f1)

#--------------------------
# connected users
#--------------------------
w > /tmp/connectedusers.txt
CONNUSERCOUNT=$(w |grep up |cut -d " " -f7)


#--------------------------
# integrity check
#--------------------------
LOCALDIR="/usr/local/lastcontrol/data/etc"
if [ ! -d "$LOCALDIR" ]; then
mkdir -p $LOCALDIR
rsync -a /etc/ $LOCALDIR
fi
rsync -a -n -v /etc/ $LOCALDIR > /tmp/integritycheck.txt
sed -i -e :a -e '$d;N;2,2ba' -e 'P;D' /tmp/integritycheck.txt
sed -i '1d' /tmp/integritycheck.txt

#--------------------------
# inventory check
#--------------------------
LOCALFILE="/usr/local/lastcontrol/data/inventory"
#fdisk -l |grep "Disk /dev" > /tmp/hddlist.txt
lsblk > /tmp/hddlist.txt
cat > /tmp/inventory.txt << EOF
HOSTNAME:$HOST_NAME
IPADDRESS:$IPADDRESS
MACADDRESS:$MACADDRESS
CPU:$CPUINFO
RAM:$RAM_TOTAL
VGA:$VGA_CONTROLLER
EOF
cat /tmp/hddlist.txt >> /tmp/inventory.txt && rm /tmp/hddlist.txt

if [ ! -f "$LOCALFILE" ]; then
cp /tmp/inventory.txt $LOCALFILE
INVCHECK="CREATED"
else
INVCHECK="DETECTED"
diff $LOCALFILE /tmp/inventory.txt > /dev/null && INVCHECK="NOTDETECTED"
fi

#--------------------------
# report file
#--------------------------
rm /tmp/$HOST_NAME.txt
cat > /tmp/$HOST_NAME.txt << EOF
$HOST_NAME LastControl Report $DATE
=======================================================================================================================================================================
------------------------------------------------------------------------------------------------------
				:::... MACHINE INVENTORY ...:::
------------------------------------------------------------------------------------------------------
|Hostname:          |$HOST_NAME
------------------------------------------------------------------------------------------------------
|CPU Info:          |$CPUINFO
|RAM:               |Total:$RAM_TOTAL | Usage:$RAM_USAGE
|VGA Controller:    |$VGA_CONTROLLER
|HDD:               |$DISK_LIST
|Virtualization:    |$VIRT_CONTROL
|Operation System:  |$OS_KERNEL
|OS Version:        |$OS_VER
|Check Update:      |$CHECK_UPDATE
|Update Count:      |$UPDATE_COUNT
|Last Boot:         |$LAST_BOOT
|Uptime	            |$UPTIME | $UPTIME_MIN
------------------------------------------------------------------------------------------------------
|Running Process:   |$NUMPROCESS
|Uses the Most Load |Process: $MOSTPROCESS | Cpu: $MOSTCPU | Ram: $MOSTRAM
------------------------------------------------------------------------------------------------------
|Listening Conn.:   |$LISTENINGCONN
|Established Conn.: |$ESTABLISHEDCONN
|Connected User:    |$CONNUSERCOUNT
|Local User Count:  |$LOCALUSERCOUNT
|SUDO Member Count  |$SUDOMEMBERCOUNT
------------------------------------------------------------------------------------------------------
|Ram Use:           |$RAM_USE_PERCENTAGE%
|Swap Use:          |$SWAP_USE_PERCENTAGE%
|Disk Use:          |$DISK_USAGE%
------------------------------------------------------------------------------------------------------
|SUDO Member Count: |$SUDOMEMBERCOUNT
|Local User Count:  |$LOCALUSERCOUNT
------------------------------------------------------------------------------------------------------
|System Score:      |$SYS_SCORE
|Network Score:     |$NW_SCORE
|SSH Score:         |$SSH_SCORE
------------------------------------------------------------------------------------------------------
|Inventory Check:   |$INVCHECK
------------------------------------------------------------------------------------------------------
|Kernel Version:    |$KERNELVER
------------------------------------------------------------------------------------------------------
|CVE List:          |$CVELIST
------------------------------------------------------------------------------------------------------
|Rootkit infected   |$ROOTKITCHECK
|Rootkit List:      |$ROOTKITLIST
------------------------------------------------------------------------------------------------------
|IP Address:        |$IPADDRESS
------------------------------------------------------------------------------------------------------
EOF

echo >> /tmp/$HOST_NAME.txt
echo >> /tmp/$HOST_NAME.txt

if [ $INVCHECK = DETECTED ]; then
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "                          :::... CHANGE HARDWARE NOTIFICATION !!! ....:::" >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	diff $LOCALFILE /tmp/inventory.txt >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
fi
rm /tmp/inventory.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "				:::... SYSTEM LOAD ....:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Running Process/Apps." >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/runningservices.txt >> /tmp/$HOST_NAME.txt ##&& rm /tmp/runningservices.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "			:::... LISTENING PORTS & ESTABLISHED CONN. ...:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Listening Ports" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/listeningconn.txt >> /tmp/$HOST_NAME.txt ##&& rm /tmp/listeningconn.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Established Connections" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/establishedconn.txt >> /tmp/$HOST_NAME.txt ##&& rm /tmp/establishedconn.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Connected Users" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/connectedusers.txt >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Login Information for all Users" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
lslogins -u >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "sudo members" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/sudomembers.txt >> /tmp/$HOST_NAME.txt && rm /tmp/sudomembers.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Checking Empty Password" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo $CHECKEMPTYPASS >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "			:::... Filesystem Configuration Check ...:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/fs_conf.txt >> /tmp/$HOST_NAME.txt && rm /tmp/fs_conf.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "                  :::... REPOs LIST ...:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/repo_list.txt >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt && rm /tmp/repo_list.txt

if [ $REP = APT ];then
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "			:::... BROKEN PACKAGE LIST ...:::" >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "" >> /tmp/$HOST_NAME.txt
	cat /tmp/package_list.txt >> /tmp/$HOST_NAME.txt && rm /tmp/package_list.txt
	echo "" >> /tmp/$HOST_NAME.txt
fi

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "			:::... INTEGRITY CHECK ...:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Warnings" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/integritycheck.txt >> /tmp/$HOST_NAME.txt && rm /tmp/integritycheck.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "=======================================================================================================================================================================" >> /tmp/$HOST_NAME.txt
