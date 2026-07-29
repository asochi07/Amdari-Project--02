# SentinelPay OPA/Rego Policy Pack (D-05)

Policy-as-code guardrails that block insecure Terraform **before** apply. Run
via [Conftest](https://www.conftest.dev/) against `terraform show -json` output.
Enforced as a fail-closed gate in the CI pipeline (Week 3) and runnable locally.

## Policies

| File | Package | Blocks |
|------|---------|--------|
| `terraform/s3.rego` | `terraform.s3` | Public bucket ACLs; missing public-access block; missing/ non-KMS default encryption |
| `terraform/security_groups.rego` | `terraform.securitygroups` | Ingress from `0.0.0.0/0` to sensitive ports (22, 3389, 5432, 3306, 6379, ...) |
| `terraform/iam.rego` | `terraform.iam` | IAM policies granting `Action:*` on `Resource:*` |
| `terraform/encryption.rego` | `terraform.encryption` | Unencrypted RDS/EBS; RDS without customer-managed KMS; ElastiCache without at-rest/in-transit encryption; VPC without flow logs |

## Usage

```bash
# Generate plan JSON
terraform plan -out=tfplan.bin
terraform show -json tfplan.bin > plan.json

# Evaluate against the policy pack
conftest test plan.json --policy policy --all-namespaces
```

Exit code is non-zero on any failure, so the CI job fails closed.

## Design notes

- Rules ignore resources being destroyed (`actions` contains only `delete`).
- The RDS KMS rule accounts for `kms_key_id` values that are *known after
  apply* (computed references), read from the plan's `after_unknown` block, to
  avoid false positives on compliant-but-not-yet-resolved plans.
- Policies mirror the V-CLD cloud anti-patterns the engagement requires the
  infrastructure to avoid, turning manual good practice into an enforced gate.

## Tests

Fixtures in `../test/bad` (violates every rule) and `../test/good` (fully
compliant) prove the pack fires on violations and passes clean infrastructure:

```
bad  -> 7 failures
good -> 0 failures
```
