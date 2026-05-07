resource "aws_security_group" "upload_lambda" {
  name        = "upload-lambda-${var.environment}"
  description = "Security group para upload lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS salida"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "upload-lambda-${var.environment}"
  }
}

resource "aws_security_group" "crop_lambda" {
  name        = "crop-lambda-${var.environment}"
  description = "Security group para crop lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS salida"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "crop-lambda-${var.environment}"
  }
}

resource "aws_security_group" "vpce_sqs" {
  name        = "vpce-sqs-${var.environment}"
  description = "Security group para VPC Endpoint de SQS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Permitir HTTPS desde Lambdas"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"

    security_groups = [
      aws_security_group.upload_lambda.id,
      aws_security_group.crop_lambda.id
    ]
  }

  tags = {
    Name = "vpce-sqs-${var.environment}"
  }
}