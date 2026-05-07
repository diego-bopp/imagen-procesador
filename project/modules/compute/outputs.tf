output "upload_lambda_arn" {
  description = "ARN de la función Lambda upload"
  value       = aws_lambda_function.upload.arn
}

output "upload_lambda_invoke_arn" {
  description = "Invoke ARN de la función Lambda upload para API Gateway"
  value       = aws_lambda_function.upload.invoke_arn
}

output "upload_lambda_function_name" {
  description = "Nombre de la función upload"
  value       = aws_lambda_function.upload.function_name
}

output "crop_lambda_function_name" {
  description = "Nombre de la función crop"
  value       = aws_lambda_function.crop.function_name
}