#!/bin/bash

info "Detected OS: Debian"
info "Installing Nginx for Debian..."

apt update -qq
apt install -y nginx

info "Creating server block for $domain..."
mkdir -p /var/www/$domain/html
echo "<h1>Welcome to $domain (Debian)</h1>" > /var/www/$domain/html/index.html

cat > /etc/nginx/sites-available/$domain <<EOF
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

ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

info "Testing and restarting Nginx..."
nginx -t && systemctl reload nginx

if [[ "$use_ssl" == "y" || "$use_ssl" == "yes" ]]; then
    info "Installing Certbot..."
    apt install -y certbot python3-certbot-nginx

    info "Obtaining SSL certificate for $domain..."
    certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$email" --redirect \
        && info "SSL successfully installed for $domain." \
        || error "Failed to install SSL. Check DNS or firewall."
else
    info "Skipping SSL setup."
fi

info "Deployment complete. Visit: http://${domain} or https://${domain}"
