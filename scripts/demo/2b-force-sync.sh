#!/bin/bash
# Demo Script 2b: Force ArgoCD Sync (for demo speed)

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ Force ArgoCD Sync (Fast Demo)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Deleting and recreating Application to force immediate sync..."
kubectl delete application ecommerce-app -n argocd
sleep 5
kubectl apply -f /home/luiz7/lab-argo/gitops-eks/03-argocd-apps/ecommerce-app.yaml
echo ""

echo "⏳ Waiting for v2 pods to be created..."
sleep 15
echo ""

echo "📊 Pods status:"
kubectl get pods -n ecommerce -L version | grep ecommerce-ui
echo ""

echo "✅ Done! Check application for v2 banner"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
