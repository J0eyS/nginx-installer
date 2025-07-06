#!/bin/bash

set -e

# === Utility Functions ===

header() {
    echo -e "\n\e[1;32m=== $1 ===\e[0m"
}

error_exit() {
    echo -e "\e[1;31m❌ $1\e[0m"
    exit 1
}

pause() {
    read -rp "Press Enter to continue..."
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        error_exit "Unsupported operating system."
    fi

    if [[ "$OS" != "ubuntu" ]]; then
        error_exit "This script only supports Ubuntu."
    fi
}

# === Installer ===

install_nginx() {
    detect_os

    read -rp "Do you want to enable SSL with Let's Encrypt? (y/n): " ENABLE_SSL
    if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
        read -rp "Enter your domain (e.g. example.com): " DOMAIN
        read -rp "Enter your email (for Let's Encrypt): " EMAIL
    fi

    header "Installing NGINX"
    sudo apt update
    sudo apt install -y nginx

    if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
        header "Installing Certbot via Snap"
        sudo snap install core && sudo snap refresh core
        sudo snap install --classic certbot
        sudo ln -sf /snap/bin/certbot /usr/bin/certbot
    fi

    if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
        header "Creating Web Root for $DOMAIN"
        sudo mkdir -p /var/www/$DOMAIN/html
        echo "<h1>Welcome to $DOMAIN</h1>" | sudo tee /var/www/$DOMAIN/html/index.html > /dev/null

        header "Creating NGINX Config"
        CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
        sudo tee "$CONFIG_PATH" > /dev/null <<EOF
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

        sudo ln -sf "$CONFIG_PATH" /etc/nginx/sites-enabled/
        sudo nginx -t && sudo systemctl reload nginx

        header "Obtaining SSL Certificate"
        sudo certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --no-eff-email

        header "Enabling Auto Renewal"
        sudo systemctl enable snap.certbot.renew.timer
    fi

    header "✅ NGINX Installation Complete"
    pause
}

# === Uninstaller ===

uninstall_nginx() {
    read -rp "Are you sure you want to completely remove NGINX and all configs? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" ]]; then
        echo "Aborted."
        return
    fi

    header "Stopping NGINX"
    sudo systemctl stop nginx || true
    sudo systemctl disable nginx || true

    header "Removing NGINX and Certbot"
    sudo apt purge -y nginx nginx-common nginx-core
    sudo snap remove certbot || true
    sudo apt autoremove -y
    sudo apt clean

    header "Cleaning Up Configs"
    sudo rm -rf /etc/nginx /etc/letsencrypt /var/www /var/log/nginx /etc/systemd/system/snap.certbot.renew.timer*

    header "✅ NGINX and all related files have been removed."
    pause
}

# === Menu ===

main_menu() {
    while true; do
        clear
        echo -e "\e[1;34m===== NGINX Auto Installer =====\e[0m"
        echo "1) Install NGINX"
        echo "2) Uninstall NGINX"
        echo "3) Exit"
        echo
        read -rp "Choose an option [1-3]: " CHOICE

        case "$CHOICE" in
            1) install_nginx ;;
            2) uninstall_nginx ;;
            3) echo "Goodbye 👋"; exit 0 ;;
            *) echo "Invalid option. Try again."; pause ;;
        esac
    done
}

# === Start ===
main_menu

