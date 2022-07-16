#!/bin/bash

# -----------------------------------------------------------------------------
# STANDART PACKAGES
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
a#pt-get -y install sqlite3
#apt-get -y install php
#apt-get -y install php-sqlite3
# apt-get -y install php-db / php-db-dataobject (for test)

# Create Work Directory
git clone https://github.com/eesmer/LastControl.git
cp -R LastControl/install/machine/usr/local/lastcontrol /usr/local/
chmod -R 755 /usr/local/lastcontrol
touch /usr/local/lastcontrol/linuxmachine

# Create SSH-KEY
mkdir -p /root/.ssh
chmod 700 /root/.ssh
rm /root/.ssh/lastcontrol
ssh-keygen -t rsa -f /root/.ssh/lastcontrol -q -P ""

# Create Web
rm -r /var/www/html/reports && rm -r /var/www/html/lastcontrol
mkdir -p /var/www/html/reports
mkdir -p /var/www/html/lastcontrol
cp /root/.ssh/lastcontrol.pub /var/www/html/lastcontrol/
rm /var/www/html/index.html
cp LastControl/install/machine/var/www/html/index.html /var/www/html/
cp LastControl/images/lastcontrol_logo.png /var/www/html/
chmod 644 /var/www/html/index.html
chmod 644 /var/www/html/lastcontrol_logo.png
systemctl reload apache2.service

#mkdir /usr/local/lastcontrol/db
#cd /usr/local/lastcontrol/db
#sqlite3 lastcontrol.sqlite "CREATE TABLE report ( date text(15), hour text(10), machinename text (15), machinegroup text(10) );"

# -----------------------------------------------------------------------------
# Service Configuration
# -----------------------------------------------------------------------------
systemctl stop lastcontrol.service && systemctl disable lastcontrol.service

if [ -f "/etc/systemd/system/multi-user.target.wants/lastcontrol.service" ]; then
rm /etc/systemd/system/multi-user.target.wants/lastcontrol.service
fi
if [ -f "/etc/systemd/system/lastcontrol.service" ]; then
rm /etc/systemd/system/lastcontrol.service
fi

cp LastControl/install/machine/etc/systemd/lastcontrol.service /etc/systemd/system/
#ln -s /etc/systemd/system/lastcontrol.service /etc/systemd/system/multi-user.target.wants/ (with systemctl enable)
systemctl enable lastcontrol.service
systemctl start lastcontrol.service
systemctl restart lastcontrol.service
