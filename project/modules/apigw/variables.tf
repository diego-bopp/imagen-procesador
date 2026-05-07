variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod)"
  type        = string
}

variable "upload_lambda_invoke_arn" {
  description = "El ARN de invocación de la Lambda de upload"
  type        = string
}

variable "upload_lambda_function_name" {
  description = "El nombre de la función Lambda de upload"
  type        = string
}

variable "apigw_log_group_arn" {
  description = "ARN del Log Group de CloudWatch para el API Gateway"
  type        = string
}

variable "api_throttle_rps" {
  description = "Límite de peticiones por segundo para el throttling"
  type        = number
}