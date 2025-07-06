#!/bin/bash

set -e

# === Helper Functions ===
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        echo "❌ Unsupported OS."
        exit 1
    fi

    if [[ "$OS" != "ubuntu" ]]; then
        echo "❌ This script only supports Ubuntu."
        exit 1
    fi
}

main_menu() {
    echo "===== NGINX Auto Installer ====="
    echo "1) Install NGINX"
    echo "2) Uninstall NGINX"
    echo "3) Exit"
    read -rp "Choose an option [1-3]: " CHOICE

    case "$CHOICE" in
        1) install_nginx ;;
        2) uninstall_nginx ;;
        3) echo "Bye 👋"; exit 0 ;;
        *) echo "Invalid option"; main_menu ;;
    esac
}

# === Install NGINX ===
install_nginx() {
    detect_os

    read -rp "Do you want to enable SSL with Let's Encrypt? (y/n): " ENABLE_SSL
    if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
        read -rp "Enter your domain (e.g. example.com): " DOMAIN
        read -rp "Enter your email (for Let's Encrypt): " EMAIL
    fi

    echo "📦 Installing NGINX..."
    sudo apt update
    sudo apt install -y nginx

    echo "📂 Creating web root..."
    sudo mkdir -p /var/www/$DOMAIN/html
    echo "<h1>Welcome to $DOMAIN</h1>" | sudo tee /var/www/$DOMAIN/html/index.html

    echo "📝 Creating NGINX config..."
    CONFIG="/etc/nginx/sites-available/$DOMAIN"
    sudo tee "$CONFIG" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/$DOMAIN/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    sudo ln -sf "$CONFIG" /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx

    if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
        echo "🔐 Installing Certbot..."
        sudo apt install -y certbot python3-certbot-nginx
        echo "🔒 Obtaining certificate..."
        sudo certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --no-eff-email
    fi

    echo "✅ NGINX is installed and configured!"
}

# === Uninstall NGINX ===
uninstall_nginx() {
    read -rp "Are you sure you want to remove NGINX and all configs? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        echo "Aborted."
        exit 0
    fi

    echo "🛑 Stopping NGINX..."
    sudo systemctl stop nginx || true
    sudo systemctl disable nginx || true

    echo "🧹 Removing packages..."
    sudo apt purge -y nginx nginx-common nginx-core certbot python3-certbot-nginx
    sudo apt autoremove -y
    sudo apt clean

    echo "🧼 Cleaning up configs..."
    sudo rm -rf /etc/nginx /etc/letsencrypt /var/www/* /var/log/nginx

    echo "✅ NGINX and all related files have been removed."
}

# === Start ===
main_menu
