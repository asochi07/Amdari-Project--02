###############################################################################
# IAM Identity Center (SSO) - DESIGN NOTE (not provisioned here).
#
# Constraint 83 requires all HUMAN access via IAM Identity Center with mandatory
# MFA and a 4-hour session cap. Identity Center is an organisation-level service
# that requires console enablement and an identity source, and cannot be cleanly
# created/destroyed per session, so it is documented here rather than applied:
#
#   1. Enable IAM Identity Center in the management account (console).
#   2. Set the identity source (Identity Center directory or external IdP).
#   3. Create permission sets with session_duration = PT4H (4-hour cap).
#   4. Enforce MFA: Settings > Authentication > require MFA every sign-in.
#   5. Assign permission sets to groups, not individual users.
#
# Where Identity Center IS Terraformable (permission sets, assignments) it can
# be added with aws_ssoadmin_permission_set (session_duration = "PT4H") and
# aws_ssoadmin_account_assignment once the instance exists. Left as a documented
# console procedure for this engagement.
###############################################################################

output "payments_task_role_arn" {
  value = aws_iam_role.payments_task.arn
}

output "kyc_task_role_arn" {
  value = aws_iam_role.kyc_task.arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}

output "github_deploy_role_arn" {
  value = aws_iam_role.github_deploy.arn
}
