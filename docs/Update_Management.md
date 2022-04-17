## LastControl-Handbook / User Guide
This document contains details on managing update issues.<br>
If Lastcontrol reported an update problem, you can use this document.

---
### -Update_Management
---
If LastControl has reported that the system has an update system update is required. <br>
Systems that have not been updated for a long time cause problems in version transitions. <br>
<br>
In addition; It is very important to use the new packages and the ones that have been corrected according to some problems in the system.(for security and stability) <br>
In that case; Continuous Update <br>

<br>

Only Windows users don't care and are afraid to update. <br>
They usually do not have an update plan. <br>

Configuration or customization may be preventing you from updating the system. <br>
Attention!! The longer this goes on, the bigger the problem. <br>
  
<br>
  
**Update Check** <br>
On Debian based systems; <br>
```sh
$ apt list --upgradable
```
On RedHat based systems; <br>
```sh
$ yum check-update or dnf check-update
```
**Update Command**

---

On Debian based systems; <br>
```sh
$ apt update && apt upgrade
```
**apt dist-upgrade vs apt full-upgrade** <br>
**apt dist-upgrade:** <br>
It updates the operating system by upgrading existing packages to be updated without installing additional packages. <br>
That is, all upgrades where the dependencies do not change are applied. <br>
<br>
If you are not doing a major upgrade, you can do a minor upgrade with a dist-upgrade.<br>
For example from version 10.1 to version 10.2<br>
You don't need to use full-upgrade for this process.<br>

**apt full-upgrade:** <br>
If installing new packages conflicts with existing packages, it updates the system by removing existing packages ans installing new ones.<br>
<br>
If there is a major version transition; You can switch major versions with apt full-upgrade.<br>
For example from version 10 to version 11<br>

---

On RedHat based systems; <br>
```sh
$ dnf update or yum update
```
