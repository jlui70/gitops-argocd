# 🧹 Limpeza de Recursos Órfãos - Pós Falha no Destroy

## 📋 Situação

Após uma interrupção durante o `destroy-all.sh` (queda de energia + force-unlock do state lock), alguns recursos ficaram órfãos:

- ✅ **EKS Cluster**: Foi deletado na segunda execução
- ❌ **Stack 01 - Networking**: VPC + Subnets + NAT Gateways + IGW ainda ativos
- ❌ **ECR Repositories**: Vários repositórios ainda existem
- ❌ **S3 Bucket**: Bucket do backend ainda ativo
- ❌ **DynamoDB**: Table de state lock pode estar ativa

O script reportou sucesso mas os recursos da stack 01 não foram realmente deletados.

---

## 🔍 PASSO 1: Verificar Recursos Ativos

Primeiro, verifique quais recursos ainda existem na AWS:

```bash
cd ~/gitops-eks
./scripts/check-resources.sh
```

Este script irá listar:
- ✅ EKS Cluster
- ✅ VPC e recursos de rede
- ✅ Elastic IPs
- ✅ ECR Repositories
- ✅ S3 Buckets
- ✅ DynamoDB Tables
- ✅ Load Balancers
- ✅ IAM Roles órfãs

---

## 🗑️ PASSO 2: Deletar Recursos Órfãos

### Opção A: Script Automático (Recomendado)

Use o script de limpeza automática que deleta TODOS os recursos órfãos:

```bash
./scripts/cleanup-orphaned-resources.sh
```

Este script irá:
1. Verificar todos os recursos órfãos
2. Pedir confirmação
3. Deletar na ordem correta:
   - ECR Repositories
   - EKS Cluster (se ainda existir)
   - Stack 01 via Terraform ou manual via AWS CLI
   - S3 Bucket + DynamoDB

### Opção B: Deletar Apenas Stack 01

Se apenas a Stack 01 ficou órfã:

```bash
./scripts/force-destroy-stack01.sh
```

Este script oferece 2 métodos:
- **Método 1**: `terraform destroy` (recomendado se o state estiver OK)
- **Método 2**: Deleção manual via AWS CLI (se Terraform falhar)

---

## 🛠️ PASSO 3: Resolver Problemas Específicos

### Problema: State Lock Travado

Se aparecer erro de state lock:

```bash
cd 01-networking

# Listar locks ativos no DynamoDB
aws dynamodb scan \
  --table-name eks-devopsproject-state-lock-table \
  --region us-east-1 \
  --profile terraform

# Forçar unlock (substitua LOCK-ID pelo ID real)
terraform force-unlock -force LOCK-ID
```

### Problema: VPC não Deleta (tem dependências)

Se a VPC não deletar por ter recursos dependentes:

```bash
# Verificar recursos na VPC
VPC_ID="vpc-xxxxx"  # Substitua pelo ID real

# Listar ENIs (Network Interfaces)
aws ec2 describe-network-interfaces \
  --region us-east-1 \
  --profile terraform \
  --filters "Name=vpc-id,Values=$VPC_ID"

# Deletar ENIs órfãos manualmente
aws ec2 delete-network-interface \
  --network-interface-id eni-xxxxx \
  --region us-east-1 \
  --profile terraform
```

### Problema: Security Group não Deleta

Security Groups podem ter dependências circulares:

```bash
SG_ID="sg-xxxxx"

# Remover todas as regras de ingress
aws ec2 describe-security-groups \
  --group-ids $SG_ID \
  --region us-east-1 \
  --profile terraform \
  --query 'SecurityGroups[0].IpPermissions' | \
aws ec2 revoke-security-group-ingress \
  --group-id $SG_ID \
  --region us-east-1 \
  --profile terraform \
  --ip-permissions file:///dev/stdin

# Tentar deletar novamente
aws ec2 delete-security-group \
  --group-id $SG_ID \
  --region us-east-1 \
  --profile terraform
```

### Problema: NAT Gateway demora para deletar

NAT Gateways levam 3-5 minutos para serem deletados:

```bash
# Verificar status
aws ec2 describe-nat-gateways \
  --region us-east-1 \
  --profile terraform \
  --nat-gateway-ids nat-xxxxx

# Aguardar até status = "deleted"
```

---

## 🧪 PASSO 4: Deleção Manual Item por Item

Se os scripts falharem, delete manualmente na ordem correta:

### 1️⃣ ECR Repositories

```bash
# Listar todos os repos
aws ecr describe-repositories --region us-east-1 --profile terraform

# Deletar cada um (force = deleta com imagens)
aws ecr delete-repository \
  --repository-name ecommerce/ecommerce-ui \
  --region us-east-1 \
  --force \
  --profile terraform

# Repetir para todos os 7 repos
```

### 2️⃣ Stack 01 - Networking (via Terraform)

```bash
cd ~/gitops-eks/01-networking

# Verificar state
terraform state list

# Tentar destroy normal
terraform destroy -auto-approve

# Se falhar, tentar sem refresh
terraform destroy -auto-approve -refresh=false

# Se continuar falhando, usar o script force-destroy-stack01.sh
```

### 3️⃣ NAT Gateways (manual se Terraform falhar)

```bash
# Listar NAT Gateways
aws ec2 describe-nat-gateways \
  --region us-east-1 \
  --profile terraform \
  --filter "Name=state,Values=available,pending"

# Deletar cada um
aws ec2 delete-nat-gateway \
  --nat-gateway-id nat-xxxxx \
  --region us-east-1 \
  --profile terraform

# Aguardar 3-5 minutos
sleep 180
```

### 4️⃣ Elastic IPs

```bash
# Listar EIPs
aws ec2 describe-addresses \
  --region us-east-1 \
  --profile terraform

# Liberar cada um
aws ec2 release-address \
  --allocation-id eipalloc-xxxxx \
  --region us-east-1 \
  --profile terraform
```

### 5️⃣ VPC e recursos

```bash
VPC_ID="vpc-xxxxx"  # Substituir pelo ID real

# 1. Deletar Subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --profile terraform
aws ec2 delete-subnet --subnet-id subnet-xxxxx --region us-east-1 --profile terraform

# 2. Deletar Route Tables (exceto main)
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --profile terraform
aws ec2 delete-route-table --route-table-id rtb-xxxxx --region us-east-1 --profile terraform

# 3. Desanexar e deletar Internet Gateway
aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --region us-east-1 --profile terraform
aws ec2 detach-internet-gateway --internet-gateway-id igw-xxxxx --vpc-id $VPC_ID --region us-east-1 --profile terraform
aws ec2 delete-internet-gateway --internet-gateway-id igw-xxxxx --region us-east-1 --profile terraform

# 4. Deletar Security Groups (exceto default)
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --profile terraform
aws ec2 delete-security-group --group-id sg-xxxxx --region us-east-1 --profile terraform

# 5. Deletar VPC
aws ec2 delete-vpc --vpc-id $VPC_ID --region us-east-1 --profile terraform
```

### 6️⃣ S3 Bucket + DynamoDB

```bash
# Obter Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile terraform)
BUCKET="eks-devopsproject-state-files-${ACCOUNT_ID}"

# Esvaziar bucket
aws s3 rm s3://$BUCKET --recursive --profile terraform

# Deletar versões antigas (se versionamento habilitado)
aws s3api list-object-versions --bucket $BUCKET --profile terraform

# Deletar bucket
aws s3 rb s3://$BUCKET --profile terraform

# Deletar DynamoDB table
aws dynamodb delete-table \
  --table-name eks-devopsproject-state-lock-table \
  --region us-east-1 \
  --profile terraform
```

---

## ✅ PASSO 5: Verificar Limpeza Completa

Após deletar tudo, verifique novamente:

```bash
./scripts/check-resources.sh
```

Deve mostrar todos como "✅ não encontrado".

---

## 🔄 PASSO 6: Recriar Infraestrutura (Opcional)

Se quiser recriar tudo do zero:

```bash
./scripts/rebuild-all.sh
```

Isso irá recriar:
- Stack 00: Backend (S3 + DynamoDB)
- Stack 01: Networking (VPC)
- Stack 02: EKS Cluster

---

## 💡 Scripts Criados

| Script | Descrição |
|--------|-----------|
| `check-resources.sh` | Verifica recursos ativos na AWS (leitura apenas) |
| `cleanup-orphaned-resources.sh` | Deleta TODOS os recursos órfãos automaticamente |
| `force-destroy-stack01.sh` | Força deleção da Stack 01 (Terraform ou manual) |

---

## 🚨 Troubleshooting

### Erro: "EntityAlreadyExists" ao recriar

Significa que IAM roles ainda existem. Use:

```bash
# Listar roles órfãos
aws iam list-roles --profile terraform | grep eks-devopsproject

# Deletar role específico
aws iam delete-role --role-name eks-devopsproject-cluster-role --profile terraform
```

### Erro: "VPC has dependencies and cannot be deleted"

Verifique:
```bash
VPC_ID="vpc-xxxxx"

# Network Interfaces (ENIs)
aws ec2 describe-network-interfaces --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --profile terraform

# Security Groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --profile terraform

# Subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 --profile terraform
```

### Erro: "InvalidParameter: Subnet still has dependencies"

Pode ser Lambda ENIs ou outros serviços. Aguarde 5-10 minutos e tente novamente.

---

## 📞 Contato

Se nenhum dos métodos funcionar:
1. Compartilhe o output de `check-resources.sh`
2. Compartilhe erros do Terraform/AWS CLI
3. Verifique manualmente no Console AWS

**Console AWS**: https://console.aws.amazon.com/
- VPC: https://console.aws.amazon.com/vpc
- EKS: https://console.aws.amazon.com/eks
- ECR: https://console.aws.amazon.com/ecr
- S3: https://console.aws.amazon.com/s3

---

## 💰 Custos Enquanto Recursos Órfãos Existem

| Recurso | Custo Aproximado |
|---------|------------------|
| VPC | Gratuito |
| Subnets | Gratuito |
| NAT Gateway | **~$33/mês por NAT** ⚠️ |
| Elastic IPs (desassociados) | **$3.6/mês por IP** ⚠️ |
| Internet Gateway | Gratuito |
| Security Groups | Gratuito |
| Route Tables | Gratuito |
| S3 Bucket | < $0.10/mês |
| DynamoDB | < $0.10/mês |
| ECR (repos vazios) | Gratuito |

**⚠️ IMPORTANTE**: NAT Gateways são o recurso mais caro! Se você tem 3 NAT Gateways ativos, está pagando ~$100/mês. **Delete o mais rápido possível!**

---

## 🎯 Ordem Recomendada de Execução

```bash
# 1. Verificar o que existe
./scripts/check-resources.sh

# 2. Deletar tudo automaticamente
./scripts/cleanup-orphaned-resources.sh

# 3. Verificar novamente
./scripts/check-resources.sh

# 4. Se Stack 01 ainda existir, forçar deleção
./scripts/force-destroy-stack01.sh

# 5. Verificar custos AWS
# Acesse: https://console.aws.amazon.com/billing
```

---

**Última atualização**: 19 de Janeiro de 2026
