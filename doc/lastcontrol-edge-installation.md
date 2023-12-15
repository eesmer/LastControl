## LastControl Install
### LastControl Edge
Edge runs locally on the server and produces reports.<br>
You can create and read reports with the CLI provided by Edge.<br>
##### Usage
```bash
wget https://esmerkan.com/lastcontrol/edge/lastcontrol
chmod +x lastcontrol
./lastcontrol
```
```bash
./lastcontrol --help
```
~~~
LastControl CLI
---------------------
Usage: lastcontrol [OPTION]
-----------------------------------------------------
one-shot            Use this to run it once
-----------------------------------------------------
install             Install LastControl
update              Update LastControl App.
version             Show LastControl Version
-----------------------------------------------------
create              Create all System Report
appsreport          Show Application List
directoryreport     Show System Directory Report
diskreport          Show System Disk Report
inventoryreport     Show Inventory Report
kernelreport        Show Kernel Report
localuserreport     Show Local User Report
nwconfigreport      Show Network Config Report
processreport       Show Process Report
servicereport       Show Service Report
sshreport           Show SSH Config Report
suidsgidreport      Show SUID/SGID Report
systemreport        Show System Report
unsecurepackreport  Show UnSecure Pack. List
updatereport        Show Update Report

(example: lastcontrol create)
(example: lastcontrol disk)
(example: lastcontrol localuser)
~~~
