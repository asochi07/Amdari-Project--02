# SentinelPay Terraform policy pack - encryption + logging rules
# Blocks unencrypted data stores and VPCs without flow logs.
package terraform.encryption

import rego.v1

resources(kind) := [r |
	some r in input.resource_changes
	r.type == kind
	r.change.actions[_] != "delete"
]

# --- RDS must be encrypted with a customer-managed key ---
deny contains msg if {
	some db in resources("aws_db_instance")
	after := db.change.after
	after.storage_encrypted != true
	msg := sprintf("RDS instance '%s' is not encrypted at rest (storage_encrypted must be true)", [db.address])
}

deny contains msg if {
	some db in resources("aws_db_instance")
	after := db.change.after
	after.storage_encrypted == true
	not after.kms_key_id
	not kms_known_after_apply(db)
	msg := sprintf("RDS instance '%s' is encrypted but uses the default AWS key; a customer-managed kms_key_id is required", [db.address])
}

# kms_key_id may be a computed reference (known after apply). In that case the
# plan records it under after_unknown, and it is NOT a violation.
kms_known_after_apply(db) if {
	db.change.after_unknown.kms_key_id == true
}

# --- ElastiCache must encrypt at rest and in transit ---
deny contains msg if {
	some rg in resources("aws_elasticache_replication_group")
	not is_true(rg.change.after.at_rest_encryption_enabled)
	msg := sprintf("ElastiCache '%s' does not enable at-rest encryption", [rg.address])
}

deny contains msg if {
	some rg in resources("aws_elasticache_replication_group")
	not is_true(rg.change.after.transit_encryption_enabled)
	msg := sprintf("ElastiCache '%s' does not enable in-transit encryption", [rg.address])
}

# --- EBS volumes must be encrypted ---
deny contains msg if {
	some v in resources("aws_ebs_volume")
	v.change.after.encrypted != true
	msg := sprintf("EBS volume '%s' is not encrypted", [v.address])
}

# --- VPCs must have flow logs (closes V-CLD-08) ---
# If a VPC is planned, at least one flow log must also be planned.
deny contains msg if {
	count(resources("aws_vpc")) > 0
	count(resources("aws_flow_log")) == 0
	msg := "A VPC is present but no aws_flow_log resource was found; VPC flow logs are required"
}

# Terraform plan JSON is inconsistent about booleans for some provider
# attributes (e.g. at_rest_encryption_enabled serializes as the string "true"
# while transit_encryption_enabled serializes as boolean true). Accept both.
is_true(v) if v == true

is_true(v) if v == "true"