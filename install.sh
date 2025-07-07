#!/bin/bash
set -euo pipefail

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

pause() {
  read -rp $'\nPress Enter to continue...'
}

detect_os() {
  if [[ -e /etc/os-release ]]; then
    # shellcheck disable=SC1091
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

pre_install_choices() {
  echo -e "${CYAN}Would you like to upgrade system packages before continuing?${NC}"
  while true; do
    read -rp "Upgrade packages? (y/n): " ANSWER
    case "${ANSWER,,}" in
      y|yes) UPGRADE_PKGS=true; break ;;
      n|no) UPGRADE_PKGS=false; break ;;
      *) echo "Please answer y or n." ;;
    esac
  done

  echo -e "${CYAN}Would you like to install SSL via Certbot?${NC}"
  while true; do
    read -rp "Enable SSL with Certbot? (y/n): " ANSWER
    case "${ANSWER,,}" in
      y|yes)
        USE_SSL=true
        while true; do
          read -rp "Enter your domain name (e.g., example.com): " DOMAIN
          if [[ -n "$DOMAIN" ]]; then
            break
          else
            echo "Domain name cannot be empty."
          fi
        done
        break
        ;;
      n|no)
        USE_SSL=false
        break
        ;;
      *)
        echo "Please answer y or n."
        ;;
    esac
  done
}

install_nginx() {
  echo -e "${GREEN}[+] Updating package lists...${NC}"
  sudo apt update

  if [[ "$UPGRADE_PKGS" == true ]]; then
    echo -e "${GREEN}[+] Upgrading packages...${NC}"
    sudo apt upgrade -y
  fi

  echo -e "${GREEN}[+] Installing NGINX...${NC}"
  sudo apt install -y nginx
  sudo systemctl enable --now nginx
}

install_certbot() {
  echo -e "${GREEN}[+] Installing Certbot and dependencies...${NC}"
  sudo apt install -y software-properties-common
  sudo add-apt-repository universe -y
  sudo apt update
  sudo apt install -y certbot python3-certbot-nginx
}

obtain_ssl() {
  echo -e "${GREEN}[+] Obtaining SSL certificate for ${DOMAIN}...${NC}"
  sudo certbot --nginx -d "$DOMAIN"
}

uninstall_all() {
  echo -e "${RED}[-] Uninstalling NGINX and Certbot...${NC}"
  sudo systemctl stop nginx || true
  sudo apt purge -y nginx certbot python3-certbot-nginx || true
  sudo apt autoremove -y
  sudo rm -rf /etc/nginx /etc/letsencrypt /var/www/html
  echo -e "${GREEN}[✓] Uninstallation and cleanup complete.${NC}"
}

check_if_installed() {
  if command -v nginx >/dev/null 2>&1; then
    echo -e "${RED}[!] NGINX is already installed. Aborting installation.${NC}"
    exit 1
  fi
}

install_flow() {
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

uninstall_flow() {
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
    3) echo -e "${CYAN}Goodbye!${NC}" && exit 0 ;;
    *) echo -e "${RED}Invalid choice.${NC}" && sleep 1 ;;
  esac
done
