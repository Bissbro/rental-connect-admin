#!/bin/bash
# Usage: ./provision-tenant.sh <slug> <db_name>
# Example: ./provision-tenant.sh coral rc_tenant_2

SLUG=$1
DB_NAME=$2
if [ -z "$SLUG" ]; then echo "Usage: $0 <slug> [db_name]"; exit 1; fi

DOMAIN="${SLUG}.api.htmrentals.com"
GUEST_DIR="/home/bitnami/rental-connect-guest"
VHOST_DIR="/opt/bitnami/apache/conf/vhosts"

echo "Provisioning: $SLUG ($DOMAIN)"

# 1. Create tenant.js
mkdir -p "${GUEST_DIR}/${SLUG}"
echo "window.RC_TENANT_SLUG = '${SLUG}';" > "${GUEST_DIR}/${SLUG}/tenant.js"
echo "✓ tenant.js created"

# 2. Clone schema + grant privileges (if db_name provided)
if [ -n "$DB_NAME" ]; then
  sudo mysqldump --no-data rc_tenant_2 2>/dev/null | sudo mysql "$DB_NAME" 2>/dev/null
  sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO 'htm_user'@'localhost'; FLUSH PRIVILEGES;" 2>/dev/null
  echo "✓ Schema cloned + privileges granted for $DB_NAME"
  # Insert default website setting
  sudo mysql "$DB_NAME" -e "INSERT IGNORE INTO settings (setting_key, setting_value) VALUES ('website', 'https://${SLUG}.api.htmrentals.com/index.html');" 2>/dev/null
  echo "✓ Default settings inserted"
fi

# 3. Write HTTP-only vhost
sudo tee "${VHOST_DIR}/${SLUG}-vhost.conf" > /dev/null << APACHEEOF
<VirtualHost *:80>
    ServerName ${DOMAIN}
    Alias /tenant.js ${GUEST_DIR}/${SLUG}/tenant.js
    DocumentRoot ${GUEST_DIR}
    <Directory ${GUEST_DIR}>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>
    ProxyPass /api http://localhost:3000/api
    ProxyPassReverse /api http://localhost:3000/api
    ProxyPass /uploads http://localhost:3000/uploads
    ProxyPassReverse /uploads http://localhost:3000/uploads
</VirtualHost>
APACHEEOF
sudo apachectl graceful
echo "✓ HTTP vhost active"

# 4. Get SSL cert
sudo certbot certonly --webroot -w ${GUEST_DIR} -d ${DOMAIN} --non-interactive --agree-tos --email htmrentalss@gmail.com
if [ $? -ne 0 ]; then echo "✗ Certbot failed"; exit 1; fi
echo "✓ SSL cert issued"

# 4b. Create nginx server block for this tenant (SSL termination for public traffic)
sudo tee "/etc/nginx/sites-available/${SLUG}" > /dev/null << NGINXEOF
server {
    listen 443 ssl;
    server_name ${DOMAIN};
    ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINXEOF
sudo ln -sf "/etc/nginx/sites-available/${SLUG}" "/etc/nginx/sites-enabled/${SLUG}"
sudo nginx -t && sudo systemctl reload nginx
if [ $? -ne 0 ]; then echo "✗ nginx config/reload failed - check manually"; exit 1; fi
echo "✓ nginx SSL vhost active"

# 5. Add HTTPS vhost
sudo tee -a "${VHOST_DIR}/${SLUG}-vhost.conf" > /dev/null << APACHEEOF

<VirtualHost *:443>
    ServerName ${DOMAIN}
    SSLEngine on
    SSLCertificateFile "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem"
    SSLCertificateKeyFile "/etc/letsencrypt/live/${DOMAIN}/privkey.pem"
    Alias /tenant.js ${GUEST_DIR}/${SLUG}/tenant.js
    DocumentRoot ${GUEST_DIR}
    <Directory ${GUEST_DIR}>
        Options -Indexes
        AllowOverride None
        Require all granted
    </Directory>
    ProxyPass /api http://localhost:3000/api
    ProxyPassReverse /api http://localhost:3000/api
    ProxyPass /uploads http://localhost:3000/uploads
    ProxyPassReverse /uploads http://localhost:3000/uploads
</VirtualHost>
APACHEEOF
sudo apachectl graceful
echo "✓ HTTPS vhost active"
echo ""
echo "Done! https://${DOMAIN}"
