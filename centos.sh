#!/bin/bash

info "Detected OS: CentOS"
info "Installing Nginx for CentOS..."

dnf install -y epel-release
dnf install -y nginx

systemctl enable --now nginx

info "Creating server block for $domain..."
mkdir -p /var/www/$domain/html
echo "<h1>Welcome to $domain (CentOS)</h1>" > /var/www/$domain/html/index.html

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

info "Testing and restarting Nginx..."
nginx -t && systemctl reload nginx

if [[ "$use_ssl" == "y" || "$use_ssl" == "yes" ]]; then
    info "Installing Certbot..."
    dnf install -y certbot python3-certbot-nginx

    info "Obtaining SSL certificate for $domain..."
    certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$email" --redirect \
        && info "SSL successfully installed for $domain." \
        || error "Failed to install SSL. Check DNS or firewall."
else
    info "Skipping SSL setup."
fi

info "Deployment complete. Visit: http://${domain} or https://${domain}"
