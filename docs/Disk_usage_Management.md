## LastControl-Handbook / User Guide
This document contains details on disk usage issues.

<br>

If Lastcontrol reported an disk usage problemi, you can use this document.

---
### -Disk_Usage_Management
---
LastControl reports if the disk usage on which the system is installed is more than 50%. <br>
You should check the system or increase the space in case the remaining disk size is running out quickly. <br>
<br>
If the usage rate of disk size is higher than expected; these can be controlled by the following operations. <br>
<br>
The following command will list all directories sizes <br>
```sh
$ du -hsx /* | sort -rh
```
**.tar.gz .tar.bz archive files** <br>
You can list the tar.gz and tar.bz compressed files in the system. <br>
(usually these are files that have been archived or transferred for one-time use) <br>

```sh
$ find "tar.gz"| grep -v ' ' | xargs du -sch | sort -nk1 | grep 'M\|G'
```
```sh
$ find "tar.bz"| grep -v ' ' | xargs du -sch | sort -nk1 | grep 'M\|G'
```
**error_log** <br>
Reporting an error can enlarge the error_log file and fill the disk. <br>
```sh
$ find "error_log"| grep -v ' ' | xargs du -sch | sort -nk1 | grep 'M\|G'
```
If error_log exists and grows; It is enough to correct the error and delete the file. <br>
<br>

**Check old kernel files** <br>
On Debian based systems; <br>
```sh
$ dpkg -l 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d'
```
```sh
$ apt autoremove --purge
```
On RedHat based systems; <br>
```sh
$ rpm -qa |grep 'linux-*' | sed '/^ii/!d;/'"$(uname -r | sed "s/\(.*\)-\([^0-9]\+\)/\1/")"'/d;s/^[^ ]* [^ ]* \([^ ]*\).*/\1/;/[0-9]/!d'
```
**List of kernel modules** <br>
```sh
$ find / -xdev -name core -ls -o  -path "/lib*" -prune
```
<br>

**Conclusion:** The 50% rate may not matter if it does not continue to grow. For manual deletions though, the above can be considered.
