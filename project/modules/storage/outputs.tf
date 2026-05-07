output "bucket_id" {
  description = "El nombre del bucket creado"
  value       = aws_s3_bucket.images.id
}

output "bucket_arn" {
  description = "El ARN del bucket"
  value       = aws_s3_bucket.images.arn
}