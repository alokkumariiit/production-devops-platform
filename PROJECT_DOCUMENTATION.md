# Production DevOps Platform — Technical Documentation

## 1. Purpose

The **Production DevOps Platform** is an end-to-end DevOps automation project designed to provision cloud infrastructure, package and deliver a containerized application, automate production deployments, configure HTTPS, and provide infrastructure monitoring.

The platform integrates:

* Infrastructure as Code
* Containerization
* Continuous Integration
* Continuous Deployment
* Cloud infrastructure automation
* Reverse proxy configuration
* DNS automation
* TLS/HTTPS automation
* Deployment health validation
* Infrastructure monitoring and observability

The application layer is implemented using Node.js and Express.js and is deployed as a Docker container on an AWS EC2 instance.

Terraform provisions the AWS infrastructure, while Bash-based EC2 User Data scripts automate server configuration.

GitHub Actions provides the CI/CD workflow responsible for building, publishing, and deploying application releases.

---

# 2. System Architecture

The platform follows an automated source-to-production delivery architecture.

```text
Developer
    |
    v
GitHub Repository
    |
    v
main Branch
    |
    v
GitHub Actions
    |
    +-----------------------------+
    |                             |
    v                             v
Docker Image Build         Image Tagging
                                  |
                                  +--> Commit SHA
                                  |
                                  +--> latest
    |                             |
    +-------------+---------------+
                  |
                  v
             Docker Hub
                  |
                  v
        SSH Deployment Stage
                  |
                  v
              AWS EC2
                  |
        +---------+---------+
        |         |         |
        v         v         v
      Nginx    Node.js    Monitoring
                Docker        |
               Container      +--> Node Exporter
                              +--> Prometheus
                              +--> Grafana
                  |
                  v
       DuckDNS + Let's Encrypt
                  |
                  v
          HTTPS Application
```

The architecture separates the system into the following logical layers:

| Layer                  | Responsibility                  |
| ---------------------- | ------------------------------- |
| Application            | Node.js and Express application |
| Container              | Docker application packaging    |
| Registry               | Docker Hub image storage        |
| CI/CD                  | GitHub Actions automation       |
| Infrastructure         | AWS EC2                         |
| Infrastructure as Code | Terraform                       |
| Reverse Proxy          | Nginx                           |
| DNS                    | DuckDNS                         |
| TLS                    | Let's Encrypt and Certbot       |
| Monitoring             | Node Exporter and Prometheus    |
| Visualization          | Grafana                         |

---

# 3. Application Layer

The application is implemented using **Node.js** and **Express.js**.

The application exposes two primary endpoints.

## Root Endpoint

```text
GET /
```

The root endpoint serves the application response.

## Health Endpoint

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

Runtime configuration is supplied using environment variables.

The primary runtime variable is:

```text
NODE_ENV
```

During production deployment, the application container is started with:

```text
NODE_ENV=production
```

The health endpoint provides a machine-readable application status and is used by the Docker health-check mechanism.

The CI/CD deployment process reads the resulting Docker container health state to determine whether a deployment is operational.

---

# 4. Containerization Layer

The Node.js application is packaged as a Docker image.

The Docker image provides a consistent application runtime across development, testing, and production environments.

Production Node.js dependencies are installed using:

```bash
npm ci --omit=dev
```

Using `npm ci` provides deterministic dependency installation based on `package-lock.json`.

The `--omit=dev` option prevents development-only dependencies from being installed in the production image.

## Non-Root Container Execution

The application process runs as a non-root container user.

Running the application as a non-root user reduces the privileges available to the application process inside the container.

## Docker Health Check

The application image includes a Docker `HEALTHCHECK`.

Docker periodically checks the application health endpoint.

Conceptual health flow:

```text
Docker Container
      |
      v
Application /health
      |
      +--> Successful Response
      |         |
      |         v
      |      healthy
      |
      +--> Failed Response
                |
                v
             unhealthy
```

The container health state is used by the deployment pipeline during release validation.

## Docker Image Registry

The application image is published to Docker Hub.

Image repository:

```text
alokkumar01/production-cicd-pipeline
```

The CI pipeline publishes image tags for:

```text
<commit-sha>
latest
```

The commit SHA tag provides traceability between a Docker image and the corresponding Git commit.

The `latest` tag identifies the newest image published by the pipeline.

---

# 5. Infrastructure as Code

Terraform manages the AWS infrastructure required by the platform.

The Terraform configuration provisions:

* AWS EC2 instance
* EC2 security group
* EC2 metadata configuration
* EC2 User Data bootstrap workflow

Infrastructure configuration is stored in the `infrastructure/` directory.

```text
infrastructure/
├── ec2-bootstrap.sh
├── https-setup.sh
├── main.tf
├── monitoring.sh
├── outputs.tf
├── provider.tf
└── variables.tf
```

---

## 5.1 EC2 Instance

The EC2 instance hosts:

* Nginx
* Docker
* Node.js application container
* Node Exporter
* Prometheus
* Grafana

The server is automatically configured during instance initialization using EC2 User Data.

---

## 5.2 EC2 Metadata Security

The EC2 instance requires **Instance Metadata Service Version 2 (IMDSv2)**.

Terraform configures metadata access using:

```text
http_tokens = required
```

IMDSv2 requires token-based requests when accessing the EC2 Instance Metadata Service.

The HTTPS automation script uses IMDSv2 to retrieve the EC2 public IPv4 address.

The conceptual metadata request flow is:

```text
EC2 Script
    |
    v
Request IMDSv2 Token
    |
    v
Receive Metadata Token
    |
    v
Request Public IPv4 Metadata
    |
    v
EC2 Public IP
```

---

## 5.3 User Data Replacement Behavior

Terraform is configured with:

```text
user_data_replace_on_change
```

When the effective EC2 User Data changes, Terraform can replace the EC2 instance so that the updated bootstrap configuration executes on a newly launched instance.

This is important because EC2 User Data normally executes during the initial instance boot process.

The replacement behavior ensures infrastructure bootstrap changes are applied consistently to a newly created server.

Before applying User Data changes, the Terraform execution plan should be reviewed because instance replacement can recreate the EC2 server.

---

# 6. EC2 Bootstrap Architecture

Terraform composes the EC2 initialization workflow from three Bash scripts.

```text
ec2-bootstrap.sh
        |
        v
monitoring.sh
        |
        v
https-setup.sh
```

The scripts are separated by infrastructure responsibility.

| Script             | Responsibility                        |
| ------------------ | ------------------------------------- |
| `ec2-bootstrap.sh` | Application runtime and reverse proxy |
| `monitoring.sh`    | Infrastructure monitoring             |
| `https-setup.sh`   | DNS and HTTPS automation              |

This modular structure separates application hosting, observability, and TLS configuration.

The scripts are executed as part of the EC2 User Data bootstrap process.

---

# 7. Application Bootstrap

The `ec2-bootstrap.sh` script prepares the EC2 instance to host the application.

The script performs the following operations:

1. Updates package repositories.
2. Installs Docker.
3. Installs Nginx.
4. Enables the Docker service.
5. Enables the Nginx service.
6. Pulls the application Docker image.
7. Starts the application container.
8. Configures Nginx as a reverse proxy.

The application container listens on:

```text
3000
```

The application traffic flow is:

```text
Client
   |
   v
Nginx
Ports 80 / 443
   |
   v
localhost:3000
   |
   v
Node.js Docker Container
```

Nginx acts as the external application entry point.

The Node.js application is hosted behind the reverse proxy.

The application port is not intended to be directly exposed through the AWS security group.

---

# 8. CI/CD Architecture

GitHub Actions implements the Continuous Integration and Continuous Deployment workflow.

The workflow is triggered by pushes to:

```text
main
```

The complete deployment flow is:

```text
Developer Push
      |
      v
GitHub main Branch
      |
      v
GitHub Actions
      |
      v
Build Docker Image
      |
      v
Tag Docker Image
      |
      +--> Commit SHA
      |
      +--> latest
      |
      v
Push Image to Docker Hub
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
Wait for Health Initialization
      |
      v
Read Docker Health Status
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

---

## 8.1 Continuous Integration

The Continuous Integration stage performs the following operations:

1. Checks out the repository.
2. Authenticates with Docker Hub.
3. Configures Docker Buildx.
4. Builds the application Docker image.
5. Creates Docker image tags.
6. Pushes the Docker image to Docker Hub.

Docker Hub authentication values are stored using GitHub Actions Secrets.

The pipeline does not store Docker Hub credentials directly in the workflow file.

---

## 8.2 Continuous Deployment

The Continuous Deployment stage begins after the Docker image is successfully published.

The deployment job connects to the EC2 instance using SSH.

The SSH private key is stored as a GitHub Actions Secret.

The deployment process:

1. Connects to EC2.
2. Pulls the newest Docker image.
3. Stops the existing application container.
4. Removes the existing application container.
5. Starts a new application container.
6. Configures the production environment.
7. Waits for Docker health-check initialization.
8. Reads the Docker container health state.
9. Fails the deployment if the container is not healthy.
10. Removes unused Docker images.

A standard Git workflow can therefore trigger an application deployment.

```bash
git add .
git commit -m "Update application"
git push
```

No manual EC2 application deployment is required during the normal CI/CD workflow.

---

# 9. Deployment Health Validation

Application health validation is part of the deployment workflow.

After the new container starts, the pipeline waits for the Docker health check to initialize.

The deployment job then reads:

```text
.State.Health.Status
```

The expected healthy state is:

```text
healthy
```

Deployment validation flow:

```text
New Container
      |
      v
Container Started
      |
      v
Docker Health Check
      |
      v
Read Health Status
      |
      +--> healthy
      |       |
      |       v
      |  Continue Deployment
      |
      +--> not healthy
              |
              v
        Exit with Failure
```

An unhealthy container causes the GitHub Actions deployment job to fail.

This prevents a container start event alone from being treated as proof of a successful application deployment.

The current implementation performs **deployment failure detection**.

It does not implement automatic rollback to a previous container image.

---

# 10. Nginx Reverse Proxy

Nginx acts as the public reverse proxy for the application.

Public traffic is received on:

```text
80
443
```

Application requests are proxied to:

```text
localhost:3000
```

Traffic flow:

```text
Internet
   |
   v
Nginx
   |
   v
localhost:3000
   |
   v
Node.js Container
```

The reverse proxy forwards request metadata required by the upstream application.

Forwarded information includes:

* Original host
* Client IP information
* Proxy forwarding chain
* Original request protocol

Typical proxy headers include:

```text
Host
X-Real-IP
X-Forwarded-For
X-Forwarded-Proto
```

Nginx also provides TLS termination for HTTPS traffic.

---

# 11. DNS Automation

The production domain is:

```text
productioncicd.duckdns.org
```

DuckDNS maps the domain to the EC2 public IPv4 address.

Because an EC2 public IP can change when infrastructure is recreated, the HTTPS automation script dynamically discovers the active EC2 public IP.

The DNS automation flow is:

```text
EC2 Instance
     |
     v
IMDSv2
     |
     v
Retrieve Public IPv4
     |
     v
DuckDNS API Update
     |
     v
productioncicd.duckdns.org
```

The HTTPS setup script waits for DNS resolution before requesting the TLS certificate.

This reduces the risk of requesting a certificate before the domain resolves to the EC2 instance.

---

# 12. HTTPS and TLS Automation

The `https-setup.sh` script automates the production HTTPS configuration.

The script performs the following operations:

1. Installs Curl.
2. Installs DNS utilities.
3. Installs Certbot.
4. Installs the Certbot Nginx plugin.
5. Requests an IMDSv2 token.
6. Retrieves the EC2 public IPv4 address.
7. Updates the DuckDNS DNS record.
8. Waits for DNS propagation.
9. Configures the Nginx server name.
10. Validates the Nginx configuration.
11. Verifies application availability.
12. Requests a Let's Encrypt certificate.
13. Configures HTTPS.
14. Configures HTTP-to-HTTPS redirection.
15. Adds Nginx security headers.
16. Enables the Certbot renewal timer.
17. Verifies the HTTPS application endpoint.

---

## 12.1 TLS Termination

Nginx terminates the HTTPS connection.

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
HTTP Proxy Request
   |
   v
Node.js Application
Port 3000
```

The application container does not directly manage TLS certificates.

TLS management is handled by Nginx and Certbot.

---

## 12.2 HTTP-to-HTTPS Redirection

HTTP requests are redirected to HTTPS.

```text
HTTP :80
   |
   v
Redirect
   |
   v
HTTPS :443
```

This ensures production application traffic uses the encrypted HTTPS endpoint.

---

## 12.3 Certificate Renewal

Certbot manages the Let's Encrypt certificate.

The Certbot systemd timer is enabled for automated renewal checks.

Certificate renewal configuration can be verified using:

```bash
sudo systemctl status certbot.timer
```

A renewal dry run can be performed using:

```bash
sudo certbot renew --dry-run
```

---

# 13. Nginx Security Headers

The Nginx configuration includes browser security headers.

Configured headers include:

```text
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Referrer-Policy: strict-origin-when-cross-origin
```

## X-Content-Type-Options

```text
nosniff
```

Instructs supported browsers not to MIME-sniff a response away from the declared content type.

## X-Frame-Options

```text
SAMEORIGIN
```

Restricts framing of the application to pages from the same origin.

## Referrer-Policy

```text
strict-origin-when-cross-origin
```

Controls the amount of referrer information sent with requests.

These headers provide basic browser-side security hardening.

---

# 14. Monitoring Architecture

The monitoring stack runs as Docker containers on the EC2 instance.

The monitoring architecture is:

```text
AWS EC2 Host
     |
     v
Node Exporter
     |
     | Host Metrics
     v
Prometheus
     |
     | Time-Series Metrics
     v
Grafana
```

The monitoring stack contains:

```text
node-exporter
prometheus
grafana
```

Docker Compose is used to manage the monitoring services.

The monitoring configuration is located under:

```text
/home/ubuntu/monitoring
```

---

# 15. Node Exporter

Node Exporter exposes Linux host metrics.

The metrics represent the EC2 host operating system and infrastructure behavior.

Metrics include:

* CPU utilization
* Memory statistics
* Disk statistics
* Filesystem metrics
* System load
* Network statistics

Node Exporter provides the metrics endpoint consumed by Prometheus.

Monitoring flow:

```text
Linux Host
    |
    v
Node Exporter
    |
    v
Metrics Endpoint
```

---

# 16. Prometheus

Prometheus collects and stores infrastructure metrics.

Prometheus is configured to scrape Node Exporter.

The global scrape interval is:

```yaml
global:
  scrape_interval: 15s
```

Prometheus therefore requests metrics from the configured target every 15 seconds.

Metrics flow:

```text
Node Exporter
      |
      | Metrics
      v
Prometheus
      |
      v
Time-Series Storage
```

Prometheus acts as the metrics collection and storage layer for the monitoring architecture.

---

# 17. Grafana

Grafana provides the visualization layer.

Prometheus is configured as the Grafana data source.

Visualization flow:

```text
Node Exporter
      |
      v
Prometheus
      |
      v
Grafana
      |
      v
Infrastructure Dashboard
```

Grafana dashboards can visualize infrastructure metrics including:

* CPU utilization
* Memory utilization
* Disk usage
* Filesystem behavior
* Network activity
* System load

The monitoring stack provides infrastructure-level visibility into the EC2 host.

The current monitoring architecture focuses on **host metrics** rather than application-specific business metrics.

---

# 18. Secrets Management

Sensitive credentials are not intended to be committed to the Git repository.

The project uses GitHub Actions Secrets and Terraform input variables for sensitive configuration.

---

## 18.1 GitHub Actions Secrets

The CI/CD workflow uses GitHub Actions Secrets for:

```text
DOCKER_USERNAME
DOCKER_PASSWORD
EC2_HOST
EC2_USER
EC2_SSH_KEY
```

These values provide:

* Docker Hub authentication
* EC2 connection information
* SSH deployment authentication

Credentials should not be hardcoded in the GitHub Actions workflow.

---

## 18.2 Terraform Sensitive Inputs

Terraform variables are used for:

```text
duckdns_token
certbot_email
```

For local Terraform execution, values can be supplied using environment variables.

PowerShell example:

```powershell
$env:TF_VAR_duckdns_token="YOUR_DUCKDNS_TOKEN"
$env:TF_VAR_certbot_email="YOUR_EMAIL"
```

The actual DuckDNS token must not be committed to Git.

---

## 18.3 Git Ignore Requirements

Recommended `.gitignore` coverage includes:

```text
.env
*.pem
*.key
terraform.tfstate
terraform.tfstate.*
*.tfvars
.terraform/
```

Terraform state can contain infrastructure details and potentially sensitive values.

Terraform variable files can contain secrets when used for local configuration.

Private keys must never be committed.

The Terraform dependency lock file should normally remain committed:

```text
.terraform.lock.hcl
```

Do not add `.terraform.lock.hcl` to `.gitignore`.

Committing the lock file helps maintain consistent Terraform provider selections.

---

# 19. Operational Verification

The following commands can be used to verify the deployed platform.

## 19.1 Application Verification

Verify the production application:

```bash
curl https://productioncicd.duckdns.org
```

Verify the health endpoint:

```bash
curl https://productioncicd.duckdns.org/health
```

---

## 19.2 Docker Verification

List running containers:

```bash
docker ps
```

Check the application health state:

```bash
docker inspect app-container --format='{{.State.Health.Status}}'
```

View application logs:

```bash
docker logs app-container
```

---

## 19.3 Nginx Verification

Validate the Nginx configuration:

```bash
sudo nginx -t
```

Check the Nginx service:

```bash
sudo systemctl status nginx
```

---

## 19.4 EC2 Bootstrap Verification

View EC2 User Data and cloud-init output:

```bash
sudo cat /var/log/cloud-init-output.log
```

This log is the primary source for troubleshooting EC2 bootstrap failures.

---

## 19.5 Monitoring Verification

Move to the monitoring directory:

```bash
cd /home/ubuntu/monitoring
```

Check the monitoring services:

```bash
docker compose ps
```

View Prometheus logs:

```bash
docker logs prometheus
```

View Grafana logs:

```bash
docker logs grafana
```

View Node Exporter logs:

```bash
docker logs node-exporter
```

---

## 19.6 HTTPS Verification

Check the Certbot renewal timer:

```bash
sudo systemctl status certbot.timer
```

Test certificate renewal:

```bash
sudo certbot renew --dry-run
```

Verify HTTPS:

```bash
curl -I https://productioncicd.duckdns.org
```

---

# 20. Troubleshooting Workflow

When the production application is unavailable, troubleshooting should follow the infrastructure request path.

```text
DNS
 |
 v
HTTPS / Certificate
 |
 v
Nginx
 |
 v
Docker Container
 |
 v
Application Health
```

Recommended troubleshooting sequence:

1. Verify domain resolution.
2. Verify the HTTPS endpoint.
3. Validate the Nginx configuration.
4. Check the Nginx service.
5. Check running Docker containers.
6. Check application container health.
7. Review application logs.
8. Review cloud-init output for bootstrap failures.

Useful commands:

```bash
nslookup productioncicd.duckdns.org

curl -I https://productioncicd.duckdns.org

sudo nginx -t

sudo systemctl status nginx

docker ps

docker inspect app-container --format='{{.State.Health.Status}}'

docker logs app-container

sudo cat /var/log/cloud-init-output.log
```

For monitoring failures:

```bash
cd /home/ubuntu/monitoring

docker compose ps

docker logs prometheus

docker logs grafana

docker logs node-exporter
```

---

# 21. Current Project Scope

## Implemented

The current platform implements:

* Node.js and Express application
* Docker containerization
* Non-root application container
* Docker health checks
* Docker Hub container registry
* Commit SHA image tagging
* Latest image tagging
* Terraform AWS provisioning
* EC2 security group configuration
* IMDSv2 enforcement
* Automated EC2 bootstrapping
* Docker installation automation
* Nginx installation automation
* Nginx reverse proxy
* GitHub Actions CI/CD
* SSH-based automated deployment
* Deployment health validation
* Failed deployment detection
* Docker image cleanup
* Node Exporter
* Prometheus
* Grafana
* Docker Compose monitoring stack
* DuckDNS automation
* Dynamic EC2 public IP discovery
* Let's Encrypt HTTPS
* Certbot automation
* Certificate renewal configuration
* HTTP-to-HTTPS redirection
* Nginx security headers

---

## Out of Scope

The following technologies and architectures are not implemented in the current project:

* Kubernetes
* Amazon Elastic Kubernetes Service
* Blue-green deployment
* Rolling deployment
* Automatic deployment rollback
* Multi-instance high availability
* Auto Scaling Group
* Application Load Balancer
* Managed database
* Amazon Route 53
* AWS Certificate Manager
* Terraform remote backend
* Terraform state locking
* Centralized log aggregation
* Application performance monitoring
* Alertmanager

These items are intentionally outside the current project scope and should not be represented as implemented features.

---

# 22. Production Hardening Recommendations

The project demonstrates a production-oriented DevOps architecture, but additional hardening would be required for a real production workload.

## 22.1 SSH Access

Public SSH access should not remain open to:

```text
0.0.0.0/0
```

Recommended approaches:

* Restrict port `22` to a trusted administrator IP address.
* Use AWS Systems Manager Session Manager.
* Remove public SSH access when Session Manager is configured.

---

## 22.2 Monitoring Access

Prometheus and Grafana should not be publicly exposed without access controls.

Relevant ports:

```text
9090 - Prometheus
3001 - Grafana
```

Recommended approaches:

* Restrict access to trusted IP addresses.
* Place monitoring services behind authenticated HTTPS.
* Use private networking.
* Use a VPN.
* Use an authenticated reverse proxy.

---

## 22.3 Container Image Versioning

Monitoring container images should use explicit versions instead of:

```text
latest
```

Pinned versions improve deployment reproducibility and reduce unexpected changes caused by upstream image updates.

---

## 22.4 Terraform State

The current project uses local Terraform state.

For team-based or production infrastructure management, Terraform state should use a remote backend.

A production-oriented state architecture could use:

```text
Terraform
    |
    v
Remote State Backend
```

Remote state should be combined with an appropriate state-locking mechanism supported by the selected backend and Terraform configuration.

This reduces the risk of concurrent infrastructure modifications and improves team collaboration.

---

## 22.5 AWS Access

Long-lived AWS credentials should be avoided where possible.

Recommended approaches include:

* IAM roles
* Short-lived credentials
* OpenID Connect for CI/CD workflows

---

## 22.6 Deployment Strategy

The current deployment process replaces the running application container.

A more advanced production deployment architecture could implement:

* Automatic rollback
* Blue-green deployment
* Rolling deployment
* Canary deployment

These strategies can reduce deployment risk and application downtime.

---

## 22.7 Logging and Alerting

The current project provides infrastructure metrics but does not implement centralized logging or automated monitoring alerts.

Future improvements could include:

* Centralized application logs
* Centralized Nginx logs
* Grafana alerting
* Prometheus Alertmanager
* Cloud-based log storage
* Application-specific metrics

---

# 23. Technical Outcomes

The Production DevOps Platform demonstrates practical implementation of:

* Infrastructure as Code
* Terraform infrastructure provisioning
* AWS EC2 management
* EC2 User Data automation
* Linux server configuration
* Bash automation
* Docker containerization
* Non-root container execution
* Container health checks
* Docker image registries
* CI/CD pipeline development
* GitHub Actions
* Automated production deployment
* SSH-based deployment automation
* Deployment health validation
* Reverse proxy configuration
* Nginx
* DNS automation
* IMDSv2 metadata access
* TLS certificate automation
* HTTPS configuration
* Prometheus metrics collection
* Node Exporter host monitoring
* Grafana visualization
* Infrastructure observability
* Secrets handling

---

# 24. Conclusion

The Production DevOps Platform demonstrates an automated source-to-production delivery workflow for a containerized Node.js application.

Terraform provisions the AWS infrastructure and initializes the EC2 bootstrap process. Bash automation configures the application runtime, reverse proxy, monitoring services, DNS, and HTTPS.

GitHub Actions builds and publishes Docker images and automatically deploys application updates to EC2. Docker health checks are integrated into the deployment workflow to detect unhealthy releases.

Nginx provides reverse proxy and TLS termination, while DuckDNS and Let's Encrypt provide domain and certificate automation.

Node Exporter, Prometheus, and Grafana provide host-level infrastructure monitoring and visualization.

The resulting platform demonstrates a practical integration of cloud infrastructure, Infrastructure as Code, containerization, CI/CD automation, HTTPS, and observability within a single DevOps project.
