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
        error "Run as root: sudo bash $0"
        exit 1
    fi
}

check_os() {
    if [[ ! -f /etc/os-release ]]; then
        error "Unsupported OS. This installer only works on Ubuntu."
        exit 1
    fi

    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]]; then
        error "Unsupported OS: $ID. Only Ubuntu is supported."
        exit 1
    fi
    info "Detected OS: Ubuntu $VERSION_ID"
}

read_domain() {
    while true; do
        prompt "Enter your domain name (e.g. example.com): "
        read -r domain
        domain=${domain,,} # lowercase
        [[ -z "$domain" ]] && warn "Domain name cannot be empty." && continue
        [[ "$domain" =~ ^[a-z0-9.-]+$ ]] && break || warn "Invalid domain format."
    done
    info "Using domain: $domain"
}

install_nginx() {
    info "Updating packages..."
    apt update -qq
    info "Installing NGINX..."
    apt install -y nginx >/dev/null
    systemctl enable --now nginx

    info "Allowing NGINX through UFW (if active)..."
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow 'Nginx Full'
    fi

    mkdir -p /var/www/$domain/html
    chown -R www-data:www-data /var/www/$domain/html
    cat > /var/www/$domain/html/index.html <<EOF
<!DOCTYPE html>
<html><head><title>Welcome</title></head>
<body><h1>Success! NGINX is serving $domain</h1></body>
</html>
EOF

    cat > /etc/nginx/sites-available/$domain <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name $domain;

    root /var/www/$domain/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    nginx -t && systemctl reload nginx
    info "NGINX installed and configured for $domain"
}

install_ssl() {
    info "Installing Certbot..."
    apt install -y certbot python3-certbot-nginx >/dev/null
    if certbot --nginx -d "$domain" --non-interactive --agree-tos -m "admin@$domain" --redirect; then
        info "SSL installed for $domain"
    else
        error "SSL installation failed. Check DNS settings."
    fi
}

uninstall_nginx() {
    prompt "Enter domain to uninstall (e.g. example.com): "
    read -r domain
    domain=${domain,,}

    info "Stopping and removing NGINX..."
    systemctl stop nginx || true
    apt purge -y nginx certbot python3-certbot-nginx >/dev/null
    apt autoremove -y >/dev/null

    info "Removing configs and files..."
    rm -rf /etc/nginx/sites-available/$domain
    rm -rf /etc/nginx/sites-enabled/$domain
    rm -rf /var/www/$domain
    rm -rf /etc/letsencrypt/live/$domain

    info "NGINX and SSL removed for $domain"
}

main_menu() {
    clear
    info "Detected OS: Ubuntu $(lsb_release -sr 2>/dev/null || echo "$VERSION_ID")"
    echo
    echo -e "${CYAN}[1] Install NGINX"
    echo -e "[2] Uninstall NGINX"
    echo -e "[3] Exit${NC}"
    echo

    prompt "Choose an option [1-3]: "
    read -r choice

    case "$choice" in
        1)
            read_domain
            install_nginx
            prompt "Install SSL for $domain? (y/N): "
            read -r ssl_choice
            [[ "${ssl_choice,,}" == "y" || "${ssl_choice,,}" == "yes" ]] && install_ssl
            ;;
        2)
            uninstall_nginx
            ;;
        3)
            info "Exiting."
            exit 0
            ;;
        *)
            warn "Invalid choice."
            ;;
    esac
}

### Script start
check_root
check_os
main_menu
