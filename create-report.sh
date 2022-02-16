#!/bin/bash

#----------------------------------------------------------------------
# Lastcontrol, it does not change any settings in the target system.
# It just checks and outputs.
# However, it is your responsibility to run it on any system.
#----------------------------------------------------------------------

WDIR=/usr/local/lastcontrol
RDIR=/tmp/reports
LINE='<hr class="dashed">'
SYSDATE=$(date +%F)
SYSDAY=$(date +%A)
SYSHOUR=$(date +%H:%M)
RDATE="$SYSDATE - $SYSDAY $SYSHOUR"

DBPATH="/usr/local/lastcontrol/db/lastcontrol.sqlite"

#------------------------------------------------------------------------------------
# report files
rm -r $RDIR
mkdir -p $RDIR

cat > $RDIR/mainpage.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>LastControl Mainpage</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
</head>
<body>
<p style="color: #000000; font-size: 30px; font-weight: bold; text-align:center;">
LastControl Main Page</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:left;">
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
<a href="generalreport.html">General Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="networkscan.html">Network Scan</a>
<a href="history.php">History</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/redlist.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>LastControl Red List</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
</head>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color: #df1c44; text-align:center;">
LastControl Red List</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:left;">
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
<a href="generalreport.html">General Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="networkscan.html">Network Scan</a>
<a href="history.php">History</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/orangelist.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>LastControl Orange List</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
</head>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color: #E65100; text-align:center;">
LastControl Orange List</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:left;">
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
<a href="generalreport.html">General Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="networkscan.html">Network Scan</a>
<a href="history.php">History</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/greenlist.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>LastControl Green List</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
</head>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color: #1B5E20; text-align:center;">
LastControl Green List</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:left;">
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
<a href="generalreport.html">General Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="networkscan.html">Network Scan</a>
<a href="history.php">History</a>
</p>
<hr class="solid">
EOF

cat > $RDIR/inventory.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>LastControl Inventory List</title>
</head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color: #607D8B; text-align:center;">
LastControl Inventory</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:left;">
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
<a href="generalreport.html">General Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="networkscan.html">Network Scan</a>
<a href="history.php">History</a>
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
<th style="text-align:left">OS</th>
<th style="text-align:left">OS VERSION</th>
</tr>
EOF

cat > $RDIR/generalreport.html << EOF
<!DOCTYPE html>
<html>
<head>
<title>LastControl General Report</title>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
</head>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color:#03A9F4; text-align:center;">
LastControl General Report</p>
<p style="text-align:center;">$RDATE</p>
<p style="text-align:left;">
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
<a href="generalreport.html">General Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="networkscan.html">Network Scan</a>
<a href="history.php">History</a>
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
<th style="text-align:left">LOGs</th>
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
#TOTALMACHINE=0
while [ "$i" -le "$NUMMACHINE" ]; do
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
	scp -P22 -i /root/.ssh/lastcontrol $WDIR/chkrootkit/chkrootkit root@$MACHINE:/tmp/
        ssh -p22 -i /root/.ssh/lastcontrol root@$MACHINE -- bash /tmp/lastcontrol.sh
        scp -P22 -i /root/.ssh/lastcontrol root@$MACHINE:/tmp/$MACHINE.txt $RDIR/
        scp -P22 -i /root/.ssh/lastcontrol root@$MACHINE:/tmp/$MACHINE.log $RDIR/

        UPDATE_CHECK=$(perl -ne'16..16 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        UPTIME=$(perl -ne'19..19 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        # for inventory.html
        MACHINE_NAME=$(perl -ne'6..6 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        IP_ADDRESS=$(perl -ne'7..7 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        CPU=$(perl -ne'9..9 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        RAM=$(perl -ne'10..10 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        VGA=$(perl -ne'11..11 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        HDD=$(perl -ne'12..12 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        VIRT=$(perl -ne'13..13 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        OS=$(perl -ne'14..14 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
        OS_VER=$(perl -ne'15..15 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	LAST_BOOT=$(perl -ne'18..18 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	NUMPROCESS=$(perl -ne'21..21 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	INVCHECK=$(perl -ne'38..38 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	CVE_LIST=$(perl -ne'45..45 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	KERNEL_VER=$(perl -ne'41..41 and print' $RDIR/$MACHINE.txt | cut -d '|' -f3)
	
	# create inventory.html
        echo "<tr>" >> $RDIR/inventory.html
        echo "<td>$MACHINE_NAME</td>" >> $RDIR/inventory.html
        echo "<td>$CPU</td>" >> $RDIR/inventory.html
        echo "<td>$RAM</td>" >> $RDIR/inventory.html
        echo "<td>$VGA</td>" >> $RDIR/inventory.html
        echo "<td>$HDD</td>" >> $RDIR/inventory.html
        echo "<td>$OS</td>" >> $RDIR/inventory.html
        echo "<td>$OS_VER</td>" >> $RDIR/inventory.html
        echo "</tr>" >> $RDIR/inventory.html

	# create generalreport.html
	echo "<tr>" >> $RDIR/generalreport.html
	echo "<td><a href=$MACHINE.txt>$MACHINE</a></td>" >> $RDIR/generalreport.html
        echo "<td>$KERNEL_VER</td>" >> $RDIR/generalreport.html
        echo "<td>$CVE_LIST</td>" >> $RDIR/generalreport.html

	# create OrangeList & GreenList
	SYS_SCORE=$(echo $SYS_SCORE |cut -d "/" -f1)
	NW_SCORE=$(echo $NW_SCORE |cut -d "/" -f1)
	SSH_SCORE=$(echo $SSH_SCORE |cut -d "/" -f1)
        if [ $UPDATE_CHECK = "EXIST" ] || [ $INVCHECK = "DETECTED" ] || [ ! -z $CVE_LIST ]; then
            echo "<ul><li><a href=$MACHINE.txt>Details</a>  &nbsp; | &nbsp; $MACHINE_NAME $LINE</li></ul>" >> $RDIR/orangelist.html && ORANGEMACHINE=$((ORANGEMACHINE+1))
	    MACHINEGROUP=ORANGE
	    savedb

		# generalreport.html
		echo "<td>" >> $RDIR/generalreport.html
		LOGSLINE=$(cat $RDIR/$MACHINE.log | wc -l)
		m=1
		while [ "$m" -le "$LOGSLINE" ]; do
		CURRENTLINE=$(ls -l |sed -n $m{p} $RDIR/$MACHINE.log)
		echo "$CURRENTLINE <br>" >> $RDIR/generalreport.html
		m=$(( m + 1 ))
		done
		echo "</td>" >> $RDIR/generalreport.html
		echo "</tr>" >> $RDIR/generalreport.html

	elif [ $UPDATE_CHECK = "NONE" ] || [ $INVCHECK = "NOTDETECTED" ] || [ -z $CVE_LIST ]; then
	    echo "<ul><li><a href=$MACHINE.txt>Details</a>  &nbsp; | &nbsp; $MACHINE_NAME $LINE</li></ul>" >> $RDIR/greenlist.html && GREENMACHINE=$((GREENMACHINE+1))
	    MACHINEGROUP=GREEN
	    savedb
	    
		# generalreport.html
		echo "<td>" >> $RDIR/generalreport.html
		LOGSLINE=$(cat $RDIR/$MACHINE.log | wc -l)
		m=1
		while [ "$m" -le "$LOGSLINE" ]; do
		CURRENTLINE=$(ls -l |sed -n $m{p} $RDIR/$MACHINE.log)
		echo "$CURRENTLINE <br>" >> $RDIR/generalreport.html
		m=$(( m + 1 ))
		done
		echo "</td>" >> $RDIR/generalreport.html
		echo "</tr>" >> $RDIR/generalreport.html
	fi
	
    elif [ $sshReturn -eq "255" ]; then
        echo "<ul><li>Connection request has been rejected. &nbsp; | &nbsp; $MACHINE $LINE</li></ul>" >> $RDIR/redlist.html && REDMACHINE=$((REDMACHINE+1))
	MACHINEGROUP=RED
	savedb
    elif [ $sshReturn -eq "130" ]; then
        echo "<ul><li>Permission denied. &nbsp; | &nbsp; $MACHINE $LINE</li></ul>" >> $RDIR/redlist.html && REDMACHINE=$((REDMACHINE+1))
	MACHINEGROUP=RED
	savedb
    fi

i=$(( i + 1 ))
done

TOTALMACHINE=0
TOTALMACHINE=$(($GREENMACHINE+$ORANGEMACHINE+$REDMACHINE))
GREEN_SCORE=$((100 * $GREENMACHINE/$TOTALMACHINE))
ORANGE_SCORE=$((100 * $ORANGEMACHINE/$TOTALMACHINE))
RED_SCORE=$((100 * $REDMACHINE/$TOTALMACHINE))

cat >> $RDIR/mainpage.html << EOF
<p style="color: #088A08; font-size: 30px; font-weight: bold; text-align:left;">
Green Machine: &nbsp; &nbsp; &nbsp; $GREENMACHINE &nbsp; &nbsp; &nbsp; Score: %$GREEN_SCORE </p>
<p style="color: #FF8000; font-size: 30px; font-weight: bold; text-align:left;">
Orange Machine: &nbsp; &nbsp; $ORANGEMACHINE &nbsp; &nbsp; &nbsp; Score: %$ORANGE_SCORE </p>
<p style="color: #FF0000; font-size: 30px; font-weight: bold; text-align:left;">
Red Machine: &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; $REDMACHINE &nbsp; &nbsp; &nbsp; Score: %$RED_SCORE </p>
<hr class="solid">
<p style="color: #000000; font-size: 30px; font-weight: bold; text-align:left;">
Total Machine: &nbsp; &nbsp; &nbsp; &nbsp; $TOTALMACHINE</p>
<hr class="solid">
EOF

echo "</table>" >> $RDIR/inventory.html
echo "</table>" >> $RDIR/generalreport.html
echo "</body>" |tee -a $RDIR/redlist.html $RDIR/orangelist.html $RDIR/greenlist.html $RDIR/inventory.html $RDIR/generalreport.html $RDIR/mainpage.html >/dev/null
echo "</html>" |tee -a $RDIR/redlist.html $RDIR/orangelist.html $RDIR/greenlist.html $RDIR/inventory.html $RDIR/generalreport.html $RDIR/mainpage.html >/dev/null

rm -r /var/www/html/reports
mkdir -p /var/www/html/reports
cp $WDIR/history/history.php $RDIR/
RDIR=/var/www/html/reports
cp /tmp/reports/* $RDIR/

#----------------
# network scan
#----------------
SRVSUBNET=$(ip r |grep link |grep proto |cut -d' ' -f1)
nmap -Pn -F -oX /tmp/networkscan.xml $SRVSUBNET
xsltproc /tmp/networkscan.xml -o /tmp/networkscan.html && cp /tmp/networkscan.html $RDIR/

cat > /tmp/buttons.txt << EOF
<p style="text-align:left;">
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
CVE Lisund-color: gray;
}
</style>
<a href="mainpage.html">Main Page</a>
<a href="generalreport.html">General Report</a>
<a href="redlist.html">Red List</a>
<a href="orangelist.html">Orange List</a>
<a href="greenlist.html">Green List</a>
<a href="inventory.html">Inventory List</a>
<a href="networkscan.html">Network Scan</a>
<a href="history.php">History</a>
</p>
<hr class="solid">
EOF

sed -i $'/1>Nmap Scan Report/{e cat /tmp/buttons.txt\n}' $RDIR/networkscan.html && rm /tmp/buttons.txt
sed -i 's/href="javascript:togglePorts'//g $RDIR/networkscan.html
