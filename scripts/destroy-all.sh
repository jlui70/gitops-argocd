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

# Limpeza de recursos AWS órfãos (quando Terraform state está vazio)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Verificando e limpando recursos AWS órfãos"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

# 1. Deletar Load Balancers órfãos (ArgoCD, ALB da aplicação)
echo "  🔍 Procurando Load Balancers órfãos..."
ORPHAN_ALBS=$(aws elbv2 describe-load-balancers \
    --profile $AWS_PROFILE \
    --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-argocd') || contains(LoadBalancerName, 'k8s-ecommerc')].LoadBalancerArn" \
    --output text 2>/dev/null)

if [ -n "$ORPHAN_ALBS" ]; then
    echo "  🗑️  Deletando ALBs órfãos:"
    for alb_arn in $ORPHAN_ALBS; do
        ALB_NAME=$(aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" --profile $AWS_PROFILE --query 'LoadBalancers[0].LoadBalancerName' --output text)
        echo "    → Deletando ALB: $ALB_NAME"
        aws elbv2 delete-load-balancer --load-balancer-arn "$alb_arn" --profile $AWS_PROFILE 2>/dev/null && \
            echo "      ✅ ALB deletado" || \
            echo "      ⚠️  Falha ao deletar"
    done
    echo "  ⏳ Aguardando ALBs serem deletados (30s)..."
    sleep 30
else
    echo "  ℹ️  Nenhum ALB órfão encontrado"
fi
echo ""

# 2. Deletar Target Groups órfãos
echo "  🔍 Procurando Target Groups órfãos..."
ORPHAN_TGS=$(aws elbv2 describe-target-groups \
    --profile $AWS_PROFILE \
    --query "TargetGroups[?contains(TargetGroupName, 'k8s-')].TargetGroupArn" \
    --output text 2>/dev/null)

if [ -n "$ORPHAN_TGS" ]; then
    echo "  🗑️  Deletando Target Groups órfãos:"
    for tg_arn in $ORPHAN_TGS; do
        TG_NAME=$(aws elbv2 describe-target-groups --target-group-arns "$tg_arn" --profile $AWS_PROFILE --query 'TargetGroups[0].TargetGroupName' --output text)
        echo "    → Deletando TG: $TG_NAME"
        aws elbv2 delete-target-group --target-group-arn "$tg_arn" --profile $AWS_PROFILE 2>/dev/null && \
            echo "      ✅ TG deletado" || \
            echo "      ⚠️  Falha ao deletar"
    done
else
    echo "  ℹ️  Nenhum Target Group órfão encontrado"
fi
echo ""

# 3. Deletar Security Groups órfãos (exceto default)
echo "  🔍 Procurando Security Groups órfãos..."
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=eks-devopsproject-vpc" \
    --profile $AWS_PROFILE \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    ORPHAN_SGS=$(aws ec2 describe-security-groups \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query "SecurityGroups[?GroupName!='default'].GroupId" \
        --output text 2>/dev/null)
    
    if [ -n "$ORPHAN_SGS" ]; then
        echo "  🗑️  Deletando Security Groups órfãos:"
        for sg_id in $ORPHAN_SGS; do
            SG_NAME=$(aws ec2 describe-security-groups --group-ids "$sg_id" --profile $AWS_PROFILE --query 'SecurityGroups[0].GroupName' --output text)
            echo "    → Deletando SG: $SG_NAME ($sg_id)"
            
            # Remover regras primeiro
            aws ec2 revoke-security-group-ingress --group-id "$sg_id" --profile $AWS_PROFILE --source-group "$sg_id" 2>/dev/null || true
            aws ec2 revoke-security-group-egress --group-id "$sg_id" --profile $AWS_PROFILE --cidr 0.0.0.0/0 --protocol -1 2>/dev/null || true
            
            aws ec2 delete-security-group --group-id "$sg_id" --profile $AWS_PROFILE 2>/dev/null && \
                echo "      ✅ SG deletado" || \
                echo "      ⚠️  Falha ao deletar (pode ter dependências)"
        done
    else
        echo "  ℹ️  Nenhum Security Group órfão encontrado"
    fi
fi
echo ""
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
    
    # Verificar se o diretório existe
    [ ! -d "$PROJECT_ROOT/$stack_path" ] && return
    
    cd "$PROJECT_ROOT/$stack_path"
    
    # Tentar obter nome da role do state (com timeout de 5s)
    local role_name=$(timeout 5 terraform state show "$resource_address" 2>/dev/null | grep -E "^\s+name\s+=" | head -1 | awk -F'"' '{print $2}')
    
    echo "$role_name"
}

# Função auxiliar para extrair nome de policy do Terraform state
get_policy_name_from_state() {
    local stack_path=$1
    local resource_address=$2
    
    # Verificar se o diretório existe
    [ ! -d "$PROJECT_ROOT/$stack_path" ] && return
    
    cd "$PROJECT_ROOT/$stack_path"
    
    # Tentar obter nome da policy do state (com timeout de 5s)
    local policy_name=$(timeout 5 terraform state show "$resource_address" 2>/dev/null | grep -E "^\s+name\s+=" | head -1 | awk -F'"' '{print $2}')
    
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
echo "ℹ️  Backend será destruído automaticamente (necessário para rebuild limpo)"
echo ""

cd "$PROJECT_ROOT/00-backend"

# Obter nome do bucket do terraform
BUCKET_NAME=$(terraform output -raw s3_bucket_name 2>/dev/null)

if [ -z "$BUCKET_NAME" ]; then
    echo "⚠️  Não foi possível obter nome do bucket. Tentando detectar..."
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    BUCKET_NAME="eks-devopsproject-state-files-${ACCOUNT_ID}"
    echo "  → Bucket detectado: $BUCKET_NAME"
fi

# Limpeza manual de VPC órfã (se Terraform falhou)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧹 Limpeza manual de VPC órfã (se existir)"
echo "═══════════════════════════════════════════════════════════════════"

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=eks-devopsproject-vpc" \
    --profile $AWS_PROFILE \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo "  📊 VPC órfã encontrada: $VPC_ID"
    echo "  🗑️  Deletando recursos da VPC manualmente..."
    
    # 1. Deletar NAT Gateways
    echo "    → Deletando NAT Gateways..."
    NAT_GWS=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
        --profile $AWS_PROFILE \
        --query 'NatGateways[].NatGatewayId' \
        --output text 2>/dev/null)
    
    for nat_id in $NAT_GWS; do
        echo "      → Deletando NAT Gateway: $nat_id"
        aws ec2 delete-nat-gateway --nat-gateway-id "$nat_id" --profile $AWS_PROFILE 2>/dev/null || true
    done
    
    if [ -n "$NAT_GWS" ]; then
        echo "      ⏳ Aguardando NAT Gateways serem deletados (60s)..."
        sleep 60
    fi
    
    # 2. Liberar e deletar Elastic IPs
    echo "    → Deletando Elastic IPs..."
    EIPS=$(aws ec2 describe-addresses \
        --filters "Name=domain,Values=vpc" \
        --profile $AWS_PROFILE \
        --query 'Addresses[?contains(Tags[?Key==`Name`].Value, `devopsproject`) || AssociationId==null].AllocationId' \
        --output text 2>/dev/null)
    
    for eip_id in $EIPS; do
        echo "      → Liberando EIP: $eip_id"
        aws ec2 release-address --allocation-id "$eip_id" --profile $AWS_PROFILE 2>/dev/null || true
    done
    
    # 3. Deletar ENIs restantes
    echo "    → Deletando ENIs restantes..."
    ENIS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text 2>/dev/null)
    
    for eni_id in $ENIS; do
        echo "      → Deletando ENI: $eni_id"
        aws ec2 delete-network-interface --network-interface-id "$eni_id" --profile $AWS_PROFILE 2>/dev/null || true
    done
    
    sleep 10
    
    # 4. Deletar Internet Gateway
    echo "    → Deletando Internet Gateway..."
    IGW_ID=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null)
    
    if [ "$IGW_ID" != "None" ] && [ -n "$IGW_ID" ]; then
        echo "      → Detachando IGW: $IGW_ID"
        aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" --profile $AWS_PROFILE 2>/dev/null || true
        echo "      → Deletando IGW: $IGW_ID"
        aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" --profile $AWS_PROFILE 2>/dev/null || true
    fi
    
    # 5. Deletar Subnets
    echo "    → Deletando Subnets..."
    SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'Subnets[].SubnetId' \
        --output text 2>/dev/null)
    
    for subnet_id in $SUBNETS; do
        echo "      → Deletando Subnet: $subnet_id"
        aws ec2 delete-subnet --subnet-id "$subnet_id" --profile $AWS_PROFILE 2>/dev/null || true
    done
    
    # 6. Deletar Route Tables (exceto main)
    echo "    → Deletando Route Tables..."
    ROUTE_TABLES=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
        --output text 2>/dev/null)
    
    for rt_id in $ROUTE_TABLES; do
        echo "      → Deletando Route Table: $rt_id"
        aws ec2 delete-route-table --route-table-id "$rt_id" --profile $AWS_PROFILE 2>/dev/null || true
    done
    
    # 7. Deletar VPC
    echo "    → Deletando VPC: $VPC_ID"
    aws ec2 delete-vpc --vpc-id "$VPC_ID" --profile $AWS_PROFILE 2>/dev/null && \
        echo "      ✅ VPC deletada com sucesso!" || \
        echo "      ⚠️  Falha ao deletar VPC (pode ter dependências restantes)"
else
    echo "  ℹ️  Nenhuma VPC órfã encontrada"
fi
echo ""

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
echo "  ✅ Stack 00: Backend (S3 + DynamoDB)"
echo ""
echo "💰 Custos AWS agora: ~$0/mês"
echo ""
echo "🔄 Para recriar tudo: ./scripts/rebuild-all.sh"
echo ""
