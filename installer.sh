#!/bin/bash

set -e

# ─────────────────────────────────────────────
# Terminal Colors and Styling
# ─────────────────────────────────────────────
RESET="\e[0m"
BOLD="\e[1m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"

# ─────────────────────────────────────────────
# Helper Functions
# ─────────────────────────────────────────────
function header() {
    echo -e "\n${BOLD}${CYAN}== NGINX Auto Installer ==${RESET}"
}

function pause() {
    read -rp "Press Enter to continue..."
}

function detect_os() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        OS=$ID
    else
        echo -e "${RED}Could not detect OS. Aborting.${RESET}"
        exit 1
    fi
}

function ask_yes_no() {
    local prompt=$1
    while true; do
        read -rp "$prompt [y/n]: " yn
        case $yn in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}

# ─────────────────────────────────────────────
# Installation Functions
# ─────────────────────────────────────────────

function install_nginx() {
    echo -e "${GREEN}Installing NGINX...${RESET}"
    apt update && apt install -y nginx
    systemctl enable --now nginx
}

function install_certbot() {
    echo -e "${GREEN}Installing Certbot (via Snap)...${RESET}"
    apt install -y snapd
    snap install core && snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
}

function configure_nginx_site() {
    read -rp "Enter your domain name (e.g. example.com): " DOMAIN
    DOMAIN_DIR="/var/www/$DOMAIN/html"
    mkdir -p "$DOMAIN_DIR"
    chown -R www-data:www-data "$DOMAIN_DIR"
    echo "<html><body><h1>$DOMAIN</h1></body></html>" > "$DOMAIN_DIR/index.html"

    echo -e "${GREEN}Creating NGINX site config for $DOMAIN...${RESET}"

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

function obtain_ssl_certificate() {
    echo -e "${GREEN}Requesting SSL certificate from Let's Encrypt...${RESET}"
    certbot certonly --webroot -w "/var/www/$DOMAIN/html" -d "$DOMAIN" --agree-tos --register-unsafely-without-email --non-interactive

    echo -e "${GREEN}Updating NGINX config with SSL...${RESET}"
    cat > "/etc/nginx/sites-available/$DOMAIN" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    root $DOMAIN_DIR;
    index index.html;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    nginx -t && systemctl reload nginx
    echo -e "${GREEN}SSL is now active for https://$DOMAIN${RESET}"
}

function allow_firewall_ports() {
    if command -v ufw &>/dev/null; then
        echo -e "${GREEN}Allowing ports 80 and 443 in UFW...${RESET}"
        ufw allow 80
        ufw allow 443
    fi
}

# ─────────────────────────────────────────────
# Uninstall Function
# ─────────────────────────────────────────────
function uninstall_all() {
    echo -e "${RED}Uninstalling NGINX and Certbot...${RESET}"
    systemctl stop nginx || true
    apt remove --purge -y nginx nginx-common snapd || true
    apt autoremove -y
    snap remove certbot || true
    rm -f /usr/bin/certbot

    echo -e "${YELLOW}Removing NGINX configs and website data...${RESET}"
    rm -rf /etc/nginx /etc/letsencrypt /var/www /var/log/letsencrypt /etc/nginx/sites-available /etc/nginx/sites-enabled

    echo -e "${GREEN}Everything was removed successfully.${RESET}"
}

# ─────────────────────────────────────────────
# Main Menu
# ─────────────────────────────────────────────
function main_menu() {
    clear
    header
    echo -e "${BOLD}1) Install NGINX${RESET}"
    echo -e "${BOLD}2) Uninstall everything${RESET}"
    echo -e "${BOLD}3) Exit${RESET}"
    echo

    read -rp "Choose an option [1-3]: " choice
    case "$choice" in
        1)
            detect_os
            install_nginx
            if ask_yes_no "Do you want to configure SSL with Certbot for a domain?"; then
                install_certbot
                configure_nginx_site
                allow_firewall_ports
                obtain_ssl_certificate
            else
                echo -e "${YELLOW}SSL setup skipped.${RESET}"
            fi
            echo -e "${GREEN}Installation complete.${RESET}"
            ;;
        2)
            uninstall_all
            ;;
        3)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Try again.${RESET}"
            ;;
    esac
}

main_menu
