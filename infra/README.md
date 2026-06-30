# SentinelPay Infrastructure (Terraform)

Module-structured Terraform provisioning the hardened AWS baseline for the
SentinelPay platform. Region: af-south-1.

## Structure

| Path | Purpose |
|------|---------|
| bootstrap/ | One-off: creates the S3 state bucket + DynamoDB lock table |
| modules/network/ | VPC, public/private subnets (2 AZs), NAT, IGW, flow logs |
| modules/identity/ | IAM roles, OIDC federation (later) |
| modules/data/ | RDS, ElastiCache, S3 + KMS (later) |
| modules/compute/ | ECS Fargate, ALB, WAF (later) |
| modules/observability/ | GuardDuty, CloudTrail, Config (later) |

## Network design (Day 6)

- VPC 10.0.0.0/16 across af-south-1a and af-south-1b.
- Private subnets host app compute and RDS; they have no route to the internet
  gateway, so they are not internet-addressable (egress via NAT only).
- Public subnets host only the NAT gateways (and later the ALB).
- VPC Flow Logs capture ALL traffic to CloudWatch (closes V-CLD-08).

## Usage

- make init      initialise
- make validate  validate (no credentials needed)
- make plan      show resource graph (offline-capable)
- make apply     provision (requires AWS credentials)

## State backend

The S3 + DynamoDB backend is created once via make bootstrap, then the
backend.tf block in the root is uncommented and terraform init migrates
state to S3. Until an AWS account is available, the project validates and
plans against local state.
