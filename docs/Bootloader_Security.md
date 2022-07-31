## LastControl-Handbook / User Guide
This document contains details on bootloader security.<br>

---
### -Bootloader_SEcurity
---
LastControl checks the system's bootloader against security requirements and generates report.<br>
You can use this document for the settings to be applied according to the Lastcontrol report.<br>
<br>
**What is bootloader?**<br>
Boot Loader is a program located on the MBR or GUID partition that loads the operating system into memory.<br>
The operating system cannot be loaded without the Boot Loader.<br>
<br>
Boot Loader (commonly used GRUB) may be the easiest way to hack Linux systems.<br>
This is done with the following 2 methods;<br>
1- Switching to edit mode using the "e" key on the GRUB screen<br>
2- Using "Recovery Mode"<br>
<br>
Here these 2 functions can be checked to ensure security.<br>
<br>
Some Boot Loader Programs<br>
**LILO:**<br>
The boot loader, which is the solution of the previous era.<br>
Today, there are cases where it is outdated and not compatible with modern needs.<br>
Example: There may be compatibility problems with configurations such as Raid, BTRFS.<br>
LILO is not in development as of 2016.<br>
<br>
**GRUB:**<br>
It is a popular old boot loader that has been replaced by GRUB2.<br>
Today, we can say that GRUB2 is used completely in common distributions.<br>
GRUB does not continue to be developed as GRUB2 has been developed, but bug fixes continue.<br>
On older systems, it is found as a boot loader.<br>
<br>
**GRUB2:**<br>
Post GRUB is the solution. Almost all common distributions today use the GRUB2 bootloader.<br>
<br>
This document contains GRUB2 compatible settings.<br>
<br>
**GRUB2 Security**<br>
**Debian Systems:**<br>
```sh
grub-mkpasswd-pbkdf2
```
The HASH output is the password after the phrase *"PBKDF2 hash of your password is"*.<br>
This output is added to the 40_custom file as follows.<br>
```sh
$ vim /etc/grub.d/40_custom
```
set superusers="root"<br>
password_pbkdf2 root + HASH output (single line)

```sh
grub-mkconfig -o /boot/grub/grub.cfg
```

**RedHat,Centos Systems:**<br>
```sh
grub2-mkpasswd-pbkdf2
```
The HASH output is the password after the phrase *"PBKDF2 hash of your password is"*.<br>
This output is added to the 40_custom file as follows.<br>
```sh
$ vim /etc/grub.d/40_custom
```
set superusers="root"<br>
password_pbkdf2 root + HASH output (single line)

```sh
grub2-mkconfig -o /boot/grub2/grub.cfg
```
<br>
**Conclusion:** It is important to put a superuser and privilege check in the options in the GRUB menu.<br>
Of course, you should review the above settings according to your own system and apply them by backing up.<br>
