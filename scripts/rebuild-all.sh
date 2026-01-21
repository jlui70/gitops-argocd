#!/bin/bash

# Script para recriar toda infraestrutura do zero
# Versão: 4.0 - Simplificada
# Data: 16 de Janeiro de 2026
# Stacks: 00-backend, 01-networking, 02-eks-cluster + 06-ecommerce-app
# Changelog v4.0: Removidas stacks 03 (Karpenter), 04 (WAF), 05 (Monitoring)

set -e  # Para em caso de erro

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🚀 RECRIANDO INFRAESTRUTURA EKS - 3 STACKS                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📋 Ordem: 00-backend → 01-networking → 02-eks-cluster"
echo ""

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Função para aplicar uma stack
apply_stack() {
    local stack_name=$1
    local stack_path=$2
    
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🚀 Aplicando: $stack_name"
    echo "═══════════════════════════════════════════════════════════════════"
    
    cd "$PROJECT_ROOT/$stack_path"
    
    # -reconfigure evita erro "Backend configuration changed" após recriar S3
    terraform init -reconfigure
    terraform apply -auto-approve
    
    echo "✅ $stack_name aplicado com sucesso!"
    echo ""
}

# Ordem correta de criação (00 → 02)
apply_stack "Stack 00 - Backend (S3 + DynamoDB)" "00-backend"

# Aguardar S3 bucket estar disponível antes de continuar
echo "⏳ Aguardando S3 bucket estar disponível para backend remoto (10s)..."
sleep 10
echo ""

apply_stack "Stack 01 - Networking (VPC)" "01-networking"
apply_stack "Stack 02 - EKS Cluster" "02-eks-cluster"

# Configurar kubectl após cluster criado
echo "═══════════════════════════════════════════════════════════════════"
echo "🔧 Configurando kubectl"
echo "═══════════════════════════════════════════════════════════════════"
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1
echo "✅ kubectl configurado"
echo ""

# Configurar aws-auth para GitHub Actions
echo "═══════════════════════════════════════════════════════════════════"
echo "🔐 Configurando acesso GitHub Actions ao cluster"
echo "═══════════════════════════════════════════════════════════════════"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

kubectl get configmap aws-auth -n kube-system -o yaml | grep -q "github-actions-eks" || {
    echo "Adicionando usuário github-actions-eks ao aws-auth..."
    kubectl patch configmap aws-auth -n kube-system --type merge -p "{\"data\":{\"mapUsers\":\"- userarn: arn:aws:iam::${ACCOUNT_ID}:user/github-actions-eks\n  username: github-actions-eks\n  groups:\n  - system:masters\n\"}}"
    echo "✅ Usuário github-actions-eks configurado"
}

echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           ✅ INFRAESTRUTURA COMPLETA RECRIADA!                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Stacks aplicadas (3 stacks):"
echo "  ✅ Stack 00: Backend (S3 + DynamoDB para Terraform State)"
echo "  ✅ Stack 01: Networking (VPC + Subnets + NAT Gateways)"
echo "  ✅ Stack 02: EKS Cluster (Kubernetes + ALB Controller + External DNS)"
echo ""
echo "🔍 Verificar recursos:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo ""
echo "🛒 Deploy Aplicação E-commerce:"
echo "  cd 06-ecommerce-app"
echo "  ./deploy.sh"
echo ""
echo "💰 Custo mensal estimado: ~$120/mês (se mantiver 24/7)"
echo "🗑️  Para destruir tudo: ./scripts/destroy-all.sh"
echo ""
