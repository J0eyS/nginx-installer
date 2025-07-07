#!/bin/sh

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
    [ "$(id -u)" -ne 0 ] && error "Run as root" && exit 1
}

check_os() {
    if ! grep -qi alpine /etc/os-release; then
        error "Unsupported OS. Only Alpine Linux is supported."
        exit 1
    fi
    info "Detected OS: Alpine"
}

read_domain() {
    while true; do
        prompt "Enter your domain name (e.g. example.com): "
        read -r domain
        domain=$(echo "$domain" | tr '[:upper:]' '[:lower:]')
        [ -z "$domain" ] && warn "Cannot be empty" && continue
        echo "$domain" | grep -Eq '^[a-z0-9.-]+$' && break || warn "Invalid domain format"
    done
    info "Using domain: $domain"
}

install_nginx() {
    info "Installing NGINX..."
    apk update >/dev/null
    apk add nginx >/dev/null
    rc-update add nginx default
    mkdir -p /var/www/$domain
    echo "<h1>Alpine NGINX for $domain</h1>" > /var/www/$domain/index.html

    cat > /etc/nginx/conf.d/$domain.conf <<EOF
server {
    listen 80;
    server_name $domain;
    root /var/www/$domain;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    nginx -t && rc-service nginx restart
    info "NGINX installed and configured for $domain"
}

uninstall_nginx() {
    prompt "Enter domain to remove: "
    read -r domain
    rc-service nginx stop
    apk del nginx
    rm -rf /etc/nginx/conf.d/$domain.conf
    rm -rf /var/www/$domain
    info "NGINX and config removed for $domain"
}

main_menu() {
    clear
    info "NGINX Installer - Alpine Linux"
    echo
    echo -e "${CYAN}[1] Install NGINX\n[2] Uninstall NGINX\n[3] Exit${NC}"
    echo
    prompt "Choice [1-3]: "
    read -r choice

    case "$choice" in
        1) read_domain; install_nginx ;;
        2) uninstall_nginx ;;
        3) exit 0 ;;
        *) warn "Invalid choice" ;;
    esac
}

check_root
check_os
main_menu
