<?php
$jsonData = file_get_contents('/var/www/html/user_report.json');

if ($jsonData === false) {
    echo "Error: Unable to read JSON file!";
    exit;
}

$data = json_decode($jsonData, true);

if ($data === null) {
    echo "Error: JSON data is invalid";
    exit;
}
?>

<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Local User Report</title>
    <link rel="stylesheet" href="style.css">
    <script>
        function filterTable(columnIndex) {
            let input, filter, table, tr, td, i, txtValue;
            input = document.getElementsByClassName("filter-input")[columnIndex];
            filter = input.value.toUpperCase();
            table = document.getElementById("userTable");
            tr = table.getElementsByTagName("tr");

            for (i = 1; i < tr.length; i++) {
                td = tr[i].getElementsByTagName("td")[columnIndex];
                if (td) {
                    txtValue = td.textContent || td.innerText;
                    tr[i].style.display = txtValue.toUpperCase().indexOf(filter) > -1 ? "" : "none";
                }
            }
        }
    </script>
</head>
<body>

<div class="navbar">
    <a href="index.php">🏠 Homepage</a>
</div>

<h1>Local User Report</h1>

<table id="userTable">
    <tr>
        <th>Username<br><input type="text" class="filter-input" onkeyup="filterTable(0)"></th>
        <th>Shell<br><input type="text" class="filter-input" onkeyup="filterTable(1)"></th>
        <th>User Type<br><input type="text" class="filter-input" onkeyup="filterTable(2)"></th>
        <th>SUDO Access<br><input type="text" class="filter-input" onkeyup="filterTable(3)"></th>
        <th>Account Expiry<br><input type="text" class="filter-input" onkeyup="filterTable(4)"></th>
    </tr>
    <?php
    foreach ($data as $user) {
        echo "<tr>";
        echo "<td>" . htmlspecialchars($user['username']) . "</td>";
        echo "<td>" . htmlspecialchars($user['shell']) . "</td>";

        $userTypeClass = ($user['type'] == 'Real User') ? 'real-user' : 'system-user';
        echo "<td class=\"$userTypeClass\">" . htmlspecialchars($user['type']) . "</td>";

        $sudoClass = ($user['sudo_access'] == 'Yes') ? 'yes' : 'no';
        echo "<td class=\"$sudoClass\">" . htmlspecialchars($user['sudo_access']) . "</td>";

        $expiryClass = ($user['account_expires'] == 'Never') ? 'never' : '';
        echo "<td class=\"$expiryClass\">" . htmlspecialchars($user['account_expires']) . "</td>";

        echo "</tr>";
    }
    ?>
</table>

</body>
</html>
