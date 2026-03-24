#!/bin/bash
###############################################################
# web_tier_setup.sh — Web Tier Setup
# Builds React app, configures nginx using the project's own
# nginx conf format (from nginx-conf-file/default)
###############################################################

set -e
exec > /var/log/web_tier_setup.log 2>&1

echo "===== WEB TIER SETUP STARTED: $(date) ====="

# ── 1. System update
echo "[1/5] Updating packages..."
apt-get update -y
apt-get upgrade -y

# ── 2. Install nginx + nodejs (build only)
echo "[2/5] Installing nginx, git, nodejs..."
apt-get install -y nginx git
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
echo "Node: $(node -v)"

# ── 3. Clone repo, build React
echo "[3/5] Cloning repo and building React..."
git clone https://github.com/jnvenkataramanan/aws-three-tier-web-architecture-workshop /tmp/workshop-repo
cd /tmp/workshop-repo/application-code/web-tier

# Fix: repo has 3TierArchitecture.png but code imports 3TierArch.png
cp src/assets/3TierArchitecture.png src/assets/3TierArch.png 2>/dev/null || true

npm install
npm run build

# Copy build output to nginx web root
WEB_DIR="/var/www/html"
rm -rf "$WEB_DIR"/*
cp -r build/. "$WEB_DIR/"
chown -R www-data:www-data "$WEB_DIR"
echo "React files in $WEB_DIR: $(ls $WEB_DIR)"

# ── 4. Remove nodejs (not needed at runtime)
echo "[4/5] Removing nodejs..."
apt-get remove -y nodejs
apt-get autoremove -y

# ── 5. Configure nginx
# Using same format as project's nginx-conf-file/default
# /api/ proxies to internal ALB, / serves React SPA
echo "[5/5] Configuring nginx..."

# Disable default site
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/conf.d/default.conf

# Write nginx config — int_lb_dns injected by Terraform local-exec
cat > /etc/nginx/sites-available/app << NGINXEOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html;
    index index.html;

    server_name _;

    location / {
        try_files \$uri /index.html;
    }

    location /api/ {
        proxy_pass http://${int_lb_dns}/;
        proxy_http_version 1.1;
        proxy_set_header Host              \$host;
        proxy_set_header X-Real-IP         \$remote_addr;
        proxy_set_header X-Forwarded-For   \$proxy_add_x_forwarded_for;
    }
}
NGINXEOF

# Enable the site
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app

# Validate and restart
nginx -t
systemctl enable nginx
systemctl restart nginx

echo "===== WEB TIER SETUP COMPLETE: $(date) ====="
echo "Nginx config:"
cat /etc/nginx/sites-available/app
echo ""
echo "Files in /var/www/html:"
ls /var/www/html/
systemctl status nginx --no-pager
