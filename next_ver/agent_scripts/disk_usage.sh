#!/bin/bash
DISK_DATA=$(df -h | grep '^/dev/' | awk '{print $1"|"$2"|"$3"|"$5}' | tr '\n' ',' | sed 's/,$//')

# -c parametresi JSON'ı tek satıra sıkıştırır, boşlukları siler
jq -c -n \
  --arg org "system_info_disk" \
  --arg hn "$(hostname)" \
  --arg data "$DISK_DATA" \
  '{origin: $org, hostname: $hn, info_data: $data}'
