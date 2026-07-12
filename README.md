# Production-Ready CI/CD Pipeline with Docker & AWS

A production-oriented DevOps platform that automates cloud infrastructure provisioning, container image delivery, application deployment, reverse proxy configuration, HTTPS enablement, DNS management, and infrastructure monitoring on AWS.

The project demonstrates an end-to-end DevOps workflow using Terraform, Docker, GitHub Actions, AWS EC2, Nginx, Prometheus, and Grafana.

---

## Live Application

**Production URL:** `https://productioncicd.duckdns.org`

**Health Endpoint:** `https://productioncicd.duckdns.org/health`

---

## Project Overview

This project implements a complete automated CI/CD workflow from source code changes to production deployment.

```text
Developer
    |
    v
GitHub Repository
    |
    v
GitHub Actions
    |
    +-----------------------------+
    |                             |
    v                             v
Build Docker Image        Tag Docker Image
                                  |
                                  v
                         Commit SHA + latest
    |                             |
    +-------------+---------------+
                  |
                  v
             Docker Hub
                  |
                  v
        SSH Automated Deployment
                  |
                  v
              AWS EC2
                  |
        +---------+---------+
        |         |         |
        v         v         v
      Nginx    Docker    Monitoring
        |      Node.js       |
        |                    +--> Node Exporter
        |                    +--> Prometheus
        |                    +--> Grafana
        |
        v
   HTTPS Application
```

Infrastructure provisioning and EC2 configuration are automated using Terraform and Bash-based EC2 User Data scripts.

Application deployments are automatically triggered when code is pushed to the `main` branch.

---

## Tech Stack

| Category               | Technology                     |
| ---------------------- | ------------------------------ |
| Application            | Node.js, Express.js            |
| Containerization       | Docker                         |
| Container Registry     | Docker Hub                     |
| CI/CD                  | GitHub Actions                 |
| Cloud Platform         | AWS EC2                        |
| Infrastructure as Code | Terraform                      |
| Reverse Proxy          | Nginx                          |
| HTTPS / TLS            | Let's Encrypt, Certbot         |
| DNS                    | DuckDNS                        |
| Metrics Collection     | Prometheus                     |
| Host Monitoring        | Node Exporter                  |
| Visualization          | Grafana                        |
| Automation             | Bash, EC2 User Data            |
| Deployment             | SSH-based automated deployment |

---

## Key Features

* Dockerized Node.js and Express application
* Non-root application container
* Docker container health checks
* Automated Docker image builds
* Docker Hub image publishing
* Commit SHA and `latest` Docker image tagging
* AWS EC2 provisioning using Terraform
* EC2 Instance Metadata Service v2 enforcement
* Automated EC2 bootstrapping using User Data
* Automated Docker and Nginx installation
* Nginx reverse proxy configuration
* GitHub Actions CI/CD pipeline
* SSH-based automated production deployment
* Container health validation after deployment
* Automatic deployment failure detection
* Automatic unused Docker image cleanup
* Prometheus infrastructure metrics collection
* Node Exporter host monitoring
* Grafana infrastructure dashboards
* Automated DuckDNS DNS updates
* Automated Let's Encrypt certificate provisioning
* Certbot certificate renewal
* HTTP-to-HTTPS redirection
* Nginx security headers

---

## Repository Structure

```text
production-devops-platform/
├── .github/
│   └── workflows/
│       └── docker-build.yml
│
├── application/
│   ├── src/
│   │   └── server.js
│   ├── .dockerignore
│   ├── Dockerfile
│   ├── package.json
│   └── package-lock.json
│
├── infrastructure/
│   ├── ec2-bootstrap.sh
│   ├── https-setup.sh
│   ├── main.tf
│   ├── monitoring.sh
│   ├── outputs.tf
│   ├── provider.tf
│   └── variables.tf
│
├── .gitignore
└── README.md
```

---

# Architecture

The application follows a reverse-proxy-based production architecture.

```text
Internet
   |
   v
DuckDNS
productioncicd.duckdns.org
   |
   v
AWS EC2
   |
   v
Nginx
Ports 80 / 443
   |
   v
Dockerized Node.js Application
Port 3000
```

Nginx acts as the public entry point for the application.

The Node.js application runs inside a Docker container on port `3000`. Public traffic is handled by Nginx and forwarded internally to the application container.

The application port is not intended to be directly exposed through the AWS security group.

---

# CI/CD Pipeline

A push to the `main` branch automatically triggers the GitHub Actions workflow.

```text
git push
   |
   v
GitHub Actions
   |
   v
Build Docker Image
   |
   v
Tag Image
   |
   +--> Commit SHA
   |
   +--> latest
   |
   v
Push to Docker Hub
   |
   v
SSH into EC2
   |
   v
Pull Latest Image
   |
   v
Replace Application Container
   |
   v
Validate Container Health
   |
   +--> Healthy --> Deployment Successful
   |
   +--> Unhealthy --> Deployment Failed
```

## Continuous Integration

The CI stage performs the following operations:

1. Checks out the GitHub repository.
2. Authenticates with Docker Hub using GitHub Actions Secrets.
3. Configures Docker Buildx.
4. Builds the application Docker image from the `application/` directory.
5. Tags the Docker image.
6. Pushes the image to Docker Hub.

Docker image repository:

```text
alokkumar01/production-cicd-pipeline
```

The pipeline uses both commit-specific and moving image tags.

```text
<commit-sha>
latest
```

Commit SHA tagging improves deployment traceability by associating a container image with a specific Git commit.

---

## Continuous Deployment

After the Docker image is successfully built and published, the deployment stage begins.

The GitHub Actions runner:

1. Connects to the EC2 instance through SSH.
2. Pulls the newest Docker image.
3. Stops and removes the existing application container.
4. Starts a new application container.
5. Runs the application with production environment settings.
6. Waits for the Docker health check.
7. Reads the container health status.
8. Fails the deployment job if the application does not become healthy.
9. Removes unused Docker images.

Application deployments can therefore be triggered through a normal Git workflow:

```bash
git add .
git commit -m "Update application"
git push
```

No manual EC2 deployment commands are required for normal application updates.

---

# Infrastructure Provisioning with Terraform

Terraform is used to provision the AWS infrastructure required by the project.

The Terraform configuration manages:

* AWS EC2 instance
* EC2 security group
* EC2 metadata configuration
* EC2 User Data bootstrap workflow

IMDSv2 is required for the EC2 instance.

The infrastructure configuration enforces:

```text
http_tokens = required
```

This prevents unauthenticated IMDSv1 metadata requests and requires token-based metadata access.

---

# Automated EC2 Bootstrapping

Terraform passes a combined User Data workflow to the EC2 instance.

The automation executes three configuration stages:

```text
ec2-bootstrap.sh
        |
        v
monitoring.sh
        |
        v
https-setup.sh
```

Each script is responsible for a separate infrastructure concern.

| Script             | Responsibility                        |
| ------------------ | ------------------------------------- |
| `ec2-bootstrap.sh` | Application runtime and reverse proxy |
| `monitoring.sh`    | Infrastructure monitoring stack       |
| `https-setup.sh`   | DNS and HTTPS automation              |

This separation keeps infrastructure automation modular and easier to maintain.

---

# EC2 Application Bootstrap

The `ec2-bootstrap.sh` script configures the EC2 application environment.

The script:

* Updates package repositories
* Installs Docker
* Installs Nginx
* Enables the Docker service
* Enables the Nginx service
* Pulls the application Docker image
* Starts the application container
* Configures Nginx as a reverse proxy

Application traffic flow:

```text
Client
   |
   v
Nginx
Ports 80 / 443
   |
   v
Node.js Docker Container
Port 3000
```

Nginx provides the external application entry point while the Node.js application remains behind the reverse proxy.

---

# DNS and HTTPS Automation

The `https-setup.sh` script automates production DNS and TLS configuration.

Domain:

```text
productioncicd.duckdns.org
```

The script performs the following workflow:

1. Installs Curl and DNS utilities.
2. Installs Certbot.
3. Installs the Certbot Nginx plugin.
4. Requests an IMDSv2 metadata token.
5. Retrieves the EC2 public IPv4 address.
6. Updates the DuckDNS DNS record.
7. Waits for DNS propagation.
8. Configures the Nginx server name.
9. Verifies application availability.
10. Requests a Let's Encrypt TLS certificate.
11. Configures HTTP-to-HTTPS redirection.
12. Adds Nginx security headers.
13. Enables the Certbot renewal timer.
14. Verifies the HTTPS application endpoint.

---

## HTTPS Traffic Flow

```text
Client
   |
   v
HTTPS :443
   |
   v
Nginx
TLS Termination
   |
   v
Node.js Application
Port 3000
```

HTTP traffic is redirected to HTTPS.

```text
HTTP :80
   |
   v
301 Redirect
   |
   v
HTTPS :443
```

---

## Nginx Security Headers

The Nginx configuration includes the following security headers:

```text
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
```

These headers provide basic browser-side security hardening.

---

# Monitoring and Observability

The infrastructure monitoring stack runs using Docker containers.

```text
AWS EC2 Host
     |
     v
Node Exporter
     |
     v
Prometheus
     |
     v
Grafana
```

Monitoring containers:

```text
node-exporter
prometheus
grafana
```

---

## Node Exporter

Node Exporter exposes Linux host metrics from the EC2 instance.

Collected metrics include:

* CPU utilization
* Memory usage
* Disk usage
* Filesystem metrics
* System load
* Network statistics

Prometheus uses Node Exporter as a metrics target.

---

## Prometheus

Prometheus collects and stores infrastructure metrics.

The configured scrape interval is:

```yaml
global:
  scrape_interval: 15s
```

Prometheus periodically scrapes the Node Exporter metrics endpoint and stores the collected time-series data.

Monitoring flow:

```text
Node Exporter
     |
     | Host Metrics
     v
Prometheus
```

---

## Grafana

Grafana is used as the visualization layer for infrastructure metrics.

Prometheus is configured as the Grafana data source.

```text
Node Exporter
     |
     v
Prometheus
     |
     v
Grafana Dashboard
```

Grafana dashboards can be used to visualize:

* CPU usage
* Memory utilization
* Disk utilization
* Network activity
* System load

---

# Application Health Checks

The Express application exposes a dedicated health endpoint:

```text
GET /health
```

Example response:

```json
{
  "status": "healthy",
  "environment": "production"
}
```

The Docker image includes a `HEALTHCHECK` instruction.

During deployment, GitHub Actions waits for the container health status.

```text
Container Started
       |
       v
Docker Health Check
       |
       +--> healthy
       |       |
       |       v
       |  Deployment Successful
       |
       +--> unhealthy
               |
               v
         Deployment Failed
```

This prevents the CI/CD workflow from reporting a successful deployment when the application container fails its health validation.

---

# Secrets Management

Sensitive values are not committed to the Git repository.

GitHub Actions Secrets are used for CI/CD credentials and deployment access.

```text
DOCKER_USERNAME
DOCKER_PASSWORD
EC2_HOST
EC2_USER
EC2_SSH_KEY
```

Terraform variables are used for infrastructure configuration values such as:

```text
duckdns_token
certbot_email
```

For local Terraform execution, sensitive Terraform variables can be supplied using environment variables.

PowerShell example:

```powershell
$env:TF_VAR_duckdns_token="YOUR_DUCKDNS_TOKEN"
$env:TF_VAR_certbot_email="YOUR_EMAIL"
```

Sensitive files and credentials should never be committed.

Examples include:

```text
*.tfvars
*.tfstate
*.tfstate.*
.env
*.pem
SSH private keys
DuckDNS tokens
```

The repository `.gitignore` should exclude these files where applicable.

---

# Local Development

Move to the application directory:

```bash
cd application
```

Install dependencies:

```bash
npm install
```

Start the development server:

```bash
npm run dev
```

Application endpoint:

```text
http://localhost:3000
```

Health endpoint:

```text
http://localhost:3000/health
```

---

# Docker Setup

Build the application Docker image:

```bash
docker build \
  -t alokkumar01/production-cicd-pipeline:local \
  ./application
```

Run the application container:

```bash
docker run -d \
  --name app-container \
  -p 3000:3000 \
  -e NODE_ENV=production \
  alokkumar01/production-cicd-pipeline:local
```

Verify the running container:

```bash
docker ps
```

View application logs:

```bash
docker logs app-container
```

Check the container health status:

```bash
docker inspect app-container --format='{{.State.Health.Status}}'
```

---

# Terraform Deployment

Move to the infrastructure directory:

```bash
cd infrastructure
```

Initialize Terraform:

```bash
terraform init
```

Validate the Terraform configuration:

```bash
terraform validate
```

Review infrastructure changes:

```bash
terraform plan
```

Provision the AWS infrastructure:

```bash
terraform apply
```

Destroy the infrastructure when it is no longer required:

```bash
terraform destroy
```

Destroying unused cloud infrastructure helps prevent unnecessary AWS charges.

---

# Deployment Verification

Verify the production application:

```bash
curl https://productioncicd.duckdns.org
```

Verify the health endpoint:

```bash
curl https://productioncicd.duckdns.org/health
```

---

# EC2 Troubleshooting

View the EC2 User Data execution logs:

```bash
sudo cat /var/log/cloud-init-output.log
```

Check running Docker containers:

```bash
docker ps
```

View application logs:

```bash
docker logs app-container
```

Check application health:

```bash
docker inspect app-container --format='{{.State.Health.Status}}'
```

Validate the Nginx configuration:

```bash
sudo nginx -t
```

Check the Nginx service:

```bash
sudo systemctl status nginx
```

Check HTTPS certificate renewal configuration:

```bash
sudo systemctl status certbot.timer
```

Test Certbot renewal:

```bash
sudo certbot renew --dry-run
```

---

# Security Considerations

The project includes several security-focused configurations:

* EC2 IMDSv2 enforcement
* Non-root application container
* HTTPS encryption
* HTTP-to-HTTPS redirection
* GitHub Actions Secrets for CI/CD credentials
* Terraform environment variables for sensitive inputs
* Nginx security headers
* Application container health validation

For a real production environment, additional hardening should be applied.

Recommended improvements:

* Restrict SSH port `22` to trusted administrator IP addresses.
* Replace public SSH access with AWS Systems Manager Session Manager.
* Restrict Prometheus port `9090`.
* Restrict Grafana access on port `3001`.
* Place Grafana behind authenticated HTTPS.
* Use a private network or VPN for monitoring services.
* Use IAM roles instead of long-lived AWS credentials where possible.
* Pin monitoring container image versions instead of using `latest`.
* Use remote Terraform state.
* Enable Terraform state locking.
* Implement centralized application logging.
* Add automated vulnerability scanning for Docker images.

---

# Project Outcomes

This project demonstrates practical experience with:

* Infrastructure as Code
* AWS infrastructure provisioning
* Linux server bootstrapping
* Docker containerization
* Container image delivery
* CI/CD pipeline design
* Automated cloud deployment
* GitHub Actions
* Docker Hub
* Reverse proxy configuration
* Nginx
* TLS and HTTPS automation
* DNS automation
* Deployment health validation
* Infrastructure monitoring
* Metrics collection
* Observability
* Prometheus
* Grafana
* Bash automation

---

# Future Improvements

Potential future enhancements include:

* AWS Systems Manager Session Manager for server access
* AWS Application Load Balancer
* Amazon Route 53 DNS management
* AWS Certificate Manager
* Remote Terraform state using Amazon S3
* Terraform state locking
* Docker image vulnerability scanning
* Centralized logging
* Alertmanager integration
* Grafana alerting
* Blue-green deployment
* Rolling deployment strategies
* Kubernetes-based deployment

---

# Author

**Alok Kumar**

B.Tech in Electronics and Telecommunication Engineering
International Institute of Information Technology Bhubaneswar

GitHub: `alokkumariiit`

LinkedIn: `alokkumariiit`
