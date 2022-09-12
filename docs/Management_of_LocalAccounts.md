## LastControl-Handbook / User Guide
This document contains details on managing of Local Account issues.<br>

---
### Management of Local Accounts
#### analysis and reporting
---
On Linux systems, local user accounts are stored in the /etc/passwd and /etc/shadow files.<br>
/etc/passwd and /etc/shadow files and work together.<br>
/etc/passwd stores local account information such as username, userID, groupID, home directory.<br>
/etc/shadow stores passwords for local accounts encrypted and contains settings for their management.<br>

---
#### about of /etc/passwd
---
Lines in /etc/passwd file consist of 7 fields separated by ":" <br>

first field: **username**<br>
This field stores the username of the local user account.

second field: **password**<br>
This field is the password field. Here, the x character indicates that the password is encrypted in the /etc/shadow file.

third field: **UserID**<br>
This field holds an identifying number of the user account.<br>
"0" is reserved for root user.<br>
1-99 UID, other predefined accounts<br>
100-999 is reserved for system accounts and groups.<br>
By default; User accounts created after installation start from 1000 UID numbers.<br>

fourth field: **GroupID**<br>
It holds the identification number for the primary group information of the user account.

fifth field: **UserID Info**<br>
This field is used for additional information.
It can be used for definitions such as user account, phone number, address information.

sixth field: **HomeDirectory**<br>
This field holds the home directory of the user account. By default, it is used with the username under the "/home" directory.
If this field is left blank, the home directory of the user account will be "/".

seventh field: **LoginShell**<br>
This field specifies the shell application that the user account will use the system after login.
If this field is filled as "/usr/bin/nologin", the user account cannot login to the system.

- ***Note:***<br>
When a local user is created in the system or the current user's password is updated<br>
Updates are made in both /etc/passwd and /etc/shadow.<br>

<br>

---
#### about of /etc/shadow
---
Lines in /etc/passwd file consist of 9 fields separated by ":" <br>

first filed: **username**<br>
The local user account contains the "User Name" information. The login name of the account.<br>
The "User Name" information of all local accounts is displayed with the following command.<br>
```sh
awk -F: '{ print $1 }' /etc/shadow
```

second field: **encrypted password**<br>
In this area, the user account password is stored encrypted.
```sh
awk -F: '{ print $2 }' /etc/shadow
```
for add username info to output;
```sh
awk -F: '{ print $1 " : " $2 }' /etc/shadow
```

- ***Note:***<br>
In the $2 (encrypted password) field,<br>
"!" or if there is a "*" character; This is a locked account.<br>

<br>

In the $2 field, if there "!" characters, this is a user account.<br>
In the $2 field, if there "*" characters, this is a service account.<br>
In the $2 field, If there are "!*" characters, this indicates a blank password.<br>

Linux environments do not support blank passwords. User accounts with blank passwords cannot login.<br>

<br>

third field: **date of last password change**<br>
This field stores the last time the user account password was updated.<br>
<br>
The password update time record can be displayed next to the user account with the following command.<br>
```sh
awk -F: '{ print $1 ":" $3 }' /etc/shadow
```
according to this;
```sh
date -d "1970-01-01 $3 days"
```
with this command The date the password was last updated is displayed.<br>

fourth field: **minimum required days between password changes**<br>
This field specifies the minimum time period between two password update operations.<br>
By default, comes with the value "0".<br>
A value of "0" supports consecutive updates without checking any number of days.<br>
```sh
awk -F: '{ print $1 ":" $4 }' /etc/shadow
```

fifth field: **maximum allowed days between password changes**<br>
This field specifies the maximum time period between two password update operations.<br>
It comes with the default value "99999".<br>
The value "99999" supports consecutive update without checking any number of days.<br>
```sh
awk -F: '{ print $1 ":" $5 }' /etc/shadow
```

sixth field: **number of days in advance to display password expiration message**<br>
This field specifies the warning time for the password change operation.<br>
As long as the number of days remaining to update the password is equal to less than the value in this field a password change warning is given.<br>
<br>
The default value is 7. But if the maximum value is 99999, the warning will not work.<br>
```sh
awk -F: '{ print $1 ":" $6 }' /etc/shadow
```

seventh field: **number of days after password expiration to disable the account**<br>
If this field is not updated after the password update period Specifies the period for which the account will be disabled.<br>
<br>
eighth field: **account expiration date**<br>
This field stores the time the user account was disabled.<br>
It is expressed as the number of days from 01.01.1970 to the date to be disabled.<br>
<br>
**For example;**
If the value 20000 is entered, the relevant account; It will be disabled on "Fri 04 Oct 2024 12:00:00".<br>
<br>
ninth field: **reserve field**<br>
This area is reserved for holding and using a new value in the shadow file.<br>



