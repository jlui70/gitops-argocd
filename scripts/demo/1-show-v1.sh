#!/bin/bash
# Demo Script 1: Show Current State (v1)

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Current State - Version 1"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "🔍 Pods with version labels:"
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version
echo ""

echo "🔍 Service Selector:"
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}' | jq '.'
echo ""

echo "🔍 ArgoCD Application Status:"
kubectl get application ecommerce-app -n argocd
echo ""

echo "🌐 Application URLs:"
echo "   App URL (ALB):"
ALB=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "   http://$ALB"
echo ""
echo "   ArgoCD UI:"
ARGOCD=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "   http://$ARGOCD"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
