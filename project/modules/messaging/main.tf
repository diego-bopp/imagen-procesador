# 1. Dead-Letter Queue (DLQ)
resource "aws_sqs_queue" "dlq" {
  name                      = "image-processor-${var.environment}-image-dlq"
  message_retention_seconds = 1209600 # 14 días
}

# 2. Main Queue
resource "aws_sqs_queue" "main" {
  name                       = "image-processor-${var.environment}-image-queue"
  visibility_timeout_seconds = 360
  message_retention_seconds  = 86400 # 1 día
  receive_wait_time_seconds  = 20    # Long polling

  # Redrive policy apuntando a la DLQ
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })
}

# 3. Política de la Main Queue para permitir mensajes desde S3
data "aws_iam_policy_document" "queue_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.main.arn]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [var.bucket_arn]
    }
  }
}

resource "aws_sqs_queue_policy" "main_policy" {
  queue_url = aws_sqs_queue.main.id
  policy    = data.aws_iam_policy_document.queue_policy.json
}

# 4. SNS Topic para las alertas (Destino de la alarma)
resource "aws_sns_topic" "dlq_alarms" {
  name = "image-processor-${var.environment}-dlq-alarms"
}

# 5. CloudWatch Metric Alarm para la DLQ
resource "aws_cloudwatch_metric_alarm" "dlq_alarm" {
  alarm_name          = "dlq-messages-alarm-${var.environment}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alarma disparada cuando hay mensajes visibles en la DLQ"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = [aws_sns_topic.dlq_alarms.arn]
}