#!/bin/bash

#---------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------------

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
LOGO=/usr/local/lastcontrol/images/lastcontrol_logo.png
DATE=$(date)

mkdir -p $RDIR

HOST_NAME=$(hostnamectl --static)
RDIR=/usr/local/lcreports/$HOST_NAME
DATE=$(date)

APPS=$(ls /usr/share/applications)

cat > $RDIR/$HOST_NAME-appsreport.md<< EOF

---
title: Installed Applications Report
geometry: "left=3cm,right=3cm,top=0.5cm,bottom=1cm"
---

![]($LOGO){ width=25% }

Date     : $DATE

Hostname : $HOST_NAME

---

Installed Applications
$APPS

---
EOF

cat > $RDIR/$HOST_NAME-appsreport.txt << EOF
====================================================================================================
:::. $HOST_NAME INSTALLED APPLICATIONS REPORT :::.
====================================================================================================
$DATE

----------------------------------------------------------------------------------------------------
INSTALLED APPLICATIONS
----------------------------------------------------------------------------------------------------

EOF

#sed -ns '1F;/^\[Desktop Entry\]/,/^\[/{/^Name=/p;/^Exec=/h};${z;x;G;p}' /usr/share/applications/*.desktop | grep -v "/usr/share/applications/" >> $RDIR/$HOST_NAME-appsreport.txt && sed -i '/^Name=/ s/./- &/' $RDIR/$HOST_NAME-appsreport.txt && sed -i '/^\s*$/d' $RDIR/$HOST_NAME-appsreport.txt

for appslist in /usr/share/applications/*.desktop; do
    sed -ns '/^\[Desktop Entry\]/,/^\[/{/^Name=/p;/^Exec=/h};${z;x;G;p}' "$appslist" | \
    grep -v "/usr/share/applications/" | \
    sed '/^Name=/ s/./- &/' | \
    sed '/^\s*$/d' >> "$RDIR/$HOST_NAME-appsreport.txt"
done


echo "" >> $RDIR/$HOST_NAME-appsreport.txt
echo "====================================================================================================" >> $RDIR/$HOST_NAME-appsreport.txt

cat > $RDIR/$HOST_NAME-appsreport.json << EOF
{
"AppsReport": {
"Installed Apps.": "$APPS"
}
}
EOF
