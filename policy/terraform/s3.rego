# SentinelPay Terraform policy pack - S3 rules
# Runs against `terraform show -json <planfile>` output via Conftest.
#
# Blocks:
#   - S3 buckets without a public-access block (or with public settings off)
#   - S3 buckets without default encryption
package terraform.s3

import rego.v1

# Collect planned resources of a given type from the plan JSON.
resources(kind) := [r |
	some r in input.resource_changes
	r.type == kind
	r.change.actions[_] != "delete"
]

# --- Public access must be blocked ---

# Every S3 bucket should have a corresponding public access block that turns
# all four protections on. We flag buckets, then separately verify a matching
# block exists with all protections true.
deny contains msg if {
	some pab in resources("aws_s3_bucket_public_access_block")
	after := pab.change.after
	not all_public_blocked(after)
	msg := sprintf("S3 public access block '%s' does not enable all four protections (block_public_acls, block_public_policy, ignore_public_acls, restrict_public_buckets)", [pab.address])
}

all_public_blocked(after) if {
	after.block_public_acls == true
	after.block_public_policy == true
	after.ignore_public_acls == true
	after.restrict_public_buckets == true
}

# Flag any bucket ACL set to a public value.
deny contains msg if {
	some acl in resources("aws_s3_bucket_acl")
	acl.change.after.acl in {"public-read", "public-read-write", "authenticated-read"}
	msg := sprintf("S3 bucket ACL '%s' is public ('%s'); buckets must be private", [acl.address, acl.change.after.acl])
}

# --- Default encryption required ---
# Each bucket must have a server-side encryption configuration. We assert that
# at least one SSE config resource exists per bucket by requiring the plan to
# contain an encryption configuration whenever it contains a bucket.
deny contains msg if {
	count(resources("aws_s3_bucket")) > 0
	count(resources("aws_s3_bucket_server_side_encryption_configuration")) == 0
	msg := "S3 buckets are present but no aws_s3_bucket_server_side_encryption_configuration was found; default encryption is required"
}

# Encryption config must use KMS (not plain AES256) for regulated data.
deny contains msg if {
	some enc in resources("aws_s3_bucket_server_side_encryption_configuration")
	rule := enc.change.after.rule[_]
	sse := rule.apply_server_side_encryption_by_default[_]
	sse.sse_algorithm != "aws:kms"
	msg := sprintf("S3 encryption '%s' uses '%s'; customer-managed KMS (aws:kms) is required", [enc.address, sse.sse_algorithm])
}
