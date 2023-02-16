## LastControl-Handbook / User Guide
This document contains details on log4j kullanımı issues.<br>
If Lastcontrol reported an log4j usage, you can use this document.

---
### -Log4j_Usage_Management
---
Log4j is a java logging library. It has a very widespread use. <br>
This use carries risks that can be exploited as described in CVE-2021-44228 <br>

<br>

You can check whether the system log4j library exists as follows.<br>
```
find / -iname "log4j*"
```

Log4j 2.15 and earlier versions are vulnerable to this attack as they contain the corresponding feature. <br>
Log4j 1.x versions do not support JNDI, so it is not affected if the JMSAppender class is not enabled. <br>

<br>

You can check the logs for log4j attack with the following command <br>

```
find /var/log/ -name '*.gz' -type f -exec sh -c "zcat {} | sed -e 's/\${lower://'g | tr -d '}' | egrep -i 'jndi:(ldap[s]?|rmi|dns|nis|iiop|corba|nds|http):'" \;
```

<br>

You must provide configuration and update and fix for the application using the log4j library. <br>
Consider the resources below. <br>
https://en.wikipedia.org/wiki/Log4Shell<br>
https://logging.apache.org/log4j/2.x/security.html<br>
https://www.slf4j.org/log4shell.html<br>
https://reload4j.qos.ch/<br>

<br>

LastControl also performs a log scan on the machine where it detects log4j usage. <br>
From this output, you can see if there has been an attempt to exploit the vulnerability. (general-report LOGs tab) <br>
