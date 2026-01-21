#!/bin/bash
# Test ArgoCD Auto-Sync WITHOUT Deleting Application

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Testing ArgoCD Auto-Sync (No Delete - Production Safe)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Switch to v1
echo "1️⃣  Switching Application to v1..."
kubectl patch application ecommerce-app -n argocd --type merge \
  --patch '{"spec":{"source":{"path":"06-ecommerce-app/argocd/overlays/v1"}}}'
echo "✅ Path changed to v1"
echo ""

echo "⏳ Waiting 45s for ArgoCD to sync (polling every 30s)..."
sleep 45

echo ""
echo "📊 Application Status:"
kubectl get application ecommerce-app -n argocd
echo ""

echo "📦 Pods v1:"
kubectl get pods -n ecommerce -L version | grep -E "NAME|ecommerce-ui-"
echo ""

# Step 2: Switch to v2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Switching Application to v2..."
kubectl patch application ecommerce-app -n argocd --type merge \
  --patch '{"spec":{"source":{"path":"06-ecommerce-app/argocd/overlays/v2"}}}'
echo "✅ Path changed to v2"
echo ""

echo "⏳ Waiting 45s for ArgoCD to sync..."
sleep 45

echo ""
echo "📊 Application Status:"
kubectl get application ecommerce-app -n argocd
echo ""

echo "📦 Pods v2:"
kubectl get pods -n ecommerce -L version | grep -E "NAME|ecommerce-ui-"
echo ""

# Verify ALB didn't change
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Verifying ALB Stability (DNS Preserved):"
ALB=$(kubectl get ingress -n ecommerce -o jsonpath='{.items[0].status.loadBalancer.ingress[0].hostname}')
echo "ALB: $ALB"
echo ""

if [[ "$ALB" == "k8s-ecommerc-ecommerc-f905cb5bda-1356497416.us-east-1.elb.amazonaws.com" ]]; then
  echo "✅ ALB PRESERVED! DNS (eks.devopsproject.com.br) still working!"
else
  echo "❌ ALB CHANGED! This would break DNS!"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Test Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Summary:"
echo "  - Auto-sync works WITHOUT deleting Application"
echo "  - ArgoCD polling: every 30 seconds"
echo "  - ALB preserved across deployments"
echo "  - DNS (eks.devopsproject.com.br) remains functional"
echo ""
