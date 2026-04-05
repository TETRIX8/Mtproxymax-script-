#!/bin/bash
# MTProxyMax Interactive Deployer

clear
echo "===================================================="
echo "   MTProxyMax Automation & Key Pool Setup"
echo "===================================================="
echo ""

# 1. Get Remote Server Details
read -p "Enter Remote Server IP: " REMOTE_IP
read -p "Enter Remote User (default: root): " REMOTE_USER
REMOTE_USER=${REMOTE_USER:-root}
read -s -p "Enter Remote Password: " REMOTE_PASS
echo ""

# 2. Install sshpass if missing
if ! command -v sshpass &> /dev/null; then
    echo "[i] Installing sshpass locally..."
    sudo apt-get update -qq && sudo apt-get install -y sshpass -qq > /dev/null
fi

# 3. Deploy to Remote Server
echo "[i] Connecting to $REMOTE_IP..."
export SSHPASS="$REMOTE_PASS"

# Install MTProxyMax and Automation
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
