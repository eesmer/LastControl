#!/bin/bash

#--------------------------------------------------------
# This script,
# It produces the report of Local User Controls.
#--------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

####TOTALACCOUNT=$(getent passwd |wc -l)
USERACCOUNT=$(cat /etc/shadow |grep -v "*" |grep -v "!" |wc -l)
cat /etc/shadow |grep -v "*" |grep -v "!" |cut -d ":" -f1 > /tmp/localaccountlist
rm -f /tmp/notloggeduserlist
i=1
while [ $i -le $USERACCOUNT ]; do
        USERACCOUNTNAME=$(awk "NR==$i" /tmp/localaccountlist)
	lastlog |grep "Never logged in" |grep "$USERACCOUNTNAME" >> /tmp/notloggeduserlist
i=$(( i + 1 ))
done
NOTLOGGEDUSER=$(wc -l /tmp/notloggeduserlist |cut -d " " -f1)

NOLOGINUSER=$(getent passwd |grep "nologin" |wc -l)
#FALSELOGINUSER=$(getent passwd |grep "bin/false" |wc -l)
LOGINAUTHUSER=$(getent passwd |grep -v "nologin" |grep -v "bin/false" |grep -v "sbin/shutdown" |grep -v "bin/sync" |grep -v "sbin/halt" |wc -l)
SERVICEACCOUNT=$(awk -F: '$2 == "*"' /etc/shadow |wc -l)
BLANKPASSACCOUNT=$(awk -F: '$2 == "!*" { print $1 }' /etc/shadow |wc -l)
rm -f /tmp/notloggeduserlist

SUDOUSERCOUNT=$(getent group sudo | awk -F: '{print $4}' | tr ',' "\n" >> /tmp/sudouserlist ; cat /etc/sudoers | grep "ALL" | grep -v "%" | awk '{print $1}' \
    >> /tmp/sudouserlist ; grep 'ALL' /etc/sudoers.d/* | cut -d":" -f2 | cut -d" " -f1 >> /tmp/sudouserlist ; cat /tmp/sudouserlist | wc -l ; \
    rm /tmp/sudouserlist)
SUDOUSERLIST=$(grep -e '^sudo:.*$' -e '^wheel:.*$' /etc/group | cut -d ":" -f4 | paste -sd ',')

LASTLOGIN07D=$(lastlog --time 30 |grep -v "Username" |cut -d " " -f1 |paste -sd ',')
LASTLOGIN0TD=$(lastlog --time 1 |grep -v "Username" |cut -d "+" -f1 |paste -sd ",")

cat > $RDIR/$HOST_NAME-localuserreport.md<< EOF

---
title: Local Users Information Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

Local User Accounts :
 ~ $USERACCOUNT

SUDO User Count :
 ~ $SUDOUSERCOUNT

* SUDO User List
$SUDOUSERLIST

---

### Not Logged User Accounts ###
$NOTLOGGEDUSER

### Login Auth. Information ###
* Login Auth. Users :
 ~ $LOGINAUTHUSER

* No Login Users :
 ~ $NOLOGINUSER

* Service Accounts :
 ~ $SERVICEACCOUNT

### Blank Password Accounts ###
$BLANKPASSACCOUNT

---

### Lastlogins of 30 Days ###
$LASTLOGIN30D

### Lastlogins in Today ###
$LASTLOGIN0TD

---

### Service Accounts ###
$SERVICEACCOUNT

---
EOF

cat > $RDIR/$HOST_NAME-localuserreport.txt << EOF
====================================================================================================
:::. $HOST_NAME LOCAL USER INFORMATION ON SYSTEM :::.
====================================================================================================
$DATE


----------------------------------------------------------------------------------------------------
|Local User Account          |$USERACCOUNT
|SUDO Users                  |$SUDOUSERCOUNT - UserList: $SUDOUSERLIST 
|Not Logged User Accounts    |$NOTLOGGEDUSER
|Login Auth. Information     |Login Auth.:$LOGINAUTHUSER - nologin:$NOLOGINUSER
|Blank Password Accounts     |$BLANKPASSACCOUNT
----------------------------------------------------------------------------------------------------
|Lastlogins of 30 Days       |$LASTLOGIN30D
|Lastlogins in Today         |$LASTLOGIN0TD
----------------------------------------------------------------------------------------------------
|Service Accounts            |$SERVICEACCOUNT
----------------------------------------------------------------------------------------------------

EOF

rm -f /tmp/activeuseraccount.txt
rm -f /tmp/useraccountpassinfo.txt
rm -f /tmp/infopasschange.txt

exit 1

echo "----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.localuserreport
echo "| DETAILED USER INFORMATION                                                                         " >> $RDIR/$HOST_NAME.localuserreport
echo "----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.localuserreport

cat /etc/shadow |grep -v "*" |grep -v "!" |cut -d ":" -f1 > /tmp/activeuseraccount.txt

USERNUM=$(cat /tmp/activeuseraccount.txt | wc -l)
i=1
while [ $i -le $USERNUM ]; do
        USERLINE=$(awk "NR==$i" /tmp/activeuseraccount.txt |cut -d ":" -f1)

        #echo $USERLINE >> /tmp/infopasschange.txt
        PASSCHANGED=$(lslogins $USERLINE |grep "Password changed:" |cut -d ":" -f2 |xargs)
        RUNPROCESS=$(lslogins $USERLINE |grep "Running processes:" |cut -d ":" -f2 |xargs)
        LASTLOGIN=$(lslogins $USERLINE |grep "Last login:" |cut -d ":" -f2 |xargs)
        LASTIP=$(lslogins $USERLINE |grep "Last hostname:" |cut -d ":" -f2 |xargs)
	SHCOUNT=$(pgrep --count bash)

	echo "|User Account              |$USERLINE                                                               " >> $RDIR/$HOST_NAME.localuserreport
	echo "|Password Changed          |$PASSCHANGED                                                            " >> $RDIR/$HOST_NAME.localuserreport
	echo "|Running Processes         |$RUNPROCESS                                                             " >> $RDIR/$HOST_NAME.localuserreport
	echo "|Last Login Date           |$LASTLOGIN                                                              " >> $RDIR/$HOST_NAME.localuserreport
	echo "|Last Accessed IP          |$LASTIP                                                                 " >> $RDIR/$HOST_NAME.localuserreport
	echo "----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.localuserreport
i=$(( i + 1 ))
done

echo "" >> $RDIR/$HOST_NAME.localuserreport
echo "----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.localuserreport
lslogins --user-accs --acc-expiration >> $RDIR/$HOST_NAME.localuserreport
echo "----------------------------------------------------------------------------------------------------" >> $RDIR/$HOST_NAME.localuserreport
echo "" >> $RDIR/$HOST_NAME.localuserreport

rm -f /tmp/activeuseraccount.txt
rm -f /tmp/useraccountpassinfo.txt
rm -f /tmp/infopasschange.txt

cat >> $RDIR/$HOST_NAME.txt << EOF

|---------------------------------------------------------------------------------------------------
| ::. User Info .::  |
|---------------------------------------------------------------------------------------------------
|Local User Account          |$USERACCOUNT
|SUDO Users                  |$SUDOUSERCOUNT - UserList: $SUDOUSERLIST 
|Not Logged User Accounts    |$NOTLOGGEDUSER
|Login Auth. Information     |Login Auth.:$LOGINAUTHUSER - nologin:$NOLOGINUSERNUM
|Blank Password Accounts     |$BLANKPASSACCOUNT
|Lastlogins of 30 Days       |$LASTLOGIN30D
|Lastlogins in Today         |$LASTLOGIN0TD
|Service Accounts            |$SERVICEACCOUNT
|----------------------------------------------------------------------------------------------------

EOF

echo "---------------------------------------------------------------------------------------------------" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "|User List with Blank Password" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "---------------------------------------------------------------------------------------------------" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
#cat /etc/shadow |grep "!*" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
awk -F: '$2 == "!*" { print $1 }' /etc/shadow |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "---------------------------------------------------------------------------------------------------" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null

echo "---------------------------------------------------------------------------------------------------" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "|Login Authorized User List" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "---------------------------------------------------------------------------------------------------" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
#getent passwd |grep -v "nologin" |cut -d ":" -f1 |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
#cat /tmp/localaccountlist |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null

rm -f /tmp/loginauthusers.txt
while IFS=: read -r f1 f2 f3 f4 f5 f6 f7
do
	echo "$f1 : Login Setting=$f7" >> /tmp/loginauthusers.txt
done < /etc/passwd
cat /tmp/loginauthusers.txt |grep -v "nologin" |grep -v "bin/false" |grep -v "sbin/shutdown" |grep -v "bin/sync" |grep -v "sbin/halt" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "---------------------------------------------------------------------------------------------------" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
rm -f /tmp/loginauthusers.txt

# user last login info
echo "---------------------------------------------------------------------------------------------------" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "|Local Users Last Login Information" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
echo "---------------------------------------------------------------------------------------------------" |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt &>/dev/null
NUMUSER=$(cat /tmp/localaccountlist |wc -l)
i=1
while [ "$i" -le "$NUMUSER" ]; do
	USER=$(ls -l |sed -n $i{p} /tmp/localaccountlist)
	lastlog |grep $USER |tee -a $RDIR/$HOST_NAME.localuserreport |tee -a $RDIR/$HOST_NAME.txt
i=$(( i + 1 ))
done

rm -f /tmp/localaccountlist

echo "====================================================================================================" >> $RDIR/$HOST_NAME.localuserreport
