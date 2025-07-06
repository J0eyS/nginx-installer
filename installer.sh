#!/bin/bash

# install-nginx.sh
# Ubuntu-based NGINX install script with SSL option and full config

set -e

# Functions
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        VERSION=$VERSION_ID
    else
        echo "Unsupported OS. Exiting."
        exit 1
    fi

    if [[ "$OS" != "ubuntu" ]]; then
        echo "This script is only designed for Ubuntu."
        exit 1
    fi
}

prompt_ssl() {
    read -rp "Do you want to enable SSL with Let's Encrypt? (y/n): " ENABLE_SSL
    if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
        read -rp "Enter your domain name (e.g. example.com): " DOMAIN
        read -rp "Enter your email for Let's Encrypt registration: " EMAIL
    fi
}

install_nginx() {
    echo "Updating packages..."
    sudo apt update

    echo "Installing NGINX..."
    sudo apt install -y nginx

    echo "Enabling and starting NGINX..."
    sudo systemctl enable nginx
    sudo systemctl start nginx
}

configure_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        echo "Configuring UFW firewall..."
        sudo ufw allow 'Nginx Full'
    else
        echo "UFW not installed. Skipping firewall config."
    fi
}

setup_ssl() {
    echo "Installing Certbot for SSL..."
    sudo apt install -y certbot python3-certbot-nginx

    echo "Obtaining SSL certificate for $DOMAIN..."
    sudo certbot --nginx -d "$DOMAIN" --email "$EMAIL" --agree-tos --no-eff-email

    echo "SSL has been set up for $DOMAIN."
}

write_nginx_config() {
    echo "Creating default NGINX site config..."

    CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
    sudo tee "$CONFIG_PATH" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root /var/www/$DOMAIN/html;
    index index.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF

    sudo mkdir -p /var/www/$DOMAIN/html
    echo "<h1>Welcome to $DOMAIN</h1>" | sudo tee /var/www/$DOMAIN/html/index.html

    sudo ln -sf "$CONFIG_PATH" /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl reload nginx
}

# Uninstall script generator
write_uninstaller() {
    cat <<'EOF' | sudo tee /usr/local/bin/uninstall-nginx.sh > /dev/null
#!/bin/bash

set -e

read -rp "Are you sure you want to completely remove NGINX and all related files? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborted."
    exit 0
fi

echo "Stopping and disabling NGINX..."
sudo systemctl stop nginx
sudo systemctl disable nginx

echo "Purging NGINX and Certbot..."
sudo apt purge -y nginx nginx-common nginx-core certbot python3-certbot-nginx
sudo apt autoremove -y
sudo apt clean

echo "Removing configuration and web root..."
sudo rm -rf /etc/nginx /var/www/* /var/log/nginx /etc/letsencrypt /var/lib/letsencrypt

echo "Removing uninstall script..."
sudo rm -- "$0"

echo "NGINX and all traces have been removed."
EOF

    sudo chmod +x /usr/local/bin/uninstall-nginx.sh
    echo "Uninstaller created at /usr/local/bin/uninstall-nginx.sh"
}

# Run steps
detect_os
prompt_ssl
install_nginx
configure_firewall

if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
    write_nginx_config
    setup_ssl
else
    echo "Skipping SSL setup."
    DOMAIN="default"
fi

write_uninstaller

echo "✅ NGINX installation complete."
if [[ "$ENABLE_SSL" =~ ^[Yy]$ ]]; then
    echo "🌐 Visit https://$DOMAIN to test your SSL-enabled site."
else
    echo "🌐 Visit http://localhost to test NGINX."
fi
