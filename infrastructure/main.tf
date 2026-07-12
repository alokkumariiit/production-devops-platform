resource "aws_security_group" "app_sg" {
  name = "production-cicd-sg"

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana
  ingress {
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "app_server" {
  ami           = "ami-01a00762f46d584a1"
  instance_type = var.instance_type
  key_name      = "aws-key-pair"

  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data_replace_on_change = true

  user_data = <<-EOF
    #!/bin/bash

    set -e

    export DUCKDNS_TOKEN='${var.duckdns_token}'
    export CERTBOT_EMAIL='${var.certbot_email}'

    echo "========================================"
    echo "Running EC2 bootstrap script..."
    echo "========================================"

    ${file("${path.module}/ec2-bootstrap.sh")}

    echo "EC2 bootstrap completed."


    echo "========================================"
    echo "Running monitoring setup script..."
    echo "========================================"

    ${file("${path.module}/monitoring.sh")}

    echo "Monitoring setup completed."


    echo "========================================"
    echo "Running HTTPS setup script..."
    echo "========================================"

    ${file("${path.module}/https-setup.sh")}

    echo "HTTPS setup completed."


    echo "========================================"
    echo "SERVER BOOTSTRAP COMPLETED"
    echo "========================================"
  EOF

  tags = {
    Name = "production-cicd-server"
  }
}