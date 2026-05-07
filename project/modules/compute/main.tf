# --- EMPAQUETADO ---
data "archive_file" "upload_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/upload"
  output_path = "${path.module}/lambda/upload.zip"
}

data "archive_file" "crop_zip" {
  type        = "zip"
  source_dir = "${path.module}/lambda/crop"
  output_path = "${path.module}/lambda/crop.zip"
}

# --- LAMBDA UPLOAD ---
resource "aws_lambda_function" "upload" {
  filename         = data.archive_file.upload_zip.output_path
  source_code_hash = data.archive_file.upload_zip.output_base64sha256
  function_name    = "image-processor-${var.environment}-upload"
  role             = aws_iam_role.upload_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = var.lambda_upload_memory
  timeout          = 30

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_upload_lambda_id]
  }

  environment {
    variables = {
      S3_BUCKET     = var.bucket_name
      UPLOAD_PREFIX = "uploads/"
    }
  }
}

# --- LAMBDA CROP ---
resource "aws_lambda_function" "crop" {
  filename         = data.archive_file.crop_zip.output_path
  source_code_hash = data.archive_file.crop_zip.output_base64sha256
  function_name    = "image-processor-${var.environment}-crop"
  role             = aws_iam_role.crop_role.arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  memory_size      = var.lambda_crop_memory
  timeout          = 60

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [var.sg_crop_lambda_id]
  }

  environment {
    variables = {
      S3_BUCKET        = var.bucket_name
      PROCESSED_PREFIX = "processed/"
    }
  }
}

# --- EVENT SOURCE MAPPING ---
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn        = var.sqs_main_queue_arn
  function_name           = aws_lambda_function.crop.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
}