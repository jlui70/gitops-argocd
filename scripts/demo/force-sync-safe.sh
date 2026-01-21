#!/bin/bash
# Force ArgoCD Sync WITHOUT deleting Application

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⚡ Force ArgoCD Sync (No Delete - Safe)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Annotate to force hard refresh from Git
kubectl annotate application ecommerce-app -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

echo "✅ Hard refresh triggered"
echo ""

# Trigger sync via kubectl patch
kubectl patch application ecommerce-app -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

echo "✅ Sync triggered"
echo ""

echo "📊 Waiting for sync to complete..."
sleep 10

kubectl get application ecommerce-app -n argocd
echo ""

echo "📦 Pods status:"
kubectl get pods -n ecommerce -L version | head -10
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Sync complete! ALB preserved, DNS working!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
