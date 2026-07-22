output "alb_dns_name" {
  description = "Public DNS name of the ALB"
  value       = aws_lb.this.dns_name
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "task_security_group_id" {
  description = "ECS task security group - feed this to the data module so RDS/ElastiCache admit it by reference"
  value       = aws_security_group.task.id
}

output "ecs_cluster_name" {
  value = aws_ecs_cluster.this.name
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.this.arn
}

output "payments_service_name" {
  value = aws_ecs_service.payments.name
}

output "kyc_service_name" {
  value = aws_ecs_service.kyc.name
}
