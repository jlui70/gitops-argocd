#!/bin/bash
# Get Application URLs

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌐 Application URLs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "📦 E-commerce App:"
ALB=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$ALB" ]; then
    echo "   http://$ALB"
    echo ""
    echo "   Testing..."
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB" --max-time 5 2>/dev/null || echo "timeout")
    if [ "$STATUS" == "200" ]; then
        echo "   ✅ Status: $STATUS - OK"
    else
        echo "   ⚠️  Status: $STATUS (ALB may be provisioning, wait 2-3 minutes)"
    fi
else
    echo "   ⚠️  Ingress not found"
fi

echo ""
echo "🔐 ArgoCD UI:"
ARGOCD=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)
if [ -n "$ARGOCD" ]; then
    echo "   http://$ARGOCD"
    echo "   User: admin"
    PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    echo "   Pass: $PASS"
else
    echo "   ⚠️  ArgoCD service not found"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
