#!/bin/bash

# Script para destruir todos os recursos na ordem correta
# Versão: 5.0 - ArgoCD GitOps
# Data: 22 de Janeiro de 2026
# Stacks: 00-backend, 01-networking, 02-eks-cluster (com ArgoCD)
# Changelog v5.0: Adaptado para ArgoCD GitOps (deleta Application ArgoCD primeiro)

set -e  # Para em caso de erro

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🗑️  DESTRUINDO INFRAESTRUTURA EKS + ARGOCD - 3 STACKS      ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

# PROJECT_ROOT deve apontar para o diretório raiz do projeto (gitops-argocd/), não scripts/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# AWS Profile usado (ajuste se necessário)
AWS_PROFILE="devopsproject"

# Função para destruir uma stack
destroy_stack() {
    local stack_name=$1
    local stack_path=$2
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🗑️  Destruindo: $stack_name"
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT/$stack_path"
    
    if [ -f "terraform.tfstate" ] || terraform state list &>/dev/null; then
        terraform destroy -auto-approve || {
            echo "⚠️  Erro ao destruir $stack_name, tentando remover state órfão..."
            terraform state list 2>/dev/null | while read resource; do
                terraform state rm "$resource" 2>/dev/null || true
            done
            echo "✅ $stack_name limpo (recursos já removidos)"
        }
        echo "✅ $stack_name destruído com sucesso!"
    else
        echo "⚠️  $stack_name: Nenhum recurso para destruir"
    fi
    
    echo ""
}

# IMPORTANTE: Primeiro deletar recursos Kubernetes que criam recursos AWS
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 PASSO 0: Deletando ArgoCD Application (GitOps)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Verificar se kubectl consegue acessar o cluster
if kubectl cluster-info &>/dev/null; then
    echo "  ✅ Cluster acessível via kubectl"
    
    # Deletar Application ArgoCD (ArgoCD vai remover todos os recursos do Git)
    if kubectl get application ecommerce-app -n argocd &>/dev/null 2>&1; then
        echo "  🗑️  Deletando ArgoCD Application: ecommerce-app"
        kubectl delete application ecommerce-app -n argocd --timeout=120s 2>/dev/null || true
        echo "  ⏳ Aguardando ArgoCD remover recursos (ALB, Services, Pods)... (60s)"
        sleep 60
        echo "  ✅ Application ArgoCD deletada"
    else
        echo "  ℹ️  Application ArgoCD não encontrada (já deletada ou nunca criada)"
    fi
    
    # Verificar e deletar namespace ecommerce se ainda existir
    if kubectl get namespace ecommerce &>/dev/null 2>&1; then
        echo "  🗑️  Deletando namespace ecommerce (forçando se necessário)..."
        kubectl delete namespace ecommerce --timeout=90s 2>/dev/null || true
        echo "  ⏳ Aguardando finalização... (30s)"
        sleep 30
    fi
    
    echo "  ✅ Recursos GitOps removidos"
else
    echo "  ⚠️  Cluster inaccessível via kubectl (pode já ter sido destruído)"
    echo "  ℹ️  Prosseguindo com destroy do Terraform"
fi
echo ""

echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 PASSO 1: Limpando recursos CI/CD (ECR + IAM)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# Deletar ECR repositories (criados manualmente para CI/CD - se existirem)
echo "🗑️  Deletando ECR repositories (se existirem)..."
ECR_REPOS=(
    "ecommerce/ecommerce-ui"
    "ecommerce/product-catalog"
    "ecommerce/order-management"
    "ecommerce/product-inventory"
    "ecommerce/profile-management"
    "ecommerce/shipping-and-handling"
    "ecommerce/contact-support-team"
)

for repo in "${ECR_REPOS[@]}"; do
    if aws ecr describe-repositories --repository-names "$repo" --region us-east-1 --profile $AWS_PROFILE &>/dev/null; then
        echo "  🗑️  Deletando ECR repo: $repo"
        aws ecr delete-repository --repository-name "$repo" --region us-east-1 --force --profile $AWS_PROFILE 2>/dev/null && \
            echo "    ✅ $repo deletado" || \
            echo "    ⚠️  Erro ao deletar $repo"
    fi
done

# Deletar IAM user github-actions-eks (se existir)
echo ""
echo "🗑️  Deletando IAM user github-actions-eks (se existir)..."
if aws iam get-user --user-name github-actions-eks --profile $AWS_PROFILE &>/dev/null; then
    # Delete access keys
    ACCESS_KEYS=$(aws iam list-access-keys --user-name github-actions-eks --profile $AWS_PROFILE --query 'AccessKeyMetadata[].AccessKeyId' --output text 2>/dev/null)
    for key in $ACCESS_KEYS; do
        echo "  → Deletando access key: $key"
        aws iam delete-access-key --user-name github-actions-eks --access-key-id "$key" --profile $AWS_PROFILE 2>/dev/null || true
    done
    
    # Detach managed policies
    ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name github-actions-eks --profile $AWS_PROFILE --query 'AttachedPolicies[].PolicyArn' --output text 2>/dev/null)
    for policy_arn in $ATTACHED_POLICIES; do
        echo "  → Detaching policy: $(basename $policy_arn)"
        aws iam detach-user-policy --user-name github-actions-eks --policy-arn "$policy_arn" --profile $AWS_PROFILE 2>/dev/null || true
    done
    
    # Delete inline policies
    INLINE_POLICIES=$(aws iam list-user-policies --user-name github-actions-eks --profile $AWS_PROFILE --query 'PolicyNames' --output text 2>/dev/null)
    for policy_name in $INLINE_POLICIES; do
        echo "  → Deletando inline policy: $policy_name"
        aws iam delete-user-policy --user-name github-actions-eks --policy-name "$policy_name" --profile $AWS_PROFILE 2>/dev/null || true
    done
    
    # Delete user
    aws iam delete-user --user-name github-actions-eks --profile $AWS_PROFILE 2>/dev/null && \
        echo "  ✅ IAM user github-actions-eks deletado" || \
        echo "  ⚠️  Erro ao deletar IAM user"
else
    echo "  ℹ️  IAM user github-actions-eks não encontrado"
fi
echo ""

# Ordem correta de destruição (REVERSA da criação: 02 → 00)
echo "📋 Ordem de destruição: 02-eks-cluster → 01-networking → 00-backend"
echo ""

# Stack 02: Remover helm releases do state (ArgoCD + ALB Controller + External DNS)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Stack 02: Limpando state de helm releases órfãos..."
echo "═══════════════════════════════════════════════════════════════════"
cd "$PROJECT_ROOT/02-eks-cluster"
terraform state rm helm_release.argocd 2>/dev/null && echo "  ✅ ArgoCD helm release removido do state" || echo "  ℹ️  ArgoCD já removido ou não existe"
terraform state rm helm_release.load_balancer_controller 2>/dev/null && echo "  ✅ ALB Controller helm release removido do state" || echo "  ℹ️  ALB Controller já removido ou não existe"
terraform state rm helm_release.external_dns 2>/dev/null && echo "  ✅ External DNS helm release removido do state" || echo "  ℹ️  External DNS já removido ou não existe"
terraform state rm helm_release.metrics_server 2>/dev/null && echo "  ✅ Metrics Server helm release removido do state" || echo "  ℹ️  Metrics Server já removido ou não existe"
echo ""

destroy_stack "Stack 02 - EKS Cluster" "02-eks-cluster"

# IMPORTANTE: Limpar IAM roles/policies órfãs que o Terraform pode não ter deletado
# Isso evita erro "EntityAlreadyExists" em reinstalações
# VERSÃO DINÂMICA v3.2: Lê nomes reais do Terraform state (funciona mesmo se usuário alterar variables.tf)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Limpando IAM Roles/Policies órfãs (prevenção de conflitos)..."
echo "═══════════════════════════════════════════════════════════════════"

# Função auxiliar para deletar role IAM (detach policies primeiro)
delete_iam_role() {
    local role_name=$1
    
    if [ -z "$role_name" ]; then
        return 0
    fi
    
    if aws iam get-role --role-name "$role_name" --profile $AWS_PROFILE &>/dev/null; then
        echo "  🗑️  Deletando role: $role_name"
        
        # Detach managed policies
        ATTACHED_POLICIES=$(aws iam list-attached-role-policies \
            --role-name "$role_name" \
            --profile $AWS_PROFILE \
            --query 'AttachedPolicies[].PolicyArn' \
            --output text 2>/dev/null || echo "")
        
        for policy_arn in $ATTACHED_POLICIES; do
            aws iam detach-role-policy \
                --role-name "$role_name" \
                --policy-arn "$policy_arn" \
                --profile $AWS_PROFILE 2>/dev/null || true
        done
        
        # Delete inline policies
        INLINE_POLICIES=$(aws iam list-role-policies \
            --role-name "$role_name" \
            --profile $AWS_PROFILE \
            --query 'PolicyNames' \
            --output text 2>/dev/null || echo "")
        
        for policy_name in $INLINE_POLICIES; do
            aws iam delete-role-policy \
                --role-name "$role_name" \
                --policy-name "$policy_name" \
                --profile $AWS_PROFILE 2>/dev/null || true
        done
        
        # Remove from instance profiles AND delete the profiles
        INSTANCE_PROFILES=$(aws iam list-instance-profiles-for-role \
            --role-name "$role_name" \
            --profile $AWS_PROFILE \
            --query 'InstanceProfiles[].InstanceProfileName' \
            --output text 2>/dev/null || echo "")
        
        for profile_name in $INSTANCE_PROFILES; do
            echo "    → Removendo role do instance profile: $profile_name"
            aws iam remove-role-from-instance-profile \
                --instance-profile-name "$profile_name" \
                --role-name "$role_name" \
                --profile $AWS_PROFILE 2>/dev/null || true
            
            # Deletar o instance profile (órfão criado pelo EKS)
            echo "    → Deletando instance profile órfão: $profile_name"
            aws iam delete-instance-profile \
                --instance-profile-name "$profile_name" \
                --profile $AWS_PROFILE 2>/dev/null || true
        done
        
        # Delete role
        aws iam delete-role --role-name "$role_name" --profile $AWS_PROFILE 2>/dev/null && \
            echo "    ✅ Role $role_name deletada" || \
            echo "    ⚠️  Role $role_name não pôde ser deletada"
    fi
}

# Função auxiliar para extrair nome de role do Terraform state
get_role_name_from_state() {
    local stack_path=$1
    local resource_address=$2
    
    cd "$PROJECT_ROOT/$stack_path"
    
    # Tentar obter nome da role do state
    local role_name=$(terraform state show "$resource_address" 2>/dev/null | grep -E "^\s+name\s+=" | head -1 | awk -F'"' '{print $2}')
    
    echo "$role_name"
}

# Função auxiliar para extrair nome de policy do Terraform state
get_policy_name_from_state() {
    local stack_path=$1
    local resource_address=$2
    
    cd "$PROJECT_ROOT/$stack_path"
    
    # Tentar obter nome da policy do state
    local policy_name=$(terraform state show "$resource_address" 2>/dev/null | grep -E "^\s+name\s+=" | head -1 | awk -F'"' '{print $2}')
    
    echo "$policy_name"
}

# Obter account ID dinamicamente
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE 2>/dev/null || echo "")

if [ -z "$ACCOUNT_ID" ]; then
    echo "  ⚠️  Não foi possível obter Account ID, pulando limpeza de IAM"
else
    echo "  📊 Account ID: $ACCOUNT_ID"
    echo "  🔍 Lendo nomes reais das roles do Terraform state..."
    echo ""
    
    # ======================================================================
    # STACK 02 - EKS CLUSTER ROLES (lendo dinamicamente do state)
    # ======================================================================
    echo "  🗂️  Stack 02 - EKS Cluster"
    
    ROLE_CSI=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.container_storage_interface")
    ROLE_ALB=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.load_balancer_controller")
    ROLE_NODE=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.eks_cluster_node_group")
    ROLE_CLUSTER=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.eks_cluster")
    ROLE_DNS=$(get_role_name_from_state "02-eks-cluster" "aws_iam_role.external_dns")
    
    POLICY_ALB=$(get_policy_name_from_state "02-eks-cluster" "aws_iam_policy.load_balancer_controller")
    
    [ -n "$ROLE_CSI" ] && delete_iam_role "$ROLE_CSI" || delete_iam_role "AmazonEKS_EFS_CSI_DriverRole"
    [ -n "$ROLE_ALB" ] && delete_iam_role "$ROLE_ALB" || delete_iam_role "aws-load-balancer-controller"
    [ -n "$ROLE_NODE" ] && delete_iam_role "$ROLE_NODE" || delete_iam_role "eks-devopsproject-node-group-role"
    [ -n "$ROLE_CLUSTER" ] && delete_iam_role "$ROLE_CLUSTER" || delete_iam_role "eks-devopsproject-cluster-role"
    [ -n "$ROLE_DNS" ] && delete_iam_role "$ROLE_DNS" || delete_iam_role "external-dns-irsa-role"
    
    # Deletar policy ALB Controller
    if [ -n "$POLICY_ALB" ]; then
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_ALB}"
    else
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy"
    fi
    
    if aws iam get-policy --policy-arn "$POLICY_ARN" --profile $AWS_PROFILE &>/dev/null; then
        echo "  🗑️  Deletando policy: $(basename $POLICY_ARN)"
        aws iam delete-policy --policy-arn "$POLICY_ARN" --profile $AWS_PROFILE 2>/dev/null && \
            echo "    ✅ Policy deletada" || \
            echo "    ⚠️  Policy não pôde ser deletada (pode estar attached)"
    fi
    echo ""
    
    # ======================================================================
    # STACK 03 - KARPENTER ROLES (lendo dinamicamente do state)
    # ======================================================================
    echo "  🗂️  Stack 03 - Karpenter"
    
    ROLE_KARPENTER=$(get_role_name_from_state "03-karpenter-auto-scaling" "aws_iam_role.karpenter_controller")
    POLICY_KARPENTER=$(get_policy_name_from_state "03-karpenter-auto-scaling" "aws_iam_policy.karpenter_controller")
    
    [ -n "$ROLE_KARPENTER" ] && delete_iam_role "$ROLE_KARPENTER" || delete_iam_role "KarpenterControllerRole"
    
    # Deletar policy Karpenter
    if [ -n "$POLICY_KARPENTER" ]; then
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_KARPENTER}"
    else
        POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/KarpenterControllerPolicy"
    fi
    
    if aws iam get-policy --policy-arn "$POLICY_ARN" --profile $AWS_PROFILE &>/dev/null; then
        echo "  🗑️  Deletando policy: $(basename $POLICY_ARN)"
        aws iam delete-policy --policy-arn "$POLICY_ARN" --profile $AWS_PROFILE 2>/dev/null && \
            echo "    ✅ Policy deletada" || \
            echo "    ⚠️  Policy não pôde ser deletada"
    fi
    echo ""
    
    # ======================================================================
    # STACK 05 - MONITORING ROLES (lendo dinamicamente do state)
    # ======================================================================
    echo "  🗂️  Stack 05 - Monitoring"
    
    ROLE_GRAFANA=$(get_role_name_from_state "05-monitoring" "aws_iam_role.grafana")
    
    [ -n "$ROLE_GRAFANA" ] && delete_iam_role "$ROLE_GRAFANA" || delete_iam_role "GrafanaWorkspaceRole"
    echo ""
    
    echo "  ✅ Limpeza de IAM concluída (modo dinâmico v3.2)"
fi
echo ""

# Limpeza de ENIs órfãas (ALB) antes de destruir VPC
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Limpando ENIs órfãas (ALB) antes de destruir VPC"
echo "═══════════════════════════════════════════════════════════════════"

# Obter VPC ID do Terraform state
cd "$PROJECT_ROOT/01-networking"
VPC_ID=$(terraform state show aws_vpc.this 2>/dev/null | grep -E "^\s+id\s+=" | awk -F'"' '{print $2}')

if [ -n "$VPC_ID" ]; then
    echo "  📊 VPC ID: $VPC_ID"
    echo "  🔍 Procurando ENIs órfãas..."
    
    # Listar ENIs na VPC que:
    # 1. Estão disponíveis (não attached) OU
    # 2. Foram criadas pelo ELB (ALB Controller)
    ORPHAN_ENIS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'NetworkInterfaces[?Status==`available` || contains(Description, `ELB`) || contains(RequesterId, `amazon-elb`)].NetworkInterfaceId' \
        --output text 2>/dev/null)
    
    if [ -n "$ORPHAN_ENIS" ]; then
        echo "  🗑️  Deletando ENIs órfãas:"
        for eni_id in $ORPHAN_ENIS; do
            echo "    → Deletando ENI: $eni_id"
            aws ec2 delete-network-interface \
                --network-interface-id "$eni_id" \
                --profile $AWS_PROFILE 2>/dev/null && \
                echo "      ✅ ENI deletada" || \
                echo "      ⚠️  Falha ao deletar (pode estar em uso)"
        done
        echo "  ⏳ Aguardando propagação (10s)..."
        sleep 10
    else
        echo "  ℹ️  Nenhuma ENI órfã encontrada"
    fi
else
    echo "  ⚠️  VPC ID não encontrado no state (VPC já foi destruída?)"
fi
echo ""
destroy_stack "Stack 01 - Networking (VPC)" "01-networking"

# Backend por último
echo "═══════════════════════════════════════════════════════════════════"
echo "🗑️  Destruindo: Stack 00 - Backend (S3 + DynamoDB)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
read -p "⚠️  Destruir backend também? Isso removerá o state remoto! (s/N): " destroy_backend

if [[ $destroy_backend =~ ^[Ss]$ ]]; then
    cd "$PROJECT_ROOT/00-backend"
    
    # Obter nome do bucket do terraform
    BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)
    
    if [ -z "$BUCKET_NAME" ]; then
        echo "⚠️  Não foi possível obter nome do bucket. Tentando detectar..."
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
        BUCKET_NAME="eks-devopsproject-state-files-${ACCOUNT_ID}"
        echo "  → Bucket detectado: $BUCKET_NAME"
    fi
    
    echo "🧹 Esvaziando bucket S3: $BUCKET_NAME"
    
    # Verificar se bucket existe antes de tentar esvaziar
    if aws s3 ls "s3://$BUCKET_NAME" --profile $AWS_PROFILE &>/dev/null; then
        echo "  → Removendo todos os objetos e versões do bucket..."
        
        # Método 1: Usar aws s3 rm com --recursive (mais simples e confiável)
        aws s3 rm "s3://$BUCKET_NAME" --recursive --profile $AWS_PROFILE 2>/dev/null || true
        
        # Método 2: Deletar versões antigas (versionamento habilitado)
        echo "  → Verificando versões antigas..."
        VERSIONS=$(aws s3api list-object-versions \
            --bucket "$BUCKET_NAME" \
            --profile $AWS_PROFILE \
            --output json \
            --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' 2>/dev/null)
        
        if [ "$VERSIONS" != "null" ] && [ "$VERSIONS" != "" ] && [ "$VERSIONS" != "{}" ]; then
            echo "  → Removendo versões de objetos..."
            aws s3api delete-objects \
                --bucket "$BUCKET_NAME" \
                --profile $AWS_PROFILE \
                --delete "$VERSIONS" 2>/dev/null || true
        fi
        
        # Método 3: Deletar delete markers
        echo "  → Verificando delete markers..."
        MARKERS=$(aws s3api list-object-versions \
            --bucket "$BUCKET_NAME" \
            --profile $AWS_PROFILE \
            --output json \
            --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' 2>/dev/null)
        
        if [ "$MARKERS" != "null" ] && [ "$MARKERS" != "" ] && [ "$MARKERS" != "{}" ]; then
            echo "  → Removendo delete markers..."
            aws s3api delete-objects \
                --bucket "$BUCKET_NAME" \
                --profile $AWS_PROFILE \
                --delete "$MARKERS" 2>/dev/null || true
        fi
        
        echo "  ✅ Bucket esvaziado completamente"
    else
        echo "  ℹ️  Bucket não encontrado ou já foi deletado"
    fi
    echo ""
    
    # Agora destruir o backend (com force_destroy = true, mesmo se houver objetos restantes)
    terraform destroy -auto-approve
    echo "✅ Stack 00 - Backend destruído"
else
    echo "⏸️  Stack 00 - Backend preservado (state remoto mantido)"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ DESTRUIÇÃO COMPLETA!                            ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Recursos destruídos:"
echo "  ✅ ECR Repositories (7 repos)"
echo "  ✅ IAM user github-actions-eks"
echo "  ✅ Namespace ecommerce + ALB (via kubectl)"
echo "  ✅ Namespace sample-app (se existia)"
echo "  ✅ Stack 02: EKS Cluster + Node Group + ALB Controller + External DNS"
echo "  ✅ Stack 01: VPC + Subnets + NAT Gateways + EIPs"
if [[ $destroy_backend =~ ^[Ss]$ ]]; then
echo "  ✅ Stack 00: Backend (S3 + DynamoDB)"
else
echo "  ⏸️  Stack 00: Backend preservado"
fi
echo ""
echo "💰 Custos AWS agora: ~$0/mês"
if [[ ! $destroy_backend =~ ^[Ss]$ ]]; then
echo "   (S3 + DynamoDB do backend: <$1/mês)"
fi
echo ""
echo "🔄 Para recriar tudo: ./scripts/rebuild-all.sh"
echo ""
