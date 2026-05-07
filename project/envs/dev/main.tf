provider "aws" {
  region = var.region
}

module "networking" {
  source            = "../../modules/networking"
  environment       = var.environment
  vpc_cidr          = var.vpc_cidr
  az_a              = var.az_a
  az_b              = var.az_b
  nat_gateway_count = var.nat_gateway_count
}

module "messaging" {
  source      = "../../modules/messaging"
  environment = var.environment
  bucket_arn  = module.storage.bucket_arn
}

module "storage" {
  source        = "../../modules/storage"
  environment   = var.environment
  sqs_queue_arn = module.messaging.main_queue_arn
}

module "observability" {
  source             = "../../modules/observability"
  environment        = var.environment
  log_retention_days = var.log_retention_days
}

module "compute" {
  source               = "../../modules/compute"
  environment          = var.environment
  private_subnet_ids   = module.networking.private_subnet_ids
  sg_upload_lambda_id  = module.networking.sg_upload_lambda_id
  sg_crop_lambda_id    = module.networking.sg_crop_lambda_id
  bucket_arn           = module.storage.bucket_arn
  bucket_name          = module.storage.bucket_id
  sqs_main_queue_arn   = module.messaging.main_queue_arn
  lambda_upload_memory = var.lambda_upload_memory
  lambda_crop_memory   = var.lambda_crop_memory
}

module "apigw" {
  source                      = "../../modules/apigw"
  environment                 = var.environment
  upload_lambda_invoke_arn    = module.compute.upload_lambda_invoke_arn
  upload_lambda_function_name = module.compute.upload_lambda_function_name
  apigw_log_group_arn         = module.observability.apigw_log_group_arn
  api_throttle_rps            = var.api_throttle_rps
}