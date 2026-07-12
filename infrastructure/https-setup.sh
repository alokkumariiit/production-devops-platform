#!/bin/bash

set -e

echo "========================================"
echo "Starting HTTPS and DuckDNS setup..."
echo "========================================"

DOMAIN="productioncicd.duckdns.org"
DUCKDNS_SUBDOMAIN="productioncicd"
DUCKDNS_TOKEN="${DUCKDNS_TOKEN}"
CERTBOT_EMAIL="${CERTBOT_EMAIL}"


echo "Installing required packages..."

apt-get update -y

apt-get install -y \
  curl \
  dnsutils \
  certbot \
  python3-certbot-nginx


echo "Getting EC2 public IPv4 using IMDSv2..."

IMDS_TOKEN=$(curl -s -X PUT \
  "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

PUBLIC_IP=$(curl -s \
  -H "X-aws-ec2-metadata-token: $IMDS_TOKEN" \
  "http://169.254.169.254/latest/meta-data/public-ipv4")


if [ -z "$PUBLIC_IP" ]; then
  echo "ERROR: Unable to get EC2 public IP."
  exit 1
fi


echo "EC2 Public IP: $PUBLIC_IP"


echo "Updating DuckDNS..."

DUCKDNS_RESPONSE=$(curl -s \
  "https://www.duckdns.org/update?domains=$DUCKDNS_SUBDOMAIN&token=$DUCKDNS_TOKEN&ip=$PUBLIC_IP")


echo "DuckDNS response: $DUCKDNS_RESPONSE"


if [ "$DUCKDNS_RESPONSE" != "OK" ]; then
  echo "ERROR: DuckDNS update failed."
  exit 1
fi


echo "DuckDNS updated successfully."


echo "Waiting for DNS propagation..."

DNS_RESOLVED=false

for i in $(seq 1 30)
do

  RESOLVED_IP=$(dig +short A "$DOMAIN" @8.8.8.8 | head -n 1)

  echo "Attempt $i"
  echo "Expected IP: $PUBLIC_IP"
  echo "Resolved IP: $RESOLVED_IP"

  if [ "$RESOLVED_IP" = "$PUBLIC_IP" ]; then

    echo "DNS propagation completed."

    DNS_RESOLVED=true

    break

  fi

  echo "DNS not ready. Waiting 10 seconds..."

  sleep 10

done


if [ "$DNS_RESOLVED" != "true" ]; then

  echo "ERROR: DNS did not resolve to EC2 IP."

  exit 1

fi


echo "Configuring Nginx domain..."

cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;

    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:3000;

        proxy_http_version 1.1;

        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF


echo "Testing Nginx configuration..."

nginx -t


echo "Reloading Nginx..."

systemctl reload nginx


echo "Checking application availability..."

for i in $(seq 1 12)
do

  HTTP_STATUS=$(curl -s \
    -o /dev/null \
    -w "%{http_code}" \
    "http://localhost:3000" || true)

  echo "Application HTTP status: $HTTP_STATUS"

  if [ "$HTTP_STATUS" = "200" ]; then

    echo "Application is ready."

    break

  fi

  echo "Application not ready. Waiting 5 seconds..."

  sleep 5

done


echo "Requesting Let's Encrypt SSL certificate..."

certbot --nginx \
  --non-interactive \
  --agree-tos \
  --no-eff-email \
  --redirect \
  --email "$CERTBOT_EMAIL" \
  -d "$DOMAIN"


echo "SSL certificate installed successfully."


echo "Adding Nginx security headers..."

sed -i "/server_name $DOMAIN;/a\\
    server_tokens off;\\
    add_header X-Content-Type-Options \"nosniff\" always;\\
    add_header X-Frame-Options \"SAMEORIGIN\" always;\\
    add_header Referrer-Policy \"strict-origin-when-cross-origin\" always;" \
    /etc/nginx/sites-available/default


echo "Testing final Nginx configuration..."

nginx -t


echo "Reloading Nginx..."

systemctl reload nginx


echo "Enabling Certbot renewal timer..."

systemctl enable certbot.timer

systemctl start certbot.timer


echo "Checking HTTPS endpoint..."

HTTPS_STATUS=$(curl -s \
  -o /dev/null \
  -w "%{http_code}" \
  "https://$DOMAIN")


echo "HTTPS status: $HTTPS_STATUS"


echo "========================================"
echo "HTTPS AUTOMATION COMPLETED"
echo "Application URL: https://$DOMAIN"
echo "========================================"