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
HOST_NAME=$(hostname -f)

ip a |grep "inet " > /tmp/ipoutput && sed -i '/127.0/d' /tmp/ipoutput
IPADDRESS=$(cat /tmp/ipoutput) && rm /tmp/ipoutput
CPUINFO=$(cat /proc/cpuinfo |grep "model name" |cut -d ':' -f2 > /tmp/cpuinfooutput.txt && tail -n1 /tmp/cpuinfooutput.txt > /tmp/cpuinfo.txt && rm /tmp/cpuinfooutput.txt && cat /tmp/cpuinfo.txt) && rm /tmp/cpuinfo.txt
RAM_TOTAL=$(free -m |awk 'NR == 2 {print "" $2*1.024}')
RAM_USAGE=$(free -m |awk 'NR == 2 {print "" $3*1.024}')
GPU=$(lspci | grep VGA | cut -d ":" -f3);GPURAM=$(cardid=$(lspci | grep VGA |cut -d " " -f1);lspci -v -s $cardid | grep " prefetchable"| awk '{print $6}' | head -1)
VGA_CONTROLLER="$GPU $GPURAM"
DISK_USAGE=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | awk '{ print $5" "$1"("$2"  "$3")" " --- "}' | sed -e :a -e N -e 's/\n/ /' -e ta)
VIRT_CONTROL=NONE               
if [ -f "/dev/kvm" ]; then $VIRT_CONTROL=ON; fi
OS_KERNEL=$(uname -a)
OS_VER=$(cat /etc/os-release |grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)
LAST_BOOT=$(who -b | awk '{print $3,$4}')
UPTIME=$(uptime)

#--------------------------
# Check Update
#--------------------------
if [ $REP = APT ]; then
	apt-get update 2>/dev/null |grep upgradable |cut -d '.' -f1 > /tmp/update_list.txt
	UPDATE_COUNT=$(cat /tmp/update_list.txt |wc -l)
		
	CHECK_UPDATE=EXIST
	if [ $UPDATE_COUNT = 0 ];then
		CHECK_UPDATE=NONE
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
	fi
fi

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
#service --status-all > /tmp/runningservices.txt && NUMPROCESS=$(wc -l /tmp/runningservices.txt |cut -d ' ' -f1)

#--------------------------
# process using the most cpu and memory
#--------------------------
rm /tmp/mostram.txt
ps aux | awk '{print $2, $4, $6, $11}' | sort -k3rn | head -n 10 > /tmp/mostram.txt
MOSTRAM=$(head -1 /tmp/mostram.txt)

#--------------------------
# ssh config check
#--------------------------
sshd -T | grep x11forwarding > /tmp/sshconfig.txt
sshd -T | grep maxauthtries >> /tmp/sshconfig.txt
sshd -T | grep hostbasedauthentication >> /tmp/sshconfig.txt
sshd -T | grep ignorerhosts >> /tmp/sshconfig.txt
sshd -T | grep permitrootlogin >> /tmp/sshconfig.txt
sshd -T | grep permitemptypasswords >> /tmp/sshconfig.txt
sshd -T | grep permituserenvironment >> /tmp/sshconfig.txt
sshd -T | grep clientaliveinterval >> /tmp/sshconfig.txt
sshd -T | grep clientalivecountmax >> /tmp/sshconfig.txt
sshd -T | grep logingracetime >> /tmp/sshconfig.txt
sshd -T | grep allowusers >> /tmp/sshconfig.txt
sshd -T | grep allowgroups >> /tmp/sshconfig.txt
sshd -T | grep denyusers >> /tmp/sshconfig.txt
sshd -T | grep denygroups >> /tmp/sshconfig.txt
sshd -T | grep -i allowtcpforwarding >> /tmp/sshconfig.txt


#------------------------------
# broken package list for APT
#------------------------------
if [ $REP = APT ];then
	dpkg -l | grep -v "^ii" > /tmp/package_list.txt
	sed -i -e '1d;2d;3d' /tmp/package_list.txt
fi

rm /tmp/mostcpu.txt
top -b -n1 | head -17 | tail -11 > /tmp/mostcpu.txt
sed -i '1d' /tmp/mostcpu.txt
MOSTCPU=$(head -1 /tmp/mostcpu.txt)

#--------------------------
# listening,established conn.
#--------------------------
rm /tmp/listeningconn.txt
rm /tmp/establishedconn.txt
netstat -tupl > /tmp/listeningconn.txt
netstat -tup | grep ESTABLISHED > /tmp/establishedconn.txt
sed -i '1d' /tmp/establishedconn.txt && sed -i '1d' /tmp/listeningconn.txt

#--------------------------
# connected users
#--------------------------
w > /tmp/connectedusers.txt

ALLOWUNAUTHENTICATED=$(grep -v "^#" /etc/apt/ -r | grep -c "AllowUnauthenticated")
DEBSIG=$(grep -v "^#" ${/etc/dpkg/dpkg.cfg} | grep -c ${no-debsig})
OPTIONS='maxsyslogins'
SETMAXLOGINS=$(sed -e '/^#/d' -e '/^[ \t][ \t]*#/d' -e 's/#.*$//' -e '/^$/d' /etc/security/limits.conf | grep "${OPTIONS}" | wc -l)

#--------------------------
# SUID check
#--------------------------
SUIDOUTPUT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' $SUDO_CMD find '{}' -xdev -type f -perm -4000 -print)
if [ ! -z "$SUIDOUTPUT" ]; then
	SUIDCHECK="OK"
else
	SUIDCHECK="SUID file not found"
fi

#--------------------------
# SGID check
#--------------------------
SGIDOUTPUT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' $SUDO_CMD find '{}' -xdev -type f -perm -2000 -print)
if [ ! -z "$SGIDOUTPUT" ]; then
	SGIDCHECK="OK"
else
	SGIDCHECK="SGID file not found"
fi

PASSWDFILEPERMS=$(ls -l /etc/passwd |cut -d ' ' -f1) && PASSWDFILEOWNER=$(ls -l /etc/passwd |cut -d ' ' -f3) && PASSWDFILEGRP=$(ls -l /etc/passwd |cut -d ' ' -f4)
SHADOWFILEPERMS=$(ls -l /etc/shadow |cut -d ' ' -f1) && SHADOWFILEOWNER=$(ls -l /etc/shadow |cut -d ' ' -f3) && SHADOWFILEGRP=$(ls -l /etc/shadow |cut -d ' ' -f4)
GROUPFILEPERMS=$(ls -l /etc/group |cut -d ' ' -f1) && GROUPFILEOWNER=$(ls -l /etc/group |cut -d ' ' -f3) && GROUPFILEGRP=$(ls -l /etc/group |cut -d ' ' -f4)
GSHADOWFILEPERMS=$(ls -l /etc/gshadow |cut -d ' ' -f1) && GSHADOWFILEOWNER=$(ls -l /etc/gshadow |cut -d ' ' -f3) && GSHADOWFILEGRP=$(ls -l /etc/gshadow |cut -d ' ' -f4)

UNOWNEDFILEOUTPUT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' $SUDO_CMD find '{}' -xdev -nouser -print 2>/dev/null)
if [ ! -z "$UNOWNEDFILEOUTPUT" ]; then
	UNOWNEDFILECHECK="Unowned file found!!"
else
	UNOWNEDFILECHECK="Unowned file not found"
fi

UNGROUPEDFILEOUTPUT=$(df --local -P | awk {'if (NR!=1) print $6'} | xargs -I '{}' $SUDO_CMD find '{}' -xdev -nogroup -print 2>/dev/null)
if [ ! -z "$UNGROUPEDFILEOUTPUT" ]; then
	UNGROUPEDFILECHECK="Ungrouped file found!!"
else
	UNGROUPEDFILECHECK="Ungrouped file not found"
fi

#--------------------------
# checking empty password
#--------------------------
EMPTYPASSOUTPUT=$($SUDO_CMD cat $FILE | awk -F: '($2 == "" ) { print $1 }')
if [ ! -z "$EMPTYPASSOUTPUT" ]; then
	CHECKEMPTYPASS="Some accounts have an empty password"
else
	CHECKEMPTYPASS="All accounts have a password"
fi

#--------------------------
# find local users
#--------------------------
getent passwd {1000..6000} > /tmp/localusers.txt

#--------------------------
# sudo members
#--------------------------
cat /etc/sudoers |grep ALL= > /tmp/sudomembers.txt

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
|HDD:               |$DISK_USAGE
|Virtualization:    |$VIRT_CONTROL
|Operation System:  |$OS_KERNEL
|OS Version:        |$OS_VER
|Check Update:      |$CHECK_UPDATE
|Last Boot:         |$LAST_BOOT
|Uptime	            |$UPTIME
------------------------------------------------------------------------------------------------------
|running process:   |$NUMPROCESS
|Most using Memory: |$MOSTRAM
|Most using Cpu:    |$MOSTCPU
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

echo "" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

#if [ $ROOTKITCHECK != "0" ]; then
#	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
#	echo "                          :::... ROOTKIT NOTIFICATION !!! ....:::" >> /tmp/$HOST_NAME.txt
#	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
#	echo $ROOTKITLIST
#fi
#echo "" >> /tmp/$HOST_NAME.txt

if [ $INVCHECK = DETECTED ]; then
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "                          :::... CHANGE HARDWARE NOTIFICATION !!! ....:::" >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	diff $LOCALFILE /tmp/inventory.txt >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
fi
rm /tmp/inventory.txt
echo "" >> /tmp/$HOST_NAME.txt

if [ $CHECK_UPDATE = EXIST ]; then
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "                          :::... UPDATE LIST ....:::" >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	cat /tmp/update_list.txt >> /tmp/$HOST_NAME.txt && rm /tmp/update_list.txt
fi
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "				:::... SYSTEM LOAD ....:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Running Process/Apps." >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/runningservices.txt >> /tmp/$HOST_NAME.txt && rm /tmp/runningservices.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Top memory using Processs/Apps." >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/mostram.txt >> /tmp/$HOST_NAME.txt && rm /tmp/mostram.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Top CPU using Processs/Apps." >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/mostcpu.txt >> /tmp/$HOST_NAME.txt && rm /tmp/mostcpu.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "			:::... LISTENING PORTS & ESTABLISHED CONN. ...:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Listening Ports" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/listeningconn.txt >> /tmp/$HOST_NAME.txt && rm /tmp/listeningconn.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Established Connections" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/establishedconn.txt >> /tmp/$HOST_NAME.txt && rm /tmp/establishedconn.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Connected Users" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/connectedusers.txt >> /tmp/$HOST_NAME.txt && rm /tmp/connectedusers.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Login Information for all Users" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
lslogins -u >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "			:::... LOCAL USERS ...:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Local User List" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/localusers.txt >> /tmp/$HOST_NAME.txt && rm /tmp/localusers.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Checking Empty Password" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo $CHECKEMPTYPASS >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "sudo members" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/sudomembers.txt >> /tmp/$HOST_NAME.txt && rm /tmp/sudomembers.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "			:::... SYSTEM SECURITY ...:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "Allow Unauthenticated Check: $ALLOWUNAUTHENTICATED" >> /tmp/$HOST_NAME.txt
echo "Deb package signature      : $DEBSIG" >> /tmp/$HOST_NAME.txt
echo "Set Max Logins             : $SETMAXLOGINS" >> /tmp/$HOST_NAME.txt
echo "SUID File Check            : $SUIDCHECK" >> /tmp/$HOST_NAME.txt
echo "SGID File Check            : $SGIDCHECK" >> /tmp/$HOST_NAME.txt
echo "passwd File Perms.         : $PASSWDFILEPERMS | $PASSWDFILEOWNER:$PASSWDFILEGRP" >> /tmp/$HOST_NAME.txt
echo "shadow File Perms.         : $SHADOWFILEPERMS | $SHADOWFILEOWNER:$SHADOWFILEGRP" >> /tmp/$HOST_NAME.txt
echo "group File Perms.          : $GROUPFILEPERMS  | $GROUPFILEOWNER:$GROUPFILEGRP" >> /tmp/$HOST_NAME.txt
echo "gshadow File Perms.        : $GSHADOWFILEPERMS| $GSHADOWFILEOWNER:$GSHADOWFILEGRP" >> /tmp/$HOST_NAME.txt
echo "Unowned File Check         : $UNOWNEDFILECHECK" >> /tmp/$HOST_NAME.txt
echo "Ungrouped File Check       : $UNGROUPEDFILECHECK" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "			:::... Filesystem Configuration Check ...:::" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/fs_conf.txt >> /tmp/$HOST_NAME.txt && rm /tmp/fs_conf.txt
echo "" >> /tmp/$HOST_NAME.txt

echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
echo "SSH Config Check" >> /tmp/$HOST_NAME.txt
echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
cat /tmp/sshconfig.txt >> /tmp/$HOST_NAME.txt && rm /tmp/sshconfig.txt
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
