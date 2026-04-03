#!/bin/bash

OUTPUT_FILE="/var/www/html/update_report.json"

detect_package_manager() {
    if command -v apt &>/dev/null; then
        echo "APT"
    elif command -v yum &>/dev/null; then
        echo "YUM"
    elif command -v dnf &>/dev/null; then
        echo "DNF"
    else
        echo "UNKNOWN"
    fi
}

PACKAGE_MANAGER=$(detect_package_manager)

check_updates() {
    if [ "$PACKAGE_MANAGER" = "APT" ]; then
        UPDATE_OUTPUT=$(apt update 2>&1)
        if echo "$UPDATE_OUTPUT" | grep -qE "(Failed to fetch|Temporary failure resolving|Could not resolve|Some index files failed to download)"; then
            echo '{"error": "APT update failed. Check internet or repository access."}' > "$OUTPUT_FILE"
            exit 1
        else
            UPDATE_LIST=$(apt list --upgradable 2>/dev/null | grep -v "Listing")
            UPDATE_COUNT=$(echo "$UPDATE_LIST" | wc -l)

            JSON_OUTPUT="{\"updates\": ["
            while read -r line; do
                PACKAGE_NAME=$(echo "$line" | awk -F/ '{print $1}')
                CURRENT_VERSION=$(echo "$line" | awk '{print $2}')

                JSON_OUTPUT+="{\"package\":\"$PACKAGE_NAME\", \"current_version\":\"$CURRENT_VERSION\"},"
            done <<< "$UPDATE_LIST"
            JSON_OUTPUT="${JSON_OUTPUT%,} ]}"

            echo "$JSON_OUTPUT" > "$OUTPUT_FILE"
        fi
    elif [ "$PACKAGE_MANAGER" = "YUM" ] || [ "$PACKAGE_MANAGER" = "DNF" ]; then
        UPDATE_LIST=$(yum check-update | grep -E "^[a-zA-Z0-9]" | awk '{print $1,$2}')
        UPDATE_COUNT=$(echo "$UPDATE_LIST" | wc -l)

        JSON_OUTPUT="{\"updates\": ["
        while read -r line; do
            PACKAGE_NAME=$(echo "$line" | awk '{print $1}')
            CURRENT_VERSION=$(echo "$line" | awk '{print $2}')

            JSON_OUTPUT+="{\"package\":\"$PACKAGE_NAME\", \"current_version\":\"$CURRENT_VERSION\"},"
        done <<< "$UPDATE_LIST"
        JSON_OUTPUT="${JSON_OUTPUT%,} ]}"

        echo "$JSON_OUTPUT" > "$OUTPUT_FILE"
    else
        echo '{"error": "Unknown package manager"}' > "$OUTPUT_FILE"
        exit 1
    fi
}

check_updates
