#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

#--------------------------
# determine distro
#--------------------------
cat /etc/redhat-release > /tmp/distrocheck 2>/dev/null || cat /etc/*-release > /tmp/distrocheck 2>/dev/null || cat /etc/issue > /tmp/distrocheck 2>/dev/null
grep -i "debian" /tmp/distrocheck &>/dev/null && REP=APT
grep -i "ubuntu" /tmp/distrocheck &>/dev/null && REP=APT
grep -i "centos" /tmp/distrocheck &>/dev/null && REP=YUM
grep -i "red hat" /tmp/distrocheck &>/dev/null && REP=YUM
grep -i "rocky" /tmp/distrocheck &>/dev/null && REP=YUM

rm /tmp/distrocheck

#--------------------------
# install packages
#--------------------------
if [ "$REP" = "APT" ]; then
	apt-get -y install net-tools rsync smartmontools
fi
if [ "$REP" = "YUM" ]; then
	yum -y install net-tools rsync perl smartmontools
fi

DATE=$(date)
HOST_NAME=$(hostnamectl --static)
HANDBOOK=https://github.com/eesmer/LastControl/blob/main/LastControl-HandBook.md

#---------------------------
# Inventory
#---------------------------
IPADDRESS=$(hostname -I)
CPUINFO=$(cat /proc/cpuinfo |grep "model name" |cut -d ':' -f2 > /tmp/cpuinfooutput.txt && tail -n1 /tmp/cpuinfooutput.txt > /tmp/cpuinfo.txt && rm /tmp/cpuinfooutput.txt && cat /tmp/cpuinfo.txt) && rm /tmp/cpuinfo.txt
RAM_TOTAL=$(free -m | head -2 | tail -1| awk '{print $2}')
RAM_USAGE=$(free -m | head -2 | tail -1| awk '{print $3}')
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
# HEALTHCHECK
#---------------------------
rm /tmp/$HOST_NAME.healthcheck

RAM_FREE=$( expr $RAM_TOTAL - $RAM_USAGE)
RAM_FREE_PERCENTAGE=$((100 * $RAM_FREE/$RAM_TOTAL))
RAM_USE_PERCENTAGE=$(expr 100 - $RAM_FREE_PERCENTAGE)
	if [ $RAM_USE_PERCENTAGE -gt "50" ]; then 
		echo "<a href='$HANDBOOK#-ram_usage_is_reported'>WARN: Ram %$RAM_USE_PERCENTAGE usage</a>" >> /tmp/$HOST_NAME.healthcheck
		OOM=0
		grep -i -r 'out of memory' /var/log/ > /dev/null && OOM=1
		if [ $OOM = "1" ]; then echo "<a href='$HANDBOOK#-ram_usage_is_reported'>WARN: out of memory message log found</a>" >> /tmp/$HOST_NAME.healthcheck; fi
	fi
DISK_USAGE=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | awk '{ print $5" "$1"("$2"  "$3")" " --- "}' | sed -e :a -e N -e 's/\n/ /' -e ta |cut -d "%" -f1)
	if [ $DISK_USAGE -gt "50" ]; then
		echo "<a href='$HANDBOOK#-disk_usage_is_reported'>WARN: Disk %$DISK_USAGE usage.</a>" >> /tmp/$HOST_NAME.healthcheck
	fi
SWAP_VALUE=$(free -m |grep Swap: |cut -d ":" -f2)
SWAP_TOTAL=$(echo $SWAP_VALUE |cut -d " " -f1)
SWAP_USE=$(echo $SWAP_VALUE |cut -d " " -f2)
SWAP_USE_PERCENTAGE=$((100 * $SWAP_USE/$SWAP_TOTAL))
	if [ $SWAP_USE_PERCENTAGE -gt "0" ]; then
		echo "<a href='$HANDBOOK#-swap_usage_is_reported'>WARN: Swap %$SWAP_USE_PERCENTAGE usage</a>" >> /tmp/$HOST_NAME.healthcheck
	fi

#---------------------------
# S.M.A.R.T check
#---------------------------
df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev|mapper' |cut -d " " -f1 > /tmp/disklist.txt
NUMDISK=$(cat /tmp/disklist.txt | wc -l)
SMART_SCORE=0
i=1

while [ "$i" -le "$NUMDISK" ]; do
DISK=$(ls -l |sed -n $i{p} /tmp/disklist.txt)

smartctl -i -x $DISK >> /dev/null > /tmp/DISK$i.txt
SMART_SUPPORT=0
egrep "SMART support is: Available - device has SMART capability." /tmp/DISK$i.txt >> /dev/null && SMART_SUPPORT=1

if [ "$SMART_SUPPORT" = "1" ]; then
	SMART_SUPPORT="Available - device has SMART capability."
	SMART_RESULT=$(cat /tmp/DISK$i.txt |grep "SMART overall-health self-assessment test result:" |cut -d: -f2 |cut -d " " -f2)
else
	SMART_SUPPORT="Unavailable - device lacks SMART capability."
	SMART_RESULT="Not Passed"
fi

if [ "$SMART_SUPPORT" = "1" ] && [ "$SMART_RESULT" = "pass" ]; then
	SMART_SCORE=$(($SMART_SCORE + 1))
fi

echo "-> $DISK" >> /tmp/smartcheck-result.txt 
echo "Support: $SMART_SUPPORT" >> /tmp/smartcheck-result.txt
echo "Result: $SMART_RESULT" >> /tmp/smartcheck-result.txt
echo  "" >> /tmp/smartcheck-result.txt

i=$(( i + 1 ))
SMART=$(cat /tmp/smartcheck-result.txt)
done
rm -f /tmp/smartcheck-result.txt
rm -f /tmp/disklist.txt
#SMART=$(echo $SMART)

if [ $SMART_SCORE = "0" ]; then
	echo "<a href='$HANDBOOK'>WARN: S.M.A.R.T Failed or not tested.</a>" >> /tmp/$HOST_NAME.healthcheck
fi

#----------------------------------
# Resource usage CPU,Ram Load
#----------------------------------
top -b -n1 | head -17 | tail -11 > /tmp/systemload.txt
sed -i '1d' /tmp/systemload.txt
MOST_PROCESS=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f3)
MOST_RAM=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f2)
MOST_CPU=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f1)
echo "<a href='$HANDBOOK#-using_the_most_resource'>INFO:  Using the most Resource: $MOST_PROCESS</a>" >> /tmp/$HOST_NAME.sysout
echo "<a href='$HANDBOOK#-using_the_most_ram'>INFO:  Using the most Ram: $MOST_RAM</a>" >> /tmp/$HOST_NAME.sysout
echo "<a href='$HANDBOOK#-using_the_most_cpu'>INFO:  Using the most Cpu: $MOST_CPU</a>" >> /tmp/$HOST_NAME.sysout	
rm -f /tmp/systemload.txt

#--------------------------
# Check Update
#--------------------------
if [ "$REP" = "APT" ]; then
	CHECK_UPDATE=NONE
	UPDATE_COUNT=0
	echo "n" |apt-get upgrade > /tmp/update_list.txt
	cat /tmp/update_list.txt |grep "The following packages will be upgraded:" >> /dev/null && CHECK_UPDATE=EXIST \
		&& UPDATE_COUNT=$(cat /tmp/update_list.txt |grep "upgraded," |cut -d " " -f1)
	if [  $CHECK_UPDATE = "EXIST" ]; then 
		echo "<a href='$HANDBOOK#-update_check_is_reported'>INFO:  Update $CHECK_UPDATE | Count: $UPDATE_COUNT</a>" >> /tmp/$HOST_NAME.healthcheck
	fi

elif [ "$REP" = "YUM" ]; then
	yum check-update > /tmp/update_list.txt
	sed -i '/Loaded/d' /tmp/update_list.txt
	sed -i '/Loading/d' /tmp/update_list.txt
	sed -i '/*/d' /tmp/update_list.txt
	sed -i '/Last metadata/d' /tmp/update_list.txt
	sed -i '/^$/d' /tmp/update_list.txt
	UPDATE_COUNT=$(cat /tmp/update_list.txt |wc -l)

	CHECK_UPDATE=EXIST
	if [ $UPDATE_COUNT -gt "0" ]; then
		echo "<a href='$HANDBOOK#-update_check_is_reported'>INFO:  Update $CHECK_UPDATE | Count: $UPDATE_COUNT</a>" >> /tmp/$HOST_NAME.healthcheck
	else
		CHECK_UPDATE=NONE
	fi
rm -f /tmp/update_list.txt
fi

#------------------------------
# broken package list
#------------------------------
if [ "$REP" = "APT" ];then
	dpkg -l | grep -v "^ii" >> /dev/null > /tmp/broken_pack_list.txt
	sed -i -e '1d;2d;3d;4d;5d' /tmp/broken_pack_list.txt
	BROKEN_COUNT=$(wc -l /tmp/broken_pack_list.txt |cut -d " " -f1)
	if [ $BROKEN_COUNT -gt "0" ]; then
		echo "<a href='$HANDBOOK'>WARN: $BROKEN_COUNT package(s) is a broken</a>" >> /tmp/$HOST_NAME.healthcheck
	fi

	### ALLOWUNAUTH=$(grep -v "^#" /etc/apt/ -r | grep -c "AllowUnauthenticated")
	### if [ $ALLOWUNAUTH = 0 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
	### DEBSIG=$(grep -v "^#" /etc/dpkg/dpkg.cfg |grep -c no-debsig)
	### if [ $DEBSIG = 1 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
fi

if [ "$REP" = "YUM" ];then
	rpm -Va >> /dev/null > /tmp/broken_pack_list.txt
	BROKEN_COUNT=$(wc -l /tmp/broken_pack_list.txt |cut -d " " -f1)
	if [ $BROKEN_COUNT -gt "0" ]; then
		echo "<a href='$HANDBOOK'>WARN: $BROKEN_COUNT package(s) is a broken</a>" >> /tmp/$HOST_NAME.healthcheck
	fi
fi

#------------------------------------
# HARDENING CHECK
#------------------------------------
rm /tmp/$HOST_NAME.hardening

#------------------------------------
# check local users,limits and sudo
#------------------------------------
getent passwd {1000..6000} |cut -d ":" -f1 > /tmp/userlist
LOCALUSER_COUNT=$(wc -l /tmp/userlist |cut -d " " -f1)
if [ $LOCALUSER_COUNT = "0" ]; then
	rm /tmp/userlist
else
	echo "<a href='$HOST_NAME.localusers'>INFO:  $LOCALUSER_COUNT local user(s) exist</a>" >> /tmp/$HOST_NAME.hardening
	# check login limits
	i=1
	while [ $i -le $LOCALUSER_COUNT ]; do
		USER=$(ls -l |sed -n $i{p} /tmp/userlist)
		cat /etc/security/limits.conf |grep $USER >> /dev/null
		if [ $? = "0" ]; then 
			echo "$USER | Limit:Pass" > /tmp/$HOST_NAME.localusers
		else
			echo "$USER | Limit:Fail" > /tmp/$HOST_NAME.localusers
		fi
	i=$(( i + 1 ))
	done
        
	cat /tmp/$HOST_NAME.localusers |grep Fail >> /dev/null
	if [ $? = "0" ]; then
		echo "<a href='$HANDBOOK'>INFO:  User Limit not used.</a>" >> /tmp/$HOST_NAME.hardening
	fi

	# sudo members check
	if [ -f "/etc/sudoers" ]; then
		SUDOMEMBERCOUNT=$(cat /etc/sudoers |grep ALL= |grep -v % |grep -v root |wc -l)
		if [ $SUDOMEMBERCOUNT -gt "0" ]; then
			cat /etc/sudoers |grep ALL= |grep -v % |grep -v root > /tmp/$HOST_NAME.sudomembers
			echo "<a href='$HOST_NAME.sudomembers'>INFO:  $SUDOMEMBERCOUNT user(s) have SUDO privileges.</a>" >> /tmp/$HOST_NAME.hardening
		fi
	else
		SUDOMEMBERCOUNT=0
	fi
fi

#--------------------------
# passwd, shadow, group file
#--------------------------
PASSWDFILEPERMS=$(ls -l /etc/passwd |cut -d ' ' -f1) && PASSWDFILEOWNER=$(ls -l /etc/passwd |cut -d ' ' -f3) && PASSWDFILEGRP=$(ls -l /etc/passwd |cut -d ' ' -f4)
SHADOWFILEPERMS=$(ls -l /etc/shadow |cut -d ' ' -f1) && SHADOWFILEOWNER=$(ls -l /etc/shadow |cut -d ' ' -f3) && SHADOWFILEGRP=$(ls -l /etc/shadow |cut -d ' ' -f4)
GROUPFILEPERMS=$(ls -l /etc/group |cut -d ' ' -f1) && GROUPFILEOWNER=$(ls -l /etc/group |cut -d ' ' -f3) && GROUPFILEGRP=$(ls -l /etc/group |cut -d ' ' -f4)
GSHADOWFILEPERMS=$(ls -l /etc/gshadow |cut -d ' ' -f1) && GSHADOWFILEOWNER=$(ls -l /etc/gshadow |cut -d ' ' -f3) && GSHADOWFILEGRP=$(ls -l /etc/gshadow |cut -d ' ' -f4)

PASSWD_CHECK=NONE
SHADOW_CHECK=NONE
GROUP_CHECK=NONE
GSHADOW_CHECK=NONE

if [ "$REP" = "APT" ];then
	if [ $PASSWDFILEPERMS = "-rw-r--r--" ] && [ $PASSWDFILEOWNER = "root" ] && [ $PASSWDFILEGRP = "root" ]; then
		PASSWD_CHECK=PASS
	else
		PASSWD_CHECK=FAIL
	fi

	if [ $SHADOWFILEPERMS = "-rw-r-----" ] && [ $SHADOWFILEOWNER = "root" ] && [ $SHADOWFILEGRP = "shadow" ]; then
		SHADOW_CHECK=PASS
	else
		SHADOW_CHECK=FAIL
	fi

	if [ $GROUPFILEPERMS = "-rw-r--r--" ] && [ $GROUPFILEOWNER = "root" ] && [ $GROUPFILEGRP = "root" ]; then
		GROUP_CHECK=PASS
	else
		GROUP_CHECK=FAIL
	fi
	
	if [ $GSHADOWFILEPERMS = "-rw-r-----" ] && [ $GSHADOWFILEOWNER = "root" ] && [ $GSHADOWFILEGRP = "shadow" ]; then
		GSHADOW_CHECK=PASS
	else
		GSHADOW_CHECK=FAIL
	fi
fi

if [ "$REP" = "YUM" ];then
	if [ $PASSWDFILEPERMS = "-rw-r--r--." ] && [ $PASSWDFILEOWNER = "root" ] && [ $PASSWDFILEGRP = "root" ]; then
		PASSWD_CHECK=PASS
	else
		PASSWD_CHECK=FAIL
	fi

	if [ $SHADOWFILEPERMS = "----------." ] && [ $SHADOWFILEOWNER = "root" ] && [ $SHADOWFILEGRP = "root" ]; then
		SHADOW_CHECK=PASS
	else
		SHADOW_CHECK=FAIL
	fi

	if [ $GROUPFILEPERMS = "-rw-r--r--." ] && [ $GROUPFILEOWNER = "root" ] && [ $GROUPFILEGRP = "root" ]; then
		GROUP_CHECK=PASS
	else
		GROUP_CHECK=FAIL
	fi

	if [ $GSHADOWFILEPERMS = "----------." ] && [ $GSHADOWFILEOWNER = "root" ] && [ $GSHADOWFILEGRP = "root" ]; then
		GSHADOW_CHECK=PASS
	else
		GSHADOW_CHECK=FAIL
	fi
fi

if [ $PASSWD_CHECK = "FAIL" ] && [ $SHADOW_CHECK = "FAIL" ] && [ $GROUP_CHECK = "FAIL" ] && [ $GSHADOW_CHECK = "FAIL" ]; then
	echo "<a href='$HANDBOOK'>WARN: passwd,shadow,group files: \
		/etc/passwd access:$PASSWD_CHECK | /etc/shadow access:$SHADOW_CHECK | /etc/group access:$GROUP_CHECK | /etc/gshadow access:$GSHADOW_CHECK</a>" \
		>> /tmp/$HOST_NAME.hardening
fi

#--------------------------
# FS Conf. check
#--------------------------
part_check () {
if [ "$#" != "1" ]; then
		options="$(echo $@ | awk 'BEGIN{FS="[()]"}{print $2}')"
	echo "[+]$@"
else
	echo "[-]\"$1\" not in separated partition."
fi
}
parts=(/tmp /var /var/tmp /var/log /var/log/audit /home /dev/shm)
for part in ${parts[*]}; do
	out="$(mount | grep $part)"
	part_check $part $out >> /tmp/fs_conf.txt
done
PART_CHECK=$(cat /tmp/fs_conf.txt |grep "not in separated partition." |wc -l) && rm /tmp/fs_conf.txt
if [ $PART_CHECK -gt "0" ]; then
	echo "<a href='$HANDBOOK'>INFO: $PART_CHECK not in separated partition.</a>" >> /tmp/$HOST_NAME.hardening
fi

#---------------------------
# Network conf. check
#---------------------------
NWCONF1=$(sysctl net.ipv4.ip_forward |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF1 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 IP Forward Check: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF2=$(sysctl net.ipv4.conf.all.send_redirects |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF2 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 Send Redirects: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF3=$(sysctl net.ipv4.conf.all.accept_source_route |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF3 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 All Accept Source Route: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF4=$(sysctl net.ipv4.conf.default.accept_source_route |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF4 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 Default Accept Source Route: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF5=$(sysctl net.ipv4.conf.all.accept_redirects |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF5 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 All Accept Redirects: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF6=$(sysctl net.ipv4.conf.default.accept_redirects |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF6 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 Default Accept Redirects: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF7=$(sysctl net.ipv4.conf.all.secure_redirects |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF7 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 All Secure Redirects: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF8=$(sysctl net.ipv4.conf.default.secure_redirects |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF8 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 Default Secure Redirects: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF9=$(sysctl net.ipv4.icmp_echo_ignore_broadcasts |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF9 = "1" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 Ignore Broadcast: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF10=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF10 = "1" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 Ignore Bogus Error Resp.: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF11=$(sysctl net.ipv4.conf.all.rp_filter |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF11 = "1" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 All rp Filter: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF12=$(sysctl net.ipv4.tcp_syncookies |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF12 = "1" ]; then echo "<p1 style='background-color:#CD853F;'>ipv4 TCP Syncookies: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
# ipv6 controls
NWCONF13=$(sysctl net.ipv6.conf.all.disable_ipv6 |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF13 = "1" ]; then echo "<p1 style='background-color:#CD853F;'>ipv6 Disable IPv6: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi
NWCONF14=$(sysctl net.ipv6.conf.all.accept_ra |cut -d "=" -f2 |cut -d " " -f2) && if [ ! $NWCONF14 = "0" ]; then echo "<p1 style='background-color:#CD853F;'>ipv6 All Accept ra: Not Passed</p1>" >> /tmp/$HOST_NAME.nwout; fi

#---------------------------
# SSH conf. check
#---------------------------
# PRIVATE HOST KEY
SSHCONF1=$(stat /etc/ssh/sshd_config |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ ! $SSHCONF1 = "0600" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config uid: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF2=$(stat /etc/ssh/ssh_host_rsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ ! $SSHCONF2 = "0600" ]; then echo "<p1 style='background-color:#D2691E;'>ssh_host_rsa_key uid: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF3=$(stat /etc/ssh/ssh_host_ecdsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ ! $SSHCONF3 = "0600" ]; then echo "<p1 style='background-color:#D2691E;'>ssh_host_ecdsa_key uid: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF4=$(stat /etc/ssh/ssh_host_ed25519_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ ! $SSHCONF4 = "0600" ]; then echo "<p1 style='background-color:#D2691E;'>ssh_host_ed25519_key uid: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
# PUBLIC HOST KEY
SSHCONF5=$(stat /etc/ssh/ssh_host_rsa_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ ! $SSHCONF5 = "0644" ]; then echo "<p1 style='background-color:#D2691E;'>ssh_host_rsa_key.pub uid: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF6=$(stat /etc/ssh/ssh_host_ed25519_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1) && if [ ! $SSHCONF6 = "0644" ]; then echo "<p1 style='background-color:#D2691E;'>ssh_host_ed25519_key.pub uid: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
grep ^Protocol /etc/ssh/sshd_config > /dev/null && if [ ! $? = "0" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config Protocol2 setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF8=$(sshd -T | grep loglevel |cut -d " " -f2) && if [ ! $SSHCONF8 = "INFO" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config LogLevel setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF9=$(sshd -T | grep x11forwarding |cut -d " " -f2) && if [ ! $SSHCONF9 = "no" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config x11Forwarding setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF10=$(sshd -T | grep maxauthtries |cut -d " " -f2) && if [ ! $SSHCONF10 -lt "4" ]; then echo "<p1 style='background-color:#D2691E;'>- sshd_config MaxAuthtries setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF11=$(sshd -T | grep ignorerhosts |cut -d " " -f2) && if [ ! $SSHCONF11 = "yes" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config IgnorerHosts setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF12=$(sshd -T | grep hostbasedauthentication |cut -d " " -f2) && if [ ! $SSHCONF12 = "no" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config HostBasedAuth. setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF13=$(sshd -T | grep permitrootlogin |cut -d " " -f2) && if [ ! $SSHCONF13 = "no" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config PermitRootLogin setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF14=$(sshd -T | grep permitemptypasswords |cut -d " " -f2) && if [ ! $SSHCONF14 = "no" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config PermitEmptyPass setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi
SSHCONF15=$(sshd -T | grep permituserenvironment |cut -d " " -f2) && if [ ! $SSHCONF15 = "no" ]; then echo "<p1 style='background-color:#D2691E;'>sshd_config PermitUserEnv. setting: Not Passed</p1>" >> /tmp/$HOST_NAME.sshout; fi

#--------------------------
# VULNEREBILITY CHECK
#--------------------------
rm /tmp/$HOST_NAME.cve

# kernel based cve check
KERNELVER=$(uname -a |cut -d " " -f3 |cut -d "-" -f1)
perl /tmp/cve_check -k $KERNELVER > /tmp/cve_list
CVELIST=$(cat /tmp/cve_list |grep CVE) && echo $CVELIST > /tmp/cve_list && CVELIST=$(cat /tmp/cve_list) && rm /tmp/cve_list && rm /tmp/cve_check

# jog4j check
find / -iname "log4j*" > /tmp/log4j_exist.txt && sed -i '/log4j_exist.txt/d' /tmp/log4j_exist.txt
if [ -s "/tmp/log4j_exist.txt" ]; then
	LOG4J_EXIST="USE"
        echo "<a href='$HANDBOOK#-log4j_usage_is_reported'>LOG4J/LOG4SHELL is use.</a>" >> /tmp/$HOST_NAME.cve
        cat /tmp/log4j_exist.txt >> /tmp/$HOST_NAME.log
	find /var/log/ -name '*.gz' -type f -exec sh -c "zcat {} | sed -e 's/\${lower://'g | tr -d '}' | egrep -i 'jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):'" \; \
		>> /tmp/$HOST_NAME.log
else
	LOG4J_EXIST=NOT_USE
fi

#--------------------------
# for notification
#--------------------------
#--------------------------
# repo list
#--------------------------
if [ "$REP" = "APT" ]; then
	cat /etc/apt/sources.list > /tmp/repo_list.txt
	shopt -s nullglob dotglob
	files=(/etc/apt/sources.list.d/*)
	DIRC=EMPTY
	if [ ${#files[@]} -gt 0 ]; then DIRC=FULL; fi
	if [ $DIRC = "FULL" ]; then
	echo "----------------------------------------------" >> /tmp/repo_list.txt
	cat /etc/apt/sources.list.d/* >> /tmp/repo_list.txt
	fi
elif [ "$REP" = "YUM" ]; then
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
# integrity check
#--------------------------
LOCALDIR="/usr/local/lastcontrol/data/etc"
if [ ! -d "$LOCALDIR" ]; then
mkdir -p $LOCALDIR
rsync -a /etc/ $LOCALDIR && INT_CHECK=INITIAL
else
	rsync -av /etc/ $LOCALDIR > /tmp/integritycheck.txt
	sed -i -e :a -e '$d;N;2,2ba' -e 'P;D' /tmp/integritycheck.txt && sed -i '/^$/d' /tmp/integritycheck.txt && sed -i '1d' /tmp/integritycheck.txt
	if [ -s "/tmp/integritycheck.txt" ]; then INT_CHECK=DETECTED; else INT_CHECK=NOTDETECTED; fi
	#sed -i -e :a -e '$d;N;2,2ba' -e 'P;D' /tmp/integritycheck.txt
	#sed -i '1d' /tmp/integritycheck.txt
fi

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
cat /tmp/hddlist.txt >> /tmp/inventory.txt && rm -f /tmp/hddlist.txt

if [ ! -f "$LOCALFILE" ]; then
cp /tmp/inventory.txt $LOCALFILE
INV_CHECK="CREATED"
else
INV_CHECK="DETECTED"
diff $LOCALFILE /tmp/inventory.txt >> /dev/null && INV_CHECK="NOTDETECTED"
fi

#--------------------------
# report file
#--------------------------
rm /tmp/$HOST_NAME.txt
cat > /tmp/$HOST_NAME.txt << EOF
$HOST_NAME LastControl Report $DATE
=======================================================================================================================================================================
--------------------------------------------------------------------------------------------------------------------------
				:::... MACHINE INVENTORY ...:::
--------------------------------------------------------------------------------------------------------------------------
|Hostname:          |$HOST_NAME
|IP Address:        |$IPADDRESS
--------------------------------------------------------------------------------------------------------------------------
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
--------------------------------------------------------------------------------------------------------------------------
|Running Process:   |$NUMPROCESS
|Uses the Most Load |Process: $MOSTPROCESS | Cpu: $MOSTCPU | Ram: $MOSTRAM
--------------------------------------------------------------------------------------------------------------------------
|Listening Conn.:   |$LISTENINGCONN
|Established Conn.: |$ESTABLISHEDCONN
--------------------------------------------------------------------------------------------------------------------------
|Ram Use:           |$RAM_USE_PERCENTAGE%
|Swap Use:          |$SWAP_USE_PERCENTAGE%
|Disk Use:          |$DISK_USAGE%
--------------------------------------------------------------------------------------------------------------------------
|SUDO Member Count: |$SUDOMEMBERCOUNT
|Local User Count:  |$LOCALUSER_COUNT
--------------------------------------------------------------------------------------------------------------------------
|System Score:      |$SYS_SCORE
|Network Score:     |$NW_SCORE
|SSH Score:         |$SSH_SCORE
--------------------------------------------------------------------------------------------------------------------------
|Inventory Check:   |$INV_CHECK
|Integrity Check:   |$INT_CHECK
--------------------------------------------------------------------------------------------------------------------------
|Kernel Version:    |$KERNELVER
--------------------------------------------------------------------------------------------------------------------------
|Vulnerability Check
--------------------------------------------------------------------------------------------------------------------------
|CVE List:          |$CVELIST
|LOG4J/LOG4SHELL    |$LOG4J_EXIST
--------------------------------------------------------------------------------------------------------------------------
|S.M.A.R.T          |
--------------------------------------------------------------------------------------------------------------------------
$SMART
--------------------------------------------------------------------------------------------------------------------------
EOF

echo >> /tmp/$HOST_NAME.txt

if [ "$INV_CHECK" = "DETECTED" ]; then
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "                          :::... CHANGE HARDWARE NOTIFICATION !!! ....:::" >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	diff $LOCALFILE /tmp/inventory.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/inventory.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "" >> /tmp/$HOST_NAME.txt
else
	rm -f /tmp/inventory.txt
fi

###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "				:::... SYSTEM LOAD ....:::" >> /tmp/$HOST_NAME.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "" >> /tmp/$HOST_NAME.txt
###
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "Running Process/Apps." >> /tmp/$HOST_NAME.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###cat /tmp/runningservices.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/runningservices.txt
###echo "" >> /tmp/$HOST_NAME.txt
###
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "			:::... LISTENING PORTS & ESTABLISHED CONN. ...:::" >> /tmp/$HOST_NAME.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "" >> /tmp/$HOST_NAME.txt
###
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "Listening Ports" >> /tmp/$HOST_NAME.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###cat /tmp/listeningconn.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/listeningconn.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "" >> /tmp/$HOST_NAME.txt
###
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "Established Connections" >> /tmp/$HOST_NAME.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###cat /tmp/establishedconn.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/establishedconn.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "" >> /tmp/$HOST_NAME.txt
###
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "Connected Users" >> /tmp/$HOST_NAME.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###cat /tmp/connectedusers.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/connectedusers.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "" >> /tmp/$HOST_NAME.txt
###
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "Login Information for all Users" >> /tmp/$HOST_NAME.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###lslogins -u >> /tmp/$HOST_NAME.txt
###echo "" >> /tmp/$HOST_NAME.txt
###
###if [ ! "$LOCALUSER_COUNT" = "0" ]; then
###        echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###        echo "Local User List" >> /tmp/$HOST_NAME.txt
###        echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###	cat /tmp/$HOST_NAME.localusers >> /tmp/$HOST_NAME.txt #&& rm -f /tmp/$HOST_NAME.localusers
###        echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###	echo "sudo members" >> /tmp/$HOST_NAME.txt
###	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###	cat /tmp/$HOST_NAME.sudomembers >> /tmp/$HOST_NAME.txt #&& rm -f /tmp/$HOST_NAME.sudomembers
###	echo "" >> /tmp/$HOST_NAME.txt
###fi
###
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###echo "                  :::... REPOs LIST ...:::" >> /tmp/$HOST_NAME.txt
###echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###cat /tmp/repo_list.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/repo_list.txt
###echo "" >> /tmp/$HOST_NAME.txt
###
###if [ ! "$BROKEN_COUNT" = "0" ]; then
###	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###	echo "			:::... BROKEN PACKAGE LIST ...:::" >> /tmp/$HOST_NAME.txt
###	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###	echo "" >> /tmp/$HOST_NAME.txt
###	cat /tmp/broken_pack_list.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/broken_pack_list.txt
###	echo "" >> /tmp/$HOST_NAME.txt
###else
###	rm -f /tmp/broken_pack_list.txt
###fi
###
###if [ ! "$PART_CHECK" = "0" ]; then
###	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###	echo "                  :::... SYSTEM PARTITION Conf. CHECK...:::" >> /tmp/$HOST_NAME.txt
###	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
###	cat /tmp/fs_conf.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/fs_conf.txt
###	echo "" >> /tmp/$HOST_NAME.txt
###fi

if [ $INT_CHECK = "DETECTED" ]; then
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "			:::... INTEGRITY CHECK ...:::" >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	echo "Warnings" >> /tmp/$HOST_NAME.txt
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.txt
	cat /tmp/integritycheck.txt >> /tmp/$HOST_NAME.txt && rm -f /tmp/integritycheck.txt
	echo "" >> /tmp/$HOST_NAME.txt
	rm -f /tmp/integritycheck.txt
	echo "=======================================================================================================================================================================" >> /tmp/$HOST_NAME.txt
fi
