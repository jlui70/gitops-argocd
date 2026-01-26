#!/bin/bash

# Script para recriar toda infraestrutura do zero - ArgoCD GitOps
# Versão: 5.0 - ArgoCD GitOps Automatizado
# Data: 22 de Janeiro de 2026
# Stacks: 00-backend, 01-networking, 02-eks-cluster (ArgoCD) + Application
# Changelog v5.0: Automatiza deploy completo com ArgoCD Application

set -e  # Para em caso de erro

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║   🚀 REBUILD COMPLETO - EKS + ARGOCD + GITOPS (AUTOMATIZADO)    ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Ordem: 00-backend → 01-networking → 02-eks-cluster → ArgoCD App"
echo ""

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AWS_PROFILE="devopsproject"

echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 PASSO 0: Limpando recursos órfãos (IAM Roles/Policies)"
echo "═══════════════════════════════════════════════════════════════════"
echo "Isso previne erros 'EntityAlreadyExists' de builds anteriores"
echo ""

# Função para deletar role IAM órfã
delete_orphan_role() {
    local role_name=$1
    
    if aws iam get-role --role-name "$role_name" --profile $AWS_PROFILE &>/dev/null; then
        echo "  🗑️  Removendo role órfã: $role_name"
        
        # Detach managed policies
        ATTACHED=$(aws iam list-attached-role-policies --role-name "$role_name" --profile $AWS_PROFILE --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null || echo "")
        for arn in $ATTACHED; do
            aws iam detach-role-policy --role-name "$role_name" --policy-arn "$arn" --profile $AWS_PROFILE 2>/dev/null || true
        done
        
        # Delete inline policies
        INLINE=$(aws iam list-role-policies --role-name "$role_name" --profile $AWS_PROFILE --query 'PolicyNames' --output text 2>/dev/null || echo "")
        for name in $INLINE; do
            aws iam delete-role-policy --role-name "$role_name" --policy-name "$name" --profile $AWS_PROFILE 2>/dev/null || true
        done
        
        # Remove from instance profiles
        PROFILES=$(aws iam list-instance-profiles-for-role --role-name "$role_name" --profile $AWS_PROFILE --query 'InstanceProfiles[].InstanceProfileName' --output text 2>/dev/null || echo "")
        for profile in $PROFILES; do
            aws iam remove-role-from-instance-profile --instance-profile-name "$profile" --role-name "$role_name" --profile $AWS_PROFILE 2>/dev/null || true
            aws iam delete-instance-profile --instance-profile-name "$profile" --profile $AWS_PROFILE 2>/dev/null || true
        done
        
        # Delete role
        aws iam delete-role --role-name "$role_name" --profile $AWS_PROFILE 2>/dev/null && echo "    ✅ Removida" || echo "    ⚠️  Falha ao remover"
    fi
}

# Deletar policy órfã
delete_orphan_policy() {
    local policy_name=$1
    local account_id=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE 2>/dev/null)
    local policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"
    
    if aws iam get-policy --policy-arn "$policy_arn" --profile $AWS_PROFILE &>/dev/null; then
        echo "  🗑️  Removendo policy órfã: $policy_name"
        
        # Listar e deletar todas as versões não-default
        VERSIONS=$(aws iam list-policy-versions --policy-arn "$policy_arn" --profile $AWS_PROFILE --query 'Versions[?IsDefaultVersion==`false`].VersionId' --output text 2>/dev/null || echo "")
        for version in $VERSIONS; do
            aws iam delete-policy-version --policy-arn "$policy_arn" --version-id "$version" --profile $AWS_PROFILE 2>/dev/null || true
        done
        
        # Deletar policy
        aws iam delete-policy --policy-arn "$policy_arn" --profile $AWS_PROFILE 2>/dev/null && echo "    ✅ Removida" || echo "    ⚠️  Falha ao remover (pode estar attached)"
    fi
}

# Roles comuns que ficam órfãs
echo "  → Verificando roles órfãs..."
delete_orphan_role "eks-devopsproject-cluster-role"
delete_orphan_role "eks-devopsproject-node-group-role"
delete_orphan_role "aws-load-balancer-controller"
delete_orphan_role "external-dns-irsa-role"
delete_orphan_role "AmazonEKS_EFS_CSI_DriverRole"

# Policies comuns que ficam órfãs
echo "  → Verificando policies órfãs..."
delete_orphan_policy "AWSLoadBalancerControllerIAMPolicy"
delete_orphan_policy "ExternalDNSPolicy"

echo "  ✅ Limpeza de recursos órfãos concluída"
echo ""

# Função para aplicar uma stack (com tratamento de recursos existentes)
apply_stack() {
    local stack_name=$1
    local stack_path=$2
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🚀 Aplicando: $stack_name"
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT/$stack_path"
    
    # -reconfigure evita erro "Backend configuration changed" após recriar S3
    terraform init -reconfigure
    
    # Aplicar com auto-approve
    if terraform apply -auto-approve; then
        echo "✅ $stack_name aplicado com sucesso!"
    else
        echo "⚠️  Erro ao aplicar $stack_name - tentando import de recursos existentes..."
        
        # Para stack 00: tentar importar S3 e DynamoDB se já existirem
        if [ "$stack_path" == "00-backend" ]; then
            ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE 2>/dev/null)
            BUCKET_NAME="eks-devopsproject-state-files-${ACCOUNT_ID}"
            TABLE_NAME="eks-devopsproject-state-lock"
            
            echo "    → Tentando importar S3 bucket: $BUCKET_NAME"
            terraform import aws_s3_bucket.terraform_state "$BUCKET_NAME" 2>/dev/null || true
            
            echo "    → Tentando importar DynamoDB table: $TABLE_NAME"
            terraform import aws_dynamodb_table.terraform_lock "$TABLE_NAME" 2>/dev/null || true
            
            echo "    → Reaplicando após import..."
            terraform apply -auto-approve
            echo "✅ $stack_name corrigido após import!"
        else
            echo "    ❌ Erro persistente - verifique manualmente"
            exit 1
        fi
    fi
    
    echo ""
}

# Ordem correta de criação (00 → 02)
apply_stack "Stack 00 - Backend (S3 + DynamoDB)" "00-backend"

# Aguardar S3 bucket estar disponível antes de continuar
echo "⏳ Aguardando S3 bucket estar disponível para backend remoto (10s)..."
sleep 10
echo ""

apply_stack "Stack 01 - Networking (VPC)" "01-networking"

# Preparar repositórios Helm antes de aplicar Stack 02
echo "═══════════════════════════════════════════════════════════════════"
echo "📦 Preparando repositórios Helm"
echo "═══════════════════════════════════════════════════════════════════"
echo "  → Adicionando AWS EKS Charts..."
helm repo add eks https://aws.github.io/eks-charts 2>/dev/null || true
echo "  → Adicionando ArgoCD Charts..."
helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
echo "  → Atualizando índices..."
helm repo update
echo "  ✅ Repositórios Helm configurados"
echo ""

apply_stack "Stack 02 - EKS Cluster + ArgoCD" "02-eks-cluster"

# Configurar kubectl após cluster criado
echo "═══════════════════════════════════════════════════════════════════"
echo "🔧 Configurando kubectl"
echo "═══════════════════════════════════════════════════════════════════"
aws eks update-kubeconfig \
    --name eks-devopsproject-cluster \
    --region us-east-1 \
    --profile $AWS_PROFILE
echo "✅ kubectl configurado"
echo ""

# Aguardar ArgoCD estar pronto
echo "═══════════════════════════════════════════════════════════════════"
echo "⏳ Aguardando ArgoCD estar pronto..."
echo "═══════════════════════════════════════════════════════════════════"
echo "  → Aguardando pods do ArgoCD (pode levar 2-3 minutos)..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=argocd-server \
    -n argocd \
    --timeout=300s 2>/dev/null || echo "  ⚠️  Timeout aguardando ArgoCD (continuando...)"

# Verificar se ArgoCD está rodando
ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)
if [ "$ARGOCD_PODS" -gt 0 ]; then
    echo "  ✅ ArgoCD instalado ($ARGOCD_PODS pods)"
else
    echo "  ⚠️  ArgoCD pode não estar instalado corretamente"
fi
echo ""

# Aplicar ArgoCD Application (GitOps)
echo "═══════════════════════════════════════════════════════════════════"
echo "🚀 Aplicando ArgoCD Application (GitOps)"
echo "═══════════════════════════════════════════════════════════════════"

if [ -f "$PROJECT_ROOT/03-argocd-apps/ecommerce-app.yaml" ]; then
    kubectl apply -f "$PROJECT_ROOT/03-argocd-apps/ecommerce-app.yaml"
    echo "  ✅ Application ArgoCD criada"
    echo ""
    
    # Aguardar sync inicial
    echo "  ⏳ Aguardando ArgoCD sincronizar aplicação (30-60s)..."
    sleep 45
    
    # Verificar status da Application
    APP_STATUS=$(kubectl get application ecommerce-app -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
    APP_HEALTH=$(kubectl get application ecommerce-app -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
    
    echo "  📊 Application Status:"
    echo "     Sync: $APP_STATUS"
    echo "     Health: $APP_HEALTH"
    
    if [ "$APP_STATUS" == "Synced" ] && [ "$APP_HEALTH" == "Healthy" ]; then
        echo "  ✅ Aplicação deployada via GitOps!"
    else
        echo "  ⚠️  Application pode ainda estar sincronizando (verifique ArgoCD UI)"
    fi
else
    echo "  ⚠️  Arquivo 03-argocd-apps/ecommerce-app.yaml não encontrado"
    echo "  ℹ️  Você precisará aplicar a Application manualmente"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           ✅ INFRAESTRUTURA COMPLETA RECRIADA!                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Stacks aplicadas (3 stacks + GitOps):"
echo "  ✅ Stack 00: Backend (S3 + DynamoDB para Terraform State)"
echo "  ✅ Stack 01: Networking (VPC + Subnets + NAT Gateways)"
echo "  ✅ Stack 02: EKS Cluster + ArgoCD + ALB Controller + External DNS"
echo "  ✅ ArgoCD Application (GitOps) - Aplicação E-commerce"
echo ""
echo "🔐 ArgoCD Admin Password:"
cd "$PROJECT_ROOT/02-eks-cluster"
ARGOCD_PASSWORD=$(terraform output -raw argocd_admin_password 2>/dev/null || echo "não disponível")
echo "  User: admin"
echo "  Pass: $ARGOCD_PASSWORD"
echo ""
echo "🌐 URLs de Acesso:"
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "não disponível")
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "aguardando ALB...")

echo "  📦 ArgoCD UI: http://$ARGOCD_URL"
echo "  🛒 Aplicação:  http://$ALB_URL"
echo ""
echo "🔍 Verificar recursos:"
echo "  kubectl get nodes"
echo "  kubectl get pods -n argocd"
echo "  kubectl get pods -n ecommerce"
echo "  kubectl get application -n argocd"
echo ""
echo "🎯 GitOps v1 → v2:"
echo "  1. Editar: 06-ecommerce-app/argocd/overlays/production/kustomization.yaml"
echo "  2. Descomentar 3 seções v2 (recursos + selector + patch)"
echo "  3. git add . && git commit -m 'Deploy v2' && git push"
echo "  4. Aguardar 30-45s (ArgoCD auto-sync)"
echo ""
echo "💰 Custo mensal estimado: ~$120/mês (se mantiver 24/7)"
echo "🗑️  Para destruir tudo: ./scripts/destroy-all.sh"
echo ""
