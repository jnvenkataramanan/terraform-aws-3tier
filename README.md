# AWS Three-Tier Web Architecture — Terraform IaC

Fully automated deployment of a production-grade three-tier web architecture on AWS using Terraform modules. Every AWS resource is defined as Infrastructure as Code — zero manual Console steps required.

[![Terraform](https://img.shields.io/badge/Terraform->=1.5.0-7B42BC?logo=terraform)](https://developer.hashicorp.com/terraform)
[![AWS](https://img.shields.io/badge/AWS-us--east--1-FF9900?logo=amazonaws)](https://aws.amazon.com)

---

## Architecture

```
Internet
    │
    ▼
[Route 53]  www.yourdomain.com → ext-lb alias
    │
    ▼
[AWS WAF]  Rate limit: 100 req/min/IP → HTTP 429
    │
    ▼
[External ALB - ext-lb]        ← HTTPS:443 with ACM SSL cert
    │                            Public Subnets (us-east-1a, us-east-1b)
    ▼
[Web Tier ASG]                 ← Nginx + React SPA
    │                            Public Subnets | desired: 2 | max: 4
    ▼
[Internal ALB - int-lb]        ← HTTP:80
    │                            Private Subnets
    ▼
[App Tier ASG]                 ← Node.js API on port 4000
    │                            Private Subnets | desired: 2 | max: 4
    ▼
[RDS MySQL 8.0]                ← Isolated DB Subnets
                                 No public access
```

---

## Module Structure

```
terraform-aws-3tier/
├── main.tf                        # Root — orchestrates all 10 modules
├── variables.tf                   # All input variables
├── outputs.tf                     # Key outputs (IPs, DNS, ARNs)
├── terraform.tfvars.example       # Template — copy and fill values
├── .gitignore                     # Excludes tfstate and secrets
├── scripts/
│   ├── app_tier_setup.sh          # Installs Node.js, clones app, starts service
│   ├── db_init.sh                 # Creates RDS tables and seed data
│   └── web_tier_setup.sh          # Builds React, configures Nginx
└── modules/
    ├── vpc/                       # VPC, 6 Subnets, IGW, NAT GWs, Route Tables
    ├── security_groups/           # All 6 Security Groups (chained order)
    ├── rds/                       # DB Subnet Group + MySQL 8.0 RDS
    ├── ec2/                       # Bastion Host with SSH-ready retry loop
    ├── acm/                       # ACM SSL Certificate + DNS validation
    ├── route53_acm/               # Route53 Hosted Zone + A record
    ├── app_tier/                  # App EC2 + provisioners + AMI + ASG + TG
    ├── alb/                       # Internal ALB (int-lb) + listener
    ├── web_tier/                  # Web EC2 + provisioners + AMI + ASG + ext-lb
    └── waf/                       # Web ACL + rate rule + CloudWatch logs
```

---

## Execution Order

`terraform apply` creates **58 resources** in this exact order:

| Stage | Resources | Notes |
|-------|-----------|-------|
| 1 | Route53 Hosted Zone + ACM cert request | Runs immediately, cert validates in background |
| 2 | VPC + Security Groups + RDS | Parallel — all depend on VPC only |
| 3 | Bastion Host | SSH retry loop — waits until EC2 is ready |
| 4 | App Tier | `app_tier_setup.sh` → `db_init.sh` → AMI → ASG |
| 5 | Internal ALB | Wires int-lb listener → app-tier-tg |
| 6 | ACM cert ISSUED wait | Terraform blocks here until cert is validated |
| 7 | Web Tier | Web EC2 → Nginx → AMI → ASG → ext-lb + HTTPS listener |
| 8 | WAF | Attaches to ext-lb |
| 9 | Route53 A record | www → ext-lb alias (after ext-lb is ready) |

---

## Prerequisites

- [Terraform >= 1.5.0](https://developer.hashicorp.com/terraform/downloads)
- [AWS CLI v2](https://aws.amazon.com/cli/) configured (`aws configure`)
- A registered domain name (GoDaddy, Namecheap, etc.)
- An EC2 Key Pair named `awsproject` created in `us-east-1`
- The `.pem` file downloaded to your machine

---

## Deployment

### Step 1 — Configure variables

```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars        # or: notepad terraform.tfvars (Windows)
```

Fill in these **4 required values**:

```hcl
my_ip            = "x.x.x.x/32"          # curl checkip.amazonaws.com
domain_name      = "yourdomain.com"
db_password      = "YourStrongPass@123"
private_key_path = "/path/to/awsproject.pem"
```

### Step 2 — Initialize

```bash
terraform init
```

### Step 3 — Preview

```bash
terraform plan
# Should show: 58 to add, 0 to change, 0 to destroy
```

### Step 4 — Deploy

```bash
terraform apply
# Type: yes
# Wait ~20-25 minutes
```

### Step 5 — Update DNS nameservers (one-time manual step)

After apply completes, get the NS records:

```bash
terraform output name_servers
```

Go to your domain registrar (GoDaddy) → DNS → Nameservers → Enter Custom → paste all 4 NS values.

DNS propagation takes 5–30 minutes.

### Step 6 — Verify

```bash
# View all outputs
terraform output

# Test website
curl https://www.yourdomain.com

# Test WAF rate limiting (from Bastion)
ssh -i awsproject.pem ubuntu@$(terraform output -raw bastion_host_public_ip)
for i in {1..150}; do curl https://www.yourdomain.com; done
# After ~100 requests → "Too many requests. Please try again after 60 Seconds."
```

---

## Security Group Chain

```
My IP ──SSH──► [bh-sg]  Bastion Host
                  │SSH              │SSH
                  ▼                 ▼
           [web-tier-sg]     [app-tier-sg]
                  ▲                 ▲
              HTTP:80          TCP:4000
           [ext-lb-sg]       [int-lb-sg]
                  ▲                 ▲
             HTTPS:443         [web-tier-sg]
               Internet
                              [app-tier-sg]
                                   │ MySQL:3306
                                   ▼
                              [db-sg]  RDS
```

Each layer only allows traffic from the immediately preceding layer — **principle of least privilege**.

---

## Key Variables

| Variable | Description | Default |
|---|---|---|
| `aws_region` | AWS region | `us-east-1` |
| `project_name` | Resource name prefix | `project` |
| `my_ip` | Your IP for Bastion SSH | *(required)* |
| `domain_name` | Your registered domain | *(required)* |
| `db_password` | RDS master password | *(required)* |
| `private_key_path` | Path to .pem key file | *(required)* |
| `instance_type` | EC2 instance type | `t3.micro` |
| `db_instance_class` | RDS instance class | `db.t4g.micro` |

---

## Outputs

After `terraform apply`:

```
bastion_host_public_ip  = "x.x.x.x"
ext_lb_dns_name         = "ext-lb-xxxx.us-east-1.elb.amazonaws.com"
int_lb_dns_name         = "internal-int-lb-xxxx.us-east-1.elb.amazonaws.com"
rds_endpoint            = "database-1.xxxx.us-east-1.rds.amazonaws.com"
acm_certificate_arn     = "arn:aws:acm:us-east-1:xxxx:certificate/xxxx"
waf_web_acl_arn         = "arn:aws:wafv2:us-east-1:xxxx:regional/webacl/..."
name_servers            = ["ns-xxx.awsdns-xx.com", ...]
website_url             = "https://www.yourdomain.com"
```

---

## Cleanup

```bash
terraform destroy
# Type: yes
```

After destroy, manually delete:
1. EC2 → AMIs → Deregister `app-tier-ami` and `web-tier-ami`
2. EC2 → Snapshots → Delete associated snapshots

---

## Tech Stack

| Layer | Technology |
|---|---|
| Infrastructure as Code | Terraform >= 1.5.0 |
| Cloud Provider | AWS (us-east-1) |
| Web Server | Nginx (React SPA + reverse proxy) |
| Frontend | React.js (HashRouter) |
| Backend API | Node.js + Express (port 4000) |
| Database | Amazon RDS MySQL 8.0 |
| SSL | AWS ACM (DNS validated) |
| DNS | Route 53 |
| WAF | AWS WAFv2 (rate limiting) |
| Monitoring | CloudWatch |

---

## Author

**J. N. Venkataramanan**  
[LinkedIn](https://www.linkedin.com/in/jnvenkataramanan) · [GitHub](https://github.com/jnvenkataramanan)
