#!/bin/bash
# Setup ArgoCD Applications

set -e

echo "🚀 Configurando ArgoCD Applications..."
echo ""

# Aguardar ArgoCD estar pronto
echo "⏳ Aguardando ArgoCD estar disponível..."
kubectl wait --for=condition=available \
  deployment/argocd-server -n argocd --timeout=300s

echo "✅ ArgoCD pronto!"
echo ""

# Aplicar Application CRD
echo "📦 Criando Application 'ecommerce-app'..."
kubectl apply -f /home/luiz7/lab-argo/gitops-eks/03-argocd-apps/ecommerce-app.yaml

echo ""
echo "✅ ArgoCD Application criada com sucesso!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Verificar status:"
echo "   kubectl get applications -n argocd"
echo ""
echo "🌐 Acessar ArgoCD UI:"
ALB=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "   http://$ALB"
echo ""
echo "🔐 Credentials:"
echo "   User: admin"
PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "   Password: $PASS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
