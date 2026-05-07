output "main_queue_arn" {
  description = "ARN de la Main Queue"
  value       = aws_sqs_queue.main.arn
}

output "main_queue_url" {
  description = "URL de la Main Queue"
  value       = aws_sqs_queue.main.id
}

output "dlq_arn" {
  description = "ARN de la Dead-Letter Queue"
  value       = aws_sqs_queue.dlq.arn
}