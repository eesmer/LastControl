#!/bin/bash
set -u

# --------------------------------------------------------------------
# LastControl Security Data Update Script
# - Keeps last known-good local data when vendor download fails
# - Downloads Debian, Ubuntu OVAL, and Red Hat Security Data
# - Uses temporary files and validates JSON before replacing active data
# - Logs warnings instead of deleting usable cached data
# --------------------------------------------------------------------

PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

BASE_DIR="/var/lib/lastcontrol/security-data"
LOG_FILE="/var/log/lastcontrol-securitydata-update.log"
DEBIAN_DIR="$BASE_DIR/debian"
UBUNTU_DIR="$BASE_DIR/ubuntu"
RHEL_DIR="$BASE_DIR/rhel"

mkdir -p "$DEBIAN_DIR" "$UBUNTU_DIR" "$RHEL_DIR"

log() {
    echo "$(date '+%F %T') - $*" >> "$LOG_FILE"
}

have_cache() {
    local file="$1"
    [ -s "$file" ]
}

host_from_url() {
    local url="$1"
    echo "$url" | sed -E 's#^https?://([^/]+)/.*#\1#'
}

dns_check() {
    local url="$1"
    local host
    host="$(host_from_url "$url")"
    if getent hosts "$host" >/dev/null 2>&1; then
        return 0
    fi
    log "WARNING: DNS lookup failed for host=$host"
    return 1
}

curl_to_tmp() {
    local url="$1"
    local tmp="$2"
    rm -f "$tmp"
    # DNS check is only for clearer logs. curl is still the real download test.
    dns_check "$url" || true
    if curl \
        --fail \
        --silent \
        --show-error \
        --location \
        --connect-timeout 20 \
        --max-time 300 \
        --retry 3 \
        --retry-delay 5 \
        --retry-all-errors \
        "$url" \
        -o "$tmp"; then
        return 0
    fi
    rm -f "$tmp"
    return 1
}

update_json_with_cache() {
    local name="$1"
    local url="$2"
    local out="$3"
    local tmp="${out}.tmp"
    log "$name update started"
    if curl_to_tmp "$url" "$tmp"; then
        if jq empty "$tmp" >/dev/null 2>&1; then
            mv "$tmp" "$out"
            log "$name updated successfully"
            return 0
        fi
        rm -f "$tmp"
        log "WARNING: $name JSON validation failed; keeping existing cache if available"
    else
        log "WARNING: $name download failed; keeping existing cache if available"
    fi
    if have_cache "$out"; then
        log "$name cache retained: $out"
        return 0
    fi
    log "ERROR: $name unavailable and no local cache exists: $out"
    return 1
}

update_binary_with_cache() {
    local name="$1"
    local url="$2"
    local out="$3"
    local tmp="${out}.tmp"
    if curl_to_tmp "$url" "$tmp"; then
        if [ -s "$tmp" ]; then
            mv "$tmp" "$out"
            log "$name updated successfully"
            return 0
        fi
        rm -f "$tmp"
        log "WARNING: $name downloaded empty file; keeping existing cache if available"
    else
        log "WARNING: $name download failed; keeping existing cache if available"
    fi
    if have_cache "$out"; then
        log "$name cache retained: $out"
        return 0
    fi
    log "WARNING: $name unavailable and no local cache exists: $out"
    return 1
}
log "Security data update started"

# Debian Security Tracker
update_json_with_cache \
    "Debian Security Tracker" \
    "https://security-tracker.debian.org/tracker/data/json" \
    "$DEBIAN_DIR/security-tracker.json" || true

# Ubuntu OVAL
log "Ubuntu OVAL update started"
UBUNTU_RELEASES=(
    "trusty"    # 14.04
    "xenial"    # 16.04
    "bionic"    # 18.04
    "focal"     # 20.04
    "jammy"     # 22.04
    "noble"     # 24.04
    "resolute"  # 26.04
)

for rel in "${UBUNTU_RELEASES[@]}"; do
    for oval_type in "cve" "usn"; do
        URL="https://security-metadata.canonical.com/oval/com.ubuntu.${rel}.${oval_type}.oval.xml.bz2"
        OUT="$UBUNTU_DIR/${rel}.${oval_type}.oval.xml.bz2"
        update_binary_with_cache "Ubuntu ${oval_type^^} OVAL: $rel" "$URL" "$OUT" || true
    done
done

# Red Hat Security Data
log "Red Hat Security Data update started"
CURRENT_YEAR=$(date +%Y)
AFTER_YEAR=$((CURRENT_YEAR - 2))
AFTER_DATE="${AFTER_YEAR}-01-01"
RECENT_URL="https://access.redhat.com/hydra/rest/securitydata/cve.json?after=${AFTER_DATE}"
RECENT_OUT="$RHEL_DIR/cve-recent.json"
DETAILS_OUT="$RHEL_DIR/cve-details.json"
DETAILS_TMP="${DETAILS_OUT}.tmp"

recent_updated=0
if update_json_with_cache "Red Hat CVE recent data" "$RECENT_URL" "$RECENT_OUT"; then
    # Continue even when the file was retained from cache.
    recent_updated=1
fi
if [ "$recent_updated" -eq 1 ] && have_cache "$RECENT_OUT"; then
    log "Red Hat CVE detail data update started"
    rm -f "$DETAILS_TMP"
    echo "[" > "$DETAILS_TMP"
    first=1
    success_count=0
    fail_count=0
    mapfile -t CVES < <(jq -r '.[].CVE // .[].name // empty' "$RECENT_OUT" 2>/dev/null | grep '^CVE-' | sort -u)
    for cve in "${CVES[@]}"; do
        DETAIL_URL="https://access.redhat.com/hydra/rest/securitydata/cve/${cve}.json"
        DETAIL_FILE="$RHEL_DIR/${cve}.json.tmp"
        if curl_to_tmp "$DETAIL_URL" "$DETAIL_FILE" && jq empty "$DETAIL_FILE" >/dev/null 2>&1; then
            if [ "$first" -eq 0 ]; then
                echo "," >> "$DETAILS_TMP"
            fi
            cat "$DETAIL_FILE" >> "$DETAILS_TMP"
            first=0
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
            log "WARNING: Red Hat CVE detail download failed: $cve"
        fi
        rm -f "$DETAIL_FILE"
    done
    echo "]" >> "$DETAILS_TMP"
    if [ "$success_count" -gt 0 ] && jq empty "$DETAILS_TMP" >/dev/null 2>&1; then
        mv "$DETAILS_TMP" "$DETAILS_OUT"
        log "Red Hat CVE detail data updated successfully. success=$success_count failed=$fail_count total=${#CVES[@]}"
    else
        rm -f "$DETAILS_TMP"
        log "WARNING: Red Hat CVE detail update failed or produced no data; keeping existing cache if available"
        if have_cache "$DETAILS_OUT"; then
            log "Red Hat CVE detail cache retained: $DETAILS_OUT"
        else
            log "ERROR: Red Hat CVE detail data unavailable and no local cache exists: $DETAILS_OUT"
        fi
    fi
fi
log "Security data update finished"
exit 0
