# Guía de implementación — Infraestructura como Código (Terraform)

## Etapa 0 — Preparación del entorno de trabajo
Antes de escribir código Terraform, se establece la estructura base del proyecto y las herramientas requeridas.

**Prerrequisitos de instalación:**
* Terraform ≥ 1.6
* AWS CLI v2 configurado con un perfil IAM con permisos de administrador (o un rol de CI con scope mínimo para recursos Lambda, S3, SQS, VPC, IAM y CloudWatch).
* Node.js 20.x para compilar los artefactos Lambda localmente si se opta por empaquetado en build time.

**Estructura de directorios recomendada:**
```text
project/
├── modules/
│   ├── networking/        # VPC, subnets, IGW, NAT GW, route tables
│   ├── storage/           # S3 bucket, prefixes, lifecycle, notifications
│   ├── messaging/         # SQS main queue + DLQ, alarmas CloudWatch
│   ├── compute/           # Lambda functions, IAM roles, security groups
│   └── observability/     # CloudWatch log groups, métricas, alarmas SNS
├── envs/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars
│   ├── qa/
│   │   └── (misma estructura)
│   └── prod/
│       └── (misma estructura)
├── lambda/
│   ├── upload/            # Código fuente Node.js upload-lambda
│   └── crop/              # Código fuente Node.js crop-lambda
└── backend.tf             # Configuración de remote state (S3 + DynamoDB)
```
## Etapa 1 — Configuración del backend remoto y workspaces
El estado de Terraform debe almacenarse de forma centralizada con bloqueo para evitar condiciones de carrera entre entornos.

Backend S3 + DynamoDB (crear manualmente una única vez antes del primer terraform init):
```
# backend.tf
terraform {
  backend "s3" {
    bucket         = "tf-state-image-processor"
    key            = "envs/${var.environment}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-lock-image-processor"
    encrypt        = true
  }
}
```
Estrategia multi-entorno: Se utilizan directorios independientes por entorno (envs/dev, envs/qa, envs/prod) con el mismo conjunto de módulos, 
pero con un terraform.tfvars distinto que define la variable environment (valor: dev, qa o prod). Esta variable se propaga como sufijo a todos 
los recursos nombrados, garantizando aislamiento total. La alternativa de Terraform Workspaces es válida pero genera mayor complejidad en la gestión 
del state; los directorios por entorno son preferibles para arquitecturas con diferencias de escala entre entornos (por ejemplo, en PROD se activan 2 NAT Gateways; en DEV puede usarse 1).
---
## Etapa 2 — Módulo networking

  .Este módulo provisiona la VPC y toda la infraestructura de red que los demás módulos consumen.
  .Recursos a declarar:
  .aws_vpc: CIDR 10.0.0.0/16, con enable_dns_support = true y enable_dns_hostnames = true.
  .aws_internet_gateway: adjunto a la VPC.
  .aws_subnet × 4: dos públicas (10.0.1.0/24 AZ-a, 10.0.2.0/24 AZ-b) y dos privadas (10.0.11.0/24 AZ-a, 10.0.12.0/24 AZ-b).
  .aws_eip × 2: IPs elásticas para ambos NAT Gateways (en PROD; en DEV puede declararse solo 1 EIP + 1 NAT).
  .aws_nat_gateway × 2: NAT-A en Public Subnet AZ-a, NAT-B en Public Subnet AZ-b.
  .aws_route_table × 3: una pública con ruta 0.0.0.0/0 → IGW, una privada AZ-a con 0.0.0.0/0 → NAT-A, una privada AZ-b con 0.0.0.0/0 → NAT-B.
  .aws_route_table_association: asociaciones correspondientes.
  .aws_vpc_endpoint (tipo Gateway) para S3: se inyecta en las route tables de las subnets privadas; no genera ENI ni costo.
  .aws_vpc_endpoint (tipo Interface) para SQS: genera ENIs en ambas subnets privadas, con private_dns_enabled = true. Requiere un Security Group (sg-vpce-sqs) que permita TCP 443 entrante desde los SGs de ambas Lambdas.
  .Security Groups: sg-upload-lambda y sg-crop-lambda sin inbound rules; egress TCP 443 hacia el endpoint S3 y SQS.

Variables de entrada del módulo: environment, vpc_cidr, az_a, az_b.
Outputs: IDs de VPC, subnets privadas, SGs de Lambda, ID del VPC endpoint SQS.
---
## Etapa 3 — Módulo storage
Gestiona el bucket S3 único que aloja ambos prefixes (uploads/ y processed/).

Recursos a declarar:
```
aws_s3_bucket: nombre image-processor-${var.environment}-images-${random_id}. Bloqueo de acceso público total habilitado.

aws_s3_bucket_server_side_encryption_configuration: algoritmo AES256.

aws_s3_bucket_versioning: estado Enabled.

aws_s3_bucket_lifecycle_configuration: dos reglas: prefix uploads/ con expiración a 30 días; prefix processed/ con expiración a 90 días.

aws_s3_bucket_notification: evento s3:ObjectCreated:* con filtro prefix uploads/; destino: ARN de la SQS Main Queue. Depende del módulo messaging (usar depends_on o pasar el ARN como variable).
```
---
## Etapa 4 — Módulo messaging

Provisiona la cola principal y la DLQ, junto con la política de recurso que permite a S3 enviar notificaciones.

Recursos a declarar:

  aws_sqs_queue (DLQ): nombre image-processor-${var.environment}-image-dlq; message_retention_seconds = 1209600 (14 días).

  aws_sqs_queue (Main): nombre image-processor-${var.environment}-image-queue; visibility_timeout_seconds = 360; message_retention_seconds = 86400 (1 día); receive_wait_time_seconds = 20; redrive_policy apuntando a la DLQ con maxReceiveCount = 3.
  
  aws_sqs_queue_policy (Main): permite sqs:SendMessage al principal s3.amazonaws.com con condición ArnLike sobre el bucket.

  aws_cloudwatch_metric_alarm: métrica ApproximateNumberOfMessagesVisible sobre la DLQ; período 60s; umbral > 0; acción de alarma hacia un aws_sns_topic.
  
Output: ARN y URL de la Main Queue, ARN de la DLQ.
---
## Etapa 5 — Módulo compute
  Provisiona los roles IAM y las funciones Lambda con sus Event Source Mappings y log groups.

Roles IAM:

  upload-lambda-role: política administrada AWSLambdaBasicExecutionRole + AWSLambdaVPCAccessExecutionRole + política inline s3:PutObject con condición de recurso arn:aws:s3:::${bucket}/uploads/*.

  crop-lambda-role: mismo set base + s3:GetObject sobre uploads/* + s3:PutObject sobre processed/* + sqs:ReceiveMessage, sqs:DeleteMessage, sqs:GetQueueAttributes, sqs:ChangeMessageVisibility sobre la Main Queue.
  
  Lambda functions:

  aws_lambda_function (upload): runtime nodejs20.x; memory 256 MB; timeout 30s; handler index.handler; variables de entorno S3_BUCKET y UPLOAD_PREFIX; VPC config con las subnets privadas de ambas AZs y sg-upload-lambda; rol upload-lambda-role.

  aws_lambda_function (crop): runtime nodejs20.x; memory 512 MB; timeout 60s; handler index.handler; variables de entorno S3_BUCKET y PROCESSED_PREFIX; VPC config; rol crop-lambda-role.

  aws_lambda_event_source_mapping: vincula la Main SQS Queue con crop-lambda; batch_size = 5; function_response_types = ["ReportBatchItemFailures"].

Empaquetado del código Lambda: Usar el recurso null_resource o el provider archive_file para generar el .zip de cada función desde el directorio lambda/upload/ y lambda/crop/ antes del deploy. En entornos CI/CD, el ZIP se puede pre-construir y referenciar con s3_bucket + s3_key en lugar de filename.
---
## Etapa 6 — Módulo observability
Centraliza la configuración de logging y monitoreo.

Recursos a declarar:

  aws_cloudwatch_log_group × 3: uno por función Lambda (/aws/lambda/...-upload, /aws/lambda/...-crop) y uno para API Gateway (/aws/apigateway/...); retention_in_days = 14.

  aws_api_gateway_account: requerido para habilitar CloudWatch Logs en API Gateway; necesita un rol con la política AmazonAPIGatewayPushToCloudWatchLogs.

  La alarma de DLQ se declara en el módulo messaging (ver Etapa 4) para mantener cohesión con el recurso que monitorea.
  ---
  ## Etapa 7 — API Gateway
Se puede declarar en el módulo raíz de cada entorno o en un módulo propio apigw.

Recursos a declarar:

  aws_apigatewayv2_api: protocol HTTP; CORS habilitado.

  aws_apigatewayv2_integration: tipo AWS_PROXY; integration URI apuntando al ARN de upload-lambda; payload format version 2.0.
  
  aws_apigatewayv2_route: POST /upload → integración anterior.

  aws_apigatewayv2_stage: nombre $default; auto-deploy; access log destination al log group de API Gateway; formato JSON.

  aws_lambda_permission: permite que API Gateway invoque upload-lambda.
  ---
## Etapa 8 — Parametrización por entorno
Cada directorio envs/{env}/terraform.tfvars define los parámetros que difieren entre entornos:

Throttling: default_route_settings con throttling_burst_limit y throttling_rate_limit configurados a 10 000 rps en PROD; valores reducidos en DEV/QA.
```
# envs/dev/terraform.tfvars
environment          = "dev"
region               = "us-east-1"
nat_gateway_count    = 1          # solo 1 NAT en DEV para reducir costo
lambda_upload_memory = 256
lambda_crop_memory   = 512
api_throttle_rps     = 1000
log_retention_days   = 7

# envs/prod/terraform.tfvars
environment          = "prod"
nat_gateway_count    = 2          # alta disponibilidad en PROD
api_throttle_rps     = 10000
log_retention_days   = 14
```
---
## Etapa 9 — Ciclo de despliegue y destrucción (evidencia requerida)
Comandos por entorno:

cd envs/dev
```
# Inicialización y validación
terraform init
terraform validate
terraform fmt -recursive

# Plan (revisar antes de aplicar)
terraform plan -out=tfplan.dev

# Aplicar
terraform apply tfplan.dev

# Verificación post-deploy (consola AWS o CLI)
aws lambda invoke --function-name image-processor-dev-upload \
  --payload '{}' response.json

# Destrucción (evidencia obligatoria)
terraform destroy
# Confirmar con: yes
```
Para generar la evidencia de destrucción requerida por la asignación, se debe capturar el output completo de terraform destroy,
que lista cada recurso eliminado con su tipo y nombre, y finaliza con el mensaje Destroy complete! Resources: N destroyed.. Esta salida, 
combinada con una captura de la consola AWS mostrando los recursos eliminados, constituye la evidencia solicitada.

Orden seguro de destrucción: (Terraform lo resuelve automáticamente por el grafo de dependencias, 
pero es útil conocerlo): ESM → Lambdas → SQS → S3 notification → S3 bucket → VPC Endpoints → Security Groups → NAT GW → EIPs → Subnets → Route Tables → IGW → VPC → IAM Roles → CloudWatch Log Groups.
---
## Etapa 10 — Pipeline CI/CD (opcional pero recomendado)
Para el flujo de entrega continua, un pipeline en GitHub Actions o GitLab CI puede estructurarse con tres jobs secuenciales: validate (init + fmt + validate + plan), apply (terraform apply sobre el plan generado), y destroy (manual, disparado por workflow dispatch). Las credenciales AWS se inyectan como secrets de repositorio; nunca se hardcodean en el código Terraform.
---
👤 Autor
Diego Fabian Escobedo Bopp - Ingeniería de Sistemas - Universidad Privada Antenor Orrego
---
