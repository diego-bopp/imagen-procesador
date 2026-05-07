output "apigw_log_group_arn" {
  description = "ARN del Log Group para API Gateway"
  value       = aws_cloudwatch_log_group.apigateway.arn
}

output "apigw_log_group_name" {
  description = "Nombre del Log Group para API Gateway"
  value       = aws_cloudwatch_log_group.apigateway.name
}