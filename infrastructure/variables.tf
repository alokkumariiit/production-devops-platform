variable "instance_type" {
  default = "t3.micro"
}

variable "duckdns_token" {
  description = "DuckDNS authentication token"
  type        = string
  sensitive   = true
}

variable "certbot_email" {
  description = "Email address for Let's Encrypt certificate"
  type        = string
}