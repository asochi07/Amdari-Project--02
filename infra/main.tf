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

# module "identity"      { source = "./modules/identity" }       # Day 7+
# module "data"          { source = "./modules/data" }           # Day 8+
# module "compute"       { source = "./modules/compute" }        # Day 9+
# module "observability" { source = "./modules/observability" }  # Day 10+
