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

if [ -d "$RDIR" ]; then
	rm -r $RDIR
fi
mkdir -p $RDIR

# LOCAL USERS
#grep -E "/bin/bash|/bin/zsh|/bin/sh" /etc/passwd | grep -v "/sbin/nologin" | grep -v "/bin/false" | cut -d":" -f1 > $RDIR/localusers
cat /etc/shadow | grep -v "*" | grep -v "!" | cut -d ":" -f1 > "$RDIR"/localusers
LOCAL_USER_COUNT=$(cat $RDIR/localusers | wc -l)
LOCAL_USER_LIST_FILE=$RDIR/localusers

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
LOCAL_DATE=$(timedatectl status | awk '/Local time:/ {print $3,$4,$5}')
TIME_ZONE=$(timedatectl status | awk -F ': ' '/Time zone:/ {print $2}') #TIME_SYNC=$(timedatectl |grep "synchronized:" |cut -d ":" -f2 | xargs)
TIME_SYNC=$(timedatectl status | awk '/synchronized:/ {print $4}')
HTTP_PROXY_USAGE=FALSE
{ env | grep -q "http_proxy"; } || { grep -q -e "export http" /etc/profile /etc/profile.d/*; } && HTTP_PROXY_USAGE=TRUE


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
        SYSLOG_INSTALL=Not_Installed
                if [ "$REP" = "APT" ]; then
                        dpkg -l | grep -q rsyslog && SYSLOG_INSTALL=Installed
                elif [ "$REP" = "YUM" ]; then
                        rpm -qa | grep -q rsyslog && SYSLOG_INSTALL=Installed
                fi

                if [ "$SYSLOG_INSTALL" = "Installed" ]; then
                        SYSLOG_SERVICE=INACTIVE
                        systemctl is-active rsyslog.service >/dev/null 2>&1 && SYSLOG_SERVICE=ACTIVE
                        SYSLOG_SOCKET=INACTIVE
                        systemctl is-active syslog.socket >/dev/null 2>&1 && SYSLOG_SOCKET=ACTIVE
                        SYSLOG_SEND=NO
                        grep -q "@" /etc/rsyslog.conf && SYSLOG_SEND=YES # ??? will check
                else
                        SYSLOG_SERVICE=NONE
                        SYSLOG_SOCKET=NONE
                        SYSLOG_SEND=NONE
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
    SUDO_USER_LIST=$(sort -u "$tmpfile" | paste -sd ",")
    rm -f "$tmpfile"
}

PASSWORD_EXPIRE_INFO() {
        rm -f $RDIR/passexpireinfo.txt
        PX=1
        while [ $PX -le $LOCAL_USER_COUNT ]; do
                USER_ACCOUNT_NAME=$(awk "NR==$PX" $LOCAL_USER_LIST_FILE)
                PASSEX=$(chage -l $USER_ACCOUNT_NAME |grep "Password expires" | awk '{print $4}')
                echo "$USER_ACCOUNT_NAME:$PASSEX" >> $RDIR/passexpireinfo.txt
                PX=$(( PX + 1 ))
        done
        PASSEXINFO=$(cat $RDIR/passexpireinfo.txt | paste -sd ",")
}

NEVER_LOGGED_USERS() {
        #cat /etc/shadow | grep -v "*" | grep -v "!" | cut -d ":" -f1 > $LOCAL_USER_LIST_FILE
        rm -f $RDIR/notloggeduserlist
        NL=1
        while [ $NL -le $LOCAL_USER_COUNT ]; do
                USER_ACCOUNT_NAME=$(awk "NR==$NL" $LOCAL_USER_LIST_FILE)
                lastlog | grep "Never logged in" | grep "$USER_ACCOUNT_NAME" >> $RDIR/notloggeduserlist
                NL=$(( NL + 1 ))
        done

        NOT_LOGGED_USER=$(cat $RDIR/notloggeduserlist | cut -d " " -f1 | paste -sd "@")
        rm $RDIR/notloggeduserlist
}

LOGIN_INFO() {
        rm -f $RDIR/lastlogininfo
        LL=1
        while [ "$LL" -le "$LOCAL_USER_COUNT" ]; do
                USER_ACCOUNT_NAME=$(ls -l |sed -n $LL{p} $LOCAL_USER_LIST_FILE)
                LOGIN_DATE=$(lslogins | grep "$USER_ACCOUNT_NAME" | xargs | cut -d " " -f6)
                LOGIN_DATE=$(lastlog | grep "$USER_ACCOUNT_NAME" | awk '{ print $4,$5,$6,$7 }')
                echo "$USER_ACCOUNT_NAME:$LOGIN_DATE" >> $RDIR/lastlogininfo
                LL=$(( LL + 1 ))
        done
        LAST_LOGIN_INFO=$(cat $RDIR/lastlogininfo | paste -sd ",")
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
        fi
done

CRAMFS=${module_statuses["cramfs"]}
FREEVXFS=${module_statuses["freevxfs"]}
JFFS2=${module_statuses["jffs2"]}
HFS=${module_statuses["hfs"]}
HFSPLUS=${module_statuses["hfsplus"]}
SQUASHFS=${module_statuses["squashfs"]}
UDF=${module_statuses["udf"]}

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
	rm $RDIR/runningservices.txt
fi

ACTIVE_CONN=$(netstat -s | awk '/active connection openings/ {print $1}')
PASSIVE_CONN=$(netstat -s | awk '/passive connection openings/ {print $1}')
FAILED_CONN=$(netstat -s | awk '/failed connection attempts/ {print $1}')
ESTAB_CONN=$(netstat -s | awk '/connections established/ {print $1}')
NOC=$(nproc --all)
LOAD_AVG=$(uptime | grep "load average:" | awk -F: '{print $5}')
ZO_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[Zz]' | wc -l)

SERVICE_USER_LIST=$(awk -F: '$2 == "*"' /etc/shadow | cut -d ":" -f1 | paste -sd ",")
BLANK_PASS_USER_LIST=$(awk -F: '$2 == "!*" { print $1 }' /etc/shadow | paste -sd ",")
LAST_LOGIN_00D=$(lastlog --time 1 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
LAST_LOGIN_07D=$(lastlog --time 7 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
LAST_LOGIN_30D=$(lastlog --time 30 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
NO_LOGIN_USER=$(awk -F: '$NF !~ "/(bash|sh)$" && $NF != "" {print $1}' /etc/passwd | wc -l)
LOGIN_AUTH_USER=$(awk -F: '$NF ~ "/bin/(ba)?sh$"{print $1}' /etc/passwd)

# NOTLOGIN USERLIST last 30 Day
lastlog --time 30 | grep -v "Username" | cut -d " " -f1 > $RDIR/lastlogin30d
getent passwd {0..0} {1000..2000} |cut -d ":" -f1 > $LOCAL_USER_LIST_FILE
NOT_LOGIN_30D=$(diff $RDIR/lastlogin30d $LOCAL_USER_LIST_FILE -n | grep -v "d1" | grep -v "a0" | grep -v "a1" | grep -v "a2" | grep -v "a3" | grep -v "a4" | paste -sd ",")

rm -f $RDIR/passchange
rm -f $RDIR/userstatus
PC=1
while [ $PC -le $LOCAL_USER_COUNT ]; do
    USER_ACCOUNT_NAME=$(awk "NR==$PC" $LOCAL_USER_LIST_FILE)
    PASS_CHANGE=$(lslogins "$USER_ACCOUNT_NAME" | grep "Password changed:" | awk ' { print $3 }')    # Password update date
    USERSTATUS=$(passwd -S "$USER_ACCOUNT_NAME" >> $RDIR/userstatus)                                 # user status information
    echo "$USER_ACCOUNT_NAME:$PASS_CHANGE" >> $RDIR/passchange
    PC=$(( PC + 1 ))
done

cat $RDIR/userstatus | grep "L" | cut -d " " -f1 > $RDIR/lockedusers
LOCKED_USERS=$(cat $RDIR/lockedusers | paste -sd ",")                                            # locked users
PASS_UPDATE_INFO=$(cat $RDIR/passchange | paste -sd ",")
rm $RDIR/lockedusers

USER_LIST
PASSWORD_EXPIRE_INFO
CHECK_QUOTA
LVM_CRYPT
SYSLOG_INFO
SUDO_USER_LIST
NEVER_LOGGED_USERS
LOGIN_INFO
MEMORY_INFO

clear
printf "%50s %s\n" "------------------------------------------------------"
$RED
printf "%50s %s\n" "                 LastControl Report                   " 
$NOCOL
printf "%50s %s\n" "------------------------------------------------------"
$CYAN
printf "%50s %s\n" "Hardware Inventory                                    " 
$NOCOL
printf "%50s %s\n" "------------------------------------------------------"
printf "%30s %s\n" "Hostname            :" "$HOST_NAME"
printf "%30s %s\n" "Internal IP Address :" "$INTERNAL_IP"
printf "%30s %s\n" "External IP Address :" "$EXTERNAL_IP"
printf "%30s %s\n" "Internet Connection :" "$INTERNET"
printf "%30s %s\n" "CPU Info            :" "$CPU_INFO"
printf "%30s %s\n" "Ram Info            :" "Total Ram: $RAM_TOTAL - Ram Usage: $RAM_USAGE"
printf "%30s %s\n" "VGA Info            :" "VGA: $GPU_INFO - VGA Ram: $GPU_RAM"
printf "%50s %s\n" "------------------------------------------------------"

#rm -f /tmp/{lastlogin30d,localuserlist,userstatus,activeusers,lockedusers,passchange,PasswordBilgileri,lastlogininfo}
rm -f "$RDIR"/{lastlogin30d,lastlogininfo,passchange,passexpireinfo.txt,userstatus}
rm -f "$RDIR"/lastlogininfo
rm -f "$RDIR"/passexpireinfo.txt
rm -f "$RDIR"/localusers

#-------------------------
# Create TXT Report File
#-------------------------
if [ -f "$RDIR/$HOST_NAME-allreports.txt" ]; then
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
|Date/Time Sync:    |Date:$LOCAL_DATE - System clock synchronized:$TIME_SYNC
|Timezone:          |$TIME_ZONE
|Proxy Usage:       |HTTP: $HTTP_PROXY_USAGE
|SYSLOG Usage:      |$SYSLOG_INSTALL | $SYSLOG_SERVICE | Socket: $SYSLOG_SOCKET | Send: $SYSLOG_SEND
--------------------------------------------------------------------------------------------------------------------------
|Ram  Usage:        |$RAM_USAGE_PERCENTAGE%
|Swap Usage:        |$SWAP_USAGE_PERCENTAGE%
|Disk Usage:        |$DISK_USAGE
|Out of Memory Logs |$OOM_LOGS
--------------------------------------------------------------------------------------------------------------------------
|Disk Quota Usage:  |Install: $QUOTA_INSTALL | Usr_Quota: $USR_QUOTA | Grp_Quota: $GRP_QUOTA | Mount: $MNT_QUOTA
|Disk Encrypt Usage:|Install: $CRYPT_INSTALL | Usage: $CRYPT_USAGE
|LVM Usage:         |$LVM_USAGE
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
|SUDO Users:        |$SUDO_USER_LIST
|Blank Pass. Users  |$BLANK_PASS_USER_LIST
|Locked Users       |$LOCKED_USERS
--------------------------------------------------------------------------------------------------------------------------
|Last Login Today   |$LAST_LOGIN_00D
|Last Login 7 Days  |$LAST_LOGIN_07D
|Last Login 30 Days |$LAST_LOGIN_30D
|Not Logged(30 Days)|$NOT_LOGIN_30D
|Last Login Info    |$LAST_LOGIN_INFO
|Never Logged Users |$NOT_LOGGED_USER
|Login Auth. Users  |$LOGIN_AUTH_USER
|NoLogin User Count |$NO_LOGIN_USER
--------------------------------------------------------------------------------------------------------------------------
|Pass. Expire Info  |$PASSEXINFO
|Pass. Update Info  |$PASS_UPDATE_INFO
--------------------------------------------------------------------------------------------------------------------------
|Service Users:     |$SERVICE_USER_LIST
--------------------------------------------------------------------------------------------------------------------------

EOF
