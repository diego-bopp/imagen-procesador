# Generar sufijo aleatorio para el nombre del bucket
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket
resource "aws_s3_bucket" "images" {
  bucket = "image-processor-${var.environment}-images-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "image-processor-${var.environment}-images"
  }
}

# Bloqueo de acceso público total
resource "aws_s3_bucket_public_access_block" "images_public_block" {
  bucket                  = aws_s3_bucket.images.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Cifrado (SSE-S3 con AES256)
resource "aws_s3_bucket_server_side_encryption_configuration" "images_sse" {
  bucket = aws_s3_bucket.images.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Versionado
resource "aws_s3_bucket_versioning" "images_versioning" {
  bucket = aws_s3_bucket.images.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Ciclo de vida (Lifecycle Configuration)
resource "aws_s3_bucket_lifecycle_configuration" "images_lifecycle" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "uploads-expiration"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    expiration {
      days = 30
    }
  }

  rule {
    id     = "processed-expiration"
    status = "Enabled"

    filter {
      prefix = "processed/"
    }

    expiration {
      days = 90
    }
  }
}

# Notificación de Eventos a SQS
resource "aws_s3_bucket_notification" "images_notification" {
  bucket = aws_s3_bucket.images.id

  queue {
    queue_arn     = var.sqs_queue_arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "uploads/"
  }
}