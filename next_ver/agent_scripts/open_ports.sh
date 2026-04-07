#!/bin/bash

# Sadece dinlenen (LISTEN) TCP portlarını çekiyoruz
if command -v ss >/dev/null; then
    # ss komutu ile hızlıca çekip virgülle ayırıyoruz
    PORTS=$(ss -tln | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -nu | tr '\n' ',' | sed 's/,$//')
else
    # ss yoksa netstat kullanıyoruz
    PORTS=$(netstat -tln | grep LISTEN | awk '{print $4}' | awk -F: '{print $NF}' | sort -nu | tr '\n' ',' | sed 's/,$//')
fi

# JSON formatında çıktı
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

