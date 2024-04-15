#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

SHOW_HELP() {
	clear
cat << EOF
Usage: $(basename "$0") [OPTION]

Options:
  --help, -h		show this help message and exit
  --report-localhost	It checks the server (local machine) you are running on
  --report-remotehost	It checks the remote server
  --report-all-servers  Retrieves reports from all remote servers     
  --server-install      install apache, create /usr/local/lastcontrol, create ssh-key
  --add-machine         check conn. remote machine, add ssh-key remote machine
  --remove-machine      remove ssh-key remote machine
EOF
echo -e
}

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
BOLD="tput bold"
NORMAL="tput sgr0"
	
HOST_NAME=$(cat /etc/hostname)
RDIR=/usr/local/lastcontrol/reports
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

if [ "$1" = "--help" ] || [ "$1" = "-h" ] || [ -z "$1" ]; then
    SHOW_HELP
    exit 0
fi

SYSTEM_REPORT() {
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
	CPU_INFO=$(awk -F ':' '/model name/ {print $2}' /proc/cpuinfo | head -n 1 | xargs)
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
	UPTIME=$(uptime | xargs) && UPTIME_MIN=$(awk '{print "up", $1/60, "minutes"}' /proc/uptime)
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
        SWAP_USAGE_PERCENTAGE=$(free -m | grep Swap | awk '{ print $3/$2 * 100 }' | cut -d "." -f1)
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

USER_LOGINS() {
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
	LOAD_AVG=$(uptime | grep "load average:" | awk -F: '{print $5}' | xargs)
	ZO_PROCESS=$(ps -A -ostat,ppid,pid,cmd | grep -e '^[Zz]' | wc -l)
}

MOST_COMMANDS() {
	HISTORY_FILE=~/.bash_history
	if [ -f "$HISTORY_FILE" ]; then
		MOST_COMMANDS=$(cat ~/.bash_history | awk '{cmd[$2]++} END {for(elem in cmd) {print cmd[elem] " " elem}}' | sort -n -r | head -20 | cut -d " " -f2 | paste -sd ",")
	else
		MOST_COMMANDS="bash_history file not found in ~/ directory"
	fi
}

SSH_AUTH_LOGS() {
        find /var/log -name 'auth*.gz' -type f -exec sh -c "zcat {} | egrep -i 'ssh'" \; \
                |grep -v "Connection closed" \
                |grep -v "Disconnected" \
                |grep -v "Received disconnect" \
                |grep -v "pam_unix" \
                |grep -v "Server listening" | tail -n 10
}

NW_CONFIG_CHECK() {
	NWCHECK1=$(sysctl net.ipv4.ip_forward |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_FORWARD_CHECK="Fail"
	if [ "$NWCHECK1" = 0 ]; then IPV4_FORWARD_CHECK="Pass"; fi
	
	NWCHECK2=$(sysctl net.ipv4.conf.all.send_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_ALL_SEND_REDIRECTS="Fail"
	if [ "$NWCHECK2" = 0 ]; then IPV4_ALL_SEND_REDIRECTS="Pass"; fi
	
	NWCHECK3=$(sysctl net.ipv4.conf.all.accept_source_route |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_ALL_ACCEPT_SOURCE_ROUTE="Fail"
	if [ "$NWCHECK3" = 0 ]; then IPV4_ALL_ACCEPT_SOURCE_ROUTE="Pass"; fi
	
	NWCHECK4=$(sysctl net.ipv4.conf.default.accept_source_route |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE="Fail"
	if [ "$NWCHECK4" = 0 ]; then IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE="Pass"; fi
	
	NWCHECK5=$(sysctl net.ipv4.conf.all.accept_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_ALL_ACCEPT_REDIRECTS="Fail"
	if [ "$NWCHECK5" = 0 ]; then IPV4_ALL_ACCEPT_REDIRECTS="Pass"; fi
	
	NWCHECK6=$(sysctl net.ipv4.conf.default.accept_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_DEFAULT_ACCEPT_REDIRECTS="Fail"
	if [ "$NWCHECK6" = 0 ]; then IPV4_DEFAULT_ACCEPT_REDIRECTS="Pass"; fi

	NWCHECK7=$(sysctl net.ipv4.conf.all.secure_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_ALL_SECURE_REDIRECTS="Fail"
	if [ "$NWCHECK7" = 0 ]; then IPV4_ALL_SECURE_REDIRECTS="Pass"; fi

	NWCHECK8=$(sysctl net.ipv4.conf.default.secure_redirects |cut -d "=" -f2 |cut -d " " -f2)
	IPV4_DEFAULT_SECURE_REDIRECTS="Fail"
	if [ "$NWCHECK8" = 0 ]; then IPV4_DEFAULT_SECURE_REDIRECTS="Pass"; fi

	NWCHECK9=$(sysctl net.ipv4.icmp_echo_ignore_broadcasts |cut -d "=" -f2 |cut -d " " -f2)
	ICMP_IGNORE_BROADCASTS="Fail"
	if [ "$NWCHECK9" = 1 ]; then ICMP_IGNORE_BROADCASTS="Pass"; fi

	NWCHECK10=$(sysctl net.ipv4.icmp_ignore_bogus_error_responses |cut -d "=" -f2 |cut -d " " -f2)
	ICMP_IGNORE_BOGUS_ERROR="Fail"
	if [ "$NWCHECK10" = 1 ]; then ICMP_IGNORE_BOGUS_ERROR="Pass"; fi

	NWCHECK11=$(sysctl net.ipv4.conf.all.rp_filter |cut -d "=" -f2 |cut -d " " -f2)
	ALL_RP_FILTER="Fail"
	if [ "$NWCHECK11" = 1 ]; then ALL_RP_FILTER="Pass"; fi

	NWCHECK12=$(sysctl net.ipv4.tcp_syncookies |cut -d "=" -f2 |cut -d " " -f2)
	TCP_SYNCOOKIES="Fail"
	if [ "$NWCHECK12" = 1 ]; then TCP_SYNCOOKIES="Pass"; fi

	NWCHECK13=$(sysctl net.ipv6.conf.all.disable_ipv6 |cut -d "=" -f2 |cut -d " " -f2)
	DISABLE_IPV6="Fail"
	if [ "$NWCHECK13" = 1 ]; then DISABLE_IPV6="Pass"; fi

	NWCHECK14=$(sysctl net.ipv6.conf.all.accept_ra |cut -d "=" -f2 |cut -d " " -f2)
	IPV6_ALL_ACCEPT_RA="Fail"
	if [ "$NWCHECK14" = 1 ]; then IPV6_ALL_ACCEPT_RA="Pass"; fi
}

SSH_CONFIG_CHECK() {
	# PRIVATE HOST KEY
	SSHCHECK1=$(stat /etc/ssh/sshd_config |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	SSHD_ACL="Fail"
	if [ "$SSHCHECK1" = 0600 ]; then SSHD_ACL="Pass"; fi
	SSHCHECK2=$(stat /etc/ssh/ssh_host_rsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	RSAKEY_ACL="Fail"
	if [ "$SSHCHECK2" = 0600 ]; then RSAKEY_ACL="Pass"; fi
	SSHCHECK3=$(stat /etc/ssh/ssh_host_ecdsa_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	ECDSAKEY_ACL="Fail"
	if [ "$SSHCHECK3" = 0600 ]; then ECDSAKEY_ACL="Pass"; fi
	SSHCHECK4=$(stat /etc/ssh/ssh_host_ed25519_key |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	ED25519KEY_ACL="Fail"
	if [ "$SSHCHECK4" = 0600 ]; then ED25519KEY_ACL="Pass"; fi
	# PUBLIC HOST KEY
	SSHCHECK5=$(stat /etc/ssh/ssh_host_rsa_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	RSAKEYPUB_ACL="Fail"
	if [ "$SSHCHECK5" = 0644 ]; then RSAKEYPUB_ACL="Pass"; fi
	SSHCHECK6=$(stat /etc/ssh/ssh_host_ed25519_key.pub |grep "Uid:" |cut -d " " -f2 |cut -d "(" -f2 |cut -d "/" -f1)
	ED25519PUB_ACL="Fail"
	if [ "$SSHCHECK6" = 0644 ]; then ED25519PUB_ACL="Pass"; fi
	grep ^Protocol /etc/ssh/sshd_config >> /dev/null
	PROTOCOL2="Fail"
	if [ "$?" = 0 ]; then PROTOCOL2="Pass"; fi
	SSHCHECK7=$(sshd -T | grep loglevel |cut -d " " -f2)
	LOGLEVEL="Fail"
	if [ "$SSHCHECK7" = INFO ]; then LOGLEVEL="Pass"; fi
	SSHCHECK8=$(sshd -T | grep x11forwarding |cut -d " " -f2)
	X11FORWARD="Fail"
	if [ "$SSHCHECK8" = no ]; then X11FORWARD="Pass"; fi
	SSHCHECK9=$(sshd -T | grep maxauthtries |cut -d " " -f2)
	MAXAUTHTRIES="Fail"
	if [ "$SSHCHECK9" -lt 4 ]; then MAXAUTHTRIES="Pass"; fi
	SSHCHECK10=$(sshd -T | grep ignorerhosts |cut -d " " -f2)
	IGNORERHOST="Fail"
	if [ "$SSHCHECK10" = yes ]; then IGNORERHOST="Pass"; fi
	SSHCHECK11=$(sshd -T | grep hostbasedauthentication |cut -d " " -f2)
	HOSTBASEDAUTH="Fail"
	if [ "$SSHCHECK11" = no ]; then HOSTBASEDAUTH="Pass"; fi
	SSHCHECK12=$(sshd -T | grep permitrootlogin |cut -d " " -f2)
	ROOTLOGIN="Fail"
	if [ "$SSHCHECK12" = no ]; then ROOTLOGIN="Pass"; fi
	SSHCHECK13=$(sshd -T | grep permitemptypasswords |cut -d " " -f2)
	EMPTYPASS="Fail"
	if [ "$SSHCHECK13" = no ]; then EMPTYPASS="Pass"; fi
	SSHCHECK14=$(sshd -T | grep permituserenvironment |cut -d " " -f2)
	PERMITUSERENV="Fail"
	if [ "$SSHCHECK14" = no ]; then PERMITUSERENV="Pass"; fi
}

SUIDGUID_FILE_CHECK() {
	echo "Sticky Bit (T Bit) Permissions Files               " >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	find / -perm /1000 &> /dev/null >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "SUID Permissions Files                             " >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	find / -perm /2000 &> /dev/null >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "GUID Permissions Files                             " >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	find / -perm /4000 &> /dev/null >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "SUID and GUID Permissions Files                    " >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	find / -perm /6000 &> /dev/null >> $RDIR/$HOST_NAME-allreports.txt
	echo "---------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
}

if [ "$1" = "--manager" ]; then
	function pause(){
		local message="$@"
		[ -z $message ] && message="Press Enter to continue"
		read -p "$message" readEnterKey
	}
	function show_menu(){
		$MAGENTA
		echo "    LastControl Server Manager"
		$NOCOL
		echo "   |-------------------------------------|"
		echo "   | 1.Add Machine    | 3.Add SSH-Key    |"
		echo "   | 2.Remove Machine | 4.Remove SSH-Key |"
		echo "   |-------------------------------------|"
		echo "   | 10.Machine List                     |"
		echo "   |-------------------------------------|"
		$WHITE
		echo "     20.Take a Report from All Machine"
		$NOCOL
		echo "   |-------------------------------------|"
		echo "   | WebPage:http://localhost            |"
		echo "   |-------------------------------------|"
		$RED
		echo "     99.Exit"
		$NOCOL
		echo -e

	}
	function read_input(){
		$WHITE
		local c
		read -p "You can choose from the menu numbers " c
		$NOCOL
		case $c in
			1) create_system_report ;;
			2) create_service_report ;;
			99) exit 0 ;;
			*)
		pause
		esac
	}

	# CTRL+C, CTRL+Z
	trap '' SIGINT SIGQUIT SIGTSTP
	while true
	do
	clear
	show_menu
	read_input
	done
fi

if [ "$1" = "--remote-host" ]; then
	#OS=$(hostnamectl | grep "Operating System" | cut -d ":" -f2 | cut -d " " -f2 | xargs)
	OS=$(cat /etc/os-release | grep "ID" | grep -v "VERSION_ID" | grep -v "ID_LIKE" | cut -d "=" -f2)
	if [ ! "$OS" = "debian" ] || [ !"$OS" = "ubuntu" ]; then
		${RED}
		echo "ERROR: This installation script does not support this distro"
		echo "Please run it with;"
		${WHITE}
		echo "[+] Ubuntu"
		echo "[+] Debian"
		${NOCOL}
		echo -e
		exit 1
	fi
fi

if [ "$1" = "--server-install" ]; then
	# Install WebServer
	apt-get -y install apache2
	# Create WorkDir
	mkdir -p /usr/local/lastcontrol
	# Generate SSH Key
	mkdir -p /root/.ssh
	chmod 700 /root/.ssh
	rm /root/.ssh/lastcontrol
	ssh-keygen -t rsa -f /root/.ssh/lastcontrol -q -P ""
	# Create Web
	rm -r /var/www/html/reports
	rm -r /var/www/html/lastcontrol
	mkdir -p /var/www/html/lastcontrol
	mkdir -p /var/www/html/reports
	#Configure Access
	cp /root/.ssh/lastcontrol.pub /var/www/html/lastcontrol/
	systemctl reload apache2.service
fi

if [ "$1" = "--localhost" ]; then
        SYSTEM_REPORT
	CHECK_QUOTA
	LVM_CRYPT
	SYSLOG_INFO
	MEMORY_INFO
	USER_LIST
	SUDO_USER_LIST
	USER_LOGINS
	PASSWORD_EXPIRE_INFO
	NEVER_LOGGED_USERS
	LOGIN_INFO
	CHECK_KERNEL_MODULES
	GRUB_CONTROL
	SERVICE_PROCESS
	MOST_COMMANDS
	DIRECTORY_CHECK
	REPOSITORY_CHECK
	NW_CONFIG_CHECK
	SSH_CONFIG_CHECK
	
	clear
	printf "%30s %s\n" "------------------------------------------------------"
	$RED
	printf "%30s %s\n" "               LastControl Summary Report             " 
	$NOCOL
	printf "%30s %s\n" "------------------------------------------------------"
	$CYAN
	printf "%30s %s\n" "- Hardware                                              " 
	$NOCOL
	printf "%30s %s\n" "------------------------------------------------------"
	printf "%30s %s\n" "Hostname            :" "$HOST_NAME"
	printf "%30s %s\n" "Internal IP Address :" "$INTERNAL_IP"
	printf "%30s %s\n" "External IP Address :" "$EXTERNAL_IP"
	printf "%30s %s\n" "Internet Connection :" "$INTERNET"
	printf "%30s %s\n" "CPU Info            :" "$CPU_INFO - Number of CPU: $NOC"
	printf "%30s %s\n" "Ram Info            :" "Total Ram: $RAM_TOTAL - Ram Usage: $RAM_USAGE"
	printf "%30s %s\n" "VGA Info            :" "VGA: $GPU_INFO - VGA Ram: $GPU_RAM"
	printf "%30s %s\n" "------------------------------------------------------"
	$CYAN
	printf "%50s %s\n" "- System                                              " 
	$NOCOL
	printf "%30s %s\n" "------------------------------------------------------"
	printf "%30s %s\n" "Distro              :" "$DISTRO"
	printf "%30s %s\n" "Kernel Version      :" "$KERNEL"
	printf "%30s %s\n" "Uptime              :" "$UPTIME - $UPTIME_MIN"
	printf "%30s %s\n" "Last Boot           :" "$LAST_BOOT"
	printf "%30s %s\n" "Virtualization      :" "$VIRT_CONTROL"
	printf "%30s %s\n" "Date                :" "Date:$LOCAL_DATE"
	printf "%30s %s\n" "Timezone            :" "$TIME_ZONE"
	printf "%30s %s\n" "------------------------------------------------------"
	$CYAN
	printf "%30s %s\n" "- Current Status                                      "
	$NOCOL
	printf "%30s %s\n" "------------------------------------------------------"
	printf "%30s %s\n" "Ram Usage           :" "$RAM_USAGE_PERCENTAGE%"
	printf "%30s %s\n" "Swap Usage          :" "$SWAP_USAGE_PERCENTAGE%"
	printf "%30s %s\n" "Service Manager     :" "$SERVICE_MANAGER"
	printf "%30s %s\n" "Running Service     :" "$RUNNING_SERVICE"
	printf "%30s %s\n" "Loaded Service      :" "$LOADED_SERVICE"
	printf "%30s %s\n" "Active Connections  :" "$ACTIVE_CONN"
	printf "%30s %s\n" "Passive Connections :" "$PASSIVE_CONN"
	printf "%30s %s\n" "Failed Connections  :" "$FAILED_CONN"
	printf "%30s %s\n" "Established Conn.   :" "$ESTAB_CONN"
	printf "%30s %s\n" "Load Average        :" "$LOAD_AVG"
	printf "%30s %s\n" "Zombie Process      :" "$ZO_PROCESS"
	printf "%30s %s\n" "------------------------------------------------------"
	$CYAN
	printf "%30s %s\n" "- Repository List                                     "
	$NOCOL
	printf "%30s %s\n" "------------------------------------------------------"
	cat $RDIR/repositorylist.txt	
	printf "%30s %s\n" "------------------------------------------------------"
	$CYAN
	printf "%30s %s\n" "- Audit                                               "
	$NOCOL
	printf "%30s %s\n" "------------------------------------------------------"
	$RED
	printf "%10s %s\n" "Most Usage Commands :"
	$NOCOL
	"$MOST_COMMANDS"
	$RED
	printf "%30s %s\n" "Last 10 SSH Auth. Log Records:"
	$NOCOL
	SSH_AUTH_LOGS
	printf "%30s %s\n" "------------------------------------------------------"
	$CYAN
	$BOLD
	printf "%10s %s\n" "- The Full Report System"
	$NOCOL
	printf "%10s %s\n" "$RDIR/$HOST_NAME-allreports.txt"
	$NORMAL
	printf "%30s %s\n" "------------------------------------------------------"
	echo -e
	
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
|Hostname:           |$HOST_NAME
|IP Address:         |$INTERNAL_IP | $EXTERNAL_IP
|Internet Conn.      |$INTERNET
|CPU:                |$CPU_INFO
|RAM:                |Total:$RAM_TOTAL | Ram Usage: $RAM_USAGE
|GPU / VGA:          |VGA: $GPU_INFO   | VGA Ram: $GPU_RAM 
|DISK LIST:          |$DISK_LIST
|DISK INFO:          |$DISK_INFO
--------------------------------------------------------------------------------------------------------------------------
| SYSTEM INFORMATION
--------------------------------------------------------------------------------------------------------------------------
|Operation System:   |$DISTRO
|Kernel Version:     |$KERNEL
|Uptime              |$UPTIME | $UPTIME_MIN
|Last Boot:          |$LAST_BOOT
|Virtualization:     |$VIRT_CONTROL
|Date/Time Sync:     |Date:$LOCAL_DATE - System clock synchronized:$TIME_SYNC
|Timezone:           |$TIME_ZONE
|Proxy Usage:        |HTTP: $HTTP_PROXY_USAGE
|SYSLOG Usage:       |$SYSLOG_INSTALL | $SYSLOG_SERVICE | Socket: $SYSLOG_SOCKET | Send: $SYSLOG_SEND
--------------------------------------------------------------------------------------------------------------------------
|Ram  Usage:         |$RAM_USAGE_PERCENTAGE%
|Swap Usage:         |$SWAP_USAGE_PERCENTAGE%
|Disk Usage:         |$DISK_USAGE
|Out of Memory Logs  |$OOM_LOGS
--------------------------------------------------------------------------------------------------------------------------
|Disk Quota Usage:   |Install: $QUOTA_INSTALL | Usr_Quota: $USR_QUOTA | Grp_Quota: $GRP_QUOTA | Mount: $MNT_QUOTA
|Disk Encrypt Usage: |Install: $CRYPT_INSTALL | Usage: $CRYPT_USAGE
|LVM Usage:          |$LVM_USAGE
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
|Service Management: |$SERVICE_MANAGER
|Running Service:    |$RUNNING_SERVICE
|Loaded Service:     |$LOADED_SERVICE
--------------------------------------------------------------------------------------------------------------------------
|Active Connection:  |$ACTIVE_CONN
|Passive Connection: |$PASSIVE_CONN
|Failed Connection:  |$FAILED_CONN
|Established Conn.:  |$ESTAB_CONN
---------------------------------------------------------------------------------------------------------------------------
|Number of CPU:      |$NOC
|Load Avarage        |$LOAD_AVG
|Zombie Process:     |$ZO_PROCESS
-------------------------------------------------------------------------------------------------------------------------
| Network Config
-------------------------------------------------------------------------------------------------------------------------
|IPv4 IP Forward Check                    | $IPV4_FORWARD_CHECK"
|IPv4 All Send Redirects Check            | $IPV4_ALL_SEND_REDIRECTS"
|IPv4 All Accept Source Route Check       | $IPV4_ALL_ACCEPT_SOURCE_ROUTE"
|IPv4 Default Accept Source Route Check   | $IPV4_DEFAULT_ACCEPT_SOURCE_ROUTE"
|IPv4 All Accept Redirects Check          | $IPV4_ALL_ACCEPT_REDIRECTS"
|IPv4 Default Accept Redirects Check      | $IPV4_DEFAULT_ACCEPT_REDIRECTS"
|IPv4 All Secure Redirects Check          | $IPV4_ALL_SECURE_REDIRECTS"
|IPv4 Default Secure Redirects Check      | $IPV4_DEFAULT_SECURE_REDIRECTS"
|IPv4 ICMP Echo Ignore Broadcasts Check   | $ICMP_IGNORE_BROADCASTS"
|IPv4 ICMP Ignore Bogus Error Resp. Check | $ICMP_IGNORE_BOGUS_ERROR"
|IPv4 ALL RP Filter Check                 | $ALL_RP_FILTER"
|IPV4 TCP SynCookies Check                | $TCP_SYNCOOKIES"
|IPv6 Disable IPv6 Check                  | $DISABLE_IPV6"
|IPv6 All Accept Ra Check                 | $IPV6_ALL_ACCEPT_RA"
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
|Local User Count:   |$LOCAL_USER_COUNT
|Local User List:    |$USER_LIST
|SUDO Users:         |$SUDO_USER_LIST
|Blank Pass. Users   |$BLANK_PASS_USER_LIST
|Locked Users        |$LOCKED_USERS
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
|Service Users:      |$SERVICE_USER_LIST
--------------------------------------------------------------------------------------------------------------------------
EOF

	echo "|LISTENING SERVICE and PORT LIST" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	#netstat -tl |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" >> $RDIR/$HOST_NAME-allreports.txt
	lsof -nP -iTCP -sTCP:LISTEN | grep -v "IPv6" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|ESTABLISHED SERVICE LIST" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	netstat -tn |grep -v "Active Internet connections (servers and established)" |grep -v "Active Internet connections (only servers)" |grep "ESTABLISHED" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "| AUDIT INFO" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|MOST USAGE COMMANDS|" >> $RDIR/$HOST_NAME-allreports.txt
	echo $MOST_COMMANDS >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "|SSH Auth. Logs (Last 10 Record) |" >> $RDIR/$HOST_NAME-allreports.txt
	SSH_AUTH_LOGS >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	echo "| REPOSITORY LIST" >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	cat $RDIR/repositorylist.txt >> $RDIR/$HOST_NAME-allreports.txt
	echo "--------------------------------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME-allreports.txt
	rm $RDIR/repositorylist.txt
	SUIDGUID_FILE_CHECK
exit 0
fi
