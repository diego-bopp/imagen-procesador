# --- API GATEWAY HTTP API ---
resource "aws_apigatewayv2_api" "http_api" {
  name          = "image-processor-${var.environment}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["content-type", "authorization"]
    max_age       = 300
  }
}

# --- INTEGRACIÓN CON LAMBDA ---
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.http_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.upload_lambda_invoke_arn
  payload_format_version = "2.0"
  integration_method     = "POST"
}

# --- RUTAS ---
resource "aws_apigatewayv2_route" "upload_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# --- STAGE Y LOGGING ---
resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = var.apigw_log_group_arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }

  default_route_settings {
    throttling_burst_limit = var.api_throttle_rps
    throttling_rate_limit  = var.api_throttle_rps
  }
}

# --- PERMISO DE INVOCACIÓN (RESOURCE-BASED POLICY) ---
resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.upload_lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # El source_arn restringe qué API específico puede invocar esta Lambda
  source_arn = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}