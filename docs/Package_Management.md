## LastControl-Handbook / User Guide
This document contains details on managing package install and remove issues.<br>
If Lastcontrol reported an package check problem, you can use this document.

--- 
### -Package_Management
---
If LastControl reported corrupt packages on the system; <br>
these broken packages should be installed or removed without any problems. <br>
Otherwise, there will be a problem with the package installation or update process. <br>
<br>
Package installations on Linux systems should be done with distribution-specific package managers. (from the repository and with apt or yum,dnf) <br>
Package managers ensure that the process is done properly by fixing dependency and installation problems or by specifying if there is an obstacle to installation. <br>
In some exceptional cases; if the installation or uninstallation is causing problems and no fix is made, it will refuse to do a new install permanently (until it is fixed). This is for system stability. <br>

In such a case, a new installation or update may not be possible. <br>
This is caused by manual installation or uninstalling/deleting without using the package manager. <br>

Therefore it is important to install, uninstall and update from the distribution's repository. <br>
Thus, a stable system is used with the skill of the package manager. (unconsciously .deb or .rpm package installs) <br>

When you receive this notification, you can take the following actions. <br>

<br>

**Debian based systems** <br>
```sh
$ apt --fix-missing update
```
You can try to fix the installation problem with the command. Also, apt update should output fine. <br>
```sh
$ apt install -f
```
command searches the system for broken packages and tries to fix them. <br>

One can also use dpkg. <br>
```sh
$ dpkg --configure -a
```
Packages that have been opened but need to be configured are checked and the configuration is attempted to be completed. <br>
```sh
$ dpkg -l | grep ^..r
```
Packages marked with a configuration requirement are listed. <br>
If this command gives a output, it must be corrected. <br>
On non-problem systems this command should output blank. <br>
```sh
$ dpkg --remove --force-remove-reinstreq
```
Attempts to delete all corrupted packages. <br>
<br>
**RedHat based systems** <br>
```sh
$ rpm -Va
```
All packages in the system are checked. <br>
```sh
$ dnf --refresh reinstall $PACKAGE_NAME
```
Reinstallation is attempted for the broken package. <br>
<br>
**Conclusion:** Package managers are pretty good for hassle-free package installation and removal. <br>
Do not install from random .deb or .rpm packages.<br>
<br>
E.g; Installation of .deb or .rpm packages cannot be updated with the distribution's package manager. <br>
If there are such manual installations in the system, since manual installations cannot be updated after 1-2 updates with the package manager, all packages will not be synchronized and installation / uninstallation / update problems will occur in the system. <br>
