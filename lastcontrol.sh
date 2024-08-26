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
BLUE="tput setaf 12"
NOCOL="tput sgr0"
BOLD="tput bold"

PAUSE(){
local message="$@"
$GREEN
[ -z $message ] && message="Press Enter to continue"
read -p "$message" readEnterKey
echo -e
$NOCOL
}

SHOW_MENU(){
$GREEN
date
echo " -----------------------"
echo $SERVERTIME
$NOCOL
echo "   |-------------------|"
$BOLD
echo "   | LastControl TUI   |"
$NOCOL
echo "   |-------------------|"
$BOLD
echo "   | Add & Remove Host |"
$NOCOL
echo "   |-------------------|"
echo "   | 1.Add Host        |"
echo "   | 2.Remove Host     |"
echo "   | 3.Host List       |"
echo "   |-------------------|"
$WHITE
$BOLD
echo "     99.Exit   0.About"
echo -e
$NOCOL
}

SHOW_HELP() {
	clear
cat << EOF
Usage: $(basename "$0") [OPTION]

Options:
  --help, -h		Show this help message
  --report-localhost	It checks the server (local machine) you are running on
  --report-remotehost	It checks the remote server
  --report-allhost	Generates reports from all remote servers in Host List
  --server-install      Installs LastControl Server to perform remote server control
  --add-host            LastControl SSH Key is added to the server and included in the Host List
  --remove-host		LastControl SSH Key is deleted and removed from the Host list
  --host-list		List of Added Hosts
 --------------------------------------------
  --tui                 Text User Interface

Example:
bash lastcontrol.sh --report-localhost
bash lastcontrol.sh --server-install
bash lastcontrol.sh --report-remotehost [TARGETHOST] [PORTNUMBER]
bash lastcontrol.sh --report-allhost

bash lastcontrol.sh --tui
EOF
echo -e
}

HOST_NAME=$(cat /etc/hostname)
WDIR=/usr/local/lastcontrol
RDIR=/usr/local/lastcontrol/reports
CDIR=$(pwd)
WEB=/var/www/html
LCKEY=/root/.ssh/lastcontrol
LCKEYPUB=$(cat /root/.ssh/lastcontrol.pub | cut -d "=" -f2 | xargs)
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

CHECKRUN_ROOT() {
    $GREEN
    echo "Checking root user session"
    $NOCOL
    if ! [[ $EUID -eq 0 ]]; then
        $RED
        echo "This script must be run with root user"
        $NOCOL
        exit 1
    fi
}

CHECK_DISTRO() {
	cat /etc/*-release /etc/issue > "$RDIR/distrocheck"
	if grep -qi "debian\|ubuntu" "$RDIR/distrocheck"; then
		REP=APT
	elif grep -qi "centos\|rocky\|red hat" "$RDIR/distrocheck"; then
		REP=YUM
	fi
	rm $RDIR/distrocheck
	# Not support message
	if [ -z "$REP" ]; then
		$RED
		echo -e
		echo "--------------------------------------------------------------"
		echo -e "Repository could not be detected.\nThis distro is not supported",
		echo "--------------------------------------------------------------"
		echo -e
		$NOCOL
		exit 1
	fi
}

CHECK_UPDATE() {
	if [ "$REP" = "APT" ]; then
      UPDATE_OUTPUT=$(apt update 2>&1)
      if echo "$UPDATE_OUTPUT" | grep -qE "(Failed to fetch|Temporary failure resolving|Could not resolve|Some index files failed to download)"; then
          UPDATE_COUNT="Some errors occurred during apt update. Please check internet or repository access."
      else
          UPDATE_COUNT=$(apt list --upgradable | grep -v "Listing" | wc -l)
      fi
	fi
	if [ "$REP" = "YUM" ]; then
      UPDATE_OUTPUT=$(yum update -y 2>&1)
      if echo "$UPDATE_OUTPUT" | grep -qE "(Failed to download|Could not resolve host|Temporary failure in name resolution|No more mirrors to try)"; then
          UPDATE_COUNT="Some errors occurred during yum update. Please check internet or repository access."
      else
          UPDATE_COUNT=$(echo N | yum update | grep "Upgrade" | awk '{print $2}')
          INSTALL_COUNT=$(echo N | yum update | grep "Install" | grep -v "Installing"| awk '{print $2}')
          UPDATE_COUNT=$(expr $UPDATE_COUNT + $INSTALL_COUNT)
      fi
	fi
}

SYSTEM_REPORT() {
	if [ -d "$RDIR" ]; then
		rm -r $RDIR
	fi
	mkdir -p $RDIR
	
	# LOCAL USERS
	LOCALUSERS=$(mktemp)
	#grep -E "/bin/bash|/bin/zsh|/bin/sh" /etc/passwd | grep -v "/sbin/nologin" | grep -v "/bin/false" | cut -d":" -f1 > $LOCALUSERS
	cat /etc/shadow | grep -v "*" | grep -v "!" | cut -d ":" -f1 > $LOCALUSERS
	LOCAL_USER_COUNT=$(cat $LOCALUSERS | wc -l)
	LOCAL_USER_LIST_FILE=$LOCALUSERS
	LOGGED_USERS=$(w -hi)
	
	# HARDWARE INVENTORY
	INTERNAL_IP=$(hostname -I | cut -d " " -f1)
	EXTERNAL_IP=$(curl -4 icanhazip.com 2>/dev/null)
	CPU_INFO=$(awk -F ':' '/model name/ {print $2}' /proc/cpuinfo | head -n 1 | xargs)
	RAM_TOTAL=$(free -m | awk 'NR==2{print $2 " MB"}')
	RAM_USAGE=$(free -m | awk 'NR==2{print $3 " MB"}')
	GPU_INFO=$(lspci | grep -i vga | cut -d ':' -f3)
	GPU_RAM=$(lspci -v | awk '/ prefetchable/{print $6}' | head -n 1)
	DISK_LIST=$(lsblk -o NAME,SIZE -d -e 11,2 | tail -n +2 | grep -v "loop")
	###DISK_INFO=$(df -h --total | awk 'END{print}')
	###DISK_USAGE=$(fdisk -lu | grep "Disk" | grep -v "Disklabel" | grep -v "dev/loop" | grep -v "Disk identifier")
	DISK=$(lsblk | grep "disk" | awk {'print $1'})
	DISK_USAGE=$(df -lh | grep "$DISK" | awk {'print $5'})

	ping -c 1 google.com &> /dev/null && INTERNET="CONNECTED" || INTERNET="DISCONNECTED"
	
	# SYSTEM INFO
	KERNEL=$(uname -sr)
	DISTRO=$(grep PRETTY_NAME /etc/os-release | cut -d '"' -f2)
	UPTIME=$(uptime | xargs) && UPTIME_MIN=$(awk '{print "up", $1/60, "minutes"}' /proc/uptime)
	LAST_BOOT=$(uptime -s)
	VIRT_CONTROL=NONE
	[ -e "/dev/kvm" ] && VIRT_CONTROL=ON
	LOCAL_DATE=$(timedatectl status | awk '/Local time:/ {print $3,$4,$5}')
	TIME_ZONE=$(timedatectl status | awk -F ': ' '/Time zone:/ {print $2}') #TIME_SYNC=$(timedatectl |grep "synchronized:" |cut -d ":" -f2 | xargs)
	TIME_SYNC=$(timedatectl status | awk '/synchronized:/ {print $4}')
	HTTP_PROXY_USAGE=FALSE
	{ env | grep -q "http_proxy"; } || { grep -q -e "export http" /etc/profile /etc/profile.d/*; } && HTTP_PROXY_USAGE=TRUE
}

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
        RAM_USAGE_PERCENTAGE=$(free -m | grep Mem | awk '{ print $3/$2 * 100 }' | cut -d "." -f1)
	SWAP=$(free -m | grep Swap | awk '{ print $2 }')
	if [ "$SWAP" = 0 ]; then
		SWAP_USAGE_PERCENTAGE="Swap Not Configured"
	else
		SWAP_USAGE_PERCENTAGE=$(free -m | grep Swap | awk '{ print $3/$2 * 100 }' | cut -d "." -f1)
	fi
        OOM=0
        grep -i -r 'out of memory' /var/log/ &>/dev/null && OOM=1
        OOM_LOGS="None"
        if [ "$OOM" = "1" ]; then OOM_LOGS="Out of Memory Log Found !!"; fi
}

USER_ACCOUNTS_SETTINGS(){
	USRSETTINGS=$(mktemp)
	cat /etc/login.defs | grep "PASS_MAX_DAYS" | grep -v "Maximum number of days a password may be used." > $USRSETTINGS
	cat /etc/login.defs | grep "PASS_MIN_DAYS" | grep -v "Minimum number of days allowed between password changes." >> $USRSETTINGS
	cat /etc/login.defs | grep "PASS_MIN_LEN" | grep -v "Minimum acceptable password length." >> $USRSETTINGS
	cat /etc/login.defs | grep "PASS_WARN_AGE" | grep -v "Number of days warning given before a password expires." >> $USRSETTINGS
}

USER_LIST(){
    USER_LIST=$(paste -sd "," "$LOCAL_USER_LIST_FILE")
}

SUDO_USER_LIST(){
    SUDOUSERLIST=$(mktemp)
    getent group sudo | awk -F: '{print $4}' | tr ',' "\n" >> "$SUDOUSERLIST"
    cat /etc/sudoers | grep "ALL" | grep -v "%" | awk '{print $1}' >> "$SUDOUSERLIST"
    grep 'ALL' /etc/sudoers.d/* | cut -d":" -f2 | cut -d" " -f1 >> "$SUDOUSERLIST"
    sed -i '/root/d' $SUDOUSERLIST
    sed -i '/Defaults/d' $SUDOUSERLIST #for Centos,RHEL
    sed -i '/^$/d' $SUDOUSERLIST
    SUDO_USER_LIST=$(sort -u "$SUDOUSERLIST" | paste -sd ",")
    SUDO_USER_COUNT=$(wc -l $SUDOUSERLIST | cut -d " " -f1)
    rm -f "$SUDOUSERLIST"
}

USER_LOGINS() {
	SERVICE_USER_LIST=$(awk -F: '$2 == "*"' /etc/shadow | cut -d ":" -f1 | paste -sd ",")
	BLANK_PASS_USER_LIST=$(awk -F: '$2 == "!*" { print $1 }' /etc/shadow | paste -sd ",")
	LAST_LOGIN_00D=$(lastlog --time 1 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
	LAST_LOGIN_07D=$(lastlog --time 7 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
	LAST_LOGIN_30D=$(lastlog --time 30 |grep -v "Username" | awk '{ print $1}' | paste -sd ',')
	NO_LOGIN_USER=$(awk -F: '$NF !~ "/(bash|sh)$" && $NF != "" {print $1}' /etc/passwd | wc -l)
	LOGIN_AUTH_USER=$(awk -F: '$NF ~ "/bin/(ba)?sh$"{print $1}' /etc/passwd)
	
	# NOTLOGIN USERLIST last 30 Day
	LASTLOGIN30D=$(mktemp)
	lastlog --time 30 | grep -v "Username" | cut -d " " -f1 > $LASTLOGIN30D
	getent passwd {0..0} {1000..2000} |cut -d ":" -f1 > $LOCAL_USER_LIST_FILE
	NOT_LOGIN_30D=$(diff $LASTLOGIN30D $LOCAL_USER_LIST_FILE -n | grep -v "d1" | grep -v "a0" | grep -v "a1" | grep -v "a2" | grep -v "a3" | grep -v "a4" | paste -sd ",")
	rm $LASTLOGIN30D
	
	PASSCHANGE=$(mktemp)
	#USERSTATUS=$(mktemp)
	PC=1
	while [ $PC -le $LOCAL_USER_COUNT ]; do
		USER_ACCOUNT_NAME=$(awk "NR==$PC" $LOCAL_USER_LIST_FILE)
		PASS_CHANGE=$(lslogins "$USER_ACCOUNT_NAME" | grep "Password changed:" | awk ' { print $3 }')    # Password update date
		###USERSTATUS=$(passwd -S "$USER_ACCOUNT_NAME" >> $USERSTATUS)                                 # user status information
		echo "$USER_ACCOUNT_NAME:$PASS_CHANGE" >> $PASSCHANGE
		PC=$(( PC + 1 ))
	done
	
	#LOCKEDUSERS=$(mktemp)
	#cat $USERSTATUS | grep "L" | cut -d " " -f1 > $LOCKEDUSERS
	#LOCKED_USERS=$(cat $LOCKEDUSERS | paste -sd ",")                                            # locked users
	#PASS_UPDATE_INFO=$(cat $PASSCHANGE | paste -sd ",")
	#rm $LOCKEDUSERS

	rm $PASSCHANGE
	#rm $USERSTATUS
}

PASSWORD_EXPIRE_INFO() {
        #rm -f $RDIR/passexpireinfo.txt
	PASSEXPIREINFO=$(mktemp)
        PX=1
        while [ $PX -le $LOCAL_USER_COUNT ]; do
                USER_ACCOUNT_NAME=$(awk "NR==$PX" $LOCAL_USER_LIST_FILE)
                PASSEX=$(chage -l $USER_ACCOUNT_NAME |grep "Password expires" | awk '{print $4}')
                echo "$USER_ACCOUNT_NAME:$PASSEX" >> $PASSEXPIREINFO
                PX=$(( PX + 1 ))
        done
        PASSEXINFO=$(cat $PASSEXPIREINFO | paste -sd ",")
	rm $PASSEXPIREINFO
}

NEVER_LOGGED_USERS() {
        #cat /etc/shadow | grep -v "*" | grep -v "!" | cut -d ":" -f1 > $LOCAL_USER_LIST_FILE
	NOTLOGGEDUSERLIST=$(mktemp)
        NL=1
        while [ $NL -le $LOCAL_USER_COUNT ]; do
                USER_ACCOUNT_NAME=$(awk "NR==$NL" $LOCAL_USER_LIST_FILE)
                lastlog | grep "Never logged in" | grep "$USER_ACCOUNT_NAME" >> $NOTLOGGEDUSERLIST
                NL=$(( NL + 1 ))
        done
        NOT_LOGGED_USER=$(cat $NOTLOGGEDUSERLIST | cut -d " " -f1 | paste -sd "@")
        rm $NOTLOGGEDUSERLIST
}

LOGIN_INFO() {
	LASTLOGININFO=$(mktemp)
        LL=1
        while [ "$LL" -le "$LOCAL_USER_COUNT" ]; do
                USER_ACCOUNT_NAME=$(ls -l |sed -n $LL{p} $LOCAL_USER_LIST_FILE)
                LOGIN_DATE=$(lslogins | grep "$USER_ACCOUNT_NAME" | xargs | cut -d " " -f6)
                LOGIN_DATE=$(lastlog | grep "$USER_ACCOUNT_NAME" | awk '{ print $4,$5,$6,$7 }')
                echo "$USER_ACCOUNT_NAME:$LOGIN_DATE" >> $LASTLOGININFO
                LL=$(( LL + 1 ))
        done
        LAST_LOGIN_INFO=$(cat $LASTLOGININFO | paste -sd ",")
	rm $LASTLOGININFO
}

CHECK_KERNEL_MODULES() {
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
}

GRUB_CONTROL() {
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
}

DIRECTORY_CHECK() {
	# /tmp directory
        mount | grep -E '\s/tmp\s' > $RDIR/tmpmount.txt
        if [ "$?" = 0 ]; then
                TMPMOUNT=Pass
                egrep "size=" $RDIR/tmpmount.txt >> /dev/null && TMPSZIE=Pass
                egrep "noexec" $RDIR/tmpmount.txt >> /dev/null && TMPNOEXEC=Pass
        else
                TMPMOUNT=Fail
                TMPSIZE=Fail
                TMPNOEXEC=Fail
        fi
        rm -f $RDIR/tmpmount.txt
	
	# /var directory
	mount | grep -E '\s/var\s' >> /dev/null
	if [ "$?" = 0 ]; then
		VARMOUNT=Pass
	else
		VARMOUNT=Fail
	fi
	
	mount | grep -E '\s/var/tmp\s' >> /dev/null
	if [ "$?" = 0 ]; then
		VARTMPMOUNT=Pass
	else
		VARTMPMOUNT=Fail
	fi
	
	mount | grep -E '\s\/var\/log\s' >> /dev/null
	if [ "$?" = 0 ]; then
		VARLOGMOUNT=Pass
	else
		VARLOGMOUNT=Fail
	fi
}

REPOSITORY_CHECK() {
        if [ "$REP" = "APT" ]; then
                grep -hE '^\s*deb\s' /etc/apt/sources.list | grep -v '^#' | awk '{print $2}' > $RDIR/repositorylist.txt
                grep -hE '^\s*deb\s' /etc/apt/sources.list.d/* | grep -v '^#' | awk '{print $2}' >> $RDIR/repositorylist.txt
        elif [ "$REP" = "YUM" ]; then
                yum repolist all | grep enabled | awk '{print $1}' > $RDIR/repositorylist.txt
        fi
}

SERVICE_PROCESS(){
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
	#LOAD_AVG=$(uptime | grep "load average:" | awk -F: '{print $4}' | xargs)
	LOAD_AVG=$(uptime | grep "load average:"| xargs)
	RUNNING_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[R]' | wc -l)
	STOPPED_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[T]' | wc -l)
	SLEEPING_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[Ss]' | wc -l)
	ZOMBIE_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[Zz]' | wc -l) #ps aux | awk '$8 ~ /^[Zz]/' | wc -l
	IDLE_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[I]' | wc -l)    #ps aux | awk '$8 ~ /^[I]/' | wc -l
}

AUDIT() {
	#most used commands
	HISTORY_FILE=~/.bash_history
	if [ -f "$HISTORY_FILE" ]; then
		#MOST_COMMANDS=$(cat ~/.bash_history | awk '{cmd[$2]++} END {for(elem in cmd) {print cmd[elem] " " elem}}' | sort -n -r | head -20 | cut -d " " -f2 | paste -sd ",")
		if [ -f "$HISTORY_FILE" ]; then
			MOST_COMMANDS=$(cat $HISTORY_FILE | head -10 | paste -sd ",")
		else
			MOST_COMMANDS="bash_history file not found in ~/ directory"
		fi
	else
		MOST_COMMANDS="bash_history file not found in ~/ directory"
	fi
	# /etc directory change check
	ETC_CHANGE_FILE=$(mktemp)
	find /etc/ -type f -mtime -1 > $ETC_CHANGE_FILE
	ETC_CHANGE_COUNT=$(wc -l $ETC_CHANGE_FILE | awk {'print $1'})
	if [ "$ETC_CHANGE_COUNT" -gt 0 ]; then
		ETC_CHANGE="Found file changed in the /etc directory in last 24 hours"
	else
		ETC_CHANGE="There has been no change in the /etc directory in the last 24 hours"
	fi

	# Host Inventory change check
	if [ ! -f "$WDIR/hostinventory" ]; then
cat > $WDIR/hostinventory  << EOF
Host Name   :$HOST_NAME
Internel IP :$INTERNAL_IP
External IP :$EXTERNAL_IP
Disk List   :$DISK_LIST
Disk        :$DISK
EOF
		INVENTORY_CHANGE="CREATED"
	else
		HOST_INVENTORY=$(mktemp)
cat > $HOST_INVENTORY << EOF
Host Name   :$HOST_NAME
Internel IP :$INTERNAL_IP
External IP :$EXTERNAL_IP
Disk List   :$DISK_LIST
Disk        :$DISK
EOF
	fi

INVENTORY_DIFF_FILE=$(mktemp)
diff -qr "$WDIR/hostinventory" "$HOST_INVENTORY" > $INVENTORY_DIFF_FILE
INVENTORY_DIFF_COUNT=$(wc -l $INVENTORY_DIFF_FILE | awk {'print $1'})

if [ "$INVENTORY_DIFF_COUNT" -gt 0 ]; then
	INVENTORY_CHANGE="Host Hardware inventory has changed !!"
else
	INVENTORY_CHANGE="Host Hardware inventory host not change"
fi

rm $HOST_INVENTORY
rm $INVENTORY_DIFF_FILE 
rm $ETC_CHANGE_FILE
}

SSH_AUTH_LOGS() {
	echo "Accepted" >> $RDIR/$HOST_NAME-allreports.txt
	echo "------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	find /var/log -type f -exec sh -c "cat {} | egrep -i 'ssh'" \; | grep "Accepted" | tail -n 10 >> $RDIR/$HOST_NAME-allreports.txt
	echo "------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "Failed" >> $RDIR/$HOST_NAME-allreports.txt >> $RDIR/$HOST_NAME-allreports.txt
	echo "------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	find /var/log/ -type f -exec sh -c "cat {} | egrep -i 'ssh'" \; | grep "Failed" | tail -n 10 >> $RDIR/$HOST_NAME-allreports.txt
	# Debian,Ubuntu /var/log/auth.log
	# RHEL,Centos   /var/log/secure
}

NW_CONFIG_CHECK() {
	NWCHECK1=$(sysctl net.ipv4.ip_forward |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_FORWARD_CHECK="Fail" && ((NWRESULT++))
	if [ "$NWCHECK1" = 0 ]; then IPV4_FORWARD_CHECK="Pass" && ((NWRESULT--)); fi
	
	NWCHECK2=$(sysctl net.ipv4.conf.all.send_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_ALL_SEND_REDIRECTS="Fail" && ((NWRESULT++)) 
	if [ "$NWCHECK2" = 0 ]; then IPV4_ALL_SEND_REDIRECTS="Pass" && ((NWRESULT--)); fi
	
	NWCHECK3=$(sysctl net.ipv4.conf.all.accept_source_route |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_ALL_ACCEPT_SOURCE_ROUTE="Fail" && ((NWRESULT++))
	if [ "$NWCHECK3" = 0 ]; then IPV4_ALL_ACCEPT_SOURCE_ROUTE="Pass" && ((NWRESULT--)); fi
	
	NWCHECK4=$(sysctl net.ipv4.conf.default.accept_source_route |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE="Fail" && ((NWRESULT++))
	if [ "$NWCHECK4" = 0 ]; then IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE="Pass" && ((NWRESULT--)); fi
	
	NWCHECK5=$(sysctl net.ipv4.conf.all.accept_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_ALL_ACCEPT_REDIRECTS="Fail" && ((NWRESULT++))
	if [ "$NWCHECK5" = 0 ]; then IPV4_ALL_ACCEPT_REDIRECTS="Pass" && ((NWRESULT--)); fi
	
	NWCHECK6=$(sysctl net.ipv4.conf.default.accept_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_DEFAULT_ACCEPT_REDIRECTS="Fail" && ((NWRESULT++))
	if [ "$NWCHECK6" = 0 ]; then IPV4_DEFAULT_ACCEPT_REDIRECTS="Pass" && ((NWRESULT--)); fi

	NWCHECK7=$(sysctl net.ipv4.conf.all.secure_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_ALL_SECURE_REDIRECTS="Fail" && ((NWRESULT++))
	if [ "$NWCHECK7" = 0 ]; then IPV4_ALL_SECURE_REDIRECTS="Pass" && ((NWRESULT--)); fi

	NWCHECK8=$(sysctl net.ipv4.conf.default.secure_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_DEFAULT_SECURE_REDIRECTS="Fail" && ((NWRESULT++))
	if [ "$NWCHECK8" = 0 ]; then IPV4_DEFAULT_SECURE_REDIRECTS="Pass" && ((NWRESULT--)); fi

	NWCHECK9=$(sysctl net.ipv4.icmp_echo_ignore_broadcasts |cut -d "=" -f2 |cut -d " " -f2)
	ICMP_IGNORE_BROADCASTS="Fail" && ((NWRESULT++))
	if [ "$NWCHECK9" = 1 ]; then ICMP_IGNORE_BROADCASTS="Pass" && ((NWRESULT--)); fi

	NWCHECK10=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses |cut -d "=" -f2 |cut -d " " -f2)
	ICMP_IGNORE_BOGUS_ERROR="Fail" && ((NWRESULT++))
	if [ "$NWCHECK10" = 1 ]; then ICMP_IGNORE_BOGUS_ERROR="Pass" && ((NWRESULT--)); fi

	NWCHECK11=$(sysctl net.ipv4.conf.all.rp_filter |cut -d "=" -f2 |cut -d " " -f2)
	ALL_RP_FILTER="Fail" && ((NWRESULT++))
	if [ "$NWCHECK11" = 1 ]; then ALL_RP_FILTER="Pass" && ((NWRESULT--)); fi

	NWCHECK12=$(sysctl net.ipv4.tcp_syncookies |cut -d "=" -f2 |cut -d " " -f2)
	TCP_SYNCOOKIES="Fail" && ((NWRESULT++))
	if [ "$NWCHECK12" = 1 ]; then TCP_SYNCOOKIES="Pass" && ((NWRESULT--)); fi

	NWCHECK13=$(sysctl net.ipv6.conf.all.disable_ipv6 |cut -d "=" -f2 |cut -d " " -f2)
	DISABLE_IPV6="Fail" && ((NWRESULT++))
	if [ "$NWCHECK13" = 1 ]; then DISABLE_IPV6="Pass" && ((NWRESULT--)); fi

	NWCHECK14=$(sysctl net.ipv6.conf.all.accept_ra |cut -d "=" -f2 |cut -d " " -f2)
	IPV6_ALL_ACCEPT_RA="Fail" && ((NWRESULT++))
	if [ "$NWCHECK14" = 1 ]; then IPV6_ALL_ACCEPT_RA="Pass" && ((NWRESULT--)); fi
}

SSH_CONFIG_CHECK() {
	# PRIVATE HOST KEY
	SSHCHECK1=$(stat /etc/ssh/sshd_config |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	SSHD_ACL="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK1" = 0600 ]; then SSHD_ACL="Pass" && ((SSHRESULT--)); fi
	SSHCHECK2=$(stat /etc/ssh/ssh_host_rsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	RSAKEY_ACL="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK2" = 0600 ]; then RSAKEY_ACL="Pass" && ((SSHRESULT--)); fi
	SSHCHECK3=$(stat /etc/ssh/ssh_host_ecdsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	ECDSAKEY_ACL="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK3" = 0600 ]; then ECDSAKEY_ACL="Pass" && ((SSHRESULT--)); fi
	SSHCHECK4=$(stat /etc/ssh/ssh_host_ed25519_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	ED25519KEY_ACL="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK4" = 0600 ]; then ED25519KEY_ACL="Pass" && ((SSHRESULT--)); fi
	# PUBLIC HOST KEY
	SSHCHECK5=$(stat /etc/ssh/ssh_host_rsa_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	RSAKEYPUB_ACL="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK5" = 0644 ]; then RSAKEYPUB_ACL="Pass" && ((SSHRESULT--)); fi
	SSHCHECK6=$(stat /etc/ssh/ssh_host_ed25519_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	ED25519PUB_ACL="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK6" = 0644 ]; then ED25519PUB_ACL="Pass" && ((SSHRESULT--)); fi
	grep ^Protocol /etc/ssh/sshd_config >> /dev/null
	PROTOCOL2="Fail" && ((SSHRESULT++))
	if [ "$?" = 0 ]; then PROTOCOL2="Pass" && ((SSHRESULT--)); fi
	SSHCHECK7=$(sshd -T | grep loglevel |cut -d " " -f2)
	LOGLEVEL="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK7" = INFO ]; then LOGLEVEL="Pass" && ((SSHRESULT--)); fi
	SSHCHECK8=$(sshd -T | grep x11forwarding |cut -d " " -f2)
	X11FORWARD="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK8" = no ]; then X11FORWARD="Pass" && ((SSHRESULT--)); fi
	SSHCHECK9=$(sshd -T | grep maxauthtries |cut -d " " -f2)
	MAXAUTHTRIES="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK9" -lt 4 ]; then MAXAUTHTRIES="Pass" && ((SSHRESULT--)); fi
	SSHCHECK10=$(sshd -T | grep ignorerhosts |cut -d " " -f2)
	IGNORERHOST="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK10" = yes ]; then IGNORERHOST="Pass" && ((SSHRESULT--)); fi
	SSHCHECK11=$(sshd -T | grep hostbasedauthentication |cut -d " " -f2)
	HOSTBASEDAUTH="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK11" = no ]; then HOSTBASEDAUTH="Pass" && ((SSHRESULT--)); fi
	SSHCHECK12=$(sshd -T | grep permitrootlogin |cut -d " " -f2)
	ROOTLOGIN="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK12" = no ]; then ROOTLOGIN="Pass" && ((SSHRESULT--)); fi
	SSHCHECK13=$(sshd -T | grep permitemptypasswords |cut -d " " -f2)
	EMPTYPASS="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK13" = no ]; then EMPTYPASS="Pass" && ((SSHRESULT--)); fi
	SSHCHECK14=$(sshd -T | grep permituserenvironment |cut -d " " -f2)
	PERMITUSERENV="Fail" && ((SSHRESULT++))
	if [ "$SSHCHECK14" = no ]; then PERMITUSERENV="Pass" && ((SSHRESULT--)); fi
}

SUIDGUID_FILE_CHECK() {
	STICKYBIT_FILE=$(mktemp)
        find / -perm /1000 &> /dev/null > $STICKYBIT_FILE
        STICKYBITCOUNT=$(wc -l $STICKYBIT_FILE | awk {'print $1'})
	rm $STICKYBIT_FILE

	SUID_FILE=$(mktemp)
	find / -perm /2000 &> /dev/null $SUID_FILE
	SUIDCOUNT=$(wc -l $SUID_FILE | awk {'print $1'})
	rm $SUID_FILE
	
	GUID_FILE=$(mktemp)
	find / -perm /4000 &> /dev/null > $GUID_FILE
	GUIDCOUNT=$(wc -l $GUID_FILE | awk {'print $1'})
	rm $GUID_FILE

	SUIDGUID_FILE=$(mktemp)	
	find / -perm /6000 &>/dev/null > $SUIDGUID_FILE
	SUIDGUIDCOUNT=$(wc -l $SUIDGUID_FILE | awk {'print $1'})
	rm $SUIDGUID_FILE
}

LAST_INSTALL() {
	if [ "$REP" = "APT" ]; then
		#LASTINSTALL=$(tail -n 100 /var/log/dpkg.log | grep "installed" | grep -v "half-installed")
		LASTINSTALL=$(mktemp)
		tail -n 100 /var/log/dpkg.log | grep "installed" | grep -v "half-installed" > $LASTINSTALL
	fi
	if [ "$REP" = "YUM" ]; then
		LASTINSTALL=$(mktemp)
		yum history > $LASTINSTALL
	fi
}

ABOUT_HOST() {
	echo "------------------------------------------------------" > $RDIR/$HOST_NAME-abouthost.txt 
	echo "About of $HOST_NAME" >> $RDIR/$HOST_NAME-abouthost.txt
	echo "------------------------------------------------------" >> $RDIR/$HOST_NAME-abouthost.txt 
	echo -e
	if [ "$NWRESULT" -gt 0 ]; then
		echo "	- Network Configuration [X]" >> $RDIR/$HOST_NAME-abouthost.txt
        else
		echo "	- Network Configuration [V]" >> $RDIR/$HOST_NAME-abouthost.txt
	fi
	if [ "$SSHRESULT" -gt 0 ]; then
		echo "	- SSH Configuration [X]" >> $RDIR/$HOST_NAME-abouthost.txt
        else
		echo "	- SSH Configuration [V]" >> $RDIR/$HOST_NAME-abouthost.txt
	fi
	if [ "$SUDO_USER_COUNT" -gt 0 ]; then
		echo "	- SUDO authorized user accounts found [I]" >> $RDIR/$HOST_NAME-abouthost.txt
        else                                                         
		echo "	- Only authorized user is the root account [I]" >> $RDIR/$HOST_NAME-abouthost.txt
	fi
	if [ "$UPDATE_COUNT" -gt 0 ]; then
		echo "	- Update Found [I]" >> $RDIR/$HOST_NAME-abouthost.txt
	fi
	if [ "$ZOMBIE_PROCESS" -gt 0 ]; then
		echo "  - Zombie process found [!]" >> $RDIR/$HOST_NAME-abouthost.txt
	fi
	if [ "$STOPPED_PROCESS" -gt 0 ]; then
		echo "  - Stopped process found [!]" >> $RDIR/$HOST_NAME-abouthost.txt
	fi
	if [ "$OOM" = "1" ]; then
		$BLUE
		echo "	Out of Memory Log Found [I]"
		$NOCOL
	fi
	if [ "$ETC_CHANGE_COUNT" -gt 0 ]; then
		$BLUE
		echo "	Found file changed in the /etc directory in last 24 hours [I]"
		$NOCOL
	fi
	if [ "$INVENTORY_DIFF_COUNT" -gt 0 ]; then
		$BLUE
		echo "	Host Hardware inventory has changed [I]"
		$NOCOL
	fi
	echo -e
	echo "------------------------------------------------------" >> $RDIR/$HOST_NAME-abouthost.txt
	echo -e
}

APP_LIST() {
        APPLIST=$(mktemp)
        for appslist in /usr/share/applications/*.desktop; do
                sed -ns '/^\[Desktop Entry\]/,/^\[/{/^Name=/p;/^Exec=/h};${z;x;G;p}' "$appslist" | \
                grep -v "/usr/share/applications/" | \
                sed '/^Name=/ s/./- &/' | \
                sed '/^\s*$/d' >> "$APPLIST"
        done
}

SHOW_ABOUT_HOST() {
#	cat $RDIR/$HOST_NAME-abouthost.txt
	#clear
	echo "------------------------------------------------------"
	$MAGENTA
	echo "About of $HOST_NAME                                   "  
	$NOCOL
	echo "------------------------------------------------------"
	echo -e
	if [ "$NWRESULT" -gt 0 ]; then
	$RED
	echo "	Network Configuration [X]"
	$NOCOL
        else
	       $GREEN
	       echo "	Network Configuration [V]"
	       $NOCOL
	fi
	if [ "$SSHRESULT" -gt 0 ]; then
	       $RED
	       echo "	SSH Configuration [X]"
	       $NOCOL
        else
	       $GREEN
	       echo "	SSH Configuration [V]"
	       $NOCOL
	fi
	if [ "$SUDO_USER_COUNT" -gt 0 ]; then
                $BLUE
                echo "	SUDO authorized user accounts found [I]"
                $NOCOL                                               
        else                                                         
		$BLUE                                                
		echo "	Only authorized user is the root account [I]"
		$NOCOL                                               
	fi
	if [ "$UPDATE_COUNT" -gt 0 ]; then
		$YELLOW
                echo "	Update Found [I]"
		$NOCOL
        fi
	if [ "$ZOMBIE_PROCESS" -gt 0 ]; then
		$BLUE
                echo "  Zombie process found [!]"
		$NOCOL
        fi
        if [ "$STOPPED_PROCESS" -gt 0 ]; then
		$BLUE
                echo "  - Stopped process found [!]"
		$NOCOL
        fi
	if [ "$OOM" = "1" ]; then
		$BLUE
		echo "	Out of Memory Log Found [I]"
		$NOCOL
	fi
	if [ "$ETC_CHANGE_COUNT" -gt 0 ]; then
		$BLUE
		echo "	Found file changed in the /etc directory in last 24 hours [I]"
		$NOCOL
	fi
	if [ "$INVENTORY_DIFF_COUNT" -gt 0 ]; then
		$BLUE
		echo "	Host Hardware inventory has changed [I]"
		$NOCOL
	fi
	$NOCOL
	echo -e
	echo "------------------------------------------------------"
	$CYAN
	$BOLD
	echo -e
	printf "%10s %s\n" "For Detailed Report:"
	$NOCOL
	printf "%10s %s\n" "$RDIR/$HOST_NAME-allreports.txt"
	$CYAN
	$BOLD
	printf "%0s %s\n" "Web:"
	$NOCOL
	printf "%10s %s\n" "http://$INTERNAL_IP"
	printf "%10s %s\n" "------------------------------------------------------"
	echo -e
}

ADD_HOST() {
	if [ -z "$2" ] || [ -z "$3" ]; then
		read -p "Enter the Machine Hostname and SSH Port (Example:ServerName 22): " TARGETMACHINE PORTNUMBER
	else
		TARGETMACHINE="$2"
		PORTNUMBER="$3"
	fi
	if [ -z "$TARGETMACHINE" ] || [ -z "$PORTNUMBER" ]; then
		$RED
		printf "    %s\n" "Server Name or Port Number is missing - Example:ServerName 22"
		$NOCOL
		exit 1
	fi
	CONN=FALSE && nc -z -w 2 $TARGETMACHINE $PORTNUMBER 2>/dev/null && CONN=TRUE
	if [ "$CONN" = "TRUE" ]; then
		LISTED=FALSE
		ack "$TARGETMACHINE" $WDIR/linuxmachine >> /dev/null && LISTED=TRUE
		if [ "$LISTED" = "FALSE" ]; then
			ssh-copy-id -fi $LCKEY.pub -o "StrictHostKeyChecking no" root@$TARGETMACHINE
			$GREEN
			printf "    %s\n" "TaliaOppy SSH Key added to $TARGETMACHINE"
			$NOCOL
			echo "$TARGETMACHINE $PORTNUMBER" >> $WDIR/linuxmachine
			$GREEN
			printf "    %s\n" "$TARGETMACHINE added to Machine List"
			$NOCOL
			echo -e
		elif [ "$LISTED" = "TRUE" ]; then
			$RED
			printf "    %s\n" "$TARGETMACHINE already exist"
			$NOCOL
			echo -e
		fi
		elif [ "$CONN" = "FALSE" ]; then
			$RED
			printf "    %s\n" "Could not reach $TARGETMACHINE from Port $PORTNUMBER"
			$NOCOL
			echo -e
	else
		printf "    %s\n" "$TARGETMACHINE could not be controlled from Port $PORTNUMBER"
	fi
	PAUSE
}

REMOVE_HOST() {
	if [ -z "$2" ]; then
                read -p "Enter the Machine Hostname : " TARGETMACHINE
	else
                TARGETMACHINE="$2"
        fi
        if [ -z "$TARGETMACHINE" ]; then
                $RED
                printf "    %s\n" "Server Name is missing"
                $NOCOL
                exit 1
        fi
        LISTED=FALSE
        ack "$TARGETMACHINE" $WDIR/linuxmachine >> /dev/null && LISTED=TRUE
        if [ "$LISTED" = "TRUE" ]; then
                PORTNUMBER=$(ack "$TARGETMACHINE" $WDIR/linuxmachine | cut -d " " -f2)
                CONN=FALSE && nc -z -w 2 $TARGETMACHINE $PORTNUMBER 2>/dev/null && CONN=TRUE
                if [ "$CONN" = "TRUE" ]; then
                        CONTINUE=FALSE
                        ssh -p22 -i $LCKEY -o "StrictHostKeyChecking no" root@$TARGETMACHINE -- sed -i "/$LCKEYPUB/d" /root/.ssh/authorized_keys && CONTINUE=TRUE
                        if [ "$CONTINUE" = "TRUE" ]; then
                                echo -e
                                $GREEN
                                printf "    %s\n" "TaliaOppy SSH Key has been removed on $TARGETMACHINE"
                                $NOCOL
                                sed -i "/$TARGETMACHINE/d" $WDIR/linuxmachine
                                echo -e
                                $CYAN
                                echo "::. Host List ::."
                                echo "--------------------"
                                $NOCOL
                                cat $WDIR/linuxmachine
                                $CYAN
                                echo "--------------------"
                                $NOCOL
                                echo -e
                                $GREEN
                                printf "    %s\n" "Info: $TARGETMACHINE removed from Machine List"
                                $NOCOL
                                echo -e
                                #elif [ "$CONTINUE" = "FALSE" ]; then
                                #$RED
                                #echo "Failed removed to $TARGETMACHINE"
                                #echo "$?"
                                #$NOCOL
                                #echo -e
                        elif [ "$CONTINUE" = "FALSE" ] || [ -z "$CONTINUE" ]; then
                                $RED
                                printf "    %s\n" "Could not remove TaliaOppy SSH Key from $TARGETMACHINE"
                                $NOCOL
                                echo -e
                        fi
                elif [ "$CONN" = "FALSE" ]; then
                        $RED
                        printf "    %s\n" "Could not reach $TARGETMACHINE from Port $PORTNUMBER"
                        $NOCOL
                        echo -e
                fi
        elif [ "$LISTED" = "FALSE" ]; then
                $RED
                printf "    %s\n" "The $TARGETMACHINE was not found in the Machine list"
                $NOCOL
                echo -e
        fi
        echo -e
        PAUSE
}

HOST_LIST() {
        echo ""
        $CYAN
        echo "::. Host List ::."
        echo "--------------------"
        $NOCOL
        cat $WDIR/linuxmachine
        $CYAN
        echo "--------------------"
        $NOCOL
        echo ""
        PAUSE
        ##exit 0
}

CREATE_REPORT_TXT() {
	if [ -f "$RDIR/$HOST_NAME-allreports.txt" ]; then
		rm $RDIR/$HOST_NAME-allreports.txt
	fi

cat > $RDIR/$HOST_NAME-allreports.txt << EOF
$HOST_NAME LastControl All Controls Report $DATE
=======================================================================================================================================================================
--------------------------------------------------------------------------------------------------------------------------
| HARDWARE INVENTORY
--------------------------------------------------------------------------------------------------------------------------
|Hostname            |$HOST_NAME
|IP Address          |$INTERNAL_IP | $EXTERNAL_IP
|Internet Conn.      |$INTERNET
|CPU                 |$CPU_INFO
|RAM                 |Total:$RAM_TOTAL | Ram Usage: $RAM_USAGE
|GPU / VGA           |VGA: $GPU_INFO   | VGA Ram: $GPU_RAM 
|DISK LIST           |$DISK_LIST
--------------------------------------------------------------------------------------------------------------------------
| SYSTEM INFORMATION
--------------------------------------------------------------------------------------------------------------------------
|Operation System    |$DISTRO
|Kernel Version      |$KERNEL
|Uptime              |$UPTIME | $UPTIME_MIN
|Last Boot           |$LAST_BOOT
|Virtualization      |$VIRT_CONTROL
|Date/Time Sync      |Date:$LOCAL_DATE - System clock synchronized:$TIME_SYNC
|Timezone            |$TIME_ZONE
|Proxy Usage         |HTTP: $HTTP_PROXY_USAGE
|SYSLOG Usage        |$SYSLOG_INSTALL | $SYSLOG_SERVICE | Socket: $SYSLOG_SOCKET | Send: $SYSLOG_SEND
--------------------------------------------------------------------------------------------------------------------------
|Ram  Usage          |$RAM_USAGE_PERCENTAGE%
|Swap Usage          |$SWAP_USAGE_PERCENTAGE%
|Disk Usage          |$DISK_USAGE
|Out of Memory Logs  |$OOM_LOGS
--------------------------------------------------------------------------------------------------------------------------
|Disk Quota Usage    |Install: $QUOTA_INSTALL | Usr_Quota: $USR_QUOTA | Grp_Quota: $GRP_QUOTA | Mount: $MNT_QUOTA
|Disk Encrypt Usage  |Install: $CRYPT_INSTALL | Usage: $CRYPT_USAGE
|LVM Usage           |$LVM_USAGE
--------------------------------------------------------------------------------------------------------------------------
| Update Count       |$UPDATE_COUNT
--------------------------------------------------------------------------------------------------------------------------
| Kernel Modules
--------------------------------------------------------------------------------------------------------------------------
|CRAMFS              |$CRAMFS
|FREEVXFS            |$FREEVXFS
|JFFS2               |$JFFS2
|HFS                 |$HFS
|HFSPLUS             |$HFSPLUS
|SQUASHFS            |$SQUASHFS
|UDF                 |$UDF
--------------------------------------------------------------------------------------------------------------------------
|GRUB                |$GRUB_PACKAGE
|GRUB Security       |$GRUB_SEC
--------------------------------------------------------------------------------------------------------------------------
| DIRECTORY CONFIG
--------------------------------------------------------------------------------------------------------------------------
|/tmp Dir Mount      |$TMPMOUNT
|/tmp Size Config    |$TMPSIZE
|/tmp Exec Config    |$TMPNOEXEC
|/var Dir Mount      |$VARMOUNT
|/var/tmp Dir Mount  |$VARTMPMOUNT
|/var/log Dir Mount  |$VARLOGMOUNT
--------------------------------------------------------------------------------------------------------------------------
| SERVICES & PROCESSES
--------------------------------------------------------------------------------------------------------------------------
|Service Management  |$SERVICE_MANAGER
|Running Service     |$RUNNING_SERVICE
|Loaded Service      |$LOADED_SERVICE
--------------------------------------------------------------------------------------------------------------------------
|Active Connection   |$ACTIVE_CONN
|Passive Connection  |$PASSIVE_CONN
|Failed Connection   |$FAILED_CONN
|Established Conn.   |$ESTAB_CONN
---------------------------------------------------------------------------------------------------------------------------
|Number of CPU       |$NOC
|Load Avarage        |$LOAD_AVG
---------------------------------------------------------------------------------------------------------------------------
|Running  Process    |$RUNNING_PROCESS
|Stopped  Process    |$STOPPED_PROCESS
|Sleeping Process    |$SLEEPING_PROCESS
|Zombie   Process    |$ZOMBIE_PROCESS
|Idle     Process    |$IDLE_PROCESS
-------------------------------------------------------------------------------------------------------------------------
| Network Config
-------------------------------------------------------------------------------------------------------------------------
|IPv4 IP Forward Check                    |$IPV4_FORWARD_CHECK"
|IPv4 All Send Redirects Check            |$IPV4_ALL_SEND_REDIRECTS"
|IPv4 All Accept Source Route Check       |$IPV4_ALL_ACCEPT_SOURCE_ROUTE"
|IPv4 Default Accept Source Route Check   |$IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE"
|IPv4 All Accept Redirects Check          |$IPV4_ALL_ACCEPT_REDIRECTS"
|IPv4 Default Accept Redirects Check      |$IPV4_DEFAULT_ACCEPT_REDIRECTS"
|IPv4 All Secure Redirects Check          |$IPV4_ALL_SECURE_REDIRECTS"
|IPv4 Default Secure Redirects Check      |$IPV4_DEFAULT_SECURE_REDIRECTS"
|IPv4 ICMP Echo Ignore Broadcasts Check   |$ICMP_IGNORE_BROADCASTS"
|IPv4 ICMP Ignore Bogus Error Resp. Check |$ICMP_IGNORE_BOGUS_ERROR"
|IPv4 ALL RP Filter Check                 |$ALL_RP_FILTER"
|IPV4 TCP SynCookies Check                |$TCP_SYNCOOKIES"
|IPv6 Disable IPv6 Check                  |$DISABLE_IPV6"
|IPv6 All Accept Ra Check                 |$IPV6_ALL_ACCEPT_RA"
-------------------------------------------------------------------------------------------------------------------------
| SSH Config
-------------------------------------------------------------------------------------------------------------------------
|SSHD Config File ACL Check               |$SSHD_ACL"
|ECDSA Public Key ACL Check               |$ECDSAKEY_ACL"
|RSA Public Key ACL Check                 |$RSAKEYPUB_ACL"
|RSA Private Key ACL Check                |$RSAKEY_ACL"
|ED25519 Public Key ACL Check             |$ED25519PUB_ACL"
|ED25519 Private Key ACL Check            |$ED25519KEY_ACL"
|Protocol2 Usage Check                    |$PROTOCOL2"
|Log Level (info) Check                   |$LOGLEVEL"
|X11 Forwarding Check                     |$X11FORWARD"
|Max. Auth Tries Check                    |$MAXAUTHTRIES"
|Ignorer Host Check                       |$IGNORERHOST"
|Host Based Authentication                |$HOSTBASEDAUTH"
|Permit Root Login                        |$ROOTLOGIN"
|Permit Empty Password                    |$EMPTYPASS"
|Permit User Environment                  |$PERMITUSERENV"
--------------------------------------------------------------------------------------------------------------------------
| USERS
--------------------------------------------------------------------------------------------------------------------------
|Local User Count    |$LOCAL_USER_COUNT
|Local User List     |$USER_LIST
|SUDO Users          |$SUDO_USER_LIST
|Blank Pass. Users   |$BLANK_PASS_USER_LIST
|Locked Users        |$LOCKED_USERS
--------------------------------------------------------------------------------------------------------------------------
|Logged Users        |$LOGGED_USERS
--------------------------------------------------------------------------------------------------------------------------
|Last Login Today    |$LAST_LOGIN_00D
|Last Login 7 Days   |$LAST_LOGIN_07D
|Last Login 30 Days  |$LAST_LOGIN_30D
|Not Logged(30 Days) |$NOT_LOGIN_30D
|Last Login Info     |$LAST_LOGIN_INFO
|Never Logged Users  |$NOT_LOGGED_USER
|Login Auth. Users   |$LOGIN_AUTH_USER
|NoLogin User Count  |$NO_LOGIN_USER
--------------------------------------------------------------------------------------------------------------------------
|Pass. Expire Info   |$PASSEXINFO
|Pass. Update Info   |$PASS_UPDATE_INFO
--------------------------------------------------------------------------------------------------------------------------
|Service Users       |$SERVICE_USER_LIST
--------------------------------------------------------------------------------------------------------------------------
SUID - GUID - STICKY BIT
--------------------------------------------------------------------------------------------------------------------------
STICKY BIT           |$STICKYBITCOUNT
SUID		     |$SUIDCOUNT
GUID	             |$GUIDCOUNT
SUID-GUID            |$SUIDGUIDCOUNT
--------------------------------------------------------------------------------------------------------------------------
/etc Change Check    |$ETC_CHANGE - Number of changed files: $ETC_CHANGE_COUNT
Host Inventory Check |$INVENTORY_CHANGE - Number of changed inventory info: $INVENTORY_DIFF_COUNT
--------------------------------------------------------------------------------------------------------------------------

EOF

	echo "| DEFAULT USER ACCOUNTS SETTINGS" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	cat $USRSETTINGS >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "" >> $RDIR/$HOST_NAME-allreports.txt
	
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "| REPOSITORY LIST" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	cat $RDIR/repositorylist.txt >> $RDIR/$HOST_NAME-allreports.txt && rm $RDIR/repositorylist.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "" >> $RDIR/$HOST_NAME-allreports.txt
	
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "| LAST INSTALLED PACKAGES" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	cat $LASTINSTALL >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "" >> $RDIR/$HOST_NAME-allreports.txt
	
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|LISTENING SERVICE and PORT LIST" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	#netstat -tl |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" >> $RDIR/$HOST_NAME-allreports.txt
	lsof -nP -iTCP -sTCP:LISTEN | grep -v "IPv6" >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "" >> $RDIR/$HOST_NAME-allreports.txt
	
	echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|ESTABLISHED SERVICE LIST" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	netstat -tn |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" |grep "ESTABLISHED" >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "" >> $RDIR/$HOST_NAME-allreports.txt
	
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|MOST USAGE COMMANDS|" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo $MOST_COMMANDS >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "" >> $RDIR/$HOST_NAME-allreports.txt

	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|SSH Auth. Logs (Last 10 Record) |" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	SSH_AUTH_LOGS >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
        echo "" >> $RDIR/$HOST_NAME-allreports.txt
        echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
        echo "|Application List |" >> $RDIR/$HOST_NAME-allreports.txt
        echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
        cat $APPLIST >> $RDIR/$HOST_NAME-allreports.txt
	rm $APPLIST
        echo ""
        echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	
	cp $RDIR/$HOST_NAME-allreports.txt $WEB/reports
}

REPORT_ALLHOST() {
	clear
	HOSTLIST=$(cat $WDIR/linuxmachine | wc -l)
	i=1
	while [ "$i" -le $HOSTLIST ]; do
		HOST=$(ls -l | sed -n $i{p} $WDIR/linuxmachine)
		HNAME=$(echo $HOST | cut -d " " -f1)
		PNAME=$(echo $HOST | cut -d " " -f2)
		$BOLD
		$YELLOW
		printf "	%s\n" "Hostname : ::::: $HNAME :::::"
		$NOCOL
		bash $CDIR/lastcontrol.sh --report-remotehost $HNAME $PNAME
		$NOCOL
		i=$(( i + 1 ))
		echo "---------------------------------------------------"
	done
}

SERVER_INSTALL() {
	clear
	# Install Required Packages
	apt-get -y install nmap ack curl wget netcat-traditional
	# Install WebServer
	apt-get -y install apache2
	# Create WorkDir
	mkdir -p $WDIR
	# Generate SSH Key
	mkdir -p /root/.ssh
	chmod 700 /root/.ssh
	rm /root/.ssh/lastcontrol
	ssh-keygen -t rsa -f /root/.ssh/lastcontrol -q -P ""
	# Create Web
	rm -r $WEB/reports
	rm -r $WEB/lastcontrol
	mkdir -p $WEB/lastcontrol
	mkdir -p $WEB/reports
	#Configure Access
	cp /root/.ssh/lastcontrol.pub $WEB/lastcontrol/
	systemctl reload apache2.service
}


if [[ $1 = --help ]] || [[ $1 = -h ]]; then
        SHOW_HELP
        exit 0
elif [[ $1 = --tui ]]; then
        SHOW_MENU
elif [[ $1 = --add-host ]]; then
        ADD_HOST
        exit 0
elif [[ $1 = --remove-host ]]; then
        REMOVE_HOST
        exit 0
elif [[ $1 = --host-list ]]; then
        HOST_LIST
        exit 0
elif [[ $1 = --report-allhost ]]; then
	REPORT_ALLHOST
	exit 0
elif [[ $1 = --server-install ]];
	SERVER_INSTALL
	exit 0
else
        SHOW_HELP
        exit 0
fi


if [ "$1" = "--report-remotehost" ]; then
	if [ -z "$2" ] || [ -z "$3" ]; then
		read -p "Enter the Machine Hostname and SSH Port (Example:ServerName 22): " TARGETMACHINE PORTNUMBER
	else
		TARGETMACHINE="$2"
		PORTNUMBER="$3"
	fi
	LISTED=FALSE
	ack "$TARGETMACHINE" $WDIR/linuxmachine >> /dev/null && LISTED=TRUE
	if [ "$LISTED" = "TRUE" ]; then
		nc -z -w 2 $TARGETMACHINE $PORTNUMBER 2>/dev/null
		if [ "$?" = "0" ]; then
			TARGETHOSTNAME=$(ssh -p$PORTNUMBER -i $LCKEY -o "StrictHostKeyChecking no" root@$TARGETMACHINE -- cat /etc/hostname)
			$GREEN
			scp -P$PORTNUMBER -i $LCKEY $CDIR/lastcontrol.sh -o "StrictHostKeyChecking no" root@$TARGETMACHINE:/usr/local/ &> /dev/null && echo "LastControl Script was transferred to the $TARGETMACHINE"
			ssh -p$PORTNUMBER -i $LCKEY -o "StrictHostKeyChecking no" root@$TARGETMACHINE -- bash /usr/local/lastcontrol.sh --report-localhost &> /dev/null
			$CYAN
			scp -P$PORTNUMBER -i $LCKEY -o "StrictHostKeyChecking no" root@$TARGETMACHINE:/usr/local/lastcontrol/reports/$TARGETHOSTNAME-allreports.txt $WEB/reports/ &> /dev/null && echo "" && echo "	Report Created"
			ABOUTHOST=$(mktemp)
			scp -P$PORTNUMBER -i $LCKEY -o "StrictHostKeyChecking no" root@$TARGETMACHINE:/usr/local/lastcontrol/reports/$TARGETHOSTNAME-abouthost.txt $ABOUTHOST &> /dev/null
			echo -e
			$WHITE
			cat $ABOUTHOST && rm $ABOUTHOST
			echo -e
			$NOCOL
		else
			$RED
			echo "	Could not reach $TARGETMACHINE from Port $PORTNUMBER"
			$NOCOL
			#echo -e
		fi

	elif [ "$LISTED" = "FALSE" ]; then
		$RED
		echo "$TARGETMACHINE Machine was not found in the Machine List"
		$GREEN
		echo "Please add the $TARGETMACHINE machine first with --add-host"
		$MAGENTA
		echo "Usage: bash lastcontrol.sh --add-host"
		$NOCOL
		exit 1
	fi
fi

if [ "$1" = "--report-localhost" ]; then
	clear
	if [ -d "$RDIR" ]; then
		rm -r $RDIR
	fi
	mkdir -p $RDIR
	CHECKRUN_ROOT
	CHECK_DISTRO
	CHECK_UPDATE
	SYSTEM_REPORT
	CHECK_QUOTA
	LVM_CRYPT
	SYSLOG_INFO
	MEMORY_INFO
	USER_LIST
	SUDO_USER_LIST
	USER_LOGINS
	USER_ACCOUNTS_SETTINGS
	PASSWORD_EXPIRE_INFO
	NEVER_LOGGED_USERS
	LOGIN_INFO
	CHECK_KERNEL_MODULES
	GRUB_CONTROL
	SERVICE_PROCESS
	AUDIT
	DIRECTORY_CHECK
	REPOSITORY_CHECK
	NW_CONFIG_CHECK
	SSH_CONFIG_CHECK
	LAST_INSTALL
	APP_LIST
	SUIDGUID_FILE_CHECK
	ABOUT_HOST
	CREATE_REPORT_TXT
	SHOW_ABOUT_HOST

	rm -f $LOCALUSERS
	rm -f $LASTINSTALL
	rm -f $USRSETTINGS
        rm -f $NOTLOGGEDUSERLIST
	rm -f $LASTLOGININFO

	rm -f /usr/local/lastcontrol.sh
	
	exit 0
fi

READ_INPUT(){
local c
read -p "You can choose from the menu numbers " c
case $c in
0)about_of ;;
1)ADD_HOST ;;
2)REMOVE_HOST ;;
3)HOST_LIST ;;
99)exit 0 ;;
*)
echo "Please select from the menu numbers"
echo -e
PAUSE
esac
}

# CTRL+C, CTRL+Z
trap '' SIGINT SIGQUIT SIGTSTP

while true
do
clear
SHOW_MENU
READ_INPUT
done
