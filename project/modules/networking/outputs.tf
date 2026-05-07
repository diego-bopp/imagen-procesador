output "vpc_id" {
  value = aws_vpc.main.id
}

output "private_subnet_ids" {
  value = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

output "sg_upload_lambda_id" {
  value = aws_security_group.upload_lambda.id
}

output "sg_crop_lambda_id" {
  value = aws_security_group.crop_lambda.id
}

output "vpce_sqs_id" {
  value = aws_vpc_endpoint.sqs.id
}