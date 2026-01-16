# 🌐 Multi-Environment Setup Guide

## 📋 Visão Geral

Este guia explica como configurar **múltiplos ambientes** (Production + Staging) com GitHub Actions e preparar para integração com ArgoCD.

---

## 🏗️ Arquitetura Multi-Ambiente

```
┌─────────────────────────────────────────────────────────────┐
│                   GitHub Repository                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐         ┌──────────────────┐         │
│  │  Environment:    │         │  Environment:    │         │
│  │  STAGING         │         │  PRODUCTION      │         │
│  ├──────────────────┤         ├──────────────────┤         │
│  │ • AWS Keys       │         │ • AWS Keys       │         │
│  │ • Cluster: -stg  │         │ • Cluster: main  │         │
│  │ • Auto deploy    │         │ • Manual approve │         │
│  └────────┬─────────┘         └────────┬─────────┘         │
│           │                            │                    │
└───────────┼────────────────────────────┼────────────────────┘
            │                            │
            ▼                            ▼
   ┌────────────────────┐     ┌────────────────────┐
   │  EKS Staging       │     │  EKS Production    │
   ├────────────────────┤     ├────────────────────┤
   │ • Testes rápidos   │     │ • Produção real    │
   │ • Quebra OK        │     │ • Alta disponib.   │
   │ • Instâncias t3.sm │     │ • Instâncias t3.md │
   └────────────────────┘     └────────────────────┘
```

---

## 🔐 1. Configurar Environments no GitHub

### **1.1 Criar Environments:**

**URL:** https://github.com/jlui70/gitops-eks/settings/environments

#### **Criar Environment: `production`**
1. Clique em **"New environment"**
2. Nome: `production`
3. **Environment protection rules:**
   - ✅ **Required reviewers:** Adicione você mesmo
   - ✅ **Wait timer:** 0 minutos (ou 5 min para ter tempo de pensar)
   - ✅ **Deployment branches:** Only protected branches (main)

#### **Criar Environment: `staging`**
1. Clique em **"New environment"**
2. Nome: `staging`
3. **Environment protection rules:**
   - ⬜ **Required reviewers:** Não necessário (deploy automático)
   - ⬜ **Wait timer:** 0 minutos
   - ✅ **Deployment branches:** Selected branches (main, develop)

---

## 🔑 2. Configurar Secrets por Environment

### **2.1 Production Secrets:**

**URL:** https://github.com/jlui70/gitops-eks/settings/environments/*/edit (production)

Adicione os secrets:
```
AWS_ACCESS_KEY_ID = [production access key]
AWS_SECRET_ACCESS_KEY = [production secret key]
AWS_ACCOUNT_ID = 794038226274
EKS_CLUSTER_NAME = eks-devopsproject-cluster
```

### **2.2 Staging Secrets (para o futuro):**

**URL:** https://github.com/jlui70/gitops-eks/settings/environments/*/edit (staging)

Adicione os secrets:
```
AWS_ACCESS_KEY_ID = [staging access key - pode ser a mesma por enquanto]
AWS_SECRET_ACCESS_KEY = [staging secret key]
AWS_ACCOUNT_ID = 794038226274
EKS_CLUSTER_NAME = eks-devopsproject-cluster-staging
```

---

## 🚀 3. Estrutura de Branches

### **Estratégia Recomendada:**

```
main (production)
  ↑
  └── Pull Request (review obrigatório)
        ↑
      develop (staging)
        ↑
        └── feature/* (desenvolvimento)
```

### **Fluxo de Trabalho:**

1. **Desenvolvimento:**
   ```bash
   git checkout -b feature/nova-funcionalidade
   # ... fazer mudanças ...
   git push origin feature/nova-funcionalidade
   ```

2. **Staging Deploy (automático):**
   ```bash
   git checkout develop
   git merge feature/nova-funcionalidade
   git push origin develop
   # → CI/CD deploy automático para STAGING
   ```

3. **Production Deploy (com aprovação):**
   ```bash
   # Criar PR: develop → main
   # Aguardar aprovação
   git checkout main
   git merge develop
   git push origin main
   # → CD deploy para PRODUCTION (requer aprovação manual)
   ```

---

## 📝 4. Atualizar Workflows para Multi-Environment

Os workflows já estão preparados para usar environments! Eles detectam automaticamente o ambiente baseado no input.

### **Exemplo de uso:**

```yaml
# CD Workflow já suporta:
environment: 
  name: ${{ github.event.inputs.environment || 'production' }}
  url: http://eks.devopsproject.com.br
```

---

## 🎯 5. Workflow por Branch (Futuro)

Quando você criar o cluster staging, adicione este workflow:

**`.github/workflows/deploy-staging.yml`:**
```yaml
name: Deploy to Staging

on:
  push:
    branches:
      - develop
  workflow_dispatch:

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment: staging
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      
      - name: Deploy to Staging
        run: |
          aws eks update-kubeconfig --name ${{ secrets.EKS_CLUSTER_NAME }} --region us-east-1
          cd 06-ecommerce-app
          ./deploy-v2.sh
```

---

## 🔄 6. Preparação para ArgoCD

### **6.1 Estrutura de Diretórios (GitOps):**

```
gitops-eks/
├── environments/
│   ├── production/
│   │   ├── kustomization.yaml
│   │   └── values.yaml
│   └── staging/
│       ├── kustomization.yaml
│       └── values.yaml
├── base/
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
└── argocd/
    ├── application-production.yaml
    └── application-staging.yaml
```

### **6.2 ArgoCD Application Example:**

**`argocd/application-production.yaml`:**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ecommerce-production
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/jlui70/gitops-eks.git
    targetRevision: main
    path: environments/production
  destination:
    server: https://kubernetes.default.svc
    namespace: ecommerce
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## 📊 7. Comparação: Repository vs Environment Secrets

| Aspecto | Repository Secrets | Environment Secrets |
|---------|-------------------|---------------------|
| Simplicidade | ✅ Mais simples | ⚠️ Configuração inicial maior |
| Multi-ambiente | ❌ Não suporta | ✅ Suporta nativamente |
| Aprovações | ❌ Não tem | ✅ Aprovação manual por ambiente |
| Credenciais | 🔴 Mesma para tudo | 🟢 Diferentes por ambiente |
| Migração futura | 🔴 Precisa refazer | 🟢 Já preparado |
| ArgoCD | ⚠️ Limitado | ✅ Integração fácil |

---

## 🎓 8. Roadmap de Evolução

### **Fase 1: Atual (Production apenas)**
- ✅ Environment Secrets configurados
- ✅ Deploy manual via workflow_dispatch
- ✅ Blue/Green deployment

### **Fase 2: Staging Environment** (próximo)
- [ ] Criar EKS cluster staging (menor, t3.small)
- [ ] Configurar DNS staging.devopsproject.com.br
- [ ] Deploy automático em push para `develop`
- [ ] Testes automatizados

### **Fase 3: ArgoCD Integration**
- [ ] Instalar ArgoCD no cluster
- [ ] Migrar para estrutura GitOps (kustomize/helm)
- [ ] Sync automático via ArgoCD
- [ ] GitHub Actions apenas para build de imagens

### **Fase 4: Advanced**
- [ ] Canary deployments
- [ ] Progressive delivery com Flagger
- [ ] Observabilidade completa (Prometheus + Grafana)
- [ ] Testes E2E automatizados

---

## 💡 Recomendações

### **Para agora:**
1. ✅ Crie os 2 environments (production + staging)
2. ✅ Configure secrets no environment `production`
3. ✅ Deixe `staging` preparado para o futuro
4. ✅ Use aprovação manual em production

### **Para depois (quando criar staging):**
1. Criar cluster EKS menor para staging
2. Adicionar workflow específico para staging
3. Configurar branch `develop` para auto-deploy

### **Para ArgoCD (futuro):**
1. Reestruturar manifests com Kustomize
2. Instalar ArgoCD no cluster
3. GitHub Actions só faz build de imagens
4. ArgoCD faz deploy (GitOps puro)

---

## 🔒 Segurança

### **Boas Práticas:**

1. **IAM Users separados:**
   ```bash
   # Production
   aws iam create-user --user-name github-actions-production
   
   # Staging
   aws iam create-user --user-name github-actions-staging
   ```

2. **Políticas com least privilege:**
   - Production: Read-only exceto para deploy
   - Staging: Permissões mais amplas para testes

3. **Aprovações obrigatórias:**
   - Production: Sempre revisar
   - Staging: Pode ser automático

---

## 📚 Recursos

- [GitHub Environments Docs](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment)
- [ArgoCD Getting Started](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [Kustomize Tutorial](https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/)

---

✅ **Configuração preparada para crescimento futuro!**
