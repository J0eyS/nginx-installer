#!/bin/bash

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
    [[ $EUID -ne 0 ]] && error "Run as root" && exit 1
}

check_os() {
    if ! grep -qiE 'centos|rhel|rocky|alma' /etc/os-release; then
        error "Unsupported OS. Only RHEL-based distros supported."
        exit 1
    fi
    . /etc/os-release
    info "Detected OS: $NAME $VERSION_ID"
}

read_domain() {
    while true; do
        prompt "Enter your domain name (e.g. example.com): "
        read -r domain
        domain=${domain,,}
        [[ -z "$domain" ]] && warn "Domain cannot be empty." && continue
        [[ "$domain" =~ ^[a-z0-9.-]+$ ]] && break || warn "Invalid domain format."
    done
    info "Using domain: $domain"
}

install_nginx() {
    info "Installing EPEL and NGINX..."
    yum install -y epel-release >/dev/null
    yum install -y nginx >/dev/null
    systemctl enable --now nginx

    mkdir -p /var/www/$domain/html
    echo "<h1>NGINX on $domain</h1>" > /var/www/$domain/html/index.html

    cat > /etc/nginx/conf.d/$domain.conf <<EOF
server {
    listen 80;
    server_name $domain;
    root /var/www/$domain/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    nginx -t && systemctl reload nginx
    info "NGINX installed and configured for $domain"
}

install_ssl() {
    info "Installing Certbot..."
    yum install -y certbot python3-certbot-nginx >/dev/null
    certbot --nginx -d "$domain" --non-interactive --agree-tos -m "admin@$domain" --redirect
    info "SSL installed for $domain"
}

uninstall_nginx() {
    prompt "Enter domain to remove: "
    read -r domain
    domain=${domain,,}

    info "Removing NGINX and configs..."
    systemctl stop nginx
    yum remove -y nginx certbot python3-certbot-nginx >/dev/null
    rm -rf /etc/nginx/conf.d/$domain.conf
    rm -rf /var/www/$domain
    rm -rf /etc/letsencrypt/live/$domain
    info "Uninstalled NGINX and cleaned up $domain"
}

main_menu() {
    clear
    info "NGINX Installer - CentOS / Rocky / AlmaLinux"
    echo
    echo -e "${CYAN}[1] Install NGINX\n[2] Uninstall NGINX\n[3] Exit${NC}"
    echo
    prompt "Choice [1-3]: "
    read -r choice

    case "$choice" in
        1)
            read_domain
            install_nginx
            prompt "Install SSL with Certbot? (y/N): "
            read -r ssl
            [[ "${ssl,,}" == "y" ]] && install_ssl
            ;;
        2) uninstall_nginx ;;
        3) exit 0 ;;
        *) warn "Invalid choice" ;;
    esac
}

check_root
check_os
main_menu
