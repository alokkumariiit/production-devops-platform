#!/bin/bash

apt-get update -y

apt-get install -y docker.io nginx

systemctl enable docker
systemctl start docker

# Add ubuntu user to docker group
usermod -aG docker ubuntu

systemctl enable nginx
systemctl start nginx

sleep 10

docker pull alokkumar01/production-cicd-pipeline:v1

docker run -d \
--name app-container \
-p 3000:3000 \
-e NODE_ENV=production \
--restart unless-stopped \
alokkumar01/production-cicd-pipeline:v1

cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    server_name _;

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

systemctl restart nginx