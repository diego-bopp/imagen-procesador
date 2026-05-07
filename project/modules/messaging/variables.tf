variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod)"
  type        = string
}

variable "bucket_arn" {
  description = "ARN del bucket S3 autorizado para enviar notificaciones a la cola"
  type        = string
}