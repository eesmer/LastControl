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

    <table>
        <thead>
            <tr>
                <th>Package Name</th>
                <th>Current Version</th>
            </tr>
        </thead>
        <tbody>
            <?php if (isset($updates['updates']) && !empty($updates['updates'])): ?>
                <?php foreach ($updates['updates'] as $update): ?>
                    <tr>
                        <td><?= htmlspecialchars($update['package']) ?></td>
                        <td><?= htmlspecialchars($update['current_version']) ?></td>
                    </tr>
                <?php endforeach; ?>
            <?php else: ?>
                <tr><td colspan="2">Update Not Found</td></tr>
            <?php endif; ?>
        </tbody>
    </table>

</body>
</html>
