#!/bin/bash
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
prompt()  { echo -ne "${CYAN}$*${NC} "; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Please run as root: sudo bash $0"
        exit 1
    fi
}

read_domain() {
    while true; do
        prompt "Enter your domain name (e.g. example.com):"
        read -r domain
        domain=${domain,,} # lowercase
        if [[ -z "$domain" ]]; then
            warn "Domain name cannot be empty."
            continue
        fi
        if [[ "$domain" =~ ^[a-z0-9.-]+$ ]]; then
            info "Domain set to: $domain"
            break
        else
            warn "Invalid domain format. Only letters, digits, dots and hyphens allowed."
        fi
    done
}

install_nginx() {
    info "Updating package cache..."
    apt update -qq

    info "Installing Nginx..."
    apt install -y nginx >/dev/null

    info "Allowing 'Nginx Full' profile through UFW firewall (if UFW active)..."
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow 'Nginx Full'
    fi

    info "Starting and enabling Nginx service..."
    systemctl enable --now nginx

    info "Nginx installed and running."
}

setup_nginx_server_block() {
    local conf_path="/etc/nginx/sites-available/$domain"
    info "Creating Nginx server block for $domain..."

    cat > "$conf_path" <<EOF
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

    info "Creating web root directory..."
    mkdir -p /var/www/"$domain"/html

    info "Setting ownership to www-data..."
    chown -R www-data:www-data /var/www/"$domain"/html

    info "Creating sample index.html..."
    cat > /var/www/"$domain"/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to $domain!</title>
</head>
<body>
    <h1>Success! Nginx is installed and serving $domain.</h1>
</body>
</html>
EOF

    info "Enabling site and disabling default..."
    ln -sf "$conf_path" /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default

    info "Testing Nginx configuration..."
    nginx -t

    info "Reloading Nginx to apply changes..."
    systemctl reload nginx
}

install_certbot() {
    info "Installing Certbot and Nginx plugin..."
    apt update -qq
    apt install -y certbot python3-certbot-nginx >/dev/null
}

obtain_ssl() {
    info "Obtaining SSL certificate for $domain via Certbot..."
    if certbot --nginx -d "$domain" --non-interactive --agree-tos -m "admin@$domain" --redirect; then
        info "SSL certificate installed successfully for $domain!"
    else
        error "Failed to obtain SSL certificate. Check DNS and try again."
    fi
}

main() {
    check_root
    read_domain
    install_nginx
    setup_nginx_server_block

    echo
    prompt "Install free SSL certificate for $domain? (y/N):"
    read -r ssl_choice
    ssl_choice=${ssl_choice,,}

    if [[ "$ssl_choice" == "y" || "$ssl_choice" == "yes" ]]; then
        install_certbot
        obtain_ssl
    else
        info "Skipping SSL installation."
    fi

    echo
    info "Done! Visit your site at: http://$domain"
    info "If SSL was installed, visit https://$domain"
}

main
