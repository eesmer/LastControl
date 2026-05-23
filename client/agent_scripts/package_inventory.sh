#!/bin/bash

HOSTNAME=$(hostname)
DISTRO_ID="unknown"
DISTRO_VERSION="unknown"
DISTRO_CODENAME="unknown"
PKG_MANAGER="unknown"
PACKAGE_COUNT=0
PACKAGE_LIST=""

if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    DISTRO_CODENAME="${VERSION_CODENAME:-unknown}"
fi

if command -v dpkg-query >/dev/null 2>&1; then
    PKG_MANAGER="dpkg"
    PACKAGE_LIST=$(dpkg-query -W -f='${binary:Package}|${Version}\n' 2>/dev/null | paste -sd "," -)
    PACKAGE_COUNT=$(dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | wc -l)

elif command -v rpm >/dev/null 2>&1; then
    PKG_MANAGER="rpm"
    PACKAGE_LIST=$(rpm -qa --qf '%{NAME}|%{VERSION}-%{RELEASE}\n' 2>/dev/null | paste -sd "," -)
    PACKAGE_COUNT=$(rpm -qa 2>/dev/null | wc -l)
fi

INFO_DATA=$(jq -c -n \
  --arg distro_id "$DISTRO_ID" \
  --arg distro_version "$DISTRO_VERSION" \
  --arg distro_codename "$DISTRO_CODENAME" \
  --arg package_manager "$PKG_MANAGER" \
  --arg package_count "$PACKAGE_COUNT" \
  --arg packages "$PACKAGE_LIST" \
  '{
    distro_id: $distro_id,
    distro_version: $distro_version,
    distro_codename: $distro_codename,
    package_manager: $package_manager,
    package_count: $package_count,
    packages: $packages
  }')

jq -c -n \
  --arg org "package_inventory" \
  --arg hn "$HOSTNAME" \
  --arg data "$INFO_DATA" \
  '{origin: $org, hostname: $hn, info_data: $data}'

