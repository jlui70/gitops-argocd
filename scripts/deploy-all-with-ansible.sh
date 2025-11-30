#!/bin/bash

# deploy-all-with-ansible.sh
# Script de orquestração completo: Terraform + Ansible
# 
# Uso: ./scripts/deploy-all-with-ansible.sh
#
# Executa:
# 1. Provisiona toda infraestrutura (Terraform)
# 2. Configura Grafana (Ansible)
# 3. Valida cluster (Ansible)

set -e  # Exit on error

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para log
log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo ""
echo "========================================"
echo "🚀 Deploy Completo - Terraform + Ansible"
echo "========================================"
echo ""

# Verificar dependências
log "Verificando dependências..."
command -v terraform >/dev/null 2>&1 || { error "Terraform não instalado"; exit 1; }
command -v ansible-playbook >/dev/null 2>&1 || { error "Ansible não instalado"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { error "kubectl não instalado"; exit 1; }
command -v aws >/dev/null 2>&1 || { error "AWS CLI não instalado"; exit 1; }
success "Todas dependências OK"
echo ""

# Função para executar Terraform em um stack
terraform_apply() {
    local stack=$1
    local description=$2
    
    log "[$stack] $description"
    cd "$stack"
    
    terraform init -upgrade > /dev/null
    terraform apply -auto-approve
    
    cd - > /dev/null
    success "[$stack] Concluído"
    echo ""
}

# ========================================
# FASE 1: TERRAFORM INFRASTRUCTURE
# ========================================
echo ""
echo "========================================="
echo "📦 FASE 1: Provisionando Infraestrutura"
echo "========================================="
echo ""

# Stack 00: Backend
terraform_apply "00-backend" "Criando S3 + DynamoDB para Remote State"

# Stack 01: Networking
terraform_apply "01-networking" "Criando VPC, Subnets, NAT Gateways"

# Stack 02: EKS Cluster
terraform_apply "02-eks-cluster" "Criando EKS Cluster + Node Group"

# Configurar kubectl
log "Configurando kubectl para EKS..."
CLUSTER_NAME="eks-devopsproject-cluster"
REGION="us-east-1"
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION" 2>/dev/null || true
success "kubectl configurado"
echo ""

# Stack 03: Karpenter
terraform_apply "03-karpenter-auto-scaling" "Instalando Karpenter Auto-Scaling"

# Stack 04: Security (WAF)
terraform_apply "04-security" "Configurando WAF"

# Stack 05: Monitoring (Grafana + Prometheus)
terraform_apply "05-monitoring" "Criando Grafana + Prometheus Workspaces"

success "✅ Infraestrutura provisionada com sucesso!"
echo ""

# ========================================
# FASE 2: ANSIBLE CONFIGURATION
# ========================================
echo ""
echo "========================================="
echo "⚙️  FASE 2: Configuração via Ansible"
echo "========================================="
echo ""

cd ansible

# Playbook 1: Configurar Grafana
log "Executando: 01-configure-grafana.yml"
ansible-playbook playbooks/01-configure-grafana.yml
success "Grafana configurado"
echo ""

# Playbook 2: Validar Cluster
log "Executando: 02-validate-cluster.yml"
ansible-playbook playbooks/02-validate-cluster.yml
success "Cluster validado"
echo ""

cd - > /dev/null

# ========================================
# RESUMO FINAL
# ========================================
echo ""
echo "========================================="
echo "✅ DEPLOY COMPLETO!"
echo "========================================="
echo ""

# Obter outputs do Terraform
log "Coletando informações do ambiente..."
cd 05-monitoring
GRAFANA_URL=$(terraform output -raw grafana_workspace_url 2>/dev/null || echo "N/A")
PROMETHEUS_ENDPOINT=$(terraform output -raw prometheus_workspace_endpoint 2>/dev/null || echo "N/A")
cd - > /dev/null

cd 02-eks-cluster
CLUSTER_ENDPOINT=$(terraform output -raw cluster_endpoint 2>/dev/null || echo "N/A")
cd - > /dev/null

echo ""
echo "📊 RECURSOS CRIADOS:"
echo ""
echo "  🌐 Grafana Workspace:"
echo "     $GRAFANA_URL"
echo ""
echo "  📈 Prometheus Workspace:"
echo "     $PROMETHEUS_ENDPOINT"
echo ""
echo "  ☸️  EKS Cluster:"
echo "     $CLUSTER_ENDPOINT"
echo ""
echo "🔍 VALIDAÇÕES:"
kubectl get nodes --no-headers 2>/dev/null | wc -l | xargs -I {} echo "  ✅ Nodes: {} Ready"
kubectl get deployment -n kube-system aws-load-balancer-controller --no-headers 2>/dev/null | awk '{print "  ✅ ALB Controller: " $2 " replicas"}' || echo "  ⚠️  ALB Controller: N/A"
kubectl get pods -n karpenter -l app.kubernetes.io/name=karpenter --no-headers 2>/dev/null | grep Running | wc -l | xargs -I {} echo "  ✅ Karpenter: {} pods running"
echo ""
echo "========================================="
echo "🎉 Ambiente pronto para uso!"
echo "========================================="
echo ""
