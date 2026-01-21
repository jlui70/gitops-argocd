#!/bin/bash
# Demo Script 2: Deploy v2 via GitOps

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploying v2 via GitOps..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd /home/luiz7/lab-argo/gitops-eks

# Check if already on v2
CURRENT=$(grep "path:" 03-argocd-apps/ecommerce-app.yaml | grep -o "v[12]")
if [ "$CURRENT" == "v2" ]; then
    echo "⚠️  Already on v2!"
    echo "   Run './scripts/demo/0-reset-to-v1.sh' first to reset."
    exit 1
fi

echo "1️⃣  Updating ArgoCD Application manifest..."
sed -i 's|overlays/v1|overlays/v2|' 03-argocd-apps/ecommerce-app.yaml

echo "2️⃣  Verifying change:"
cat 03-argocd-apps/ecommerce-app.yaml | grep "path:"
echo ""

echo "3️⃣  Git add + commit + push..."
git add 03-argocd-apps/ecommerce-app.yaml
git commit -m "feat: deploy v2 via ArgoCD GitOps"
git push origin main
echo ""

echo "✅ Push done!"
echo ""
echo "⏳ ArgoCD will detect change and sync automatically"
echo "   (or manually: kubectl delete app ecommerce-app -n argocd && kubectl apply -f 03-argocd-apps/ecommerce-app.yaml)"
echo ""
echo "📊 Check status:"
echo "   watch kubectl get pods -n ecommerce -L version"
echo ""
echo "🌐 Open ArgoCD UI to watch sync in real-time:"
ARGOCD=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "   http://$ARGOCD"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
