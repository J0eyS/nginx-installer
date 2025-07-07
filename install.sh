#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

info()   { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()   { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()  { echo -e "${RED}[ERROR]${NC} $*"; }
prompt() { echo -ne "${CYAN}$*${NC} "; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Please run as root: sudo bash $0"
        exit 1
    fi
}

detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_NAME=$NAME
    else
        error "Unable to detect OS."
        exit 1
    fi
}

show_menu() {
    echo
    info "Detected Operating System: $OS_NAME"
    echo -e "${CYAN}"
    echo "[1] Install Nginx"
    echo "[2] Uninstall Nginx"
    echo "[3] Exit"
    echo -e "${NC}"
    prompt "Choose an option [1-3]: "
    read -r choice
}

main() {
    check_root
    detect_os
    show_menu

    case "$choice" in
        1)
            if [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" ]]; then
                source ./debian.sh
                run_installer
            elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
                source ./centos.sh
                run_installer
            else
                error "Unsupported OS: $OS_NAME"
                exit 1
            fi
            ;;
        2)
            if [[ "$OS_ID" == "debian" || "$OS_ID" == "ubuntu" ]]; then
                source ./debian.sh
                run_uninstaller
            elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" ]]; then
                source ./centos.sh
                run_uninstaller
            else
                error "Unsupported OS: $OS_NAME"
                exit 1
            fi
            ;;
        3)
            info "Exiting."
            exit 0
            ;;
        *)
            warn "Invalid option."
            ;;
    esac
}

main
