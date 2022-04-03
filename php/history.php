<!DOCTYPE html>
<html>
<head>
<title>LastControl History</title>
</head>
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8"/>
<body>
<p style="color: #000000; font-size: 25px; font-weight: bold; background-color:yellow; text-align:center;">
LastControl History</p>
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
<a href="cvelist.html">CVE List</a>
<a href="machine-report.html">Machine Report</a>
<a href="networkscan.html">Network Scan</a>
<a href="history.php">History</a>
</p>
<hr class="solid">
<style>
table, th, td {
border: 5px solid lightgray;
}
</style>

<?php
class MyDB extends SQLite3 {
	function __construct() {
	$this ->open('/usr/local/lastcontrol/db/lastcontrol.sqlite');
	}
}

$db = new MyDB();
$sql =<<<EOF
SELECT * FROM report ORDER BY date DESC;
EOF;

$ret = $db->query($sql);
while($row = $ret->fetchArray(SQLITE3_ASSOC) ) {
	echo "--------------------------------------" . "<br>" ;
	echo "DATE = ". $row['date'] . "<br>";
	echo "--------------------------------------" . "<br>" ;
	echo "HOUR = ". $row['hour'] . "<br>" ;
	echo "MACHINE NAME = ". $row['machinename'] . "<br>" ;
echo "MACHINE GROUP = ". $row['machinegroup'] . "<br>" ;
echo "--------------------------------------" . "<br>" ;
}
$db->close();
?>

</body>
</html>
