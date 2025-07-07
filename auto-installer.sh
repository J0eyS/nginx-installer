#!/bin/bash
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

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

detect_os() {
    if command -v lsb_release &>/dev/null; then
        os_name=$(lsb_release -si)
        os_version=$(lsb_release -sr)
    elif [[ -f /etc/os-release ]]; then
        os_name=$(grep "^NAME=" /etc/os-release | cut -d= -f2 | tr -d \")
        os_version=$(grep "^VERSION_ID=" /etc/os-release | cut -d= -f2 | tr -d \")
    else
        os_name="Unknown OS"
        os_version=""
    fi
    echo "$os_name $os_version"
}

read_domain() {
    while true; do
        prompt "Enter your domain name (e.g. example.com): "
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
    local email="$1"
    info "Obtaining SSL certificate for $domain via Certbot..."
    if certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$email" --redirect; then
        info "SSL certificate installed successfully for $domain!"
        return 0
    else
        error "Failed to obtain SSL certificate. Check DNS and try again."
        return 1
    fi
}

uninstall_nginx() {
    info "This will uninstall Nginx and remove all sites and web roots."
    prompt "Are you sure you want to continue? (y/N): "
    read -r answer
    answer=${answer,,}
    if [[ "$answer" != "y" && "$answer" != "yes" ]]; then
        warn "Uninstallation aborted."
        return
    fi

    info "Stopping Nginx service..."
    systemctl stop nginx || warn "Nginx service was not running."

    info "Disabling Nginx service..."
    systemctl disable nginx || warn "Nginx service was not enabled."

    info "Removing Nginx and Certbot packages..."
    apt purge -y nginx certbot python3-certbot-nginx >/dev/null

    info "Removing all site configurations in /etc/nginx/sites-available and sites-enabled..."
    rm -f /etc/nginx/sites-available/*
    rm -f /etc/nginx/sites-enabled/*

    info "Removing all web root directories in /var/www/..."
    # Only remove dirs with html subfolder inside (to avoid deleting unrelated folders)
    for d in /var/www/*; do
        if [[ -d "$d/html" ]]; then
            rm -rf "$d"
        fi
    done

    info "Removing Nginx Full UFW firewall rule (if exists)..."
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw delete allow 'Nginx Full' || warn "Failed to remove UFW rule or it did not exist."
        ufw reload
    fi

    info "Reloading systemd daemon..."
    systemctl daemon-reload

    info "Uninstallation complete. Nginx and all sites removed."
}

print_header() {
    local width=50
    echo -e "${BOLD}${CYAN}$(printf '%*s' $((width / 2)) '' | tr ' ' '=')${NC}"
    echo -e "${BOLD}${CYAN}$(printf '%*s' $(( (width - 23) / 2 )) '' )Nginx Installer Script${NC}"
    echo -e "${BOLD}${CYAN}$(printf '%*s' $((width / 2)) '' | tr ' ' '=')${NC}"
    echo
}

main_menu() {
    check_root
    while true; do
        clear
        print_header
        osinfo=$(detect_os)
        echo -e "${CYAN}Detected Operating System:${NC} $osinfo"
        echo
        echo -e "${BOLD}Please choose an option:${NC}"
        echo -e "  [${GREEN}1${NC}] Install Nginx"
        echo -e "  [${GREEN}2${NC}] Uninstall Nginx"
        echo -e "  [${GREEN}3${NC}] Exit"
        echo
        prompt "Enter choice [1-3]: "
        read -r choice
        case "$choice" in
            1)
                echo
                read_domain
                install_nginx
                setup_nginx_server_block

                echo
                prompt "Install free SSL certificate for $domain? (y/N): "
                read -r ssl_choice
                ssl_choice=${ssl_choice,,}

                if [[ "$ssl_choice" == "y" || "$ssl_choice" == "yes" ]]; then
                    install_certbot
                    prompt "Enter your email address (for Let's Encrypt notifications): "
                    read -r email
                    if obtain_ssl "$email"; then
                        echo
                        info "Done! Visit your site at: https://$domain"
                    else
                        echo
                        info "SSL installation skipped due to errors. Visit your site at: http://$domain"
                    fi
                else
                    info "Skipping SSL installation."
                    echo
                    info "Done! Visit your site at: http://$domain"
                fi
                prompt "Press Enter to continue..."
                read -r _
                ;;
            2)
                echo
                uninstall_nginx
                prompt "Press Enter to continue..."
                read -r _
                ;;
            3)
                echo
                info "Goodbye!"
                exit 0
                ;;
            *)
                warn "Invalid choice. Please enter 1, 2, or 3."
                sleep 1
                ;;
        esac
    done
}

main_menu
