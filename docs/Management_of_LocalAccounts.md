## LastControl-Handbook / User Guide
This document contains details on managing of Local Account issues.<br>

---
### -Management of Local Accounts
#### Analyzing and Reporting
---
On Linux systems, local user accounts are stored in the /etc/passwd and /etc/shadow files.<br>
/etc/passwd and /etc/shadow files and work together.<br>
/etc/passwd stores local account information such as username, userID, groupID, home directory.<br>
/etc/shadow stores passwords for local accounts encrypted and contains settings for their management.<br>

---
#### about of /etc/passwd
---
Lines in /etc/passwd file consist of 7 fields separated by ":" <br>

**first field: username**
This field stores the username of the local user account.

**second field: password**
This field is the password field. Here, the x character indicates that the password is encrypted in the /etc/shadow file.

**third field: UserID**
This field holds an identifying number of the user account.<br>
"0" is reserved for root user.<br>
1-99 UID, other predefined accounts<br>
100-999 is reserved for system accounts and groups.<br>
By default; User accounts created after installation start from 1000 UID numbers.<br>

**fourth field: GroupID**
It holds the identification number for the primary group information of the user account.

**fifth field: UserID Info**
This field is used for additional information.
It can be used for definitions such as user account, phone number, address information.

**sixth field: HomeDirectory**
This field holds the home directory of the user account. By default, it is used with the username under the "/home" directory.
If this field is left blank, the home directory of the user account will be "/".

**seventh field: LoginShell**
This field specifies the shell application that the user account will use the system after login.
If this field is filled as "/usr/bin/nologin", the user account cannot login to the system.

***Note***<br>
```sh
When a local user is created in the system or the current user's password is updated
Updates are made in both /etc/passwd and /etc/shadow.
```

<br>

---
#### about of /etc/shadow
---
Lines in /etc/passwd file consist of 9 fields separated by ":" <br>

**first filed: username**
The local user account contains the "User Name" information. The login name of the account.<br>
The "User Name" information of all local accounts is displayed with the following command.<br>
```sh
awk -F: '{ print $1 }' /etc/shadow
```

