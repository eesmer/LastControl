#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

#------------------
# Color Codes
#------------------
MAGENTA="tput setaf 1"
GREEN="tput setaf 2"
YELLOW="tput setaf 3"
DGREEN="tput setaf 4"
CYAN="tput setaf 6"
WHITE="tput setaf 7"
GRAY="tput setaf 8"
RED="tput setaf 9"
NOCOL="tput sgr0"

HOST_NAME=$(cat /etc/hostname)
RDIR=/usr/local/lastcontrol/reports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

rm -r $RDIR
mkdir -p $RDIR

#----------------------------
# determine distro
#----------------------------
cat /etc/*-release /etc/issue > "$RDIR/distrocheck"
if grep -qi "debian\|ubuntu" "$RDIR/distrocheck"; then
    REP=APT
elif grep -qi "centos\|rocky\|red hat" "$RDIR/distrocheck"; then
    REP=YUM
fi
rm $RDIR/distrocheck

#----------------------------
# Not support message
#----------------------------
if [ -z "$REP" ]; then
	$RED
	echo -e
	echo "--------------------------------------------------------------"
	echo -e "Repository could not be detected.\nThis distro is not supported"
	echo "--------------------------------------------------------------"
	echo -e
	$NOCOL
	exit 1
fi

CHECK_QUOTA() {
    if command -v quotacheck &> /dev/null; then
        QUOTA_INSTALL=Pass
    else
        QUOTA_INSTALL=Fail
    fi

    if grep -q -E 'usrquota|grpquota' /proc/mounts; then
        USR_QUOTA=Pass
        GRP_QUOTA=Pass
        MNT_QUOTA=Pass
    else
        USR_QUOTA=Fail
        GRP_QUOTA=Fail
        MNT_QUOTA=Fail
    fi
}

LVM_CRYPT() {
    if lsblk --output type | grep -qw "lvm"; then
        LVM_USAGE=Pass
    else
        LVM_USAGE=Fail
    fi

    if command -v cryptsetup &> /dev/null && lsblk --output type | grep -qw "crypt"; then
        CRYPT_INSTALL=Pass
        CRYPT_USAGE=Pass
    else
        CRYPT_INSTALL=Fail
        CRYPT_USAGE=Fail
    fi
}

SYSLOG_INFO() {
        SYSLOGINSTALL=Not_Installed
                if [ "$REP" = "APT" ]; then
                        dpkg -l | grep -q rsyslog && SYSLOGINSTALL=Installed
                elif [ "$REP" = "YUM" ]; then
                        rpm -qa | grep -q rsyslog && SYSLOGINSTALL=Installed
                fi

                if [ "$SYSLOGINSTALL" = "Installed" ]; then
                        SYSLOGSERVICE=INACTIVE
                        systemctl is-active rsyslog.service && SYSLOGSERVICE=ACTIVE
                        SYSLOGSOCKET=INACTIVE
                        systemctl is-active syslog.socket && SYSLOGSOCKET=ACTIVE
                        SYSLOGSEND=NO
                        grep -q "@" /etc/rsyslog.conf && SYSLOGSEND=YES # ??? kontrol edilecek
                else
                        SYSLOGSERVICE=NONE
                        SYSLOGSOCKET=NONE
                        SYSLOGSEND=NONE
                fi
}


#----------------------------
# HARDWARE INVENTORY
#----------------------------
INTERNAL_IP=$(hostname -I)
EXTERNAL_IP=$(curl -4 icanhazip.com 2>/dev/null)
CPU_INFO=$(awk -F ':' '/model name/ {print $2}' /proc/cpuinfo | head -n 1)
RAM_TOTAL=$(free -m | awk 'NR==2{print $2 " MB"}')
RAM_USAGE=$(free -m | awk 'NR==2{print $3 " MB"}')
GPU_INFO=$(lspci | grep -i vga | cut -d ':' -f3)
GPU_RAM=$(lspci -v | awk '/ prefetchable/{print $6}' | head -n 1)
DISK_LIST=$(lsblk -o NAME,SIZE -d -e 11,2 | tail -n +2)
DISK_INFO=$(df -h --total | awk 'END{print}')
ping -c 1 google.com &> /dev/null && INTERNET="CONNECTED" || INTERNET="DISCONNECTED"

#----------------------------
# SYSTEM
#----------------------------
KERNEL=$(uname -sr)
DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f2)
UPTIME=$(uptime) && UPTIME_MIN=$(awk '{print "up", $1/60, "minutes"}' /proc/uptime)
LASTBOOT=$(uptime -s)
VIRT_CONTROL=NONE
[ -e "/dev/kvm" ] && VIRT_CONTROL=ON
LOCALDATE=$(timedatectl status | awk '/Local time:/ {print $3,$4,$5}')
TIMEZONE=$(timedatectl status | awk -F ': ' '/Time zone:/ {print $2}') #TIME_SYNC=$(timedatectl |grep "synchronized:" |cut -d ":" -f2 | xargs)
TIME_SYNC=$(timedatectl status | awk '/synchronized:/ {print $4}')
HTTP_PROXY_USAGE=FALSE
{ env | grep -q "http_proxy"; } || { grep -q -e "export http" /etc/profile /etc/profile.d/*; } && HTTP_PROXY_USAGE=TRUE

##----------------------------
## SYSLOG Service
##----------------------------
#SYSLOGINSTALL=Not_Installed
#if [ "$REP" = "APT" ]; then
#    dpkg -l | grep -q rsyslog && SYSLOGINSTALL=Installed
#elif [ "$REP" = "YUM" ]; then
#    rpm -qa | grep -q rsyslog && SYSLOGINSTALL=Installed
#fi
#
#if [ "$SYSLOGINSTALL" = "Installed" ]; then
#    SYSLOGSERVICE=INACTIVE
#    systemctl is-active --quiet service && SYSLOGSERVICE=ACTIVE
#
#   SYSLOGSOCKET=INACTIVE
#   systemctl is-active --quiet syslog.socket && SYSLOGSOCKET=ACTIVE
#
#    SYSLOGSEND=NO
#    grep -q "@" /etc/rsyslog.conf && SYSLOGSEND=YES
#
#else
#        SYSLOGSERVICE=NONE
#        SYSLOGSOCKET=NONE
#        SYSLOGSEND=NONE
#fi

RAM_USAGE_PERCENTAGE=$(free |grep Mem |awk '{print $3/$2 * 100}' |cut -d "." -f1)
OOM=0
grep -i -r 'out of memory' /var/log/ &>/dev/null && OOM=1
if [ "$OOM" = "1" ]; then OOM_LOGS="Out of Memory Log Found !!"; fi
SWAP_USAGE_PERCENTAGE=$(free -m |grep Swap |awk '{print $3/$2 * 100}' |cut -d "." -f1)
DISK_USAGE=$(fdisk -lu | grep "Disk" | grep -v "Disklabel" | grep -v "dev/loop" | grep -v "Disk identifier")

#KERNEL MODULE CONTROL
###KERNEL_VER=$(uname -r)
CRAMFS="NOT LOADED"
lsmod |grep cramfs &>/dev/null && CRAMFS=LOADED
FREEVXFS="NOT LOADED"
lsmod |grep freevxfs &>/dev/null && FREEVXFS=LOADED
JFFS2="NOT LOADED"
lsmod |grep jffs2 &>/dev/null && JFFS2=LOADED
HFS="NOT LOADED"
lsmod |grep hfs &>/dev/null && HFS=LOADED
HFSPLUS="NOT LOADED"
lsmod |grep hfsplus &>/dev/null && HFS=LOADED
SQUASHFS="NOT LOADED"
lsmod |grep squashfs &>/dev/null && SQUASHFS=LOADED
UDF="NOT LOADED"
lsmod |grep udf &>/dev/null && UDF=LOADED

# GRUB CONTROL
if [ "$REP" = APT ]; then
        GRUB_EXIST=Fail
        dpkg -l |grep -w "grub" &>/dev/null && GRUB_EXIST=GRUB
        dpkg -l |grep -w "grub2" &>/dev/null && GRUB_EXIST=GRUB2

        if [ "$GRUB_EXIST" = "GRUB" ]; then
                GRUB_PACKAGE=$(dpkg -l |grep -w "grub" |grep "common")
        elif [ "$GRUB_EXIST" = "GRUB2" ]; then
                GRUB_PACKAGE=$(dpkg -l |grep -w "grub2" |grep "common")
        elif [ "$GRUB_EXIST" = "Fail" ]; then
                GRUB_PACKAGE="Fail"
        fi
        # GRUB Security
        GRUB_SEC=Fail
        grep "set superusers=" /etc/grub.d/* &>/dev/null && GRUB_SEC=Pass

elif [ "$REP" = YUM ]; then
        GRUB_EXIST=Fail
        rpm -qa |grep -w "grub" &>/dev/null && GRUB_EXIST=GRUB
        rpm -qa |grep -w "grub2" &>/dev/null && GRUB_EXIST=GRUB2

        if [ "$GRUB_EXIST" = "GRUB" ]; then
                GRUB_PACKAGE=$(rpm -qa |grep -w "grub" |grep "common")
        elif [ "$GRUB_EXIST" = "GRUB2" ]; then
                GRUB_PACKAGE=$(rpm -qa |grep -w "grub2" |grep "common")
        elif [ "$GRUB_EXIST" = "Fail" ]; then
                GRUB_PACKAGE="Fail"
        fi

        # GRUB Security
        GRUB_SEC="Fail"
        if [ -a "/boot/grub2/user.cfg" ]; then GRUB_SEC="Pass"; fi
fi
#----------------------------
# SERVICE & PROCESSES
#----------------------------
SERVICE_MANAGER="$(ps --no-headers -o comm 1)"
if [ "$SERVICE_MANAGER" = systemd ]; then
        systemctl list-units --type service |grep running > $RDIR/runningservices.txt
        RUNNING_SERVICE=$(wc -l $RDIR/runningservices.txt |cut -d ' ' -f1)
        LOADED_SERVICE=$(systemctl list-units --type service |grep "units." |cut -d "." -f1)
fi
ACTIVE_CONN=$(netstat -s |grep "active connection openings")
PASSIVE_CONN=$(netstat -s |grep "passive connection openings")
FAILED_CONN=$(netstat -s |grep "failed connection attempts")
ESTAB_CONN=$(netstat -s |grep "connections established")
NOC=$(nproc --all)
LOAD_AVG=$(uptime |grep "load average:" |awk -F: '{print $5}')
ZO_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[Zz]' | wc -l)

USERCOUNT=$(cat /etc/shadow |grep -v "*" |grep -v "!" |wc -l)
USERLIST=$(cat /etc/passwd | grep -v "/sbin/nologin" | grep -v "/bin/false" | grep -E "/bin/bash|/bin/zsh|/bin/sh" | cut -d":" -f1 | paste -sd ",")
SUDOUSERLIST=$(getent group sudo | awk -F: '{print $4}' | tr ',' "\n" >> /tmp/sudouserlist ; cat /etc/sudoers | grep "ALL" | grep -v "%" | awk '{print $1}' >> /tmp/sudouserlist ; grep 'ALL' /etc/sudoers.d/* | cut -d":" -f2 | cut -d" " -f1 >> /tmp/sudouserlist ; cat /tmp/sudouserlist | sort -u | paste -sd "," ; rm -f /tmp/sudouserlist)
SERVICEUSERLIST=$(awk -F: '$2 == "*"' /etc/shadow | cut -d ":" -f1 | paste -sd ",")
BLANKPASSUSERLIST=$(awk -F: '$2 == "!*" { print $1 }' /etc/shadow | paste -sd ",")
LASTLOGIN00D=$(lastlog --time 1 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
LASTLOGIN07D=$(lastlog --time 7 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
LASTLOGIN30D=$(lastlog --time 30 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
# NOTLOGIN USERLIST last 30 Day
lastlog --time 30 | grep -v "Username" | cut -d " " -f1 > /tmp/lastlogin30d
getent passwd {0..0} {1000..2000} |cut -d ":" -f1 > /tmp/localuserlist
NOTLOGIN30D=$(diff /tmp/lastlogin30d /tmp/localuserlist -n | grep -v "d1" | grep -v "a0" | grep -v "a1" | grep -v "a2" | grep -v "a3" | grep -v "a4" | paste -sd ",")
# PASSWORD EXPIRE INFO
rm -f /tmp/passexpireinfo.txt
USERCOUNT=$(cat /tmp/localuserlist | wc -l)
PX=1
while [ $PX -le $USERCOUNT ]; do
    USERACCOUNTNAME=$(awk "NR==$PX" /tmp/localuserlist)
    PASSEX=$(chage -l $USERACCOUNTNAME |grep "Password expires" | awk '{print $4}')
    echo "$USERACCOUNTNAME:$PASSEX" >> /tmp/passexpireinfo.txt
    PX=$(( PX + 1 ))
done
PASSEXINFO=$(cat /tmp/passexpireinfo.txt | paste -sd ",")

rm -f /tmp/passchange
rm -f /tmp/userstatus
PC=1
while [ $PC -le $USERCOUNT ]; do
    USERACCOUNTNAME=$(awk "NR==$PC" /tmp/localuserlist)
    PASSCHANGE=$(lslogins "$USERACCOUNTNAME" | grep "Password changed:" | awk ' { print $3 }')    # Password update date
    USERSTATUS=$(passwd -S "$USERACCOUNTNAME" >> /tmp/userstatus)                                 # user status information
    echo "$USERACCOUNTNAME:$PASSCHANGE" >> /tmp/passchange
    PC=$(( PC + 1 ))
done

cat /tmp/userstatus | grep "L" | cut -d " " -f1 > /tmp/lockedusers
LOCKEDUSERS=$(cat /tmp/lockedusers | paste -sd ",")                                            # locked users
PASSUPDATEINFO=$(cat /tmp/passchange | paste -sd ",")
rm /tmp/lockedusers

# LOGIN INFO
rm -f /tmp/lastlogininfo
LL=1
while [ "$LL" -le "$USERCOUNT" ]; do
        USERACCOUNTNAME=$(ls -l |sed -n $LL{p} /tmp/localuserlist)
        #LOGINFROM=$(lastlog | grep $USERACCOUNTNAME | xargs)
        ###lastlog | grep $USERACCOUNTNAME | cut -d "+" -f1 >> /tmp/lastlogininfo
        LOGINDATE=$(lslogins | grep "$USERACCOUNTNAME" | xargs | cut -d " " -f6)
        LOGINDATE=$(lastlog | grep "$USERACCOUNTNAME" | awk '{ print $4,$5,$6,$7 }')
        echo "$USERACCOUNTNAME:$LOGINDATE" >> /tmp/lastlogininfo
LL=$(( LL + 1 ))
done
LASTLOGININFO=$(cat /tmp/lastlogininfo | paste -sd ",")

# NEVER LOGGED USERS
USERCOUNT=$(cat /etc/shadow | grep -v "*" | grep -v "!" | wc -l)
cat /etc/shadow | grep -v "*" | grep -v "!" | cut -d ":" -f1 > /tmp/localaccountlist
rm -f /tmp/notloggeduserlist
NL=1
while [ $NL -le $USERCOUNT ]; do
    USERACCOUNTNAME=$(awk "NR==$NL" /tmp/localaccountlist)
    lastlog | grep "Never logged in" | grep "$USERACCOUNTNAME" >> /tmp/notloggeduserlist
    NL=$(( NL + 1 ))
done
NOTLOGGEDUSER=$(cat /tmp/notloggeduserlist | cut -d " " -f1 | paste -sd "@")

rm -f /tmp/{localaccountlist,notloggeduserlist}
rm -f /tmp/{lastlogin30d,localuserlist,userstatus,activeusers,lockedusers,passchange,PasswordBilgileri,userstatus,lastlogininfo}

######################ping -c 1 google.com &> /dev/null && INTERNET="CONNECTED" || INTERNET="DISCONNECTED"
######################UPTIME=$(uptime | awk '{print $1,$2,$3,$4}' |cut -d "," -f1)
#DISTRO=$(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)
#KERNEL=$(uname -mrs)

CHECK_QUOTA
LVM_CRYPT
SYSLOG_INFO

#-------------------------
# Create TXT Report File
#-------------------------
rm $RDIR/$HOST_NAME-allreports.txt
cat > $RDIR/$HOST_NAME-allreports.txt << EOF
$HOST_NAME LastControl All Controls Report $DATE
=======================================================================================================================================================================
--------------------------------------------------------------------------------------------------------------------------
| HARDWARE INVENTORY
--------------------------------------------------------------------------------------------------------------------------
|Hostname:          |$HOST_NAME
|IP Address:        |$INTERNAL_IP | $EXTERNAL_IP
|Internet Conn.     |$INTERNET
|CPU:               |$CPU_INFO
|RAM:               |Total:$RAM_TOTAL | Ram Usage: $RAM_USAGE
|GPU / VGA:         |VGA: $GPU_INFO   | VGA Ram: $GPU_RAM 
|DISK LIST:         |$DISK_LIST
|DISK INFO:         |$DISK_INFO
--------------------------------------------------------------------------------------------------------------------------
| SYSTEM INFORMATION
--------------------------------------------------------------------------------------------------------------------------
|Operation System:  |$DISTRO
|Kernel Version:    |$KERNEL
|Uptime             |$UPTIME | $UPTIME_MIN
|Last Boot:         |$LAST_BOOT
|Virtualization:    |$VIRT_CONTROL
|Date/Time Sync:    |Date:$LOCALDATE - System clock synchronized:$TIME_SYNC
|Timezone:          |$TIMEZONE
|Proxy Usage:       |HTTP: $HTTPPROXY_USAGE
|SYSLOG Usage:      |$SYSLOGINSTALL | $SYSLOGSERVICE | Socket: $SYSLOGSOCKET | Send: $SYSLOGSEND
--------------------------------------------------------------------------------------------------------------------------
|Ram  Usage:        |$RAM_USAGE_PERCENTAGE%
|Swap Usage:        |$SWAP_USAGE_PERCENTAGE%
|Disk Usage:        |$DISK_USAGE
|Out of Memory Logs |$OOM_LOGS
--------------------------------------------------------------------------------------------------------------------------
|Disk Quota Usage:  |$QUOTA_INSTALL | Usr_Quota: $USR_QUOTA | Grp_Quota: $GRP_QUOTA | Mount: $MNT_MOUNT
|Disk Encrypt Usage:|$CRYPT_INSTALL | $CRYPT_Usage
|LVM Usage:         |$LVM_Usage
--------------------------------------------------------------------------------------------------------------------------
| Kernel Modules
--------------------------------------------------------------------------------------------------------------------------
|CRAMFS             |$CRAMFS
|FREEVXFS           |$FREEVXFS
|JFFS2              |$JFFS2
|HFS                |$HFS
|HFSPLUS            |$HFSPLUS
|SQUASHFS           |$SQUASHFS
|UDF                |$UDF
--------------------------------------------------------------------------------------------------------------------------
|GRUB               |$GRUB_PACKAGE
|GRUB Security      |$GRUB_SEC
--------------------------------------------------------------------------------------------------------------------------
| SERVICES & PROCESSES
--------------------------------------------------------------------------------------------------------------------------
|Service Management:|$SERVICE_MANAGER
|Running Service:   |$RUNNING_SERVICE
|Loaded Service:    |$LOADED_SERVICE
--------------------------------------------------------------------------------------------------------------------------
|Active Connection: |$ACTIVE_CONN
|Passive Connection:|$PASSIVE_CONN
|Failed Connection: |$FAILED_CONN
|Established Conn.: |$ESTAB_CONN
---------------------------------------------------------------------------------------------------------------------------
|Number of CPU:     |$NOC
|Load Avarage       |$LOAD_AVG
|Zombie Process:    |$ZO_PROCESS
-------------------------------------------------------------------------------------------------------------------------
EOF
echo "|LISTENING SERVICE LIST" >> $RDIR/$HOST_NAME-allreports.txt
echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
netstat -tl |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" >> $RDIR/$HOST_NAME-allreports.txt
echo "" >> $RDIR/$HOST_NAME-allreports.txt
echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
echo "|ESTABLISHED SERVICE LIST" >> $RDIR/$HOST_NAME-allreports.txt
echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
netstat -tn |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" |grep "ESTABLISHED" >> $RDIR/$HOST_NAME-allreports.txt
echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
cat >> $RDIR/$HOST_NAME-allreports.txt << EOF
| USERS
--------------------------------------------------------------------------------------------------------------------------
|Local User Count:  |$USERCOUNT
|Local User List:   |$USERLIST
|SUDO Users:        |$SUDOUSERLIST
|Blank Pass. Users  |$BLANKPASSUSERLIST
|Locked Users       |$LOCKEDUSERS
--------------------------------------------------------------------------------------------------------------------------
|Last Login Today   |$LASTLOGIN00D
|Last Login 7 Days  |$LASTLOGIN07D
|Last Login 30 Days |$LASTLOGIN30D
|Not Logged(30 Days)|$NOTLOGIN30D
|Last Login Info    |$LASTLOGININFO
|Never Logged Users |$NEVERLOGGED
--------------------------------------------------------------------------------------------------------------------------
|Pass. Expire Info  |$PASSEXINFO
|Pass. Update Info  |$PASSUPDATEINFO
--------------------------------------------------------------------------------------------------------------------------
|Service Users:     |$SERVICEUSERLIST
--------------------------------------------------------------------------------------------------------------------------

EOF
