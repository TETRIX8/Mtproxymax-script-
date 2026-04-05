#!/bin/bash
# MTProxyMax Automation & Key Pool Setup

# Check if arguments are provided, otherwise use interactive input
if [ "$#" -ge 2 ]; then
    REMOTE_IP="$1"
    REMOTE_PASS="$2"
    REMOTE_USER="${3:-root}"
else
    # Force input from TTY if running via curl | bash without args
    exec < /dev/tty
    clear
    echo "===================================================="
    echo "   MTProxyMax Automation & Key Pool Setup"
    echo "===================================================="
    echo ""
    printf "Enter Remote Server IP: "
    read REMOTE_IP
    printf "Enter Remote User (default: root): "
    read REMOTE_USER
    REMOTE_USER=${REMOTE_USER:-root}
    printf "Enter Remote Password: "
    read -s REMOTE_PASS
    echo ""
fi

# 2. Install sshpass if missing
if ! command -v sshpass &> /dev/null; then
    echo "[i] Installing sshpass locally..."
    sudo apt-get update -qq && sudo apt-get install -y sshpass -qq > /dev/null
fi

# 3. Deploy to Remote Server
echo "[i] Connecting to $REMOTE_IP and installing automation..."
export SSHPASS="$REMOTE_PASS"

# Install MTProxyMax and Automation on the remote server
sshpass -e ssh -o StrictHostKeyChecking=no "$REMOTE_USER@$REMOTE_IP" "curl -sL https://raw.githubusercontent.com/TETRIX8/Mtproxymax-script-/main/install_automation.sh | bash"

# 4. Show Status and API Info
echo ""
echo "===================================================="
echo "   DEPLOYMENT COMPLETE!"
echo "===================================================="
echo "Server IP: $REMOTE_IP"
echo "API Port:  8000"
echo "API Token: MTProxyMaxSecretToken123"
echo ""
echo "--- API EXAMPLES ---"
echo "Get Test Key (1 day):"
echo "curl -X GET \"http://$REMOTE_IP:8000/get-test\" -H \"Authorization: Bearer MTProxyMaxSecretToken123\""
echo ""
echo "Get Regular Key (30 days):"
echo "curl -X GET \"http://$REMOTE_IP:8000/get-regular?label=user1&period=+30days\" -H \"Authorization: Bearer MTProxyMaxSecretToken123\""
echo "===================================================="
