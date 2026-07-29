# SentinelPay Terraform policy pack - security group rules
# Blocks security group rules that expose sensitive ports to 0.0.0.0/0.
package terraform.securitygroups

import rego.v1

resources(kind) := [r |
	some r in input.resource_changes
	r.type == kind
	r.change.actions[_] != "delete"
]

# Ports that must never be open to the world.
sensitive_ports := {22, 3389, 5432, 3306, 6379, 27017, 9200, 1433}

# --- Standalone rule resources ---
deny contains msg if {
	some rule in resources("aws_security_group_rule")
	after := rule.change.after
	after.type == "ingress"
	world_open(after.cidr_blocks)
	port_in_range(after.from_port, after.to_port)
	msg := sprintf("Security group rule '%s' exposes a sensitive port (%d-%d) to 0.0.0.0/0; restrict to a source security group by reference", [rule.address, after.from_port, after.to_port])
}

# --- Inline ingress blocks on aws_security_group ---
deny contains msg if {
	some sg in resources("aws_security_group")
	ingress := sg.change.after.ingress[_]
	world_open(ingress.cidr_blocks)
	port_in_range(ingress.from_port, ingress.to_port)
	msg := sprintf("Security group '%s' has an inline ingress exposing a sensitive port (%d-%d) to 0.0.0.0/0", [sg.address, ingress.from_port, ingress.to_port])
}

world_open(cidrs) if {
	some c in cidrs
	c == "0.0.0.0/0"
}

# True if any sensitive port falls within [from,to], or the range is "all ports".
port_in_range(from, to) if {
	some p in sensitive_ports
	from <= p
	to >= p
}

port_in_range(from, to) if {
	from == 0
	to == 0
}
