resource "aws_security_group" "app_sg" {
  name = "production-cicd-sg"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
  key_name = "aws-key-pair"
  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  user_data = file("${path.module}/ec2-bootstrap.sh")

  tags = {
    Name = "production-cicd-server"
  }
}