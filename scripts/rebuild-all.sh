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

# Criar recursos Kubernetes de teste (opcional)
echo "═══════════════════════════════════════════════════════════════════"
echo "🧪 Recursos de Teste (Opcional)"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
read -p "Criar deployment NGINX de teste? (S/n): " create_test

if [[ ! $create_test =~ ^[Nn]$ ]]; then
    echo "🌐 Criando deployment NGINX + Ingress..."
    
    # Criar deployment e service
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: 80
  selector:
    app: nginx
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: eks-devopsproject-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
    
    echo "⏳ Aguardando ALB ser provisionado (90s)..."
    sleep 90
    echo "✅ Recursos de teste criados"
else
    echo "⏸️  Pulando criação de recursos de teste"
fi
echo ""

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           ✅ INFRAESTRUTURA COMPLETA RECRIADA!                   ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "📊 Stacks aplicadas (3 stacks):"
echo "  ✅ Stack 00: Backend (S3 + DynamoDB para Terraform State)"
echo "  ✅ Stack 01: Networking (VPC + Subnets + NAT Gateways)"
echo "  ✅ Stack 02: EKS Cluster (Kubernetes + ALB Controller + External DNS)"
if [[ ! $create_test =~ ^[Nn]$ ]]; then
echo "  ✅ Recursos de teste (NGINX + Ingress + ALB)"
fi
echo ""
echo "🔍 Verificar recursos:"
echo "  kubectl get nodes"
echo "  kubectl get pods -A"
echo "  kubectl get ingress"
echo ""
if [[ ! $create_test =~ ^[Nn]$ ]]; then
echo "🌐 Obter URL do ALB:"
echo "  kubectl get ingress eks-devopsproject-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
echo "🧪 Testar aplicação:"
echo "  ALB_URL=\$(kubectl get ingress eks-devopsproject-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "  curl http://\$ALB_URL"
echo ""
fi
echo "🛒 Deploy Aplicação E-commerce:"
echo "  cd 06-ecommerce-app"
echo "  ./deploy.sh"
echo ""
echo "💰 Custo mensal estimado: ~$120/mês (se mantiver 24/7)"
echo "🗑️  Para destruir tudo: ./scripts/destroy-all.sh"
echo ""
