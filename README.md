![alt text](screenshot/lastcontrol_logo.png "LastControl")
<br>

LastControl is a work around for health checking on linux machines. <br>
**distributions that are compatible and tested as a client:** Debian, Ubuntu, Centos, RedHat, Oracle Linux

## Features
- Checks for updates
- Looks at running services and load status
- Takes out inventory
- Checks configurations according to hardening policies. https://www.cisecurity.org/
- It scans for kernel-based exploits and CVE Ref. gives https://github.com/InteliSecureLabs/Linux_Exploit_Suggester
- It only performs a fast scan with nmap on the subnet.
- All these outputs with a web page; It shows the reports on a single screen by categorizing the machines as 'red' 'green' and 'orange'

## Requirements
It works in Debian environment. Desktop environment is not required.

### Installation and Usage
Use LastControl with root user
```sh
$ wget https://raw.githubusercontent.com/eesmer/LastControl/main/lastcontrol-installer.sh
$ bash lastcontrol-installer.sh
```
![alt text](screenshot/LastControl_main_page.png "LastControl Main Page")

**Access Page:** http://$LASTCONTROL_IP

#### add/remove machine
```sh
$ vim /usr/local/lastcontrol/hostlist
```
In this file, one machine is written per line.<br>
Each machine must be written with the machine name.
(example: debianhost1, client_99) <br>
<br>
LastControl should be able to reach the target machine by hostname.
If you cannot use DNS;<br>
Add the target machine to the **/etc/hosts file** on the LastControl machine.

##### install ssh-key (lastcontrol.pub)
LastControl uses ssh-key to access machines. The ssh-key file is created during the installation of the LastControl machine.<br>
You can install the LastControl ssh-key file as follows to access the added machines.
```sh
$ wget http://$LASTCONTROL_IP/lastcontrol/lastcontrol.pub
$ cat lastcontrol.pub >> /root/.ssh/authorized_keys
```

#### How it works
It runs periodically every 3 hours.<br>
If you want to trigger the operation manually;<br>
```sh
$ systemctl restart lastcontrol.service
```
