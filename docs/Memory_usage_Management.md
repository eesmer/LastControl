## LastControl-Handbook / User Guide
This document contains details on memory and swap usage issues.

<br>

If Lastcontrol reported an ram and swap usage problemi, you can use this document.

---
### -Memory_usage_Management
---
LastControl reports if the system's memory usage is greater than 50%. <br>
<br>
In Linux systems, the system takes all of the physical memory and distributes it according to the service it provides. <br>
When the machine is out of memory, running processes are abruptly terminated and this is a major issue. <br>
These interrupt the service provided by the machine. <br>
<br>
You can control it with the following tools or commands; <br>
**free -h** <br>
To understand this output correctly; <br>
You should be able to distinguish between the memory used in the application and the cache. <br>
You should remember that the cache takes physical memory for faster access and at the application level this is free memory. <br>
**top** <br>
With this program, you can observe the resource used by an application or process. <br>
**grep -i -r 'out of memory' /var/log/** <br>
This command will list if there is an "out of memory" record in the logs under the /var/log directory. <br>

## Extras
These notes contain additional information for this topic. It is not a recommendation for use or solution. <br>
<br>
**OOM Score:** <br>
Linux, keeps a score for each running process to kill in case of memory shortage.(/proc/<pid>/oom_score) <br>
The process to be terminated when the system is out of memory is selected according to the high of this score. <br>
<br>
Typically, non-critical and non-memory applications will output oom_score of 0. <br>
Yes, if ram usage and oom_score are high; In the first problem, that process is terminated. (example: mysql process) <br>
<br>

```sh
$ ps aux | grep <process name>
```
```sh
$ cat /proc/<pid>/oom_score  
```
If you cannot produce a permanent solution instantly and the system memory is exhausted; <br>
The kill feature can be disabled for the critical process. <br>
(This is obviously not a good idea. You may not have met Kernel Panic before. We're just learning more now. (: ) <br>
For this, it is necessary to change the system's overcommit calls. <br>
<br>
You can list all parameters with **sysctl -a** <br>
sysctl allows you to set some kernel-specific parameters without rebooting the system. <br>
<br>
vm.overcommit_memory and vm.overcommit_ratio are parameters used to check system memory. <br>
<br>
- With vm.overcommit_memory=2, it is not allowed to exceed the physical ram percentage for the process.
- With vm.overcommit_memory=1, the process can request as much memory as it deems necessary. (This may be more than physical memory.)
- With vm.overcommit_ratio=100, all physical memory is allowed to be used.

```sh
$ sysctl -w vm.overcommit_memory=2
```
```sh
$ sysctl -w vm.overcommit_ratio=100 
```
for permanent setting <br>
```sh
$ vim /etc/sysctl.conf
```
**Additional information:** <br>
Linux systems often allow processes to request more memory than is idle on the system to improve our memory usage. <br>
In such a case, if there is an insufficient memory problem in the system, the process is terminated. oom_score is kept as used information here.
<br>
Linux intentionally caches data on disk to increase system responsiveness. Cached memory is available for each application. <br>
So don't be surprised by the ram usage output from the free -m command. <br>
https://www.linuxatemyram.com/
<br>
<br>
**Conclusion:** In fact, if LastControl reports this situation frequently; <br>
This means that the resource is insufficient for the service provided by the machine. <br>
  
---
### -Swap_Usage_is_Reported
---
If LastControl reported the swap usage, the swap usage was probably required due to lack of memory. <br>
This warning is added to the report if the swap usage is not 0. <br>
<br>
The following can be used to investigate the swap usage status in the system. <br>
<br>
**smem package** <br>
On Debian based system; <br>
```sh
$ apt -y install smem
```
On RedHat based system; <br>
```sh
$ yum -y install smem
(from epel-release repository)
```
**smem** <br>
Lists swap usage per PID,User and process <br>
**PID &nbsp; User &nbsp; Command &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; Swap &nbsp; USS &nbsp; PSS &nbsp; RSS** <br>
461 &nbsp; root &nbsp; /sbin/agetty -o -p -- \u --  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 0 &nbsp; &nbsp; &nbsp; 316 &nbsp; 414 &nbsp; 2064 <br>
394 &nbsp; root &nbsp; /usr/sbin/cron -f &nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp;&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 0 &nbsp; &nbsp; 360 &nbsp; 604 &nbsp; 2736 <br>
360 &nbsp; messagebus &nbsp; /usr/bin/dbus-daemon --syst &nbsp; &nbsp; 0 &nbsp; &nbsp; 1080 &nbsp; 1506 &nbsp; 4324 <br>
3909 &nbsp; www-data &nbsp; /usr/sbin/apache2 -k start &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 0 &nbsp; &nbsp; 200 &nbsp; 1617 &nbsp; 11164 <br>
3910 &nbsp; www-data &nbsp; /usr/sbin/apache2 -k start &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 0 &nbsp; &nbsp; 200 &nbsp; 1617 &nbsp; 11164 <br>
479 &nbsp; ntp &nbsp; &nbsp; /usr/sbin/ntpd -p /var/run/ &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 0 &nbsp; 1372 &nbsp; 1658 &nbsp; 4308 <br>
187 &nbsp; postfix &nbsp; qmgr -l -t unix -u &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 0 &nbsp; 1176 &nbsp; 1208 &nbsp; 1620 <br>
635 &nbsp; dbus &nbsp; /usr/bin/dbus-daemon --syst &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; 192 &nbsp; &nbsp; 792 &nbsp; 928 &nbsp; 1612 <br>
<br>

**smem -u** <br>
With the parameter, the swap usage is listed on a per user basis. <br>
**smem -m** <br>
With the parameter, swap usage dump of each PID can be taken. <br>
**smem -p** <br>
With the parameter, PID, user, and used command basis usage is listed show a percentage. <br>
**smem --processfilter="apache"** <br>
apache process can be filtered <br>
<br>
https://linux.die.net/man/8/smem
<br>
<br>
**Conclusion:** In fact, if LastControl reports this situation frequently; <br>
This means that the resource is insufficient for the service provided by the machine. <br>
