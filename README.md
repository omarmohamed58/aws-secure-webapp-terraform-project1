## Secure Webapp Terraform Project

This project automates the deployment of a secure, scalable web application on AWS using Terraform. It includes VPC setup, subnets, NAT & Internet gateways, security groups, EC2 instances, ALBs, and target groups, along with automated backend deployment using a Flask application.

## Project Structure
    project-root/
    ├── modrls/
    │   ├── alb_target/         
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   └── variable.tf
    │   ├── ec2/                 
    │   │   ├── scripts/
    │   │   │   └── deploy_backend.sh
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   └── variable.tf
    │   └── vpc/                
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── variable.tf
    ├── webapp/                  
    ├── .gitignore
    ├── README.md
    └── main.tf                 

## Features

### VPC Setup
- Creates a custom VPC with public and private subnets.
- Enables DNS support and hostnames.
- Provides tagged resources for easier management.

### Networking
- Internet Gateway and NAT Gateway configured for secure connectivity.
- Public and private route tables for traffic routing.
- Supports multiple availability zones for high availability.

### Security Groups
- Public ALB security group allows HTTP/HTTPS traffic from the internet.
- Proxy EC2 instances secure communication between ALB and backend.
- Internal ALB and backend security groups restrict traffic internally.

### Load Balancers
- Public ALB distributes traffic to proxy instances.
- Internal ALB forwards requests to backend EC2 instances.
- Health checks ensure application availability.

### EC2 Instances
- Proxy and backend servers deployed across public/private subnets.
- Automated Flask backend deployment via `deploy_backend.sh`.
- Environment metadata injected into backend for monitoring.

### Target Groups
- Each EC2 instance automatically attached to the relevant ALB target group.
- Supports HTTP/HTTPS protocols and custom health check paths.

### Automation
- Fully automated deployment of backend app using systemd services.
- Secure retrieval of instance metadata via IMDSv2.
- Virtual environment setup with Python dependencies installed from `requirements.txt`.

