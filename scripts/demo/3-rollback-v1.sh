#!/bin/bash
# Demo Script 3: Rollback to v1

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏪ Rolling back to v1..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

cd /home/luiz7/lab-argo/gitops-eks

echo "1️⃣  Git revert (undo last commit)..."
git revert HEAD --no-edit
echo ""

echo "2️⃣  Verifying rollback:"
cat 03-argocd-apps/ecommerce-app.yaml | grep "path:"
echo ""

echo "3️⃣  Pushing rollback..."
git push origin main
echo ""

echo "✅ Rollback pushed!"
echo ""
echo "⏳ ArgoCD will detect and sync back to v1"
echo "   (or manually: kubectl delete app ecommerce-app -n argocd && kubectl apply -f 03-argocd-apps/ecommerce-app.yaml)"
echo ""
echo "📊 Check status:"
echo "   watch kubectl get pods -n ecommerce -L version"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
