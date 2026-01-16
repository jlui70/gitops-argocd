#!/bin/bash

# Update aws-auth ConfigMap to add github-actions-eks IAM user
# This allows GitHub Actions to deploy to the EKS cluster

echo "🔧 Updating aws-auth ConfigMap..."

# Ensure we're using admin credentials
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
export AWS_PROFILE=devopsproject

# Update kubeconfig
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1

# Get current ConfigMap
kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth-current.yaml

# Create updated ConfigMap
cat > /tmp/aws-auth-updated.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn: arn:aws:iam::794038226274:role/eks-devopsproject-node-group-role
      groups:
      - system:bootstrappers
      - system:nodes
      username: system:node:{{EC2PrivateDNSName}}
  mapUsers: |
    - userarn: arn:aws:iam::794038226274:user/github-actions-eks
      username: github-actions-eks
      groups:
      - system:masters
EOF

# Apply the updated ConfigMap
kubectl apply -f /tmp/aws-auth-updated.yaml

# Verify
echo ""
echo "✅ aws-auth ConfigMap updated!"
echo ""
echo "📋 Current ConfigMap:"
kubectl get configmap aws-auth -n kube-system -o yaml

echo ""
echo "🧪 Testing access with github-actions-eks credentials..."
