#!/bin/bash

if command -v ss >/dev/null; then
    PORTS=$(ss -tln | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -nu | tr '\n' ',' | sed 's/,$//')
else
    PORTS=$(netstat -tln | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -nu | tr '\n' ',' | sed 's/,$//')
fi

REPORT_JSON=$(jq -n \
  --arg org "system_info_ports" \
  --arg hn "$(hostname)" \
  --arg data "$PORTS" \
  '{
    origin: $org,
    hostname: $hn,
    info_data: $data
  }')

echo "$REPORT_JSON"

