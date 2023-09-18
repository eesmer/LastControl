#!/bin/bash

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

clear

cat << "EOF"
 _              _    ____            _             _
| |    __ _ ___| |_ / ___|___  _ __ | |_ _ __ ___ | |
| |   / _` / __| __| |   / _ \| '_ \| __| '__/ _ \| |
| |__| (_| \__ \ |_| |__| (_) | | | | |_| | | (_) | |
|_____\__,_|___/\__|\____\___/|_| |_|\__|_|  \___/|_|
EOF
echo -e
${GREEN}
echo "Welcome to LastControl installation script"
${NOCOL}
echo -e ""

OS=$(hostnamectl | grep "Operating System" | cut -d ":" -f2 | cut -d " " -f2 | xargs)

if [ !"$OS" = "Debian" ] || [ !"$OS" = "Ubuntu" ]; then
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

function pause(){
local message="$@"
[ -z $message ] && message="Press Enter to continue"
read -p "$message" readEnterKey
}

function installer_menu(){
$GRAY
echo "    # LastControl Installer Menu # "
echo "   --------------------------------"
echo "   1. New Install                  "
echo "   2. LastControl Update           "
echo "   3. Check Distro                 "
echo "   --------------------------------"
$RED
echo "   99.Exit                         "
$NOCOL
echo -e
}

function new_install(){
	# -----------------------------------------------------------------------------
	# Packages to Install
	# -----------------------------------------------------------------------------
	  export DEBIAN_FRONTEND=noninteractive
	  apt-get -y update && apt-get -y upgrade && apt-get -y dist-upgrade && apt-get -y autoremove
	  
	  apt-get -y install git
	  apt-get -y install apache2
	  apt-get -y install openssh-server ntp
	  apt-get -y install tmux vim
	  apt-get -y install curl wget
	  apt-get -y install ack
	  apt-get -y install nmap
	  apt-get -y install xsltproc
	  apt-get -y install imagemagick
	  apt-get -y install pandoc texlive-latex-base texlive-fonts-recommended
	  #apt-get -y install sqlite3
	  ##apt-get -y install php
	  ##apt-get -y install php-sqlite3
	  ##apt-get -y install php-db / php-db-dataobject (for test)
	  ##apt-get -y install wapiti #for webserver roles
	  # -----------------------------------------------------------------------------
	  # Create Work Directory
	  # -----------------------------------------------------------------------------
	  git clone https://github.com/eesmer/LastControl.git
	  if [ -d /usr/local/lastcontrol ]; then
		  rm -rf /usr/local/lastcontrol
	  fi
	  cp -r LastControl/lastcontrol /usr/local/
	  chmod -R 755 /usr/local/lastcontrol
	  touch /usr/local/lastcontrol/linuxmachine
	  
	# -----------------------------------------------------------------------------
	# Create SSH-KEY
	# -----------------------------------------------------------------------------
	  mkdir -p /root/.ssh
	  chmod 700 /root/.ssh
	  rm /root/.ssh/lastcontrol
	  ssh-keygen -t rsa -f /root/.ssh/lastcontrol -q -P ""
	  
        # -----------------------------------------------------------------------------
	# Create Web
	# -----------------------------------------------------------------------------
	  rm -r /var/www/html/reports
	  rm -r /var/www/html/lastcontrol
	  mkdir -p /var/www/html/lastcontrol
	  mkdir -p /var/www/html/reports
	  rm /var/www/html/index.html
	  cp LastControl/installer/var/www/html/index.html /var/www/html/
	  cp LastControl/images/lastcontrol_logo.png /var/www/html/
	  chmod 644 /var/www/html/index.html
	  chmod 644 /var/www/html/lastcontrol_logo.png

	# -----------------------------------------------------------------------------
	# Configure Access
	# -----------------------------------------------------------------------------
	  cp /root/.ssh/lastcontrol.pub /var/www/html/lastcontrol/
	  systemctl reload apache2.service

	# -----------------------------------------------------------------------------
	# Configure reports design
	# -----------------------------------------------------------------------------
	# motd modified
	cp LastControl/installer/etc/motd /etc/
	# ImageMagick
	cp LastControl/installer/etc/ImageMagick-6/policy.xml /etc/ImageMagick-6/
	# logo for pdf file
	cp -r LastControl/images /usr/local/lastcontrol/

	#mkdir /usr/local/lastcontrol/db
	#cd /usr/local/lastcontrol/db
	#sqlite3 lastcontrol.sqlite "CREATE TABLE report ( date text(15), hour text(10), machinename text (15), machinegroup text(10) );"

	# -----------------------------------------------------------------------------
	# service has been removed. Because it will only be used from the menu.
	# It can be looked at again for some automations.
	# -----------------------------------------------------------------------------
	# lastcontrol.service
	# -----------------------------------------------------------------------------
	#systemctl stop lastcontrol.service && systemctl disable lastcontrol.service
	#if [ -f "/etc/systemd/system/multi-user.target.wants/lastcontrol.service" ]; then
	#rm /etc/systemd/system/multi-user.target.wants/lastcontrol.service
	#fi
	#if [ -f "/etc/systemd/system/lastcontrol.service" ]; then
	#rm /etc/systemd/system/lastcontrol.service
	#fi
	#cp LastControl/install/machine/etc/systemd/lastcontrol.service /etc/systemd/system/
	#ln -s /etc/systemd/system/lastcontrol.service /etc/systemd/system/multi-user.target.wants/ #(with systemctl enable)
	#systemctl disable lastcontrol.service

	clear
	
	echo "********************************************************"
	echo "Installation completed.."
	echo "********************************************************"
	echo -e
	$DGREEN
	echo "Usage:"
	$CYAN
	echo "bash /usr/local/lastcontrol/manager"
	$NOCOL
	echo "--------------------------------------------------------"
	pause
}

function check_distro(){
	SUPPORT="Supported"
	OS=$(hostnamectl | grep "Operating System" | cut -d ":" -f2 | cut -d " " -f2 | xargs)
	if [ "$OS" = "Debian" ]; then
		VER=$(cat /etc/debian_version)
	elif [ "$OS" = "Ubuntu" ]; then
		. /etc/lsb-release
		VER=$DISTRIB_RELEASE
	else
		OS=$(uname -s)
		VER=$(uname -r)
		SUPPORT="Not Supported"
	fi

	echo -e
	echo "OS : $OS"
	echo "VER: $VER"
	echo -e
	echo "LastControl installation is $SUPPORT this machine"
	echo -e
	pause
}

function read_input(){
$WHITE
local c
read -p "You can choose from the menu numbers " c
$NOCOL
case $c in
1) new_install ;;
3) check_distro ;;
99) exit 0 ;;
*)
$MAGENTA
echo "Please select from the menu numbers"
$NOCOL
pause
esac
}

# CTRL+C, CTRL+Z
trap '' SIGINT SIGQUIT SIGTSTP

while true
do
installer_menu
read_input
clear
done
