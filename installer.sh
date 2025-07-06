#!/bin/bash

# Colors
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
NC="\033[0m"

# Welcome
clear
echo -e "${CYAN}== NGINX Auto Installer ==${NC}"

function pause() {
    read -rp "Press Enter to continue..."
}

function detect_os() {
    if [[ -e /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
    else
        echo -e "${RED}Cannot detect OS. Aborting.${NC}"
        exit 1
    fi

    if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
        echo -e "${RED}Unsupported OS: $OS. Only Ubuntu/Debian supported.${NC}"
        exit 1
    fi
}

function ask_ssl() {
    read -rp "Do you want to enable SSL with Certbot? (y/n): " ENABLE_SSL
    if [[ "$ENABLE_SSL" == "y" || "$ENABLE_SSL" == "Y" ]]; then
        read -rp "Enter your domain name (e.g. example.com): " DOMAIN
        USE_SSL=true
    else
        USE_SSL=false
    fi
}

function install_nginx() {
    echo -e "${CYAN}Installing NGINX...${NC}"
    apt update -y && apt install -y nginx
    systemctl enable nginx
    systemctl start nginx
}

function install_certbot_apt() {
    echo -e "${CYAN}Installing Certbot (via apt)...${NC}"
    apt install -y software-properties-common
    add-apt-repository universe -y
    apt update -y
    apt install -y certbot python3-certbot-nginx
}

function obtain_ssl() {
    echo -e "${CYAN}Setting up SSL for ${DOMAIN}...${NC}"
    systemctl stop nginx
    sleep 1
    systemctl start nginx

    # Certbot will configure nginx itself
    certbot --nginx -d "$DOMAIN"

    echo -e "${GREEN}SSL certificate obtained and NGINX configured.${NC}"
}

function uninstall_all() {
    echo -e "${RED}Uninstalling NGINX and Certbot...${NC}"
    systemctl stop nginx
    apt purge -y nginx certbot python3-certbot-nginx
    apt autoremove -y
    rm -rf /etc/nginx /etc/letsencrypt /var/www/html
    echo -e "${GREEN}Cleanup complete.${NC}"
}

function install_flow() {
    detect_os
    ask_ssl
    install_nginx

    if [[ "$USE_SSL" == true ]]; then
        install_certbot_apt
        obtain_ssl
    fi

    echo -e "${GREEN}Installation complete.${NC}"
    pause
}

function uninstall_flow() {
    uninstall_all
    pause
}

# Menu
while true; do
    clear
    echo -e "${CYAN}== NGINX Auto Installer ==${NC}"
    echo -e "${GREEN}1)${NC} Install NGINX"
    echo -e "${RED}2)${NC} Uninstall everything"
    echo -e "${CYAN}3)${NC} Exit"
    echo ""
    read -rp "Select an option: " CHOICE

    case "$CHOICE" in
        1) install_flow ;;
        2) uninstall_flow ;;
        3) echo "Goodbye!" && exit 0 ;;
        *) echo -e "${RED}Invalid choice.${NC}" && sleep 1 ;;
    esac
done

