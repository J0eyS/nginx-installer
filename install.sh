#!/bin/bash

# Colors
GREEN="\033[1;32m"
RED="\033[1;31m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
NC="\033[0m"

# Globals
OS=""
USE_SSL=false
UPGRADE_PKGS=false
DOMAIN=""

function pause() {
  read -rp $'\nPress Enter to continue...'
}

function detect_os() {
  if [[ -e /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
  else
    echo -e "${RED}[!] Cannot detect OS. Aborting.${NC}"
    exit 1
  fi

  if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    echo -e "${RED}[!] Unsupported OS: $OS. Only Ubuntu/Debian are supported.${NC}"
    exit 1
  fi
}

function pre_install_choices() {
  echo -e "${CYAN}Would you like to upgrade system packages before continuing?${NC}"
  read -rp "Upgrade packages? (y/n): " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    UPGRADE_PKGS=true
  fi

  echo -e "${CYAN}Would you like to install SSL via Certbot?${NC}"
  read -rp "Enable SSL with Certbot? (y/n): " ANSWER
  if [[ "$ANSWER" =~ ^[Yy]$ ]]; then
    USE_SSL=true
    read -rp "Enter your domain name (e.g., example.com): " DOMAIN
  fi
}

function install_nginx() {
  echo -e "${GREEN}[+] Updating packages...${NC}"
  apt update -y

  if [[ "$UPGRADE_PKGS" == true ]]; then
    echo -e "${GREEN}[+] Upgrading packages...${NC}"
    apt upgrade -y
  fi

  echo -e "${GREEN}[+] Installing NGINX...${NC}"
  apt install -y nginx
  systemctl enable --now nginx
}

function install_certbot() {
  echo -e "${GREEN}[+] Installing Certbot...${NC}"
  apt install -y software-properties-common
  add-apt-repository universe -y
  apt update -y
  apt install -y certbot python3-certbot-nginx
}

function obtain_ssl() {
  echo -e "${GREEN}[+] Obtaining SSL certificate for ${DOMAIN}...${NC}"
  certbot --nginx -d "$DOMAIN"
}

function uninstall_all() {
  echo -e "${RED}[-] Uninstalling NGINX and Certbot...${NC}"
  systemctl stop nginx
  apt purge -y nginx certbot python3-certbot-nginx
  apt autoremove -y
  rm -rf /etc/nginx /etc/letsencrypt /var/www/html
  echo -e "${GREEN}[✓] Uninstallation and cleanup complete.${NC}"
}

function check_if_installed() {
  if command -v nginx >/dev/null 2>&1; then
    echo -e "${RED}[!] NGINX is already installed. Aborting installation.${NC}"
    exit 1
  fi
}

function install_flow() {
  detect_os
  check_if_installed
  pre_install_choices
  install_nginx
  if [[ "$USE_SSL" == true ]]; then
    install_certbot
    obtain_ssl
  fi
  echo -e "\n${GREEN}[✓] Installation complete.${NC}"
  pause
}

function uninstall_flow() {
  uninstall_all
  pause
}

# Main Menu
while true; do
  clear
  detect_os
  echo -e "${CYAN}== NGINX Auto Installer ==${NC}"
  echo -e "Detected OS: ${YELLOW}${OS^^}${NC}\n"
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
