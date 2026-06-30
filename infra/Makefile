# SentinelPay infrastructure - developer experience targets (D-04).
# Plan/validate work offline; apply requires real AWS credentials.

.PHONY: init validate fmt plan apply destroy bootstrap

init:        ## Initialise providers and modules (no backend yet)
	terraform init -backend=false

validate:    ## Validate configuration (no credentials needed)
	terraform validate

fmt:         ## Format all Terraform files
	terraform fmt -recursive

plan:        ## Show the resource graph (offline-capable via provider skip flags)
	terraform plan

apply:       ## Provision infrastructure (requires AWS credentials)
	terraform apply

destroy:     ## Tear down all managed infrastructure
	terraform destroy

bootstrap:   ## One-off: create the S3+DynamoDB state backend (run in ./bootstrap)
	cd bootstrap && terraform init && terraform apply
