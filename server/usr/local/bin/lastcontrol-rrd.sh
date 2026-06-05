#!/bin/bash

set -euo pipefail

RRD_BASE="/usr/local/lastcontrol/web/rrd"
GRAPH_BASE="/usr/local/lastcontrol/web/graphs"
LOG_FILE="/var/log/lastcontrol-rrd.log"

log_msg() {
    echo "$(date '+%F %T') $*" >> "$LOG_FILE"
}

trap 'log_msg "ERROR: Script failed at line $LINENO"' ERR

JSON_INPUT="$(cat)"

if [[ -z "$JSON_INPUT" ]]; then
    log_msg "ERROR: Empty JSON input"
    exit 1
fi

HOSTNAME="$(echo "$JSON_INPUT" | jq -r '.hostname // empty')"
TIMESTAMP="$(echo "$JSON_INPUT" | jq -r '.timestamp // empty')"

if [[ -z "$HOSTNAME" || -z "$TIMESTAMP" ]]; then
    log_msg "ERROR: hostname or timestamp missing"
    exit 1
fi

SAFE_HOSTNAME="$(echo "$HOSTNAME" | tr -cd 'A-Za-z0-9._-')"

HOST_DIR="${RRD_BASE}/${SAFE_HOSTNAME}"
GRAPH_DIR="${GRAPH_BASE}/${SAFE_HOSTNAME}"

mkdir -p "$HOST_DIR" "$GRAPH_DIR"

LOAD_RRD="${HOST_DIR}/load.rrd"
MEMORY_RRD="${HOST_DIR}/memory.rrd"
NETWORK_RRD="${HOST_DIR}/network.rrd"
DISKIO_RRD="${HOST_DIR}/diskio.rrd"
FILESYSTEM_RRD="${HOST_DIR}/filesystem.rrd"

create_rrd_files() {
    [[ -f "$LOAD_RRD" ]] || rrdtool create "$LOAD_RRD" \
      --step 300 \
      DS:load1:GAUGE:600:0:100 \
      DS:load5:GAUGE:600:0:100 \
      DS:load15:GAUGE:600:0:100 \
      RRA:AVERAGE:0.5:1:288 \
      RRA:AVERAGE:0.5:12:168 \
      RRA:AVERAGE:0.5:288:365

    [[ -f "$MEMORY_RRD" ]] || rrdtool create "$MEMORY_RRD" \
      --step 300 \
      DS:used_mb:GAUGE:600:0:U \
      DS:total_mb:GAUGE:600:0:U \
      DS:used_percent:GAUGE:600:0:100 \
      RRA:AVERAGE:0.5:1:288 \
      RRA:AVERAGE:0.5:12:168 \
      RRA:AVERAGE:0.5:288:365

    [[ -f "$NETWORK_RRD" ]] || rrdtool create "$NETWORK_RRD" \
      --step 300 \
      DS:rx:DERIVE:600:0:U \
      DS:tx:DERIVE:600:0:U \
      RRA:AVERAGE:0.5:1:288 \
      RRA:AVERAGE:0.5:12:168 \
      RRA:AVERAGE:0.5:288:365

    [[ -f "$DISKIO_RRD" ]] || rrdtool create "$DISKIO_RRD" \
      --step 300 \
      DS:read_sectors:DERIVE:600:0:U \
      DS:write_sectors:DERIVE:600:0:U \
      RRA:AVERAGE:0.5:1:288 \
      RRA:AVERAGE:0.5:12:168 \
      RRA:AVERAGE:0.5:288:365

    [[ -f "$FILESYSTEM_RRD" ]] || rrdtool create "$FILESYSTEM_RRD" \
      --step 300 \
      DS:used_mb:GAUGE:600:0:U \
      DS:total_mb:GAUGE:600:0:U \
      DS:used_percent:GAUGE:600:0:100 \
      RRA:AVERAGE:0.5:1:288 \
      RRA:AVERAGE:0.5:12:168 \
      RRA:AVERAGE:0.5:288:365
}

update_rrd_files() {
    LOAD1="$(echo "$JSON_INPUT" | jq -r '.load.load1 // 0')"
    LOAD5="$(echo "$JSON_INPUT" | jq -r '.load.load5 // 0')"
    LOAD15="$(echo "$JSON_INPUT" | jq -r '.load.load15 // 0')"

    MEM_USED_MB="$(echo "$JSON_INPUT" | jq -r '.memory.mem_used_mb // 0')"
    MEM_TOTAL_MB="$(echo "$JSON_INPUT" | jq -r '.memory.mem_total_mb // 0')"
    MEM_USED_PERCENT="$(echo "$JSON_INPUT" | jq -r '.memory.mem_used_percent // 0')"

    RX_BYTES="$(echo "$JSON_INPUT" | jq -r '.network.rx_bytes // 0')"
    TX_BYTES="$(echo "$JSON_INPUT" | jq -r '.network.tx_bytes // 0')"

    READ_SECTORS="$(echo "$JSON_INPUT" | jq -r '.diskio.read_sectors // 0')"
    WRITE_SECTORS="$(echo "$JSON_INPUT" | jq -r '.diskio.write_sectors // 0')"

    FS_USED_MB="$(echo "$JSON_INPUT" | jq -r '.filesystem.used_mb // 0')"
    FS_TOTAL_MB="$(echo "$JSON_INPUT" | jq -r '.filesystem.total_mb // 0')"
    FS_USED_PERCENT="$(echo "$JSON_INPUT" | jq -r '.filesystem.used_percent // 0')"

    rrdtool update "$LOAD_RRD" "${TIMESTAMP}:${LOAD1}:${LOAD5}:${LOAD15}"
    rrdtool update "$MEMORY_RRD" "${TIMESTAMP}:${MEM_USED_MB}:${MEM_TOTAL_MB}:${MEM_USED_PERCENT}"
    rrdtool update "$NETWORK_RRD" "${TIMESTAMP}:${RX_BYTES}:${TX_BYTES}"
    rrdtool update "$DISKIO_RRD" "${TIMESTAMP}:${READ_SECTORS}:${WRITE_SECTORS}"
    rrdtool update "$FILESYSTEM_RRD" "${TIMESTAMP}:${FS_USED_MB}:${FS_TOTAL_MB}:${FS_USED_PERCENT}"
}

graph_rrd_files() {
    rrdtool graph "${GRAPH_DIR}/load-day.png" \
      --start -1d \
      --title "System Load - ${SAFE_HOSTNAME}" \
      --vertical-label "Load" \
      DEF:load1="$LOAD_RRD":load1:AVERAGE \
      DEF:load5="$LOAD_RRD":load5:AVERAGE \
      DEF:load15="$LOAD_RRD":load15:AVERAGE \
      LINE2:load1#0000FF:"Load 1" \
      LINE2:load5#00AA00:"Load 5" \
      LINE2:load15#FF0000:"Load 15" >/dev/null

    rrdtool graph "${GRAPH_DIR}/memory-day.png" \
      --start -1d \
      --title "Memory Usage - ${SAFE_HOSTNAME}" \
      --vertical-label "Percent" \
      DEF:used="$MEMORY_RRD":used_percent:AVERAGE \
      AREA:used#00AAFF:"Memory Used %" >/dev/null

    rrdtool graph "${GRAPH_DIR}/network-day.png" \
      --start -1d \
      --title "Network Traffic - ${SAFE_HOSTNAME}" \
      --vertical-label "Bytes/sec" \
      DEF:rx="$NETWORK_RRD":rx:AVERAGE \
      DEF:tx="$NETWORK_RRD":tx:AVERAGE \
      LINE2:rx#0000FF:"RX" \
      LINE2:tx#00AA00:"TX" >/dev/null

    rrdtool graph "${GRAPH_DIR}/diskio-day.png" \
      --start -1d \
      --title "Disk I/O - ${SAFE_HOSTNAME}" \
      --vertical-label "Sectors/sec" \
      DEF:read="$DISKIO_RRD":read_sectors:AVERAGE \
      DEF:write="$DISKIO_RRD":write_sectors:AVERAGE \
      LINE2:read#0000FF:"Read" \
      LINE2:write#FF0000:"Write" >/dev/null

    rrdtool graph "${GRAPH_DIR}/filesystem-day.png" \
      --start -1d \
      --title "Filesystem Usage - ${SAFE_HOSTNAME}" \
      --vertical-label "Percent" \
      DEF:used="$FILESYSTEM_RRD":used_percent:AVERAGE \
      AREA:used#FFAA00:"Filesystem Used %" >/dev/null
}

create_rrd_files
update_rrd_files
graph_rrd_files

log_msg "OK: RRD telemetry processed hostname=${SAFE_HOSTNAME}"
echo "OK"
