#!/bin/bash

set -e

BOLD="\e[1m"
RESET="\e[0m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"

function pause() {
    read -rp "Press enter to continue..."
}

function print_header() {
    echo -e "${BOLD}===== NGINX Auto Installer =====${RESET}"
}

function detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
    else
        echo -e "${RED}Cannot detect OS. Aborting.${RESET}"
        exit 1
    fi
}

function install_nginx() {
    echo -e "\n${GREEN}=== Installing NGINX ===${RESET}"
    if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
        apt update && apt install -y nginx snapd
    else
        echo -e "${RED}Only Ubuntu/Debian are supported in this script currently.${RESET}"
        exit 1
    fi

    echo -e "\n${GREEN}=== Enabling NGINX ===${RESET}"
    systemctl enable --now nginx
}

function install_certbot() {
    echo -e "\n${GREEN}=== Installing Certbot via Snap ===${RESET}"
    snap install core && snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
}

function configure_domain() {
    read -rp "Enter your domain name (e.g. example.com): " DOMAIN
    DOMAIN_DIR="/var/www/$DOMAIN/html"
    mkdir -p "$DOMAIN_DIR"
    chown -R www-data:www-data "$DOMAIN_DIR"

    echo -e "\n${GREEN}=== Creating NGINX Config for $DOMAIN ===${RESET}"

    cat > "/etc/nginx/sites-available/$DOMAIN" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $DOMAIN_DIR;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ ^/.well-known/acme-challenge/ {
        allow all;
        root $DOMAIN_DIR;
    }
}
EOF

    ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"
    nginx -t && systemctl reload nginx
}

function obtain_ssl() {
    echo -e "\n${GREEN}=== Obtaining SSL Certificate for $DOMAIN ===${RESET}"
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --register-unsafely-without-email
}

function open_ports() {
    echo -e "\n${GREEN}=== Allowing HTTP/HTTPS Ports ===${RESET}"
    if command -v ufw &>/dev/null; then
        ufw allow 80
        ufw allow 443
    fi
}

function uninstall_all() {
    echo -e "\n${RED}=== Uninstalling Everything ===${RESET}"

    echo -e "\nStopping and removing NGINX and Certbot..."
    systemctl stop nginx || true
    apt remove --purge -y nginx nginx-common || true
    apt autoremove -y
    snap remove certbot || true
    rm -f /usr/bin/certbot

    echo -e "\nRemoving NGINX configs and SSL..."
    rm -rf /etc/nginx /var/www/* /etc/letsencrypt /var/log/letsencrypt /etc/systemd/system/nginx.service
    rm -rf /etc/nginx/sites-available/* /etc/nginx/sites-enabled/*

    echo -e "\n${GREEN}Uninstallation complete. NGINX and SSL certificates removed.${RESET}"
}

function main_menu() {
    print_header
    echo "1) Install NGINX with SSL"
    echo "2) Uninstall NGINX and SSL"
    echo "3) Exit"
    echo
    read -rp "Choose an option [1-3]: " choice
    case "$choice" in
        1)
            detect_os
            install_nginx
            install_certbot
            configure_domain
            open_ports
            obtain_ssl
            echo -e "\n${GREEN}Installation complete!${RESET}"
            ;;
        2)
            uninstall_all
            ;;
        3)
            echo "Bye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option.${RESET}"
            ;;
    esac
}

main_menu
