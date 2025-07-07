#!/bin/bash

info "Installing Nginx for Ubuntu..."

apt update -qq
apt install -y nginx

info "Creating server block for $domain..."
mkdir -p /var/www/$domain/html
echo "<h1>Hello from $domain (Ubuntu)</h1>" > /var/www/$domain/html/index.html

cat > /etc/nginx/sites-available/$domain <<EOF
server {
    listen 80;
    server_name $domain;
    root /var/www/$domain/html;
    index index.html;
}
EOF

ln -sf /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/

if [[ "$use_ssl" == "y" || "$use_ssl" == "yes" ]]; then
    apt install -y certbot python3-certbot-nginx
    certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$email" --redirect
fi

nginx -t && systemctl reload nginx
info "Done. Visit http://${domain} or https://${domain}"
