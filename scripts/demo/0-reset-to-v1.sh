#!/bin/bash
# Demo Script 0: Reset to v1 (Preparation)

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Resetting to v1 (Demo Preparation)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd /home/luiz7/lab-argo/gitops-eks

# Check current state
CURRENT=$(grep "path:" 03-argocd-apps/ecommerce-app.yaml | grep -o "v[12]")
echo "📊 Current version: $CURRENT"
echo ""

if [ "$CURRENT" == "v1" ]; then
    echo "✅ Already on v1! Ready for demo."
    echo ""
    kubectl get application ecommerce-app -n argocd 2>/dev/null || echo "⚠️  Application not found, run: cd 03-argocd-apps && ./setup.sh"
else
    echo "🔄 Switching back to v1..."
    sed -i 's|overlays/v2|overlays/v1|' 03-argocd-apps/ecommerce-app.yaml
    
    echo "📝 Git commit + push..."
    git add 03-argocd-apps/ecommerce-app.yaml
    git commit -m "chore: reset to v1 for demo"
    git push origin main
    
    echo "⚡ Force ArgoCD sync..."
    kubectl delete application ecommerce-app -n argocd 2>/dev/null || true
    sleep 5
    kubectl apply -f 03-argocd-apps/ecommerce-app.yaml
    
    echo "⏳ Waiting for v1 pods..."
    sleep 20
    
    echo "✅ Reset complete!"
fi

echo ""
echo "📊 Current state:"
kubectl get pods -n ecommerce -L version | head -5
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎬 Ready for demo! Run: ./scripts/demo/2-deploy-v2.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
