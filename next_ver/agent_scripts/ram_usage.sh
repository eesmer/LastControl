#!/bin/bash
RAM_TOTAL=$(free -m | awk '/Mem:/ {print $2}')
RAM_USED=$(free -m | awk '/Mem:/ {print $3}')
RAM_PERC=$(( RAM_USED * 100 / RAM_TOTAL ))
SWAP_TOTAL=$(free -m | awk '/Swap:/ {print $2}')
SWAP_USED=$(free -m | awk '/Swap:/ {print $3}')
SWAP_PERC=0
[ $SWAP_TOTAL -gt 0 ] && SWAP_PERC=$(( SWAP_USED * 100 / SWAP_TOTAL ))

DATA="{\"ram_total\": \"$RAM_TOTAL\", \"ram_used\": \"$RAM_USED\", \"ram_perc\": \"$RAM_PERC\", \"swap_total\": \"$SWAP_TOTAL\", \"swap_used\": \"$SWAP_USED\", \"swap_perc\": \"$SWAP_PERC\"}"

jq -c -n --arg org "system_info_ram" --arg hn "$(hostname)" --arg data "$DATA" \
'{origin: $org, hostname: $hn, info_data: $data}'

