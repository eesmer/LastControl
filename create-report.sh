#!/bin/bash

#---------------------------------------------------------------
# Lastcontrol, it does not change any settings in the system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#---------------------------------------------------------------

WDIR=/usr/local/lastcontrol
RDIR=/var/www/html/reports
LINE='<hr class="dashed">'
SYSDATE=$(date +%F)
SYSDAY=$(date +%A)
SYSHOUR=$(date +%H:%M)
RDATE="$SYSDATE - $SYSDAY $SYSHOUR"

DBPATH="/usr/local/lastcontrol/db/lastcontrol.sqlite"

#------------------------------------------------------------------------------------
# report files
rm $RDIR/*

cat > $RDIR/mainpage.html << EOF
<!DOCTYPE html>
<html>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; text-align:center;">
LastControl Main Page</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:right;">
<style>
a:link, a:visited {
background-color: #1C1C1C;
color: white;
padding: 5px 10px;
text-align: center;
text-decoration: none;
display: inline-block;
}
a:hover, a:active {
background-color: gray;
}
</style>
<a href="mainpage.html">Main Page</a>
<a href="report.html">Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="cvelist.html">CVE List</a>
<a href="networkscan.html">Network Scan</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/report.html << EOF
<!DOCTYPE html>
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
</head>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; text-align:center;">
LastControl Report</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:right;">
<style>
a:link, a:visited {
background-color: #1C1C1C;
color: white;
padding: 5px 10px;
text-align: center;
text-decoration: none;
display: inline-block;
}
a:hover, a:active {
background-color: gray;
}
</style>
<a href="mainpage.html">Main Page</a>
<a href="report.html">Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="cvelist.html">CVE List</a>
<a href="networkscan.html">Network Scan</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/redlist.html << EOF
<!DOCTYPE html>
<html>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color:Red; text-align:center;">
LastControl Red List</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:right;">
<style>
a:link, a:visited {
background-color: #1C1C1C;
color: white;
padding: 5px 10px;
text-align: center;
text-decoration: none;
display: inline-block;
}
a:hover, a:active {
background-color: gray;
}
</style>
<a href="mainpage.html">Main Page</a>
<a href="report.html">Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="cvelist.html">CVE List</a>
<a href="networkscan.html">Network Scan</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/orangelist.html << EOF
<!DOCTYPE html>
<html>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color:orange; text-align:center;">
LastControl Orange List</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:right;">
<style>
a:link, a:visited {
background-color: #1C1C1C;
color: white;
padding: 5px 10px;
text-align: center;
text-decoration: none;
display: inline-block;
}
a:hover, a:active {
background-color: gray;
}
</style>
<a href="mainpage.html">Main Page</a>
<a href="report.html">Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="cvelist.html">CVE List</a>
<a href="networkscan.html">Network Scan</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/greenlist.html << EOF
<!DOCTYPE html>
<html>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color:green; text-align:center;">
LastControl Green List</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:right;">
<style>
a:link, a:visited {
background-color: #1C1C1C;
color: white;
padding: 5px 10px;
text-align: center;
text-decoration: none;
display: inline-block;
}
a:hover, a:active {
background-color: gray;
}
</style>
<a href="mainpage.html">Main Page</a>
<a href="report.html">Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="cvelist.html">CVE List</a>
<a href="networkscan.html">Network Scan</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/inventory.html << EOF
<!DOCTYPE html>
<html>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color:gray; text-align:center;">
LastControl Inventory</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:right;">
<style>
a:link, a:visited {
background-color: #1C1C1C;
color: white;
padding: 5px 10px;
text-align: center;
text-decoration: none;
display: inline-block;
}
a:hover, a:active {
background-color: gray;
}
</style>
<a href="mainpage.html">Main Page</a>
<a href="report.html">Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="cvelist.html">CVE List</a>
<a href="networkscan.html">Network Scan</a>
</p>
<hr class="solid">
<style>
table, th, td {
border: 5px solid lightgray;
}
</style>
<table id="tblinventory">
<tr>
<th style="text-align:left">MACHINE NAME</th>
<th style="text-align:left">CPU</th>
<th style="text-align:left">RAM</th>
<th style="text-align:left">VGA</th>
<th style="text-align:left">HDD</th>
<th style="text-align:left">Virtualization</th>
<th style="text-align:left">OS</th>
<th style="text-align:left">OS VERSION</th>
</tr>
EOF

cat > $RDIR/cvelist.html << EOF
<!DOCTYPE html>
<html>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color:blue; text-align:center;">
LastControl Kernel Based CVE Check Result</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:right;">
<style>
a:link, a:visited {
background-color: #1C1C1C;
color: white;
padding: 5px 10px;
text-align: center;
text-decoration: none;
display: inline-block;
}
a:hover, a:active {
background-color: gray;
}
</style>
<a href="mainpage.html">Main Page</a>
<a href="report.html">Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="cvelist.html">CVE List</a>
<a href="networkscan.html">Network Scan</a>
</p>
<hr class="solid">
<style>
table, th, td {
border: 5px solid lightgray;
}
</style>
<table id="tblinventory">
<tr>
<th style="text-align:left">MACHINE NAME</th>
<th style="text-align:left">KERNEL VERSION</th>
<th style="text-align:left">CVE CHECK RESULT</th>
</tr>
EOF
#------------------------------------------------------------------------------------

function savedb () {
sqlite3 $DBPATH <<SQL
INSERT INTO report (date, hour, machinename, machinegroup) values ('$SYSDATE', '$SYSHOUR', '$MACHINE', '$MACHINEGROUP');
SQL
}

NUMMACHINE=$(cat $WDIR/hostlist | wc -l)
i=1
ORANGEMACHINE=0
GREENMACHINE=0
REDMACHINE=0
TOTALMACHINE=0
while [ "$i" -le $NUMMACHINE ]; do
    MACHINE=$(ls -l |sed -n $i{p} $WDIR/hostlist)
    ping $MACHINE -c 1 &> /dev/null
    pingReturn=$?

    if [ $pingReturn -eq 0 ]; then
        ssh -p22 -i /root/.ssh/lastcontrol -o "StrictHostKeyChecking no" root@$MACHINE -- exit
        sshReturn=$?
    elif [ $pingReturn -eq 1 ]; then
        echo "<ul><li>Destination Host Unreachable. &nbsp; | &nbsp; $MACHINE $LINE</li></ul>" >> $RDIR/redlist.html && REDMACHINE=$((REDMACHINE+1))
	MACHINEGROUP=RED
	savedb
    elif [ $pingReturn -eq 2 ]; then
        echo "<ul><li>Hostname could not be resolved. &nbsp; | &nbsp; $MACHINE $LINE</li></ul>" >> $RDIR/redlist.html && REDMACHINE=$((REDMACHINE+1))
	MACHINEGROUP=RED
	savedb
    fi

    if [ $pingReturn -eq 0 ] && [ $sshReturn -eq 0 ]; then
	scp -P22 -i /root/.ssh/lastcontrol $WDIR/lastcontrol.sh root@$MACHINE:/tmp/
	scp -P22 -i /root/.ssh/lastcontrol $WDIR/cve_check root@$MACHINE:/tmp/
        ssh -p22 -i /root/.ssh/lastcontrol root@$MACHINE -- bash /tmp/lastcontrol.sh
        scp -P22 -i /root/.ssh/lastcontrol root@$MACHINE:/tmp/$MACHINE.txt $RDIR/

        UPDATE_CHECK=$(perl -ne'15..15 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        UPTIME=$(perl -ne'17..17 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        # for inventory.html
        MACHINE_NAME=$(perl -ne'6..6 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        CPU=$(perl -ne'8..8 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        RAM=$(perl -ne'9..9 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        VGA=$(perl -ne'10..10 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        HDD=$(perl -ne'11..11 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        VIRT=$(perl -ne'12..12 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        OS=$(perl -ne'13..13 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        OS_VER=$(perl -ne'14..14 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	LAST_BOOT=$(perl -ne'16..16 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	NUMPROCESS=$(perl -ne'19..19 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	INVCHECK=$(perl -ne'22..22 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	CVE_LIST=$(perl -ne'26..26 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	KERNEL_VER=$(perl -ne'24..24 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)

        # create cvelist.html
	echo "<tr>" >> $RDIR/cvelist.html
	echo "<td>$MACHINE_NAME</td>" >> $RDIR/cvelist.html
	echo "<td>$KERNEL_VER</td>" >> $RDIR/cvelist.html
	echo "<td>$CVE_LIST</td>" >> $RDIR/cvelist.html

	# create inventory.html
        echo "<tr>" >> $RDIR/inventory.html
        echo "<td>$MACHINE_NAME</td>" >> $RDIR/inventory.html
        echo "<td>$CPU</td>" >> $RDIR/inventory.html
        echo "<td>$RAM</td>" >> $RDIR/inventory.html
        echo "<td>$VGA</td>" >> $RDIR/inventory.html
        echo "<td>$HDD</td>" >> $RDIR/inventory.html
        echo "<td>$VIRT</td>" >> $RDIR/inventory.html
        echo "<td>$OS</td>" >> $RDIR/inventory.html
        echo "<td>$OS_VER</td>" >> $RDIR/inventory.html
        echo "</tr>" >> $RDIR/inventory.html

        # create OrangeList & GreenList
        if [ $UPDATE_CHECK = EXIST ] || [ $INVCHECK = DETECTED ] || [ ! -z "$CVE_LIST" ]; then
            echo "<ul><li><a href=report.html#$MACHINE>Details</a>  &nbsp; | &nbsp; $MACHINE_NAME $LINE</li></ul>" >> $RDIR/orangelist.html && ORANGEMACHINE=$((ORANGEMACHINE+1))
	    MACHINEGROUP=ORANGE
	    savedb
        elif [ $UPDATE_CHECK = NONE ] || [ $INVCHECK = NOTDETECTED ] || [ -z "$CVE_LIST" ]; then
	    echo "<ul><li><a href=report.html#$MACHINE>Details</a>  &nbsp; | &nbsp; $MACHINE_NAME $LINE</li></ul>" >> $RDIR/greenlist.html && GREENMACHINE=$((GREENMACHINE+1))
	    MACHINEGROUP=GREEN
	    savedb
        fi

        echo "<h2 id="'"'$MACHINE'"'">$MACHINE</h2>| &nbsp; <a href=$MACHINE.txt>More</a>&nbsp; | &nbsp;<br><br>" >> $RDIR/report.html && TOTALMACHINE=$((TOTALMACHINE+1))
        echo "$OS &nbsp; | &nbsp; $OS_VER <br>" >> $RDIR/report.html
        echo "<b>Uptime:</b> $UPTIME <br>" >> $RDIR/report.html
        echo "<b>Update Check:</b> $UPDATE_CHECK <br>" >> $RDIR/report.html
        echo "<b>Number of Running Process:</b> $NUMPROCESS <br>" >> $RDIR/report.html
        echo "<b>CVE Check:</b> $CVE_LIST <br>" >> $RDIR/report.html
        echo "<b>Inventory Check:</b> $INVCHECK <br>" >> $RDIR/report.html
        echo "$LINE <br>" >> $RDIR/report.html
        echo "$LINE <br>" >> $RDIR/report.html

    elif [ $sshReturn -eq 255 ]; then
        echo "<ul><li>Connection request has been rejected. &nbsp; | &nbsp; $MACHINE $LINE</li></ul>" >> $RDIR/redlist.html && REDMACHINE=$((REDMACHINE+1))
	MACHINEGROUP=RED
	savedb
    elif [ $sshReturn -eq 130 ]; then
        echo "<ul><li>Permission denied. &nbsp; | &nbsp; $MACHINE $LINE</li></ul>" >> $RDIR/redlist.html && REDMACHINE=$((REDMACHINE+1))
	MACHINEGROUP=RED
	savedb
    fi

i=$(( i + 1 ))
done

TOTALMACHINE=$((TOTALMACHINE+REDMACHINE))
SCORE=$((200 * $GREENMACHINE/$TOTALMACHINE -  100 * $GREENMACHINE/$TOTALMACHINE ))

cat >> $RDIR/mainpage.html << EOF
<p style="color: #088A08; font-size: 22px; font-weight: bold; text-align: left;">
Green Machine: &nbsp; &nbsp; &nbsp; $GREENMACHINE</p>
<p style="color: #FF8000; font-size: 22px; font-weight: bold; text-align: left;">
Orange Machine: &nbsp; &nbsp; $ORANGEMACHINE</p>
<p style="color: #FF0000; font-size: 22px; font-weight: bold; text-align:left;">
Red Machine: &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; $REDMACHINE</p>
<hr class="solid">
<p style="color: #000000; font-size: 22px; font-weight: bold; text-align:left;">
Total Machine: &nbsp; &nbsp; &nbsp; &nbsp; $TOTALMACHINE</p>
<p style="color: #4B088A; font-size: 45px; font-weight: bold; text-align:center;">
SCORE <br>
% $SCORE </p>
EOF

echo "</table>" >> $RDIR/inventory.html
echo "</body>" |tee -a $RDIR/report.html $RDIR/redlist.html $RDIR/orangelist.html $RDIR/greenlist.html $RDIR/inventory.html $RDIR/mainpage.html >/dev/null
echo "</html>" |tee -a $RDIR/report.html $RDIR/redlist.html $RDIR/orangelist.html $RDIR/greenlist.html $RDIR/inventory.html $RDIR/mainpage.html >/dev/null

#----------------
# network scan
#----------------
#SRVSUBNET=$(ip r |grep link |grep proto |cut -d' ' -f1)
#nmap -Pn -F -oX /tmp/networkscan.xml $SRVSUBNET
#xsltproc /tmp/networkscan.xml -o /tmp/networkscan.html && cp /tmp/networkscan.html /var/www/html/reports/

#cat > /tmp/buttons.txt << EOF
#<p style="text-align:right;">
#<style>
#a:link, a:visited {
#background-color: #1C1C1C;
#color: white;
#padding: 5px 10px;
#text-align: center;
#text-decoration: none;
#display: inline-block;
#}
#a:hover, a:active {
#background-color: gray;
#}
#</style>
#<a href="mainpage.html">Main Page</a>
#<a href="report.html">Report</a>
#<a href="redlist.html">Red List</a>
#<a href="orangelist.html">Orange List</a>
#<a href="greenlist.html">Green List</a>
#<a href="inventory.html">Inventory List</a>
#<a href="networkscan.html">Network Scan</a>
#</p>
#<hr class="solid">
#EOF

#sed -i $'/1>Nmap Scan Report/{e cat /tmp/buttons.txt\n}' /var/www/html/reports/networkscan.html
#sed -i 's/href="javascript:togglePorts'//g /var/www/html/reports/networkscan.html
