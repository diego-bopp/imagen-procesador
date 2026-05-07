# Guía de Despliegue - Entorno DEV

## 1. Inicialización y validación
[cite_start]Ingresa al directorio del entorno[cite: 125]:
\`\`\`bash
cd envs/dev
terraform init
terraform validate
terraform fmt -recursive
\`\`\`

## 2. Plan (Revisar antes de aplicar)
\`\`\`bash
terraform plan -out=tfplan.dev
\`\`\`

## 3. Aplicar
\`\`\`bash
terraform apply tfplan.dev
\`\`\`

## 4. Verificación post-deploy
[cite_start]Verifica invocando la Lambda desde la CLI:
\`\`\`bash
aws lambda invoke --function-name image-processor-dev-upload \
  --payload '{}' response.json
\`\`\`

## 5. Destrucción (Evidencia Obligatoria)
\`\`\`bash
terraform destroy
\`\`\`