variable "environment" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}
variable "nat_gateway_count" {
  type = number
}

variable "lambda_upload_memory" {
  type    = number
  default = 256
}

variable "lambda_crop_memory" {
  type    = number
  default = 512
}

variable "api_throttle_rps" {
  type = number
}

variable "log_retention_days" {
  type = number
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az_a" {
  type    = string
  default = "us-east-1a"
}

variable "az_b" {
  type    = string
  default = "us-east-1b"
}