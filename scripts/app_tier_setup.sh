#!/bin/bash
###############################################################
# app_tier_setup.sh — App Tier Setup
# Installs Node.js, clones app code, creates .env file, starts app
###############################################################

set -e
exec > /var/log/app_tier_setup.log 2>&1

echo "===== APP TIER SETUP STARTED: $(date) ====="

# ── 1. System update
echo "[1/6] Updating system packages..."
apt-get update -y
apt-get upgrade -y

# ── 2. Install Node.js 18 + mysql-client
echo "[2/6] Installing Node.js 18..."
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs mysql-client git
echo "Node: $(node -v) | NPM: $(npm -v)"

# ── 3. Clone app code
echo "[3/6] Cloning app code..."
APP_DIR="/home/ubuntu/app"
mkdir -p "$APP_DIR"
git clone https://github.com/jnvenkataramanan/aws-three-tier-web-architecture-workshop /tmp/workshop-repo
cp -r /tmp/workshop-repo/application-code/app-tier/. "$APP_DIR/"
cd "$APP_DIR"

# ── 4. Install npm dependencies
echo "[4/6] Installing npm dependencies..."
npm install

# ── 5. Create .env file — app uses dotenv/process.env
echo "[5/6] Creating .env file..."
cat > "$APP_DIR/.env" << ENVFILE
DB_HOST=${db_host}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
DB_NAME=${db_name}
DB_PORT=3306
PORT=4000
ENVFILE

echo ".env created:"
cat "$APP_DIR/.env"

# ── 6. Create systemd service
echo "[6/6] Creating systemd service..."
cat > /etc/systemd/system/nodeapp.service << SERVICE
[Unit]
Description=Node.js App Tier - Port 4000
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/app
EnvironmentFile=/home/ubuntu/app/.env
ExecStart=/usr/bin/node index.js
Restart=on-failure
RestartSec=5
StandardOutput=append:/var/log/nodeapp.log
StandardError=append:/var/log/nodeapp.log

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable nodeapp
systemctl start nodeapp

sleep 3
echo "===== APP TIER SETUP COMPLETE: $(date) ====="
systemctl status nodeapp --no-pager
curl -s http://localhost:4000/health || echo "Health check pending..."
