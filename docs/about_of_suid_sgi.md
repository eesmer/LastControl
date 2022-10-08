## LastControl Documention
This document contains details and manage on suid and sgid file,directories.<br>

---
### SUID,SGID files and management of this process
---
In Linux systems, the executable file takes over the privileges of the user running it.<br>
Example: If the user does not have access to the /var/log/messages file, executable (even if the file owner is root)<br>
cannot access this file when run with this user.<br>
In this case, you need to run the program with a user authority that you can access.<br>
<br>
Instead, it is possible to have the program run with the authority of the owner who created the file, regardless of the authority of the user running the program.<br>
This can be done for user account with suid definition and group based with sgid definition.<br>
<br>
suid is used for files and the file always inherits its owner's authority, regardless of the user running it.<br>
sgid affects both files and directories, and the file always inherits the owner's group privilege, regardless of the group of the user running it.<br>
<br>
When sgid is set for directory the files in that directory work as if they are in the same group as the owner of the directory they are in, not the user who created the files.<br>
This is important for file server and sharing issues.<br>
<br>
To find these definitions, look for s instead of x in file permissions.<br>

If the executable file is owned by the root user and suid or sgid is defined, it should be carefully configured and controlled as it will inherit the root privilege for access.<br>
<br>

The suid definition is done by adding the prefix 4 to the chmod parameter.
```sh
chmod 4755 filename
```
The sgid definition is made by adding the 2 prefix to the chmod parameter.
```sh
chmod 2755 filename
```

To remove these definitions
for suid
```sh
chmod u-s filename
```
for sgid
```sh
chmod g-s filename
```

With the following command, suid files can be searched in the entire system.
```sh
find / -user root -perm -4000 -exec ls -ldb {} \; |awk '{print $1 " - " $3 ":" $4 " - " $9}'
```

With the following command, sgid files/directories can be searched in the entire system.
```sh
find / -user root -perm -2000 -exec ls -ldb {} \; |awk '{print $1 " - " $3 ":" $4 " - " $9}'
```

It is identified and separated by the suid 4 prefix and the sgid 2 prefix.

Both suid and sgid defined files/directories can be searched with the following command.
```sh
find / -user root -perm -6000 -exec ls -ldb {} \; |awk '{print $1 " - " $3 ":" $4 " - " $9}'
```
