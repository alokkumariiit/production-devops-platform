output "ec2_public_ip" {
  description = "EC2 public IPv4 address"
  value       = aws_instance.app_server.public_ip
}

output "application_url" {
  description = "Production HTTPS application URL"
  value       = "https://production-cicd.duckdns.org"
}

output "prometheus_url" {
  description = "Prometheus URL"
  value       = "http://${aws_instance.app_server.public_ip}:9090"
}

output "grafana_url" {
  description = "Grafana URL"
  value       = "http://${aws_instance.app_server.public_ip}:3001"
}