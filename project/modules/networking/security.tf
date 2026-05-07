resource "aws_security_group" "vpce_sqs" {
  name        = "sg-vpce-sqs-${var.environment}"
  description = "Security group para el VPC Endpoint de SQS"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Permitir TCP 443 desde Lambdas"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.upload_lambda.id, aws_security_group.crop_lambda.id]
  }

  tags = {
    Name = "sg-vpce-sqs-${var.environment}"
  }
}

resource "aws_security_group" "upload_lambda" {
  name        = "sg-upload-lambda-${var.environment}"
  description = "Security group para upload lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Permitir salida HTTPS hacia S3 y SQS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restringido por la red de AWS hacia los endpoints
  }

  tags = {
    Name = "sg-upload-lambda-${var.environment}"
  }
}

resource "aws_security_group" "crop_lambda" {
  name        = "sg-crop-lambda-${var.environment}"
  description = "Security group para crop lambda"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "Permitir salida HTTPS hacia S3 y SQS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sg-crop-lambda-${var.environment}"
  }
}