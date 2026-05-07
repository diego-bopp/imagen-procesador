variable "environment" {
  description = "Entorno de despliegue (dev, qa, prod)"
  type        = string
}

variable "sqs_queue_arn" {
  description = "ARN de la Main Queue de SQS para notificaciones de eventos"
  type        = string
}