## LastControl-Handbook / User Guide
The document contains detailed information about the use for the LastControl
- [1. Installation and Usage](#1-installation)
- [2. Reporting](#2-reporting)<br>
  For the results in the LastControl report, the following headings guide the solution.<br>
  - [Memory Usage Management](#-memory_usage_management)<br>
  - [Bootloader Security](#-bootloader_security)<br>
  - [Disk Usage Management](#-disk_usage_management)<br>
  - [Update Management](#-update_management)<br>
  - [Package Management](#-package_management)<br>
  - [Log4j Usage Management](#-log4j_usage_management)<br>
---

## 1. Installation

**Requirements**<br>
It works in Debian environment. Desktop environment is not required.<br>

**Installation**<br>
Use LastControl with root user
```sh
$ wget https://raw.githubusercontent.com/eesmer/LastControl/main/install/lastcontrol-installer.sh
$ bash lastcontrol-installer.sh
```
**Usage**<br>
**Access Page:** http://$LASTCONTROL_IP

**add/remove machine**
```sh
$ vim /usr/local/lastcontrol/linuxmachine
```
In this file, one machine is written per line.<br>
Each machine must be written with the machine name.
(example: debianhost1, client_99) <br>
<br>
LastControl should be able to reach the target machine by hostname.
If you cannot use DNS;<br>
Add the target machine to the **/etc/hosts file** on the LastControl machine.

**install ssh-key (lastcontrol.pub)**
LastControl uses ssh-key to access machines. The ssh-key file is created during the installation of the LastControl machine.<br>
You can install the LastControl ssh-key file as follows to access the added machines.
```sh
$ wget http://$LASTCONTROL_IP/lastcontrol/lastcontrol.pub
$ cat lastcontrol.pub >> /root/.ssh/authorized_keys
```
**How it works**<br>
It runs periodically every 3 hours.<br>
If you want to trigger the operation manually;<br>
```sh
$ systemctl restart lastcontrol.service
```

## 2. Reporting
---
### -Memory_Usage_Management
---
LastControl reports if the system's memory usage is greater than 50%. <br>
<br>
[Read More](https://github.com/eesmer/LastControl/blob/main/docs/Memory_usage_Management.md)

---
### -Boot_Loader_Security
---
LastControl checks the system's bootloader against security requirements and generates report. <br>
<br>
[Read More](https://github.com/eesmer/LastControl/blob/main/docs/Bootloader_Security.md)

---
### -Disk_Usage_Management
---
LastControl reports if the disk usage on which the system is installed is more than 50%. <br>
You should check the system or increase the space in case the remaining disk size is running out quickly. <br>
<br>
[Read More](https://github.com/eesmer/LastControl/blob/main/docs/Disk_usage_Management.md)

---
### -Update_Management
---
If LastControl has reported that the system has an update system update is required. <br>
Systems that have not been updated for a long time cause problems in version transitions. <br>
<br>
[Read More](https://github.com/eesmer/LastControl/blob/main/docs/Update_Management.md)

---
### -Package_Management
---
If LastControl reported corrupt packages on the system; <br>
these broken packages should be installed or removed without any problems. <br>
Otherwise, there will be a problem with the package installation or update process. <br>
<br>
[Read More](https://github.com/eesmer/LastControl/blob/main/docs/Package_Management.md)

---
### -Log4j_Usage_Management
---
Log4j is a java logging library. It has a very widespread use. <br>
This use carries risks that can be exploited as described in CVE-2021-44228 <br>
<br>
[Read More](https://github.com/eesmer/LastControl/blob/main/docs/Log4j_usage_Management.md)

