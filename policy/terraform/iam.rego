# SentinelPay Terraform policy pack - IAM rules
# Blocks IAM policy documents that grant wildcard actions on wildcard resources.
package terraform.iam

import rego.v1

resources(kind) := [r |
	some r in input.resource_changes
	r.type == kind
	r.change.actions[_] != "delete"
]

# Inline/managed policies carry a JSON policy string in `policy`.
# Flag Allow statements combining Action "*" (or service:*) with Resource "*".
deny contains msg if {
	some p in policy_resources
	doc := json.unmarshal(p.change.after.policy)
	stmt := statements(doc)[_]
	stmt.Effect == "Allow"
	has_wildcard_action(stmt)
	has_wildcard_resource(stmt)
	msg := sprintf("IAM policy '%s' grants wildcard action on wildcard resource (Action:* / Resource:*); scope actions and resources explicitly", [p.address])
}

policy_resources := array.concat(
	resources("aws_iam_policy"),
	array.concat(resources("aws_iam_role_policy"), resources("aws_iam_user_policy")),
)

# Normalise Statement to a list whether it is one object or many.
statements(doc) := doc.Statement if is_array(doc.Statement)

statements(doc) := [doc.Statement] if is_object(doc.Statement)

has_wildcard_action(stmt) if {
	actions := to_list(stmt.Action)
	some a in actions
	a == "*"
}

has_wildcard_resource(stmt) if {
	res := to_list(stmt.Resource)
	some r in res
	r == "*"
}

to_list(x) := x if is_array(x)

to_list(x) := [x] if is_string(x)
