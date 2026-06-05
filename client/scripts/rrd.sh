#!/bin/bash

HOSTNAME="$(hostname)"
TIMESTAMP="$(date +%s)"

# Load
read LOAD1 LOAD5 LOAD15 _ < /proc/loadavg

# Memory
MEM_TOTAL_KB=$(awk '/MemTotal:/ {print $2}' /proc/meminfo)
MEM_AVAILABLE_KB=$(awk '/MemAvailable:/ {print $2}' /proc/meminfo)

MEM_USED_KB=$((MEM_TOTAL_KB - MEM_AVAILABLE_KB))
MEM_TOTAL_MB=$((MEM_TOTAL_KB / 1024))
MEM_USED_MB=$((MEM_USED_KB / 1024))
MEM_USED_PERCENT=$(awk -v used="$MEM_USED_KB" -v total="$MEM_TOTAL_KB" 'BEGIN { printf "%.2f", (used/total)*100 }')

# Default network interface
IFACE="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"
if [[ -z "$IFACE" ]]; then
    IFACE="unknown"
    RX_BYTES=0
    TX_BYTES=0
else
    RX_BYTES=$(awk -v iface="$IFACE" '$1 ~ iface":" {gsub(":", "", $1); print $2}' /proc/net/dev)
    TX_BYTES=$(awk -v iface="$IFACE" '$1 ~ iface":" {gsub(":", "", $1); print $10}' /proc/net/dev)
fi

# Root filesystem
FS_MOUNT="/"
FS_USED_PERCENT=$(df -P / | awk 'NR==2 {gsub("%","",$5); print $5}')
FS_USED_MB=$(df -Pm / | awk 'NR==2 {print $3}')
FS_TOTAL_MB=$(df -Pm / | awk 'NR==2 {print $2}')

# Root disk device
ROOT_SRC="$(findmnt -n -o SOURCE /)"
ROOT_DISK="$(lsblk -no PKNAME "$ROOT_SRC" 2>/dev/null | head -n1)"

if [[ -z "$ROOT_DISK" ]]; then
    ROOT_DISK="$(basename "$ROOT_SRC" | sed 's/[0-9]*$//')"
fi

if [[ -z "$ROOT_DISK" ]]; then
    ROOT_DISK="unknown"
    READ_SECTORS=0
    WRITE_SECTORS=0
else
    READ_SECTORS=$(awk -v disk="$ROOT_DISK" '$3 == disk {print $6}' /proc/diskstats)
    WRITE_SECTORS=$(awk -v disk="$ROOT_DISK" '$3 == disk {print $10}' /proc/diskstats)
fi

READ_SECTORS="${READ_SECTORS:-0}"
WRITE_SECTORS="${WRITE_SECTORS:-0}"

cat <<EOF
{
  "origin": "rrd_telemetry",
  "hostname": "$HOSTNAME",
  "timestamp": $TIMESTAMP,
  "load": {
    "load1": $LOAD1,
    "load5": $LOAD5,
    "load15": $LOAD15
  },
  "memory": {
    "mem_total_mb": $MEM_TOTAL_MB,
    "mem_used_mb": $MEM_USED_MB,
    "mem_used_percent": $MEM_USED_PERCENT
  },
  "network": {
    "iface": "$IFACE",
    "rx_bytes": $RX_BYTES,
    "tx_bytes": $TX_BYTES
  },
  "diskio": {
    "disk": "$ROOT_DISK",
    "read_sectors": $READ_SECTORS,
    "write_sectors": $WRITE_SECTORS
  },
  "filesystem": {
    "mount": "$FS_MOUNT",
    "used_percent": $FS_USED_PERCENT,
    "used_mb": $FS_USED_MB,
    "total_mb": $FS_TOTAL_MB
  }
}
EOF

