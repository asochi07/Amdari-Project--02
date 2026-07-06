###############################################################################
# Root configuration. Day 6 wires in the network module; identity, data,
# compute, and observability modules are scaffolded and will be added on
# subsequent days.
###############################################################################

module "network" {
  source = "./modules/network"

  name_prefix = var.name_prefix
  vpc_cidr    = var.vpc_cidr
  azs         = var.azs
}

module "data" {
  source = "./modules/data"

  name_prefix        = var.name_prefix
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  # App security groups don't exist until the compute module (Day 8),
  # so ingress-by-reference rules are created empty (closed) for now
  # and populated when compute lands.
  app_security_group_ids = []
}

module "identity" {
  source = "./modules/identity"

  name_prefix = var.name_prefix
  github_org  = "asochi07"
  github_repo = "Amdari-Project--02"

  # Scope each task role to only the secrets/keys it consumes
  payments_secret_arns  = [module.data.db_secret_arn]
  kyc_secret_arns       = [module.data.cache_auth_secret_arn]
  payments_kms_key_arns = [module.data.kms_key_arns.rds, module.data.kms_key_arns.secrets]
  kyc_kms_key_arns      = [module.data.kms_key_arns.s3, module.data.kms_key_arns.secrets]
  app_bucket_arn        = "arn:aws:s3:::${module.data.app_bucket}"
}

output "rds_endpoint"          { value = module.data.rds_endpoint }
output "app_bucket"            { value = module.data.app_bucket }
output "db_secret_arn"         { value = module.data.db_secret_arn }
output "payments_task_role_arn" { value = module.identity.payments_task_role_arn }
output "kyc_task_role_arn"      { value = module.identity.kyc_task_role_arn }
output "github_deploy_role_arn" { value = module.identity.github_deploy_role_arn }
# module "compute"       { source = "./modules/compute" }        # Day 8
# module "observability" { source = "./modules/observability" }  # Day 8+