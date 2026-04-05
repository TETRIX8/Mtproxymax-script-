#!/bin/bash
# MTProxyMax Worker for Key Generation
# This script manages key pools: regular and test.

INSTALL_DIR="/opt/mtproxymax"
POOL_REGULAR="${INSTALL_DIR}/pool_regular.conf"
POOL_TEST="${INSTALL_DIR}/pool_test.conf"
TARGET_COUNT=100
MIN_THRESHOLD=20
REFILL_COUNT=20

# Function to generate a random 32-char hex secret
generate_secret() {
    openssl rand -hex 16 2>/dev/null || {
        head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 32
    }
}

# Function to refill a pool
refill_pool() {
    local pool_file="$1"
    local target="$2"
    local current_count=0
    
    if [ -f "$pool_file" ]; then
        current_count=$(wc -l < "$pool_file")
    fi
    
    local needed=$((target - current_count))
    if [ "$needed" -gt 0 ]; then
        echo "Refilling $pool_file: adding $needed keys..."
        for ((i=0; i<needed; i++)); do
            generate_secret >> "$pool_file"
        done
        chmod 600 "$pool_file"
    fi
}

# Main logic
mkdir -p "$INSTALL_DIR"

# Daily refill (called at 7 AM)
if [ "$1" == "--daily" ]; then
    echo "Running daily refill at $(date)"
    refill_pool "$POOL_REGULAR" "$TARGET_COUNT"
    refill_pool "$POOL_TEST" "$TARGET_COUNT"
fi

# On-demand refill (called when pool is low)
if [ "$1" == "--check" ]; then
    # Check regular pool
    reg_count=$(wc -l < "$POOL_REGULAR" 2>/dev/null || echo 0)
    if [ "$reg_count" -lt "$MIN_THRESHOLD" ]; then
        echo "Regular pool low ($reg_count), adding $REFILL_COUNT keys..."
        for ((i=0; i<REFILL_COUNT; i++)); do
            generate_secret >> "$POOL_REGULAR"
        done
    fi
    
    # Check test pool
    test_count=$(wc -l < "$POOL_TEST" 2>/dev/null || echo 0)
    if [ "$test_count" -lt "$MIN_THRESHOLD" ]; then
        echo "Test pool low ($test_count), adding $REFILL_COUNT keys..."
        for ((i=0; i<REFILL_COUNT; i++)); do
            generate_secret >> "$POOL_TEST"
        done
    fi
fi
