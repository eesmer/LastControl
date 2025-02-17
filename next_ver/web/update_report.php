<?php
$jsonFile = '/var/www/html/update_report.json';
$jsonData = file_get_contents($jsonFile);
$updates = json_decode($jsonData, true);
?>

<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Update Report</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>

    <div class="top-bar">
        <a href="index.php" class="home-button">Homepage</a>
        <h1>Update Report</h1>
    </div>
