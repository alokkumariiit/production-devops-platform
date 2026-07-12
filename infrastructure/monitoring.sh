#!/bin/bash

set -e

echo "Starting monitoring setup..."

echo "Installing Docker Compose..."

apt-get install -y docker-compose-v2

echo "Creating monitoring directory..."

mkdir -p /home/ubuntu/monitoring

cd /home/ubuntu/monitoring

echo "Creating Prometheus configuration..."

cat > prometheus.yml <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "node_exporter"

    static_configs:
      - targets:
          - node-exporter:9100
EOF

echo "Creating Docker Compose configuration..."

cat > docker-compose.yml <<'EOF'
services:

  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter

    restart: unless-stopped

    ports:
      - "9100:9100"

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus

    restart: unless-stopped

    ports:
      - "9090:9090"

    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml

  grafana:
    image: grafana/grafana:latest
    container_name: grafana

    restart: unless-stopped

    ports:
      - "3001:3000"
EOF

echo "Setting monitoring directory permissions..."

chown -R ubuntu:ubuntu /home/ubuntu/monitoring

echo "Starting monitoring stack..."

docker compose up -d

echo "Monitoring stack started successfully."

docker ps