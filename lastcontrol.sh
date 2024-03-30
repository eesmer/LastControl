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

# LOCAL USERS
#grep -E "/bin/bash|/bin/zsh|/bin/sh" /etc/passwd | grep -v "/sbin/nologin" | grep -v "/bin/false" | cut -d":" -f1 > /tmp/localusers
cat /etc/shadow | grep -v "*" | grep -v "!" | cut -d ":" -f1 > /tmp/localusers
LOCAL_USER_COUNT=$(cat /tmp/localusers | wc -l)
LOCAL_USER_LIST_FILE=/tmp/localusers


# HARDWARE INVENTORY
INTERNAL_IP=$(hostname -I)
EXTERNAL_IP=$(curl -4 icanhazip.com 2>/dev/null)
CPU_INFO=$(awk -F ':' '/model name/ {print $2}' /proc/cpuinfo | head -n 1)
RAM_TOTAL=$(free -m | awk 'NR==2{print $2 " MB"}')
RAM_USAGE=$(free -m | awk 'NR==2{print $3 " MB"}')
GPU_INFO=$(lspci | grep -i vga | cut -d ':' -f3)
GPU_RAM=$(lspci -v | awk '/ prefetchable/{print $6}' | head -n 1)
DISK_LIST=$(lsblk -o NAME,SIZE -d -e 11,2 | tail -n +2 | grep -v "loop")
DISK_INFO=$(df -h --total | awk 'END{print}')
DISK_USAGE=$(fdisk -lu | grep "Disk" | grep -v "Disklabel" | grep -v "dev/loop" | grep -v "Disk identifier")
ping -c 1 google.com &> /dev/null && INTERNET="CONNECTED" || INTERNET="DISCONNECTED"

# SYSTEM INFO
KERNEL=$(uname -sr)
DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f2)
UPTIME=$(uptime) && UPTIME_MIN=$(awk '{print "up", $1/60, "minutes"}' /proc/uptime)
LAST_BOOT=$(uptime -s)
VIRT_CONTROL=NONE
[ -e "/dev/kvm" ] && VIRT_CONTROL=ON
LOCALDATE=$(timedatectl status | awk '/Local time:/ {print $3,$4,$5}')
TIMEZONE=$(timedatectl status | awk -F ': ' '/Time zone:/ {print $2}') #TIME_SYNC=$(timedatectl |grep "synchronized:" |cut -d ":" -f2 | xargs)
TIME_SYNC=$(timedatectl status | awk '/synchronized:/ {print $4}')
HTTP_PROXY_USAGE=FALSE
{ env | grep -q "http_proxy"; } || { grep -q -e "export http" /etc/profile /etc/profile.d/*; } && HTTP_PROXY_USAGE=TRUE

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
                        systemctl is-active rsyslog.service >/dev/null 2>&1 && SYSLOGSERVICE=ACTIVE
                        SYSLOGSOCKET=INACTIVE
                        systemctl is-active syslog.socket >/dev/null 2>&1 && SYSLOGSOCKET=ACTIVE
                        SYSLOGSEND=NO
                        grep -q "@" /etc/rsyslog.conf && SYSLOGSEND=YES # ??? kontrol edilecek
                else
                        SYSLOGSERVICE=NONE
                        SYSLOGSOCKET=NONE
                        SYSLOGSEND=NONE
                fi
}

MEMORY_INFO() {
        RAM_USAGE_PERCENTAGE=$(free |grep Mem |awk '{print $3/$2 * 100}' |cut -d "." -f1)
        SWAP_USAGE_PERCENTAGE=$(free -m |grep Swap |awk '{print $3/$2 * 100}' |cut -d "." -f1)
        OOM=0
        grep -i -r 'out of memory' /var/log/ &>/dev/null && OOM=1
        OOM_LOGS="None"
        if [ "$OOM" = "1" ]; then OOM_LOGS="Out of Memory Log Found !!"; fi
}

USER_LIST(){
    USER_LIST=$(paste -sd "," "$LOCAL_USER_LIST_FILE")
}

SUDO_USER_LIST(){
    tmpfile=$(mktemp)
    getent group sudo | awk -F: '{print $4}' | tr ',' "\n" >> "$tmpfile"
    cat /etc/sudoers | grep "ALL" | grep -v "%" | awk '{print $1}' >> "$tmpfile"
    grep 'ALL' /etc/sudoers.d/* | cut -d":" -f2 | cut -d" " -f1 >> "$tmpfile"
    SUDOUSERLIST=$(sort -u "$tmpfile" | paste -sd ",")
    rm -f "$tmpfile"
}

PASSWORD_EXPIRE_INFO() {
        rm -f /tmp/passexpireinfo.txt
        PX=1
        while [ $PX -le $LOCAL_USER_COUNT ]; do
                USERACCOUNTNAME=$(awk "NR==$PX" /tmp/localuserlist)
                PASSEX=$(chage -l $USERACCOUNTNAME |grep "Password expires" | awk '{print $4}')
                echo "$USERACCOUNTNAME:$PASSEX" >> /tmp/passexpireinfo.txt
                PX=$(( PX + 1 ))
        done
        PASSEXINFO=$(cat /tmp/passexpireinfo.txt | paste -sd ",")
}

NEVER_LOGGED_USERS() {
        cat /etc/shadow | grep -v "*" | grep -v "!" | cut -d ":" -f1 > /tmp/localaccountlist
        rm -f /tmp/notloggeduserlist
        NL=1
        while [ $NL -le $LOCAL_USER_COUNT ]; do
                USER_ACCOUNT_NAME=$(awk "NR==$NL" $LOCAL_USER_LIST_FILE)
                lastlog | grep "Never logged in" | grep "$USER_ACCOUNT_NAME" >> /tmp/notloggeduserlist
                NL=$(( NL + 1 ))
        done

        NOTLOGGEDUSER=$(cat /tmp/notloggeduserlist | cut -d " " -f1 | paste -sd "@")
        rm /tmp/notloggeduserlist
}

LOGIN_INFO() {
        rm -f /tmp/lastlogininfo
        LL=1
        while [ "$LL" -le "$LOCAL_USER_COUNT" ]; do
                USER_ACCOUNT_NAME=$(ls -l |sed -n $LL{p} $LOCAL_USER_LIST_FILE)
                LOGINDATE=$(lslogins | grep "$USER_ACCOUNT_NAME" | xargs | cut -d " " -f6)
                LOGINDATE=$(lastlog | grep "$USER_ACCOUNT_NAME" | awk '{ print $4,$5,$6,$7 }')
                echo "$USER_ACCOUNT_NAME:$LOGINDATE" >> /tmp/lastlogininfo
                LL=$(( LL + 1 ))
        done
        LASTLOGININFO=$(cat /tmp/lastlogininfo | paste -sd ",")
}

# CHECK KERNEL MODULES
####OSVER=$(grep PRETTY_NAME /etc/os-release | cut -d '=' -f2 | cut -d '"' -f2)
modules=("cramfs" "freevxfs" "jffs2" "hfs" "hfsplus" "squashfs" "udf")
# Initialize a variable to hold the module statuses
declare -A module_statuses
# Loop through the modules array and check their status
for module in "${modules[@]}"; do
        module_statuses["$module"]="FALSE"
        if lsmod | grep -q "$module"; then
                module_statuses["$module"]="LOADED"
                #echo "<a href='$HANDBOOK#-hardening_loaded_kernel_modules'>$module Filesystem loaded</a>" >> "/tmp/the.hardeningsys"
        fi
done
#echo ${module_statuses["cramfs"]}
#echo ${module_statuses["freevxfs"]}
#echo ${module_statuses["jffs2"]}
#echo ${module_statuses["hfs"]}
#echo ${module_statuses["hfsplus"]}
#echo ${module_statuses["squashfs"]}
#echo ${module_statuses["udf"]}

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

ACTIVE_CONN=$(netstat -s | awk '/active connection openings/ {print $1}')
PASSIVE_CONN=$(netstat -s | awk '/passive connection openings/ {print $1}')
FAILED_CONN=$(netstat -s | awk '/failed connection attempts/ {print $1}')
ESTAB_CONN=$(netstat -s | awk '/connections established/ {print $1}')
NOC=$(nproc --all)
LOAD_AVG=$(uptime | grep "load average:" | awk -F: '{print $5}')
ZO_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[Zz]' | wc -l)

SERVICEUSERLIST=$(awk -F: '$2 == "*"' /etc/shadow | cut -d ":" -f1 | paste -sd ",")
BLANKPASSUSERLIST=$(awk -F: '$2 == "!*" { print $1 }' /etc/shadow | paste -sd ",")
LASTLOGIN00D=$(lastlog --time 1 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
LASTLOGIN07D=$(lastlog --time 7 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
LASTLOGIN30D=$(lastlog --time 30 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
NOLOGINUSER=$(awk -F: '$NF !~ "/(bash|sh)$" && $NF != "" {print $1}' /etc/passwd | wc -l)
LOGINAUTHUSER=$(awk -F: '$NF ~ "/bin/(ba)?sh$"{print $1}' /etc/passwd)

# NOTLOGIN USERLIST last 30 Day
lastlog --time 30 | grep -v "Username" | cut -d " " -f1 > /tmp/lastlogin30d
getent passwd {0..0} {1000..2000} |cut -d ":" -f1 > /tmp/localuserlist
NOTLOGIN30D=$(diff /tmp/lastlogin30d /tmp/localuserlist -n | grep -v "d1" | grep -v "a0" | grep -v "a1" | grep -v "a2" | grep -v "a3" | grep -v "a4" | paste -sd ",")

rm -f /tmp/passchange
rm -f /tmp/userstatus
PC=1
while [ $PC -le $LOCAL_USER_COUNT ]; do
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

rm -f /tmp/{localaccountlist,notloggeduserlist}
rm -f /tmp/{lastlogin30d,localuserlist,userstatus,activeusers,lockedusers,passchange,PasswordBilgileri,lastlogininfo}

CHECK_QUOTA
LVM_CRYPT
SYSLOG_INFO
SUDO_USER_LIST
NEVER_LOGGED_USERS
LOGIN_INFO
MEMORY_INFO

#-------------------------
# Create TXT Report File
#-------------------------
if [ -f "$RDIR/$HOST_NAME-lastcontrolreport.txt" ]; then
        rm $RDIR/$HOST_NAME-allreports.txt
fi

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
|Local User Count:  |$LOCAL_USER_COUNT
|Local User List:   |$USER_LIST
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
