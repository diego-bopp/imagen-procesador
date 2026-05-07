output "api_endpoint" {
  description = "La URL base del API Gateway"
  value       = aws_apigatewayv2_api.http_api.api_endpoint
}