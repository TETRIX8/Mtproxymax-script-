#!/bin/bash
# MTProxyMax Automation Installer (Non-interactive)

set -e

INSTALL_DIR="/opt/mtproxymax"
mkdir -p "$INSTALL_DIR"

# 1. Install MTProxyMax (Non-interactive)
if ! command -v mtproxymax &> /dev/null; then
    echo "Installing MTProxyMax..."
    # Use printf to provide default answers to the installer
    printf "\n\n\n\n\n" | curl -sL https://raw.githubusercontent.com/SamNet-dev/MTProxyMax/main/install.sh | bash
    
    # Ensure it's in /usr/local/bin
    if [ -f "/tmp/mtproxymax.sh" ]; then
        cp /tmp/mtproxymax.sh /usr/local/bin/mtproxymax
        chmod +x /usr/local/bin/mtproxymax
    fi
fi

# 2. Create Worker Script
cat << 'EOF' > "$INSTALL_DIR/worker.sh"
#!/bin/bash
INSTALL_DIR="/opt/mtproxymax"
POOL_REGULAR="${INSTALL_DIR}/pool_regular.conf"
POOL_TEST="${INSTALL_DIR}/pool_test.conf"
TARGET_COUNT=100
MIN_THRESHOLD=20
REFILL_COUNT=20

generate_secret() {
    openssl rand -hex 16 2>/dev/null || head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' | head -c 32
}

refill_pool() {
    local pool_file="$1"
    local target="$2"
    local current_count=0
    [ -f "$pool_file" ] && current_count=$(wc -l < "$pool_file")
    local needed=$((target - current_count))
    if [ "$needed" -gt 0 ]; then
        for ((i=0; i<needed; i++)); do generate_secret >> "$pool_file"; done
        chmod 600 "$pool_file"
    fi
}

if [ "$1" == "--daily" ]; then
    refill_pool "$POOL_REGULAR" "$TARGET_COUNT"
    refill_pool "$POOL_TEST" "$TARGET_COUNT"
elif [ "$1" == "--check" ]; then
    reg_count=$(wc -l < "$POOL_REGULAR" 2>/dev/null || echo 0)
    [ "$reg_count" -lt "$MIN_THRESHOLD" ] && for ((i=0; i<REFILL_COUNT; i++)); do generate_secret >> "$POOL_REGULAR"; done
    test_count=$(wc -l < "$POOL_TEST" 2>/dev/null || echo 0)
    [ "$test_count" -lt "$MIN_THRESHOLD" ] && for ((i=0; i<REFILL_COUNT; i++)); do generate_secret >> "$POOL_TEST"; done
fi
EOF
chmod +x "$INSTALL_DIR/worker.sh"

# 3. Create Pool Manager Script
cat << 'EOF' > "$INSTALL_DIR/pool_manager.sh"
#!/bin/bash
INSTALL_DIR="/opt/mtproxymax"
POOL_REGULAR="${INSTALL_DIR}/pool_regular.conf"
POOL_TEST="${INSTALL_DIR}/pool_test.conf"
WORKER_SCRIPT="${INSTALL_DIR}/worker.sh"

get_key_from_pool() {
    local pool_file="$1"
    [ ! -s "$pool_file" ] && return 1
    local key=$(head -n 1 "$pool_file")
    sed -i '1d' "$pool_file"
    bash "$WORKER_SCRIPT" --check &
    echo "$key"
}

issue_test_key() {
    local label="test_$(date +%s)"
    local key=$(get_key_from_pool "$POOL_TEST") || return 1
    local expiry=$(date -d "+1 day" +%Y-%m-%d)
    mtproxymax secret add "$label" "$key" "true" > /dev/null
    mtproxymax secret setlimits "$label" 15 5 0 "$expiry" > /dev/null
    echo "Test key issued: $label"
}

issue_regular_key() {
    local label="$1"
    local period="$2"
    local key=$(get_key_from_pool "$POOL_REGULAR") || return 1
    local expiry="0"
    [ -n "$period" ] && expiry=$(date -d "$period" +%Y-%m-%d)
    mtproxymax secret add "$label" "$key" "true" > /dev/null
    [ "$expiry" != "0" ] && mtproxymax secret setlimits "$label" 15 5 0 "$expiry" > /dev/null
    echo "Regular key issued: $label"
}

case "$1" in
    get-test) issue_test_key ;;
    get-regular) issue_regular_key "$2" "$3" ;;
esac
EOF
chmod +x "$INSTALL_DIR/pool_manager.sh"
ln -sf "$INSTALL_DIR/pool_manager.sh" /usr/local/bin/mtproxymax-pool

# 4. Create API Server Script
cat << 'EOF' > "$INSTALL_DIR/api_server.py"
import subprocess, re, uvicorn
from fastapi import FastAPI, HTTPException, Header
app = FastAPI()
API_TOKEN = "MTProxyMaxSecretToken123"
def clean_ansi(text): return re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])').sub('', text)
def extract_link(text):
    match = re.search(r'(https://t.me/proxy\?server=[^\s]+)', text)
    return match.group(1) if match else None
def run_command(cmd):
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        if result.returncode != 0: return {"error": clean_ansi(result.stderr.strip())}
        raw_output = clean_ansi(result.stdout)
        link = extract_link(raw_output)
        return {"link": link} if link else {"output": raw_output.strip()}
    except Exception as e: return {"error": str(e)}
@app.get("/get-test")
async def get_test(authorization: str = Header(None)):
    if authorization != f"Bearer {API_TOKEN}": raise HTTPException(status_code=401, detail="Unauthorized")
    return run_command("mtproxymax-pool get-test")
@app.get("/get-regular")
async def get_regular(label: str, period: str = "", authorization: str = Header(None)):
    if authorization != f"Bearer {API_TOKEN}": raise HTTPException(status_code=401, detail="Unauthorized")
    return run_command(f"mtproxymax-pool get-regular {label} '{period}'")
if __name__ == "__main__": uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# 5. Install Python dependencies
apt-get update -qq && apt-get install -y python3-pip -qq > /dev/null
pip3 install fastapi uvicorn --break-system-packages || pip3 install fastapi uvicorn

# 6. Setup Cron
(crontab -l 2>/dev/null | grep -v "worker.sh --daily"; echo "0 7 * * * $INSTALL_DIR/worker.sh --daily") | crontab -
(crontab -l 2>/dev/null | grep -v "api_server.py"; echo "@reboot nohup python3 $INSTALL_DIR/api_server.py > $INSTALL_DIR/api.log 2>&1 &") | crontab -

# 7. Initial Refill and Start API
bash "$INSTALL_DIR/worker.sh" --daily
pkill -f api_server.py || true
nohup python3 "$INSTALL_DIR/api_server.py" > "$INSTALL_DIR/api.log" 2>&1 &

echo "Installation complete! API running on port 8000."
