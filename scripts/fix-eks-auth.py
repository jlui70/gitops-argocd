#!/usr/bin/env python3
"""
Fix EKS aws-auth ConfigMap to add github-actions-eks IAM user
"""
import subprocess
import json
import os

# Set environment
os.environ['AWS_PROFILE'] = 'devopsproject'
for key in ['AWS_ACCESS_KEY_ID', 'AWS_SECRET_ACCESS_KEY']:
    os.environ.pop(key, None)

print("🔧 Updating aws-auth ConfigMap for EKS cluster access...")

# Update kubeconfig
print("\n📡 Updating kubeconfig...")
subprocess.run([
    'aws', 'eks', 'update-kubeconfig',
    '--name', 'eks-devopsproject-cluster',
    '--region', 'us-east-1'
], check=True)

# Get current ConfigMap
print("\n📋 Getting current aws-auth ConfigMap...")
result = subprocess.run([
    'kubectl', 'get', 'configmap', 'aws-auth',
    '-n', 'kube-system', '-o', 'json'
], capture_output=True, text=True, check=True)

configmap = json.loads(result.stdout)

# Update mapUsers
map_users = """- userarn: arn:aws:iam::794038226274:user/github-actions-eks
  username: github-actions-eks
  groups:
  - system:masters
"""

configmap['data']['mapUsers'] = map_users

# Write to temp file
temp_file = '/tmp/aws-auth-updated.json'
with open(temp_file, 'w') as f:
    json.dump(configmap, f)

# Apply updated ConfigMap
print("\n✨ Applying updated ConfigMap...")
subprocess.run([
    'kubectl', 'apply', '-f', temp_file
], check=True)

print("\n✅ aws-auth ConfigMap updated successfully!")
print("\n📋 Verification:")
subprocess.run([
    'kubectl', 'get', 'configmap', 'aws-auth',
    '-n', 'kube-system', '-o', 'yaml'
])

print("\n✅ Done! GitHub Actions can now access the EKS cluster.")
print("🔄 Re-run your CD workflow: https://github.com/jlui70/gitops-eks/actions")
