#!/bin/bash

# Script de limpeza rápida - Account 794038226274
# Versão: 1.0
# Data: 19 de Janeiro de 2026

set -e

REGION="us-east-1"
VPC_ID="vpc-048d441429e098bf4"
ACCOUNT_ID="794038226274"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🧹 LIMPEZA RÁPIDA DE RECURSOS                               ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Account: $ACCOUNT_ID"
echo "🌍 Region: $REGION"
echo ""

read -p "⚠️  Deletar TODOS os recursos órfãos? (s/N): " confirm

if [[ ! $confirm =~ ^[Ss]$ ]]; then
    echo "❌ Operação cancelada"
    exit 0
fi

echo ""

# 1. ECR Repositories
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  PASSO 1: Deletando ECR Repositories"
echo "═══════════════════════════════════════════════════════════════════"

ECR_REPOS=(
    "ecommerce/profile-management"
    "ecommerce/order-management"
    "ecommerce/contact-support-team"
    "ecommerce/ecommerce-ui"
    "ecommerce/product-catalog"
    "ecommerce/product-inventory"
    "ecommerce/shipping-and-handling"
)

for repo in "${ECR_REPOS[@]}"; do
    echo "🗑️  Deletando: $repo"
    aws ecr delete-repository \
        --repository-name "$repo" \
        --region $REGION \
        --force 2>/dev/null && \
        echo "   ✅ Deletado" || \
        echo "   ⚠️  Erro ou já deletado"
done

echo ""

# 2. IAM User github-actions-eks
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  PASSO 2: Deletando IAM User github-actions-eks"
echo "═══════════════════════════════════════════════════════════════════"

if aws iam get-user --user-name github-actions-eks &>/dev/null; then
    # Delete access keys
    echo "→ Deletando access keys..."
    ACCESS_KEYS=$(aws iam list-access-keys --user-name github-actions-eks --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
    for key in $ACCESS_KEYS; do
        aws iam delete-access-key --user-name github-actions-eks --access-key-id "$key" 2>/dev/null || true
    done
    
    # Detach managed policies
    echo "→ Detaching policies..."
    ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name github-actions-eks --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
    for policy_arn in $ATTACHED_POLICIES; do
        aws iam detach-user-policy --user-name github-actions-eks --policy-arn "$policy_arn" 2>/dev/null || true
    done
    
    # Delete inline policies
    echo "→ Deletando inline policies..."
    INLINE_POLICIES=$(aws iam list-user-policies --user-name github-actions-eks --query 'PolicyNames' --output text 2>/dev/null)
    for policy_name in $INLINE_POLICIES; do
        aws iam delete-user-policy --user-name github-actions-eks --policy-name "$policy_name" 2>/dev/null || true
    done
    
    # Delete user
    echo "→ Deletando user..."
    aws iam delete-user --user-name github-actions-eks 2>/dev/null && \
        echo "✅ IAM user deletado" || \
        echo "❌ Erro ao deletar user"
else
    echo "✅ User já foi deletado"
fi

echo ""

# 3. IAM Role
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  PASSO 3: Deletando IAM Role external-dns-irsa-role"
echo "═══════════════════════════════════════════════════════════════════"

ROLE_NAME="external-dns-irsa-role"

if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
    # Detach managed policies
    echo "→ Detaching policies..."
    ATTACHED_POLICIES=$(aws iam list-attached-role-policies --role-name "$ROLE_NAME" --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
    for policy_arn in $ATTACHED_POLICIES; do
        aws iam detach-role-policy --role-name "$ROLE_NAME" --policy-arn "$policy_arn" 2>/dev/null || true
    done
    
    # Delete inline policies
    echo "→ Deletando inline policies..."
    INLINE_POLICIES=$(aws iam list-role-policies --role-name "$ROLE_NAME" --query 'PolicyNames' --output text 2>/dev/null)
    for policy_name in $INLINE_POLICIES; do
        aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name "$policy_name" 2>/dev/null || true
    done
    
    # Delete role
    echo "→ Deletando role..."
    aws iam delete-role --role-name "$ROLE_NAME" 2>/dev/null && \
        echo "✅ IAM role deletada" || \
        echo "❌ Erro ao deletar role"
else
    echo "✅ Role já foi deletada"
fi

echo ""

# 4. VPC (via Terraform se possível, senão manual)
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  PASSO 4: Deletando Stack 01 - Networking (VPC)"
echo "═══════════════════════════════════════════════════════════════════"

cd ~/gitops-eks/01-networking

# Verificar se há terraform state
if terraform state list &>/dev/null 2>&1; then
    echo "📋 Terraform state encontrado"
    echo "→ Tentando terraform destroy..."
    
    if terraform destroy -auto-approve 2>&1; then
        echo "✅ Stack 01 destruída via Terraform"
    else
        echo "⚠️  Terraform destroy falhou, tentando deleção manual..."
        
        # Deleção manual
        echo ""
        echo "→ Deletando subnets..."
        SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'Subnets[].SubnetId' --output text 2>/dev/null)
        for subnet_id in $SUBNET_IDS; do
            echo "   Deletando: $subnet_id"
            aws ec2 delete-subnet --subnet-id "$subnet_id" --region $REGION 2>/dev/null || true
        done
        
        echo "→ Deletando VPC..."
        aws ec2 delete-vpc --vpc-id "$VPC_ID" --region $REGION && \
            echo "✅ VPC deletada" || \
            echo "❌ Erro ao deletar VPC"
    fi
else
    echo "⚠️  Terraform state não encontrado, deletando manualmente..."
    
    # Deleção manual
    echo "→ Deletando subnets..."
    SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region $REGION --query 'Subnets[].SubnetId' --output text 2>/dev/null)
    for subnet_id in $SUBNET_IDS; do
        echo "   Deletando: $subnet_id"
        aws ec2 delete-subnet --subnet-id "$subnet_id" --region $REGION 2>/dev/null || true
    done
    
    echo "→ Deletando VPC..."
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --region $REGION && \
        echo "✅ VPC deletada" || \
        echo "❌ Erro ao deletar VPC"
fi

echo ""

# 5. S3 Bucket
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  PASSO 5: Deletando S3 Bucket (Backend)"
echo "═══════════════════════════════════════════════════════════════════"

BUCKET_NAME="eks-devopsproject-state-files-${ACCOUNT_ID}"

echo "→ Esvaziando bucket (objetos atuais)..."
aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || true

echo "→ Deletando versões antigas de objetos..."
aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json --query 'Versions[].{Key:Key,VersionId:VersionId}' 2>/dev/null | \
    jq -r '.[] | .Key + " " + .VersionId' 2>/dev/null | \
    while read key version; do
        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" 2>/dev/null || true
    done

echo "→ Deletando delete markers..."
aws s3api list-object-versions --bucket "$BUCKET_NAME" --output json --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' 2>/dev/null | \
    jq -r '.[] | .Key + " " + .VersionId' 2>/dev/null | \
    while read key version; do
        aws s3api delete-object --bucket "$BUCKET_NAME" --key "$key" --version-id "$version" 2>/dev/null || true
    done

echo "→ Deletando bucket..."
aws s3 rb "s3://$BUCKET_NAME" 2>/dev/null && \
    echo "✅ Bucket deletado" || \
    echo "❌ Erro ao deletar bucket"

# Tentar deletar DynamoDB também
echo ""
echo "→ Deletando DynamoDB table (se existir)..."
aws dynamodb delete-table --table-name eks-devopsproject-state-locking --region $REGION 2>/dev/null && \
    echo "✅ DynamoDB table deletada" || \
    echo "ℹ️  Table não encontrada ou já deletada"

echo ""

# Verificação final
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ LIMPEZA CONCLUÍDA!                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "🔍 Verificando recursos restantes..."
echo ""

cd ~/gitops-eks
./scripts/check-resources.sh

echo ""
echo "💰 Custo estimado após limpeza: ~$0/mês"
echo ""
