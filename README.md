![alt text](doc/images/lastcontrol_logo.png "LastControl")
<br>

LastControl performs hardening and health checks on Linux systems.<br>
After the check, it prints a summary report on the screen and creates a detailed machine report.<br>
<br>
You can use the LastControl application in 2 ways;<br>
- Performing checks on the local machine
- Control of remote machines and collection of reports with server mode

<br>

**It is compatible with the following distributions and can generate reports** <br>
Debian, Ubuntu, Centos, RedHat, Fedora, Oracle Linux, Rocky Linux<br>

<br>

All checks are made according to CIS Benchmark bulletins.<br>
https://www.cisecurity.org/

---

bash lastcontrol.sh [OPTION] <br>

| Option           | Description                                                |
| :--------------- | :--------------------------------------------------------- |
| --help           | show this help message                                     |
| --localhost      | It controls the server (local machine) you are running on  |
| --server-config  | It installs the LastControl as a server                    |

---

## Help

[Usage](https://github.com/eesmer/LastControl/blob/main/lastcontrol-handbook.md)
