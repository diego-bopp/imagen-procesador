# --- GRUPOS DE LOGS ---
resource "aws_cloudwatch_log_group" "upload_lambda" {
  name              = "/aws/lambda/image-processor-${var.environment}-upload"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "crop_lambda" {
  name              = "/aws/lambda/image-processor-${var.environment}-crop"
  retention_in_days = var.log_retention_days
}

resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/image-processor-${var.environment}"
  retention_in_days = var.log_retention_days
}

# --- ROL Y CUENTA PARA API GATEWAY ---
data "aws_iam_policy_document" "apigw_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigw_cw_role" {
  name               = "apigw-cw-role-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.apigw_assume_role.json
}

resource "aws_iam_role_policy_attachment" "apigw_cw_policy" {
  role       = aws_iam_role.apigw_cw_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigw_cw_role.arn
}