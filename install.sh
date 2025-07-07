#!/bin/bash

# Colors
GREEN="\033[1;32m"
RED="\033[1;31m"
YELLOW="\033[1;33m"
CYAN="\033[1;36m"
NC="\033[0m"

# Globals
NGINX_INSTALLED=false
CERTBOT_INSTALLED=false
DOMAIN=""
USE_SSL=false
OS=""

# === UTILITY FUNCTIONS ===

function print_header() {
    clear
    echo -e "${CYAN}====================================="
    echo -e "      NGINX AUTO INSTALLER"
    echo -e "=====================================${NC}"
}

function pause() {
    read -rp "Press Enter to continue..."
}

function check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root.${NC}"
        exit 1
    fi
}

function detect_os() {
    if [[ -e /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        echo -e "${RED}Unsupported OS: $OS. Only Ubuntu/Debian are supported.${NC}"
        exit 1
    fi
}

function check_installed() {
    if command -v nginx &>/dev/null; then
        NGINX_INSTALLED=true
    fi
    if command -v certbot &>/dev/null; then
        CERTBOT_INSTALLED=true
    fi
}

function ask_options() {
    echo -e "${YELLOW}Pre-Installation Options:${NC}"
    echo ""
    read -rp "Do you want to install an SSL certificate using Certbot? (y/n): " ssl_choice
    if [[ "$ssl_choice" =~ ^[Yy]$ ]]; then
        read -rp "Enter the domain name to secure (e.g. example.com): " DOMAIN
        USE_SSL=true
    fi
    echo ""
    pause
}

# === INSTALLATION ===

function install_nginx() {
    echo -e "${CYAN}Installing NGINX...${NC}"
    apt update -y
    apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
    echo -e "${GREEN}NGINX installed and running.${NC}"
}

function install_certbot() {
    echo -e "${CYAN}Installing Certbot...${NC}"
    apt install -y software-properties-common
    if [[ "$OS" == "ubuntu" ]]; then
        add-apt-repository universe -y
    fi
    apt update -y
    apt install -y certbot python3-certbot-nginx
    echo -e "${GREEN}Certbot installed.${NC}"
}

function obtain_ssl() {
    echo -e "${CYAN}Requesting SSL certificate for ${DOMAIN}...${NC}"
    systemctl start nginx
    certbot --nginx --non-interactive --agree-tos -m "admin@${DOMAIN}" -d "${DOMAIN}" || {
        echo -e "${RED}Failed to obtain SSL certificate for ${DOMAIN}.${NC}"
        exit 1
    }
    echo -e "${GREEN}SSL successfully configured for ${DOMAIN}.${NC}"
}

# === UNINSTALLATION ===

function uninstall_all() {
    echo -e "${RED}Uninstalling NGINX and Certbot...${NC}"
    systemctl stop nginx
    apt purge -y nginx certbot python3-certbot-nginx
    apt autoremove -y
    rm -rf /etc/nginx /etc/letsencrypt /var/www/html
    echo -e "${GREEN}Uninstall complete.${NC}"
}

# === FLOW ===

function install_flow() {
    check_root
    detect_os
    check_installed

    if $NGINX_INSTALLED; then
        echo -e "${RED}NGINX is already installed. Please uninstall first or use it manually.${NC}"
        exit 1
    fi

    print_header
    ask_options

    install_nginx

    if $USE_SSL; then
        install_certbot
        obtain_ssl
    fi

    echo -e "${GREEN}Installation complete!${NC}"
    pause
}

function uninstall_flow() {
    check_root
    detect_os
    print_header
    uninstall_all
    pause
}

# === MENU ===

function main_menu() {
    while true; do
        print_header
        echo -e "${GREEN}1)${NC} Install NGINX"
        echo -e "${RED}2)${NC} Uninstall NGINX & Certbot"
        echo -e "${CYAN}3)${NC} Exit"
        echo ""
        read -rp "Select an option [1-3]: " choice
        case "$choice" in
            1) install_flow ;;
            2) uninstall_flow ;;
            3) echo "Goodbye!" && exit 0 ;;
            *) echo -e "${RED}Invalid option.${NC}" && sleep 1 ;;
        esac
    done
}

main_menu
