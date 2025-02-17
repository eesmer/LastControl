<?php
$jsonFile = '/var/www/html/update_report.json';
$jsonData = file_get_contents($jsonFile);
$updates = json_decode($jsonData, true);
?>
