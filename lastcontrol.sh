#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

############################
# determine distro
############################
cat /etc/redhat-release > /tmp/distrocheck 2>/dev/null || cat /etc/*-release > /tmp/distrocheck 2>/dev/null || cat /etc/issue > /tmp/distrocheck 2>/dev/null
grep -i "debian" /tmp/distrocheck &>/dev/null && REP=APT
grep -i "ubuntu" /tmp/distrocheck &>/dev/null && REP=APT
grep -i "centos" /tmp/distrocheck &>/dev/null && REP=YUM
grep -i "red hat" /tmp/distrocheck &>/dev/null && REP=YUM
grep -i "rocky" /tmp/distrocheck &>/dev/null && REP=YUM

rm /tmp/distrocheck

############################
# install packages
############################
if [ "$REP" = "APT" ]; then
        apt-get -y install net-tools rsync smartmontools curl
fi
if [ "$REP" = "YUM" ]; then
        yum -y install net-tools rsync perl smartmontools curl pciutils
fi

DATE=$(date)
HOST_NAME=$(hostnamectl --static)
HANDBOOK=https://github.com/eesmer/LastControl/blob/main/LastControl-HandBook.md

############################
# INVENTORY
############################
INT_IPADDR=$(hostname -I)
EXT_IPADDR=$(curl -4 icanhazip.com)
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
ping -c 1 google.com &> /dev/null && INTERNET="CONNECTED" || INTERNET="DISCONNECTED"

# Control of if Centos repo is available
if [ "$INTERNET" = CONNECTED ]; then
	INSTALL_CHECK=FAIL
	if [ "$REP" = APT ]; then apt-get install -s zathura && INSTALL_CHECK=PASS; fi #zathura: a minimalist choice, not stupid (:
	if [ "$REP" = YUM ]; then yum update && INSTALL_CHECK=PASS; fi #Unable to use after Centos8
fi

############################
# HEALTHCHECK
############################
rm /tmp/$HOST_NAME.healthcheck

#----------------------
# check ram usage
#----------------------
RAM_FREE=$( expr $RAM_TOTAL - $RAM_USAGE)
RAM_FREE_PERCENTAGE=$((100 * $RAM_FREE/$RAM_TOTAL))
RAM_USE_PERCENTAGE=$(expr 100 - $RAM_FREE_PERCENTAGE)
        if [ $RAM_USE_PERCENTAGE -gt "50" ]; then
                echo "<a href='$HANDBOOK#-ram_usage_is_reported'>Ram %$RAM_USE_PERCENTAGE usage</a>" >> /tmp/$HOST_NAME.healthcheck
                OOM=0
                grep -i -r 'out of memory' /var/log/ > /dev/null && OOM=1
                if [ $OOM = "1" ]; then echo "<a href='$HANDBOOK#-ram_usage_is_reported'>out of memory message log found</a>" >> /tmp/$HOST_NAME.healthcheck; fi
        fi
#----------------------
# check swap usage
#----------------------
SWAP_VALUE=$(free -m |grep Swap: |cut -d ":" -f2)
SWAP_TOTAL=$(echo $SWAP_VALUE |cut -d " " -f1)
SWAP_USE=$(echo $SWAP_VALUE |cut -d " " -f2)
SWAP_USE_PERCENTAGE=$((100 * $SWAP_USE/$SWAP_TOTAL))
        if [ $SWAP_USE_PERCENTAGE -gt "0" ]; then
                echo "<a href='$HANDBOOK#-swap_usage_is_reported'>Swap %$SWAP_USE_PERCENTAGE usage</a>" >> /tmp/$HOST_NAME.healthcheck
        fi

#----------------------
# check disk usage
#----------------------
DISK_USAGE=$(df -H | grep -vE 'Filesystem|tmpfs|cdrom|udev' | awk '{ print $5" "$1"("$2"  "$3")" " --- "}' | sed -e :a -e N -e 's/\n/ /' -e ta |cut -d "%" -f1)
        if [ $DISK_USAGE -gt "50" ]; then
                echo "<a href='$HANDBOOK#-disk_usage_is_reported'>Disk %$DISK_USAGE usage.</a>" >> /tmp/$HOST_NAME.healthcheck
        fi

#----------------------
# check system load
#----------------------
NOC=$(nproc --all)
LAST01=$(top -n 1 -b | grep "load average:" |awk '{print $10}')
LAST05=$(top -n 1 -b | grep "load average:" |awk '{print $11}')
LAST15=$(top -n 1 -b | grep "load average:" |awk '{print $12}')
LOAD_AVG=$(echo Last 1 Min: $LAST01 && echo "-" && echo Last 5 Min: $LAST05 && echo "-" && echo Last 15 Min: $LAST15) && LOAD_AVG=$(echo $LOAD_AVG)

#----------------------
# overload check
#----------------------
LAST01=$(echo $LAST01 |cut -d "." -f1)
LAST05=$(echo $LAST05 |cut -d "." -f1)
LAST15=$(echo $LAST15 |cut -d "." -f1)

if [ $LAST01 -gt "$NOC" ] || [ $LAST05 -gt "$NOC" ] || [ $LAST15 -gt "$NOC" ]; then
	echo "<a href='$HANDBOOK'>Overload %$LOAD_AVG</a>" >> /tmp/$HOST_NAME.healthcheck
fi

top -b -n1 | head -17 | tail -11 > /tmp/systemload.txt
sed -i '1d' /tmp/systemload.txt
MOST_PROCESS=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f3)
MOST_RAM=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f2)
MOST_CPU=$(cat /tmp/systemload.txt |awk '{print $9, $10, $12}' |head -1 |cut -d " " -f1)
echo "<a href='$HANDBOOK#-using_the_most_resource'>Using the most Resource: $MOST_PROCESS</a>" >> /tmp/$HOST_NAME.healthcheck
echo "<a href='$HANDBOOK#-using_the_most_ram'>Using the most Ram: $MOST_RAM</a>" >> /tmp/$HOST_NAME.healthcheck
echo "<a href='$HANDBOOK#-using_the_most_cpu'>Using the most Cpu: $MOST_CPU</a>" >> /tmp/$HOST_NAME.healthcheck
rm -f /tmp/systemload.txt

#----------------------
# check zombie,stopped process
#----------------------
TO_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $2}')
RU_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $4}')
SL_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $6}')
ST_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $8}')
ZO_PROCESS=$(top -n 1 -b |grep "Tasks:" |awk '{print $10}')
if [ $ZO_PROCESS -gt "0" ] || [ $ST_PROCESS -gt "0" ]; then
     echo "<a href='$HANDBOOK'>Process - Zombie:$ZO_PROCESS | Stopped:$ST_PROCESS</a>" >> /tmp/$HOST_NAME.healthcheck
fi

#----------------------
# S.M.A.R.T check
#----------------------
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
        echo "<a href='$HANDBOOK'>S.M.A.R.T Failed or not tested.</a>" >> /tmp/$HOST_NAME.healthcheck
fi

#----------------------
# Check Update
#----------------------
if [ "$REP" = "APT" ]; then
        CHECK_UPDATE=NONE
        UPDATE_COUNT=0
        echo "n" |apt-get upgrade > /tmp/update_list.txt
        cat /tmp/update_list.txt |grep "The following packages will be upgraded:" >> /dev/null && CHECK_UPDATE=EXIST \
                && UPDATE_COUNT=$(cat /tmp/update_list.txt |grep "upgraded," |cut -d " " -f1)
        if [  $CHECK_UPDATE = "EXIST" ]; then
                echo "<a href='$HANDBOOK#-update_check_is_reported'>Update $CHECK_UPDATE | Count: $UPDATE_COUNT</a>" >> /tmp/$HOST_NAME.healthcheck
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
                echo "<a href='$HANDBOOK#-update_check_is_reported'>Update $CHECK_UPDATE | Count: $UPDATE_COUNT</a>" >> /tmp/$HOST_NAME.healthcheck
        else
                CHECK_UPDATE=NONE
        fi
rm -f /tmp/update_list.txt
fi

#--------------------------
# broken package list
#--------------------------
if [ $REP = "APT" ];then
        dpkg -l | grep -v "^ii" >> /dev/null > /tmp/broken_pack_list.txt
        sed -i -e '1d;2d;3d;4d;5d' /tmp/broken_pack_list.txt
        BROKEN_COUNT=$(wc -l /tmp/broken_pack_list.txt |cut -d " " -f1)
        if [ $BROKEN_COUNT -gt "0" ]; then
                echo "<a href='$HANDBOOK'>$BROKEN_COUNT package(s) is a broken</a>" >> /tmp/$HOST_NAME.healthcheck
        fi

        ### ALLOWUNAUTH=$(grep -v "^#" /etc/apt/ -r | grep -c "AllowUnauthenticated")
        ### if [ $ALLOWUNAUTH = 0 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
        ### DEBSIG=$(grep -v "^#" /etc/dpkg/dpkg.cfg |grep -c no-debsig)
        ### if [ $DEBSIG = 1 ]; then SYS_SCORE=$(($SYS_SCORE + 10)); fi
fi

if [ $REP = "YUM" ];then
        rpm -Va >> /dev/null > /tmp/broken_pack_list.txt
        BROKEN_COUNT=$(wc -l /tmp/broken_pack_list.txt |cut -d " " -f1)
        if [ $BROKEN_COUNT -gt "0" ]; then
                echo "<a href='$HANDBOOK'>$BROKEN_COUNT package(s) is a broken</a>" >> /tmp/$HOST_NAME.healthcheck
        fi
fi

############################
# HARDENING CHECK
############################
rm /tmp/$HOST_NAME.hardeningsys
rm /tmp/$HOST_NAME.hardeningnw
rm /tmp/$HOST_NAME.hardeningssh

#---------------------------
# Find wifi or wireless adapter
#---------------------------
update-pciids
lspci | egrep -i 'wifi|wireless' > /tmp/$HOST_NAME.wifi
if [ -s "/tmp/$HOST_NAME.wifi" ];then
     echo "<a href='$HOST_NAME.wifi'>Wireless adaptor found</a>" >> /tmp/$HOST_NAME.hardeningsys
else
     rm /tmp/$HOST_NAME.wifi
fi

#---------------------------
# Check Time Sync
#---------------------------
TIME_SYNC=$(timedatectl |grep "synchronized:" |cut -d ":" -f2 |cut -d " " -f2)
if [ ! $TIME_SYNC = "yes" ]; then echo "<a href='$HANDBOOK#-time_date_synchronization'>System clock is not synchronized</a>" >> /tmp/$HOST_NAME.hardeningsys; fi

#---------------------------
# Check syslog
#---------------------------
SYSLOGINSTALL=NOTINSTALLED
if [ $REP = "APT" ]; then
     dpkg -l |grep rsyslog >> /dev/null && SYSLOGINSTALL=INSTALLED
fi
if [ $REP = "YUM" ]; then
     rpm -qa rsyslog >> /dev/null && SYSLOGINSTALL=INSTALLED

fi

if [ $SYSLOGINSTALL = "INSTALLED" ]; then
     SYSLOGSERVICE=INACTIVE
     systemctl status rsyslog.service |grep "active (running)" >> /dev/null && SYSLOGSERVICE=ACTIVE
     SYSLOGSOCKET=INACTIVE
     systemctl status syslog.socket |grep "active (running)" >> /dev/null && SYSLOGSOCKET=ACTIVE
     SYSLOGSEND=NO
     cat /etc/rsyslog.conf |grep "@" |grep -v "#" >> /dev/null && SYSLOGSEND=YES	#??? i will check it
fi

if [ $SYSLOGSERVICE = "INACTIVE" ] || [ $SYSLOGSOCKET = "INACTIVE" ] || [ $SYSLOGSEND = "NO" ]; then
     echo "<a href='$HANDBOOK#-forward_logs_to_remote_server'>SYSLOG: $SYSLOGINSTALL | $SYSLOGSERVICE | Socket:$SYSLOGSOCKET | Send:$SYSLOGSEND</a>" >> /tmp/$HOST_NAME.hardeningsys
fi

#---------------------------
# check HTTP proxy server use
#---------------------------
# http, https, ftp, no_proxy -> examples for definitions
#---
# export http_proxy=""http://10.10.1.20:8080/
# export https_proxy="http://10.10.1.20:8080/"
# export ftp_proxy="http://10.10.1.20:8080/"
# export no_proxy="127.0.0.1,localhost"
# Acquire::http::proxy "http://192.168.1.1:8080/";
# Acquire::https::proxy "https://192.168.1.1:8080/";
# Acquire::ftp::proxy "ftp://192.168.1.1:8080/";
#---

HTTPPROXY_USE=FALSE
env |grep "http_proxy" >> /dev/null && HTTPPROXY_USE=TRUE
grep -e "export http" /etc/profile |grep -v "#" >> /dev/null && HTTPPROXY_USE=TRUE
grep -e "export http" /etc/profile.d/* |grep -v "#" >> /dev/null && HTTPPROXY_USE=TRUE

if [ $REP = "APT" ]; then
     grep -e "Acquire::http" /etc/apt/apt.conf.d/* |grep -v "#" >> /dev/null && HTTPPROXY_USE=TRUE
elif [ $REP = "YUM" ]; then
     grep -e "proxy=" /etc/yum.conf |grep -v "#" >> /dev/null && HTTPPROXY_USE=TRUE
fi

if [ $HTTPPROXY_USE = "TRUE" ]; then
     echo "<a href='$HANDBOOK'>HTTP Proxy is use</a>" >> /tmp/$HOST_NAME.hardeningsys
else
     echo "<a href='$HANDBOOK'>HTTP Proxy usage is not set</a>" >> /tmp/$HOST_NAME.hardeningsys
fi

#---------------------------
# Check usage Disk quota
#---------------------------
QUOTA_INSTALL=Installed
if ! [ "$(command -v quotacheck)" ]; then
     QUOTA_INSTALL=Not_Installed
fi
USR_QUOTA=Fail
grep -i "usrquota" /etc/fstab >> /dev/null && USR_QUOTA=Active
GRP_QUOTA=Fail
grep -i "grpquota" /etc/fstab >> /dev/null && GRP_QUOTA=Active
MNT_QUOTA=Not_Found
mount |grep "quota" >> /dev/null && MNT_QUOTA=Found

if [ $USR_QUOTA = "Active" ] || [ $GRP_QUOTA = "Active" ] || [ $MNT_QUOTA = "Found" ]; then
     cat /etc/fstab |grep "quota" > /tmp/$HOST_NAME.quotamount
     mount |grep "quota" >> /tmp/$HOST_NAME.quotamount
     echo "<a href='$HANDBOOK'>Quota Usage:$QUOTA_INSTALL | Usr_Quota:$USR_QUOTA | Grp_Quota:$GRP_QUOTA</a>" >> /tmp/$HOST_NAME.hardeningsys
     echo "<a href='$HANDBOOK'>Quota Mount:$MNT_QUOTA</a>" >> /tmp/$HOST_NAME.hardeningsys
else
     echo "<a href='$HANDBOOK'>Quota Usage:$QUOTA_INSTALL | Usr_Quota:$USR_QUOTA | Grp_Quota:$GRP_QUOTA</a>" >> /tmp/$HOST_NAME.hardeningsys
     echo "<a href='$HANDBOOK'>Quota Mount:$MNT_QUOTA</a>" >> /tmp/$HOST_NAME.hardeningsys
fi

#---------------------------
# check domain join
#---------------------------
#systemctl list-units --full -all | grep -Fq "sssd.service"
#systemctl list-units --full -all | grep -Fq "winbind.service"

#---------------------------
# check loaded kernel modules (filesystems)
#---------------------------
lsmod |grep cramfs > /tmp/kernel_modules.txt && CRAMFS=LOADED
if [ "$CRAMFS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>CRAMFS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
lsmod |grep freevxfs > /tmp/kernel_modules.txt && FREEVXFS=LOADED
if [ "$FREEVXFS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>FREEVXFS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
lsmod |grep jffs2 > /tmp/kernel_modules.txt && JFFS2=LOADED
if [ "$JFFS2" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>JFFS2 Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
lsmod |grep hfs > /tmp/kernel_modules.txt && HFS=LOADED
if [ "$HFS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>HFS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
lsmod |grep hfsplus > /tmp/kernel_modules.txt && HFSPLUS=LOADED
if [ "$HFSPLUS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>HFSPLUS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
lsmod |grep squashfs > /tmp/kernel_modules.txt && SQUASHFS=LOADED
if [ "$SQUASHFS" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>HFSPLUS Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
lsmod |grep udf > /tmp/kernel_modules.txt && UDF=LOADED
if [ "$UDF" = LOADED ]; then echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>UDF Filesystem loaded</a>" >> /tmp/$HOST_NAME.hardeningsys; fi

# /tmp directory
if [ "$REP" = APT ]; then TMPMNTPATH="/usr/share/systemd/tmp.mount"; fi
if [ "$REP" = YUM ]; then TMPMNTPATH="/usr/lib/systemd/system/tmp.mount"; fi

mount | grep -E '\s/tmp\s' >> /dev/null
if [ "$?" = 1 ]; then
     echo "<a href='$HANDBOOK#-directory_conf_hardening'>/tmp directory is not mounted and configured</a>" >> /tmp/$HOST_NAME.hardeningsys
else
     #FSTABFILE=NONE
     #egrep "/tmp" /etc/fstab >> /dev/null && FSTABFILE=EXIST
     TMPSIZE=NONE
     egrep "size=" $TMPMNTPATH >> /dev/null && TMPMNT=EXIST
     TMPEXEC=NONE
     egrep "noexec" $TMPMNTPATH >> /dev/null && TMPMNT=EXIST
fi

if [ "$TMPEXEC" = NONE ] || [ "$TMPSIZE" = NONE ]; then
     echo "<a href='$HANDBOOK#-directory_conf_hardening'>/tmp directory is not configured</a>" >> /tmp/$HOST_NAME.hardeningsys
fi

# /var directory
mount | grep -E '\s/var\s' >> /dev/null
if [ "$?" = 1 ]; then echo "<a href='$HANDBOOK#-directory_conf_hardening'>/var directory is not configured</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
mount | grep -E '\s/var/tmp\s' >> /dev/null
if [ "$?" = 1 ]; then echo "<a href='$HANDBOOK#-directory_conf_hardening'>/var/tmp directory is not configured</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
mount | grep -E '\s\/var\/log\s' >> /dev/null
if [ "$?" = 1 ]; then echo "<a href='$HANDBOOK#-directory_conf_hardening'>/var/log directory is not configured</a>" >> /tmp/$HOST_NAME.hardeningsys; fi

# sticky bit for writable directories
df --local -P | awk '{if (NR!=1) print $6}' | xargs -I '{}' find '{}' -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null
if [ "$?" = 1 ]; then echo "<a href='$HANDBOOK#-directory_conf_hardening'>Sticky bit is not configured for writable directory</a>" >> /tmp/$HOST_NAME.hardeningsys; fi

#--------------------------
# check automount
#--------------------------
if [ "$REP" = APT ]; then
     dpkg -l |grep autofs >> /dev/null
     if [ "$?" = 0 ]; then AUTOFSSTAT=$(systemctl status autofs.service  |grep Active: |cut -d ":" -f2 |cut -d " " -f2); fi
elif [ "$REP" = YUM ]; then
     yum list installed |grep autofs >> /dev/null
     if [ "$?" = 0 ]; then AUTOFSSTAT=$(systemctl status autofs.service  |grep Active: |cut -d ":" -f2 |cut -d " " -f2); fi
fi
if [ "$AUTOFSSTAT" = active ]; then echo "<a href='$HANDBOOK#-directory_conf_hardening'>Autofs is active</a>" >> /tmp/$HOST_NAME.hardeningsys; fi

#--------------------------
# check local users,limits and sudo
#--------------------------
getent passwd {1000..60000} |cut -d ":" -f1 > /tmp/userlist
LOCALUSER_COUNT=$(wc -l /tmp/userlist |cut -d " " -f1)
if [ $LOCALUSER_COUNT = "0" ]; then
        rm /tmp/userlist
else
        echo "<a href='$HOST_NAME.localusers'>$LOCALUSER_COUNT local user(s) exist</a>" >> /tmp/$HOST_NAME.hardeningsys
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
                echo "<a href='$HANDBOOK'>User Limit not used</a>" >> /tmp/$HOST_NAME.hardeningsys
        fi

	# /etc/login.defs
        PASS_MAX=$(cat /etc/login.defs |grep PASS_MAX_DAYS |grep -v "Maximum number of days") && PASS_MAX=$(echo $PASS_MAX |cut -d " " -f2)
        PASS_MIN=$(cat /etc/login.defs |grep PASS_MIN_DAYS |grep -v "Minimum number of days") && PASS_MIN=$(echo $PASS_MIN |cut -d " " -f2)
        PASS_LEN=$(cat /etc/login.defs |grep PASS_MIN_LEN |grep -v "Minimum acceptable password") && PASS_LEN=$(echo $PASS_LEN |cut -d " " -f2)

        if [ "$PASS_MAX" -eq "$PASS_MAX" ] 2> /dev/null;
	then
		if [ ! "$PASS_MAX" -lt 99999 ]; then echo "<a href='$HANDBOOK>Local user password policy not configured</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
	else
		echo "<a href='$HANDBOOK>Local user password policy definition not found</a>" >> /tmp/$HOST_NAME.hardeningsys
	fi
	
	if [ "$PASS_MIN" -eq "$PASS_MIN" ] 2> /dev/null;
	then
		if [ ! "$PASS_MIN" -gt 0 ]; then echo "<a href='$HANDBOOK>Local user password change interval not configured</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
	else
		echo "<a href='$HANDBOOK>Local user password change interval definition not found</a>" >> /tmp/$HOST_NAME.hardeningsys
	fi
        
	if [ "$PASS_LEN" -eq "$PASS_LEN" ] 2> /dev/null;
	then
		if [ ! "$PASS_LEN" -gt 5 ]; then echo "<a href='$HANDBOOK>Local user password length is not configured (according CIS) (<=5)</a>" >> /tmp/$HOST_NAME.hardeningsys; fi
	else
		echo "<a href='$HANDBOOK>Local user password length definition not found</a>" >> /tmp/$HOST_NAME.hardeningsys
	fi

        # sudo members check
        if [ -f "/etc/sudoers" ]; then
                SUDOMEMBERCOUNT=$(cat /etc/sudoers |grep ALL= |grep -v % |grep -v root |wc -l)
                if [ $SUDOMEMBERCOUNT -gt "0" ]; then
                        cat /etc/sudoers |grep ALL= |grep -v % |grep -v root > /tmp/$HOST_NAME.sudomembers
                        echo "<a href='$HOST_NAME.sudomembers'>$SUDOMEMBERCOUNT user(s) have SUDO privileges</a>" >> /tmp/$HOST_NAME.hardeningsys
                fi
        else
                SUDOMEMBERCOUNT=0
        fi
fi

#--------------------------
# passwd, shadow, group file
#--------------------------
PASSWDFILEPERMS=$(stat /etc/passwd |grep "Access:" |grep "Uid:" |cut -d ":" -f2 |cut -d "/" -f1 |cut -d "(" -f2) \
	&& PASSWDFILEOWNER=$(ls -l /etc/passwd |cut -d ' ' -f3) && PASSWDFILEGRP=$(ls -l /etc/passwd |cut -d ' ' -f4)
	SHADOWFILEPERMS=$(stat /etc/shadow |grep "Access:" |grep "Uid:" |cut -d ":" -f2 |cut -d "/" -f1 |cut -d "(" -f2) \
	&& SHADOWFILEOWNER=$(ls -l /etc/shadow |cut -d ' ' -f3) && SHADOWFILEGRP=$(ls -l /etc/shadow |cut -d ' ' -f4)
	GROUPFILEPERMS=$(stat /etc/group |grep "Access:" |grep "Uid:" |cut -d ":" -f2 |cut -d "/" -f1 |cut -d "(" -f2) \
	&& GROUPFILEOWNER=$(ls -l /etc/group |cut -d ' ' -f3) && GROUPFILEGRP=$(ls -l /etc/group |cut -d ' ' -f4)
	GSHADOWFILEPERMS=$(stat /etc/gshadow |grep "Access:" |grep "Uid:" |cut -d ":" -f2 |cut -d "/" -f1 |cut -d "(" -f2) \
	&& GSHADOWFILEOWNER=$(ls -l /etc/gshadow |cut -d ' ' -f3) && GSHADOWFILEGRP=$(ls -l /etc/gshadow |cut -d ' ' -f4)

PASSWD_CHECK=NONE
SHADOW_CHECK=NONE
GROUP_CHECK=NONE
GSHADOW_CHECK=NONE

if [ "$REP" = "APT" ];then
        if [ $PASSWDFILEPERMS = "0644" ] && [ $PASSWDFILEOWNER = "root" ] && [ $PASSWDFILEGRP = "root" ]; then
                PASSWD_CHECK=Pass
        else
                PASSWD_CHECK=Fail
        fi
	
	if [ $SHADOWFILEPERMS = "0640" ] && [ $SHADOWFILEOWNER = "root" ] && [ $SHADOWFILEGRP = "shadow" ]; then
                SHADOW_CHECK=Pass
        else
                SHADOW_CHECK=Fail
        fi
	
	if [ $GROUPFILEPERMS = "0644" ] && [ $GROUPFILEOWNER = "root" ] && [ $GROUPFILEGRP = "root" ]; then
                GROUP_CHECK=Pass
        else
                GROUP_CHECK=Fail
        fi
	
	if [ $GSHADOWFILEPERMS = "0640" ] && [ $GSHADOWFILEOWNER = "root" ] && [ $GSHADOWFILEGRP = "shadow" ]; then
                GSHADOW_CHECK=Pass
        else
                GSHADOW_CHECK=Fail
        fi
fi

if [ "$REP" = "YUM" ];then
        if [ $PASSWDFILEPERMS = "0644" ] && [ $PASSWDFILEOWNER = "root" ] && [ $PASSWDFILEGRP = "root" ]; then
                PASSWD_CHECK=Pass
        else
                PASSWD_CHECK=Fail
        fi

	if [ $SHADOWFILEPERMS = "0000" ] && [ $SHADOWFILEOWNER = "root" ] && [ $SHADOWFILEGRP = "root" ]; then
                SHADOW_CHECK=Pass
        else
                SHADOW_CHECK=Fail
        fi

	if [ $GROUPFILEPERMS = "0644" ] && [ $GROUPFILEOWNER = "root" ] && [ $GROUPFILEGRP = "root" ]; then
                GROUP_CHECK=Pass
        else
                GROUP_CHECK=Fail
        fi

	if [ $GSHADOWFILEPERMS = "0000" ] && [ $GSHADOWFILEOWNER = "root" ] && [ $GSHADOWFILEGRP = "root" ]; then
                GSHADOW_CHECK=Pass
        else
                GSHADOW_CHECK=Fail
        fi
fi

if [ $PASSWD_CHECK = "Fail" ] || [ $SHADOW_CHECK = "Fail" ] || [ $GROUP_CHECK = "Fail" ] || [ $GSHADOW_CHECK = "Fail" ]; then
        echo "<a href='$HANDBOOK'>Files access check: passwd:$PASSWD_CHECK | shadow:$SHADOW_CHECK | group:$GROUP_CHECK | gshadow:$GSHADOW_CHECK</a>" \
                >> /tmp/$HOST_NAME.hardeningsys
fi

#---------------------------
# Network conf. check
#---------------------------
NW_CHECK1=$(sysctl net.ipv4.ip_forward |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK1 = "0" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 Forward Check: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK2=$(sysctl net.ipv4.conf.all.send_redirects |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK2 = "0" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 Send Redirects: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK3=$(sysctl net.ipv4.conf.all.accept_source_route |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK3 = "0" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 All Accept Source Route: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK4=$(sysctl net.ipv4.conf.default.accept_source_route |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK4 = "0" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 Default Accept Source Route: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK5=$(sysctl net.ipv4.conf.all.accept_redirects |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK5= "0" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 All Accept Redirects: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK6=$(sysctl net.ipv4.conf.default.accept_redirects |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK6 = "0" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 Default Accept Redirects: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK7=$(sysctl net.ipv4.conf.all.secure_redirects |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK7 = "0" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 All Secure Redirects: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK8=$(sysctl net.ipv4.conf.default.secure_redirects |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK8 = "0" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 Default Secure Redirects: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK9=$(sysctl net.ipv4.icmp_echo_ignore_broadcasts |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK9 = "1" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 Ignore Broadcast: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK10=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK10 = "1" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 Ignore Bogus Error Resp.: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK11=$(sysctl net.ipv4.conf.all.rp_filter |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK11 = "1" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 All rp Filter: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK12=$(sysctl net.ipv4.tcp_syncookies |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK12 = "1" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv4 TCP Syncookies: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK13=$(sysctl net.ipv6.conf.all.disable_ipv6 |cut -d "=" -f2 |cut -d " " -f2)
if [ ! $NW_CHECK13 = "1" ]; then echo "<a href='$HANDBOOK#-hardening_network_settings'>ipv6 Disable IPv6: Fail</a>" >> /tmp/$HOST_NAME.hardeningnw; fi
NW_CHECK14=$(sysctl net.ipv6.conf.all.accept_ra |cut -d "=" -f2 |cut -d " " -f2)

#---------------------------
# SSH conf. check
#---------------------------
# PRIVATE HOST KEY
SSH1=$(stat /etc/ssh/sshd_config |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
if [ ! $SSH1 = "0600" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>sshd_config uid: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH2=$(stat /etc/ssh/ssh_host_rsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
if [ ! $SSH2 = "0600" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>ssh_host_rsa_key uid: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH3=$(stat /etc/ssh/ssh_host_ecdsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
if [ ! $SSH3 = "0600" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>ssh_host_ecdsa_key uid: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH4=$(stat /etc/ssh/ssh_host_ed25519_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
if [ ! $SSH4 = "0600" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>ssh_host_ed25519_key uid: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
# PUBLIC HOST KEY
SSH5=$(stat /etc/ssh/ssh_host_rsa_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
if [ ! $SSH5 = "0644" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>ssh_host_rsa_key.pub uid: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH6=$(stat /etc/ssh/ssh_host_ed25519_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
if [ ! $SSH6 = "0644" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>ssh_host_ed25519_key.pub uid: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
grep ^Protocol /etc/ssh/sshd_config >> /dev/null
if [ ! $? = "0" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH Protocol2 setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH7=$(sshd -T | grep loglevel |cut -d " " -f2)
if [ ! $SSH7 = "INFO" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH LogLevel setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH8=$(sshd -T | grep x11forwarding |cut -d " " -f2)
if [ ! $SSH8 = "no" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH x11Forwarding setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH9=$(sshd -T | grep maxauthtries |cut -d " " -f2)
if [ ! $SSH9 -lt "4" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH MaxAuthtries setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH10=$(sshd -T | grep ignorerhosts |cut -d " " -f2)
if [ ! $SSH10 = "yes" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH IgnorerHosts setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH11=$(sshd -T | grep hostbasedauthentication |cut -d " " -f2)
if [ ! $SSH11 = "no" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH HostBasedAuth. setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH12=$(sshd -T | grep permitrootlogin |cut -d " " -f2)
if [ ! $SSH12 = "no" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH PermitRootLogin setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH13=$(sshd -T | grep permitemptypasswords |cut -d " " -f2)
if [ ! $SSH13 = "no" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH PermitEmptyPass setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi
SSH14=$(sshd -T | grep permituserenvironment |cut -d " " -f2)
if [ ! $SSH14 = "no" ]; then echo "<a href='$HANDBOOK#-hardening_ssh_settings'>SSH PermitUserEnv. setting: Fail</a>" >> /tmp/$HOST_NAME.hardeningssh; fi

############################
# VULNERABILITY CHECK
############################
rm /tmp/$HOST_NAME.cve

#---------------------------
# kernel based cve check
#---------------------------
###KERNEL_VER=$(uname -r |cut -d "-" -f1)
###perl /tmp/cve_check -k $KERNELVER > /tmp/cve_list
###CVELIST=$(cat /tmp/cve_list |grep CVE) && echo $CVELIST > /tmp/cve_list && CVELIST=$(cat /tmp/cve_list) && rm /tmp/cve_list && rm /tmp/cve_check

#---------------------------
# spectre-meltown check
#---------------------------
wget -O /tmp/spectre-meltdown.sh https://raw.githubusercontent.com/speed47/spectre-meltdown-checker/master/spectre-meltdown-checker.sh
bash /tmp/spectre-meltdown.sh > /tmp/spectre.txt
cat /tmp/spectre.txt |grep Affected |cut -d " " -f6 > /tmp/$HOST_NAME.spectre

SPECTRECOUNT=$(cat /tmp/spectre.txt |grep Affected |cut -d " " -f6 | wc -l)
if [ "$SPECTRECOUNT" -gt 0 ]; then
     echo "<a href='$HOST_NAME.spectre'>Spectre-Meltdown found</a>" >> /tmp/$HOST_NAME.cve
fi

rm /tmp/spectre-meltdown.sh
rm /tmp/spectre.txt

#---------------------------
# jog4j check
#---------------------------
find / -iname "log4j*" > /tmp/log4j_exist.txt && sed -i '/log4j_exist.txt/d' /tmp/log4j_exist.txt
if [ -s "/tmp/log4j_exist.txt" ]; then
        LOG4J_EXIST="USE"
        echo "<a href='$HOST_NAME.log4j'LOG4J/LOG4SHELL is use</a>" >> /tmp/$HOST_NAME.cve
        cat /tmp/log4j_exist.txt > /tmp/$HOST_NAME.log4j
        find /var/log/ -name '*.gz' -type f -exec sh -c "zcat {} | sed -e 's/\${lower://'g | tr -d '}' | egrep -i 'jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):'" \; \
                >> /tmp/$HOST_NAME.log4j
else
        LOG4J_EXIST=NOT_USE
fi

#---------------------------
# debian10 linux-source package check
#---------------------------
DEB_V=$(cat /etc/debian_version |cut -d "." -f1)
if [ "$REP" = APT ] && [ $DEB_V = "10" ]; then
        EBPF_DISABLED=$(sysctl kernel.unprivileged_bpf_disabled |cut -d"=" -f2 |cut -d " " -f2)
        DEB_U=$(dpkg -l |grep "linux-image-amd64" |cut -d "." -f2 |cut -d " " -f1 |cut -d "+" -f3)
        if [ ! "$EBPF_DISABLED" = 0 ] && [ ! "$DEB_U" = deb10u15 ]; then
                echo "<a href='$HOST_NAME.ebpf'eBPF exist</a>" >> /tmp/$HOST_NAME.cve
        fi

cat > /tmp/$HOST_NAME.ebpf << EOF
apt-listchanges: News
---------------------
linux-latest (105+deb10u14) buster-security; urgency=high
* From Linux 4.19.232-1, the Extended Berkeley Packet Fillter (eBPF)
facility is no longer enabled by default for users without the
CAP_SYS_ADMIN capability (this normally means only the root user).

eBPF can be used for speculative execution side-channel attacks, and
earlier attempts to mitigate this have not completely succeeded.

This can be overridden by setting the sysctl:
kernel.unprivileged_bpf_disabled=0

-- Ben Hutchings <benh@debian.org>  Mon, 07 Mar 2022 22:37:11 +0100
EOF
fi

############################
# repo list
############################
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

############################
# running services
############################
rm /tmp/runningservices.txt
systemctl list-units --type service |grep running > /tmp/runningservices.txt && NUM_SERVICES=$(wc -l /tmp/runningservices.txt |cut -d ' ' -f1)

############################
# listening,established conn.
############################
rm /tmp/listeningconn.txt
rm /tmp/establishedconn.txt
netstat -tupl > /tmp/listeningconn.txt
netstat -tup | grep ESTABLISHED > /tmp/establishedconn.txt
sed -i '1d' /tmp/establishedconn.txt && sed -i '1d' /tmp/listeningconn.txt
ESTABLISHEDCONN=$(wc -l /tmp/establishedconn.txt |cut -d " " -f1)
LISTENINGCONN=$(wc -l /tmp/listeningconn.txt |cut -d " " -f1)

############################
# INTEGRITY CHECK
############################
LOCALDIR="/usr/local/lastcontrol/data/etc"
if [ ! -d "$LOCALDIR" ]; then
mkdir -p $LOCALDIR
rsync -a /etc/ $LOCALDIR && INT_CHECK=INITIAL
else
        rsync -av /etc/ $LOCALDIR > /tmp/integritycheck.txt
        sed -i -e :a -e '$d;N;2,2ba' -e 'P;D' /tmp/integritycheck.txt && sed -i '/^$/d' /tmp/integritycheck.txt && sed -i '1d' /tmp/integritycheck.txt
        if [ -s "/tmp/integritycheck.txt" ]; then INT_CHECK=DETECTED; else INT_CHECK=NOTDETECTED; fi
fi

if [ $INT_CHECK = "DETECTED" ]; then
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.intcheck
	echo "                  :::... INTEGRITY CHECK ...:::" >> /tmp/$HOST_NAME.intcheck
	echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.intcheck
	cat /tmp/integritycheck.txt > /tmp/$HOST_NAME.intcheck && rm /tmp/integritycheck.txt
else
	rm /tmp/integritycheck.txt
fi

############################
# INVENTORY CHECK
############################
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

if [ "$INV_CHECK" = "DETECTED" ]; then
        echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.invcheck
        echo "                          :::... CHANGE HARDWARE NOTIFICATION !!! ....:::" >> /tmp/$HOST_NAME.invcheck
        echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.invcheck
        diff $LOCALFILE /tmp/inventory.txt >> /tmp/$HOST_NAME.invcheck && rm /tmp/inventory.txt
        echo "------------------------------------------------------------------------------------------------------" >> /tmp/$HOST_NAME.invcheck
        echo "" >> /tmp/$HOST_NAME.invcheck
else
        rm /tmp/inventory.txt
fi

############################
# report file
############################
rm /tmp/$HOST_NAME.txt
cat > /tmp/$HOST_NAME.txt << EOF
$HOST_NAME LastControl Report $DATE
=======================================================================================================================================================================
--------------------------------------------------------------------------------------------------------------------------
                                :::... MACHINE INVENTORY ...:::
--------------------------------------------------------------------------------------------------------------------------
|Hostname:          |$HOST_NAME
|IP Address:        |$INT_IPADDR | $EXT_IPADDR
|Internet Conn.     |$INTERNET   | Installation Check: $INSTALL_CHECK
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
|Uptime             |$UPTIME | $UPTIME_MIN
|Kernel Version:    |$OS_KERNEL
--------------------------------------------------------------------------------------------------------------------------
|Date/Time Sync:    |System clock synchronized:$TIME_SYNC
|Proxy Usage:       |HTTP: $HTTPPROXY_USE
|SYSLOG Usage:      |$SYSLOGINSTALL | $SYSLOGSERVICE | Socket: $SYSLOGSOCKET | Send: $SYSLOGSEND
--------------------------------------------------------------------------------------------------------------------------
|Listening Conn.:   |$LISTENINGCONN
|Established Conn.: |$ESTABLISHEDCONN
--------------------------------------------------------------------------------------------------------------------------
| RESOURCE
--------------------------------------------------------------------------------------------------------------------------
|Ram Use:           |$RAM_USE_PERCENTAGE%
|Swap Use:          |$SWAP_USE_PERCENTAGE%
|Disk Use:          |$DISK_USAGE%
--------------------------------------------------------------------------------------------------------------------------
| SERVICES
--------------------------------------------------------------------------------------------------------------------------
|Running Services:  |$NUM_SERVICES
|Services Info:     |Loaded: | Active: | Failed: | Inactive:
--------------------------------------------------------------------------------------------------------------------------
| PROCESS
--------------------------------------------------------------------------------------------------------------------------
|Process Info:      |Total:$TO_PROCESS | Running:$RU_PROCESS | Sleeping:$SL_PROCESS
|Stopping Process:  |$ST_PROCESS
|Zombie Process:    |$ZO_PROCESS
--------------------------------------------------------------------------------------------------------------------------
|Load Average:      |There are $NOC CPUs in the system | $LOAD_AVG
|Uses the Most Load:|Process: $MOST_PROCESS | Cpu: $MOST_CPU | Ram: $MOST_RAM
--------------------------------------------------------------------------------------------------------------------------
| USERS
--------------------------------------------------------------------------------------------------------------------------
|SUDO Member Count: |$SUDOMEMBERCOUNT
|Local User Count:  |$LOCALUSER_COUNT
--------------------------------------------------------------------------------------------------------------------------
| VULNERABILITY
--------------------------------------------------------------------------------------------------------------------------
|CVE List:          |$CVELIST
|LOG4J/LOG4SHELL    |$LOG4J_EXIST
--------------------------------------------------------------------------------------------------------------------------
|Inventory Check:   |$INV_CHECK
|Integrity Check:   |$INT_CHECK
--------------------------------------------------------------------------------------------------------------------------
|Disk Quota Usage:  |$QUOTA_INSTALL | Usr_Quota: $USR_QUOTA | Grp_Quota: $GRP_QUOTA | Mount: $MNT_MOUNT
|S.M.A.R.T          |
--------------------------------------------------------------------------------------------------------------------------
$SMART
--------------------------------------------------------------------------------------------------------------------------
EOF
