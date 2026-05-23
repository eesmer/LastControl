#!/bin/bash

HOSTNAME=$(hostname)
LOAD1=$(awk '{print $1}' /proc/loadavg)
LOAD5=$(awk '{print $2}' /proc/loadavg)
LOAD15=$(awk '{print $3}' /proc/loadavg)
CPU_CORES=$(nproc)
LOAD_PER_CORE=$(awk "BEGIN { printf \"%.2f\", $LOAD1/$CPU_CORES }")
IOWAIT=$(vmstat 1 2 | tail -1 | awk '{print $16}')
TOP_DISK="unknown"
TOP_UTIL="0"

if command -v iostat >/dev/null 2>&1; then
    DISK_LINE=$(iostat -dx 1 1 2>/dev/null | \
        awk '
        /^[sv]d|^nvme|^vd/ {
            if ($NF+0 > max) {
                max=$NF
                disk=$1
            }
        }
        END {
            print disk, max
        }')
    TOP_DISK=$(echo "$DISK_LINE" | awk '{print $1}')
    TOP_UTIL=$(echo "$DISK_LINE" | awk '{print $2}')
fi

INFO_DATA=$(jq -c -n \
  --arg load1 "$LOAD1" \
  --arg load5 "$LOAD5" \
  --arg load15 "$LOAD15" \
  --arg cpu_cores "$CPU_CORES" \
  --arg load_per_core "$LOAD_PER_CORE" \
  --arg iowait "$IOWAIT" \
  --arg top_disk "$TOP_DISK" \
  --arg top_util "$TOP_UTIL" \
  '{
    load1: $load1,
    load5: $load5,
    load15: $load15,
    cpu_cores: $cpu_cores,
    load_per_core: $load_per_core,
    iowait: $iowait,
    top_disk: $top_disk,
    top_util: $top_util
  }')

jq -c -n \
  --arg org "disk_io_load" \
  --arg hn "$HOSTNAME" \
  --arg data "$INFO_DATA" \
  '{origin: $org, hostname: $hn, info_data: $data}'

