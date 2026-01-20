#!/bin/bash

# Script de Deploy da Aplicação E-commerce
# EKS DevOps Project - Microservices Demo

echo "🚀 Iniciando deploy da aplicação E-commerce..."
echo "=========================================="

# Verificar se kubectl está configurado
if ! kubectl cluster-info >/dev/null 2>&1; then
    echo "❌ Erro: kubectl não está configurado ou cluster não está acessível"
    echo "Execute: aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1"
    exit 1
fi

echo "✅ Cluster EKS conectado"

# Verificar se já existe aplicação nginx no namespace default
echo ""
echo "📋 Verificando aplicação existente no namespace default..."
EXISTING_NGINX=$(kubectl get deployment nginx-deployment -n default 2>/dev/null || echo "not-found")

if [[ "$EXISTING_NGINX" != "not-found" ]]; then
    echo "⚠️  Encontrada aplicação nginx existente no namespace default"
    echo "   Esta aplicação continuará funcionando normalmente"
    echo "   A nova aplicação e-commerce será implantada no namespace 'ecommerce'"
fi

# Deploy da aplicação e-commerce
echo ""
echo "🛒 Fazendo deploy dos microserviços e-commerce..."

# Aplicar todos os manifestos
echo "   📦 Aplicando manifests..."
kubectl apply -f manifests/ --recursive

# Aguardar namespace ser criado
echo "   ⏳ Aguardando namespace ecommerce ser criado..."
kubectl wait --for=condition=ready namespace/ecommerce --timeout=30s 2>/dev/null || echo "Namespace já existe"

# Aguardar todos os microserviços estarem prontos
echo "   🔧 Aguardando microserviços iniciarem..."
kubectl wait --for=condition=available deployment/product-catalog -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/order-management -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/product-inventory -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/profile-management -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/shipping-and-handling -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/contact-support-team -n ecommerce --timeout=300s

# Aguardar frontend estar pronto
echo "   🎨 Aguardando frontend UI inicializar..."
kubectl wait --for=condition=available deployment/ecommerce-ui -n ecommerce --timeout=300s

# Aguardar ingress ser provisionado
echo "   🌐 Aguardando ALB ser provisionado..."
echo "      (Isso pode levar 2-3 minutos...)"

# Verificar status do ingress
for i in {1..12}; do
    INGRESS_ADDRESS=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
    if [[ -n "$INGRESS_ADDRESS" ]]; then
        echo "   ✅ ALB provisionado: $INGRESS_ADDRESS"
        break
    fi
    echo "      Tentativa $i/12: Aguardando ALB..."
    sleep 15
done

# Mostrar status final
echo ""
echo "📊 Status Final:"
echo "================"

echo ""
echo "🎯 Pods da aplicação:"
kubectl get pods -n ecommerce

echo ""
echo "🔗 Services:"
kubectl get svc -n ecommerce

echo ""
echo "🌐 Ingress:"
kubectl get ingress -n ecommerce

# Obter informações de acesso
INGRESS_ADDRESS=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

echo ""
echo "🎉 Deploy Concluído!"
echo "===================="
echo ""
echo "URLs de Acesso:"
echo "  🎯 DNS Personalizado: http://eks.devopsproject.com.br"
if [[ -n "$INGRESS_ADDRESS" ]]; then
    echo "  🔧 ALB Direto: http://$INGRESS_ADDRESS"
fi
echo ""
echo "🔍 Comandos Úteis:"
echo "  kubectl get all -n ecommerce"
echo "  kubectl logs -f deployment/ecommerce-ui -n ecommerce"
echo "  kubectl port-forward svc/ecommerce-ui 8080:80 -n ecommerce"
echo ""

# Teste de conectividade
if [[ -n "$INGRESS_ADDRESS" ]]; then
    echo "🧪 Testando conectividade..."
    sleep 30  # Aguardar ALB estar totalmente pronto
    
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$INGRESS_ADDRESS" || echo "000")
    if [[ "$HTTP_STATUS" == "200" ]]; then
        echo "   ✅ Aplicação respondendo (HTTP $HTTP_STATUS)"
    else
        echo "   ⚠️  Aguarde mais alguns minutos para ALB estar totalmente pronto"
        echo "      Status atual: HTTP $HTTP_STATUS"
    fi
fi

echo ""
echo "🛒 Aplicação E-commerce pronta para demonstrações!"
echo "   Acesse: http://eks.devopsproject.com.br"
echo ""