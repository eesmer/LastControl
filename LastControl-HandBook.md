## LastControl-Handbook / User Guide
The document contains detailed information about the use for the LastControl
- [1. Installation and Usage](#1-installation)
- [2. Documentation](#)<br>
  For the results in the LastControl report, the following headings guide the solution.<br>
  - [Bootloader Security](https://github.com/eesmer/LastControl/blob/main/docs/Bootloader_Security.md)<br>
  - [Memory Usage Management](https://github.com/eesmer/LastControl/blob/main/docs/Memory_usage_Management.md)<br>
  - [Disk Usage Security](https://github.com/eesmer/LastControl/blob/main/docs/Disk_usage_Management.md)<br>
  - [Update Management](https://github.com/eesmer/LastControl/blob/main/docs/Update_Management.md)<br>
  - [Package Management](https://github.com/eesmer/LastControl/blob/main/docs/Package_Management.md)<br>
  - [Management of Local Accounts](https://github.com/eesmer/LastControl/blob/main/docs/Management_of_LocalAccounts.md)<br>
  - [Log4j Usage Management](https://github.com/eesmer/LastControl/blob/main/docs/Log4j_usage_Management.md)
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

**install ssh-key (lastcontrol.pub)**<br>
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
