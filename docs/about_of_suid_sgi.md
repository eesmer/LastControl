## LastControl-Handbook / User Guide
This document contains details and manage on suid and sgid file,directories.<br>

---
### -SUID,SGID files and management of this process
---
In Linux systems, the executable file takes over the privileges of the user running it.<br>
Example: If the user does not have access to the /var/log/messages file, executable (even if the file owner is root)<br>
cannot access this file when run with this user.<br>
In this case, you need to run the program with a user authority that you can access.<br>
