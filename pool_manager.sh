#!/bin/bash
# MTProxyMax Pool Manager
# Logic for issuing keys from pools and auto-refilling.

INSTALL_DIR="/opt/mtproxymax"
POOL_REGULAR="${INSTALL_DIR}/pool_regular.conf"
POOL_TEST="${INSTALL_DIR}/pool_test.conf"
WORKER_SCRIPT="${INSTALL_DIR}/worker.sh"

# Function to get a key from a pool
get_key_from_pool() {
    local pool_file="$1"
    local key
    
    if [ ! -f "$pool_file" ] || [ ! -s "$pool_file" ]; then
        echo "ERROR: Pool $pool_file is empty or missing!" >&2
        return 1
    fi
    
    # Get the first key and remove it from the file
    key=$(head -n 1 "$pool_file")
    sed -i '1d' "$pool_file"
    
    # Trigger check for refill in background
    bash "$WORKER_SCRIPT" --check &
    
    echo "$key"
}

# Issue a test key (1 day)
issue_test_key() {
    local label="test_$(date +%s)"
    local key
    key=$(get_key_from_pool "$POOL_TEST") || return 1
    
    # Calculate expiry date (tomorrow)
    local expiry
    expiry=$(date -d "+1 day" +%Y-%m-%d)
    
    # Add to MTProxyMax
    mtproxymax secret add "$label" "$key" "true"
    mtproxymax secret setlimits "$label" 15 5 0 "$expiry"
    
    echo "Test key issued: $label (expires $expiry)"
}

# Issue a regular key
issue_regular_key() {
    local label="$1"
    local period="$2" # e.g., "+30 days"
    local key
    
    if [ -z "$label" ]; then
        echo "ERROR: Label is required" >&2
        return 1
    fi
    
    key=$(get_key_from_pool "$POOL_REGULAR") || return 1
    
    # Calculate expiry date
    local expiry="0"
    if [ -n "$period" ]; then
        expiry=$(date -d "$period" +%Y-%m-%d)
    fi
    
    # Add to MTProxyMax
    mtproxymax secret add "$label" "$key" "true"
    if [ "$expiry" != "0" ]; then
        mtproxymax secret setlimits "$label" 15 5 0 "$expiry"
    fi
    
    echo "Regular key issued: $label (expires $expiry)"
}

# Main CLI interface
case "$1" in
    get-test)
        issue_test_key
        ;;
    get-regular)
        issue_regular_key "$2" "$3"
        ;;
    *)
        echo "Usage: $0 {get-test|get-regular label period}"
        exit 1
        ;;
esac
