#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

RDIR=/usr/local/lastcontrol-reports
rm -r $RDIR
mkdir -p $RDIR

#############################
# determine distro
#############################
cat /etc/redhat-release > $RDIR/distrocheck || cat /etc/*-release > $RDIR/distrocheck || cat /etc/issue > $RDIR/distrocheck
grep -i "debian" $RDIR/distrocheck &> /dev/null && REP=APT
grep -i "ubuntu" $RDIR/distrocheck &> /dev/null && REP=APT
grep -i "centos" $RDIR/distrocheck &> /dev/null && REP=YUM
grep -i "rocky" $RDIR/distrocheck &> /dev/null && REP=YUM
grep -i "red hat" $RDIR/distrocheck &> /dev/null && REP=YUM
#cat /etc/*-release | grep "NAME=" | grep -v "PRETTY_NAME" | grep -v "CPE_NAME" | cut -d "=" -f2
rm $RDIR/distrocheck

DATE=$(date)
HOST_NAME=$(cat /etc/hostname)

#----------------------------
# INVENTORY
#----------------------------
INT_IPADDR=$(hostname -I)
EXT_IPADDR=$(curl -4 icanhazip.com)
CPUINFO=$(cat /proc/cpuinfo |grep "model name" |cut -d ':' -f2 > /tmp/cpuinfooutput.txt && tail -n1 /tmp/cpuinfooutput.txt > /tmp/cpuinfo.txt && rm /tmp/cpuinfooutput.txt && cat /tmp/cpuinfo.txt) && rm /tmp/cpuinfo.txt
RAM_TOTAL=$(free -m | head -2 | tail -1| awk '{print $2}')
GPU=$(lspci | grep VGA | cut -d ":" -f3);GPURAM=$(cardid=$(lspci | grep VGA |cut -d " " -f1);lspci -v -s $cardid | grep " prefetchable"| awk '{print $6}' | head -1)
VGA_CONTROLLER="'$GPU' '$GPURAM'"
DISK_LIST=$(fdisk -lu | grep "Disk" | grep -v "Disklabel" | grep -v "dev/loop" | grep -v "Disk identifier" | cut -d ":" -f1)
#----------------------------
# SYSTEM
#----------------------------
OS_KERNEL=$(uname -mrsv)
DISTRO=$(cat /etc/os-release |grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)
UPTIME=$(uptime) && UPTIME_MIN=$(awk '{ print "up " $1 /60 " minutes"}' /proc/uptime)
LASTBOOT=$(who -b | awk '{print $3,$4}')
VIRT_CONTROL=NONE
if [ -f "/dev/kvm" ]; then "$VIRT_CONTROL"=ON; fi
LOCALDATE=$(timedatectl | grep "Local time:" | awk '{print $3,$4,$5}')
TIMEZONE=$(timedatectl | grep "Time zone:" | cut -d ":" -f2 | xargs)
TIME_SYNC=$(timedatectl |grep "synchronized:" |cut -d ":" -f2 | xargs)
HTTP_PROXY_USAGE=FALSE
env |grep "http_proxy" >> /dev/null && HTTP_PROXY_USAGE=TRUE
grep -e "export http" /etc/profile |grep -v "#" >> /dev/null && HTTP_PROXY_USAGE=TRUE
grep -e "export http" /etc/profile.d/* |grep -v "#" >> /dev/null && HTTP_PROXY_USAGE=TRUE
SYSLOGINSTALL=Not_Installed
if [ "$REP" = "APT" ]; then
        dpkg -l |grep rsyslog >> /dev/null && SYSLOGINSTALL=Installed
fi
if [ "$REP" = "YUM" ]; then
        rpm -qa rsyslog >> /dev/null && SYSLOGINSTALL=Installed
fi

if [ "$SYSLOGINSTALL" = "Installed" ]; then
        SYSLOGSERVICE=INACTIVE
        systemctl status rsyslog.service |grep "active (running)" >> /dev/null && SYSLOGSERVICE=ACTIVE
        SYSLOGSOCKET=INACTIVE
        systemctl status syslog.socket |grep "active (running)" >> /dev/null && SYSLOGSOCKET=ACTIVE
        SYSLOGSEND=NO
        cat /etc/rsyslog.conf |grep "@" |grep -v "#" >> /dev/null && SYSLOGSEND=YES        #??? i will check it
fi
RAM_USAGE_PERCENTAGE=$(free |grep Mem |awk '{print $3/$2 * 100}' |cut -d "." -f1)
OOM=0
grep -i -r 'out of memory' /var/log/ &>/dev/null && OOM=1
if [ "$OOM" = "1" ]; then OOM_LOGS="Out of Memory Log Found !!"; fi
SWAP_USAGE_PERCENTAGE=$(free -m |grep Swap |awk '{print $3/$2 * 100}' |cut -d "." -f1)
DISK_USAGE=$(fdisk -lu | grep "Disk" | grep -v "Disklabel" | grep -v "dev/loop" | grep -v "Disk identifier")
QUOTA_INSTALL=Pass
if ! [ "$(command -v quotacheck)" ]; then
             QUOTA_INSTALL=Fail
fi
USR_QUOTA=Fail
grep -i "usrquota" /etc/fstab >> /dev/null && USR_QUOTA=Pass
GRP_QUOTA=Fail
grep -i "grpquota" /etc/fstab >> /dev/null && GRP_QUOTA=Pass
MNT_QUOTA=Fail
mount |grep "quota" >> /dev/null && MNT_QUOTA=Pass
LVM_USAGE=Fail
lsblk --output type |grep -w "lvm" && LVM_USAGE=Pass
CRYPT_INSTALL=Fail
if [ -x "$(command -v cryptsetup)" ]; then CRYPT_INSTALL=Pass; fi
CRYPT_USAGE=Fail
lsblk --output type |grep -w "crypt" && CRYPT_USAGE=Pass
rm -f /tmp/disklist.txt

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
DISTRO=$(cat /etc/os-release | grep PRETTY_NAME | cut -d '=' -f2 |cut -d '"' -f2)
KERNEL=$(uname -mrs)

######################
# Create TXT Report File
######################
rm $RDIR/$HOST_NAME.txt
cat > $RDIR/$HOST_NAME.txt << EOF
$HOST_NAME LastControl Report $DATE
=======================================================================================================================================================================
--------------------------------------------------------------------------------------------------------------------------
| INVENTORY
--------------------------------------------------------------------------------------------------------------------------
|Hostname:          |$HOST_NAME
|IP Address:        |$INT_IPADDR | $EXT_IPADDR
|Internet Conn.     |$INTERNET
|CPU:               |$CPUINFO
|RAM:               |Total:$RAM_TOTAL | Usage:$RAM_USAGE
|VGA:               |$VGA_CONTROLLER
|HDD:               |$DISK_LIST
--------------------------------------------------------------------------------------------------------------------------
| SYSTEM
--------------------------------------------------------------------------------------------------------------------------
|Operation System:  |$DISTRO
|Kernel Version:    |$OS_KERNEL
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
echo "|LISTENING SERVICE LIST" >> $RDIR/$HOST_NAME.txt
echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.txt
netstat -tl |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" >> $RDIR/$HOST_NAME.txt
echo "" >> $RDIR/$HOST_NAME.txt
echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.txt
echo "|ESTABLISHED SERVICE LIST" >> $RDIR/$HOST_NAME.txt
echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.txt
netstat -tn |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" |grep "ESTABLISHED" >> $RDIR/$HOST_NAME.txt
echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.txt
cat >> $RDIR/$HOST_NAME.txt << EOF
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

--------------------------------------------------------------------------------------------------------------------------
| UPDATE
--------------------------------------------------------------------------------------------------------------------------
|Update             |$SYSUPDATE_COUNT
|Install Package    |$INSTALLPACK
|BugFix Update      |$BUGFIX
|Sec. Updated       |$SECUPDATE_COUNT
|Critical Update    |$CRITICALPACKAGE
|High-Medium-Low    |$IMMUPDATE_COUNT - $MODERATEPACKAGE - $LOWPACKAGE
|Total Download     |$TOTALDOWNLOAD
--------------------------------------------------------------------------------------------------------------------------
EOF
