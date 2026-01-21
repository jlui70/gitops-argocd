# 📋 PLANO DE IMPLEMENTAÇÃO - ArgoCD GitOps Automation

**Projeto:** GitOps EKS - Integração ArgoCD  
**Data:** Janeiro 2026  
**Status:** 🔍 Análise para Aprovação

---

## 🎯 OBJETIVO

Implementar **ArgoCD** para automação completa do CD (Continuous Deployment) mantendo todas as funcionalidades aprovadas do projeto atual e adicionando monitoramento contínuo do repositório Git com aplicação automática de mudanças.

---

## 📊 ANÁLISE DO PROJETO ATUAL (APROVADO)

### ✅ Componentes Funcionais que Devem Ser Mantidos

#### 1. **Infraestrutura Terraform (100% Mantido)**
- **Stack 00-backend:** S3 + DynamoDB para tfstate
- **Stack 01-networking:** VPC, Subnets, NAT, IGW
- **Stack 02-eks-cluster:** EKS, Node Groups, ALB Controller, External DNS

#### 2. **Deploy Inicial v1 (100% Mantido)**
- **Script:** `06-ecommerce-app/deploy.sh`
- **Função:** Deploy automático da v1 após Terraform
- **Componentes:** 7 microserviços + Ingress
- **Resultado:** App v1 acessível via ALB

#### 3. **Blue/Green Deployment (100% Mantido)**
- **Estratégia:** Selector-based Blue/Green
- **v1:** 2 pods (label `version: v1`)
- **v2:** 2 pods v2 + 1 pod backend (label `version: v2`)
- **Switch:** Mudança do Service selector `version: v1 → v2`

#### 4. **GitHub Actions Workflows (Evoluir)**
- **CI:** `.github/workflows/ci.yml` (Build, Test, Push ECR)
- **CD:** `.github/workflows/cd.yml` (Deploy v2 Blue/Green - Manual)
- **Rollback:** `.github/workflows/rollback.yml` (v2 → v1 - Manual)

---

## 🔄 MUDANÇAS PROPOSTAS

### Fluxo Atual (Manual CD)
```
┌─────────────┐      ┌──────────────┐      ┌─────────────────┐
│ Dev: Commit │ ───> │ GitHub       │ ───> │ Desenvolvedor   │
│ (manifests) │      │ Actions CI   │      │ vai no GitHub   │
└─────────────┘      │ (automático) │      │ Actions e clica │
                     └──────────────┘      │ "Run workflow"  │
                                           │ em CD           │
                                           └────────┬────────┘
                                                    │
                                                    ▼
                                           ┌─────────────────┐
                                           │ GitHub Actions  │
                                           │ CD executa      │
                                           │ kubectl apply   │
                                           └────────┬────────┘
                                                    │
                                                    ▼
                                           ┌─────────────────┐
                                           │ EKS Cluster     │
                                           │ App v2 deployed │
                                           └─────────────────┘
```

### Fluxo Novo (ArgoCD Automático)
```
┌─────────────┐      ┌──────────────┐      ┌─────────────────┐
│ Dev: Commit │ ───> │ GitHub       │      │ ArgoCD detecta  │
│ (manifests) │      │ Actions CI   │      │ mudança no Git  │
└─────────────┘      │ (automático) │ <─── │ (poll 3 min)    │
                     └──────────────┘      └────────┬────────┘
                                                    │ (Auto)
                                                    ▼
                                           ┌─────────────────┐
                                           │ ArgoCD aplica   │
                                           │ kubectl apply   │
                                           │ automático      │
                                           └────────┬────────┘
                                                    │
                                                    ▼
                                           ┌─────────────────┐
                                           │ EKS Cluster     │
                                           │ App v2 deployed │
                                           └─────────────────┘
```

---

## 🏗️ ARQUITETURA PROPOSTA

### Estrutura do Repositório (Reorganização)

```
gitops-eks/
├── 00-backend/              # (Mantido) Terraform tfstate
├── 01-networking/           # (Mantido) Terraform VPC
├── 02-eks-cluster/          # (Atualizado) Terraform EKS + ArgoCD
│   └── argocd.tf            # ← NOVO: Helm release ArgoCD
├── 03-argocd-apps/          # ← NOVO: ArgoCD Applications
│   ├── ecommerce-app.yaml   # ArgoCD Application CRD
│   └── setup.sh             # Script para aplicar ArgoCD Apps
├── 06-ecommerce-app/
│   ├── deploy.sh            # (Mantido) Deploy v1 inicial
│   ├── manifests/           # (Mantido) v1 manifests
│   │   └── *.yaml
│   ├── manifests-v2/        # (Reorganizado) v2 manifests
│   │   └── *.yaml
│   └── argocd/              # ← NOVO: Overlays ArgoCD
│       ├── base/            # Manifests base (compartilhado v1/v2)
│       ├── overlays/
│       │   ├── v1/          # Kustomization v1
│       │   └── v2/          # Kustomization v2
│       └── application.yaml # ArgoCD Application (opcional)
└── .github/workflows/
    ├── ci.yml               # (Mantido) Build images
    ├── cd.yml               # (Opcional) Fallback manual
    └── rollback.yml         # (Mantido) Emergency rollback
```

---

## 📝 COMPONENTES A IMPLEMENTAR

### 1️⃣ **ArgoCD Installation (Terraform)**

**Arquivo:** `02-eks-cluster/argocd.tf`

**Conteúdo:**
```hcl
# ArgoCD Helm Chart Installation
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"  # Stable version
  namespace  = "argocd"
  create_namespace = true

  # High Availability Configuration
  set {
    name  = "server.replicas"
    value = "2"
  }

  set {
    name  = "controller.replicas"
    value = "1"
  }

  # Expose ArgoCD Server via ALB
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "external"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  # Sync Configuration
  set {
    name  = "configs.params.application\\.sync\\.timeout"
    value = "180"
  }

  set {
    name  = "configs.params.application\\.sync\\.pollInterval"
    value = "3m"  # Poll Git a cada 3 minutos
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.this,
    helm_release.load_balancer_controller  # ALB Controller primeiro
  ]
}

# Secret para ArgoCD (admin password)
resource "kubernetes_secret" "argocd_admin" {
  metadata {
    name      = "argocd-admin-password"
    namespace = "argocd"
  }

  data = {
    password = bcrypt(var.argocd_admin_password)
  }

  depends_on = [helm_release.argocd]
}
```

**Arquivo:** `02-eks-cluster/variables.tf` (adicionar)
```hcl
variable "argocd_admin_password" {
  description = "ArgoCD admin password"
  type        = string
  default     = "AdminArgo2026!"  # CHANGE IN PRODUCTION
  sensitive   = true
}
```

---

### 2️⃣ **ArgoCD Application CRD**

**Arquivo:** `03-argocd-apps/ecommerce-app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ecommerce-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  # Source: Git Repository
  source:
    repoURL: https://github.com/<SEU-USER>/gitops-eks.git
    targetRevision: main
    path: 06-ecommerce-app/argocd/overlays/v1  # Inicia com v1
    
  # Destination: EKS Cluster
  destination:
    server: https://kubernetes.default.svc
    namespace: ecommerce
  
  # Sync Policy: Automático
  syncPolicy:
    automated:
      prune: true      # Remove recursos deletados do Git
      selfHeal: true   # Auto-corrige drift
      allowEmpty: false
    
    syncOptions:
      - CreateNamespace=true
      - PruneLast=true
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  # Health Check
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore HPA changes
```

**Script de Setup:** `03-argocd-apps/setup.sh`

```bash
#!/bin/bash
# Apply ArgoCD Applications

set -e

echo "🚀 Configurando ArgoCD Applications..."

# Aguardar ArgoCD estar pronto
kubectl wait --for=condition=available \
  deployment/argocd-server -n argocd --timeout=300s

# Aplicar Application CRD
kubectl apply -f 03-argocd-apps/ecommerce-app.yaml

echo "✅ ArgoCD Application criada!"
echo ""
echo "📊 Verificar status:"
echo "   kubectl get applications -n argocd"
echo ""
echo "🌐 Acessar ArgoCD UI:"
ALB=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "   http://$ALB"
echo ""
echo "🔐 Credentials:"
echo "   User: admin"
echo "   Password: AdminArgo2026!"
```

---

### 3️⃣ **Kustomize Structure (GitOps)**

**Estrutura:**
```
06-ecommerce-app/argocd/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── ecommerce-ui.yaml
│   ├── product-catalog.yaml
│   ├── order-management.yaml
│   ├── product-inventory.yaml
│   ├── profile-management.yaml
│   ├── shipping-and-handling.yaml
│   ├── team-contact-support.yaml
│   └── ingress.yaml
└── overlays/
    ├── v1/
    │   └── kustomization.yaml
    └── v2/
        ├── kustomization.yaml
        ├── ecommerce-ui-backend.yaml
        ├── ecommerce-ui-v2-proxy.yaml
        ├── configmap-nginx-v2.yaml
        └── patch-service-v2.yaml
```

**Arquivo:** `06-ecommerce-app/argocd/base/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ecommerce

resources:
  - namespace.yaml
  - ecommerce-ui.yaml
  - product-catalog.yaml
  - order-management.yaml
  - product-inventory.yaml
  - profile-management.yaml
  - shipping-and-handling.yaml
  - team-contact-support.yaml
  - ingress.yaml

commonLabels:
  managed-by: argocd
  app.kubernetes.io/part-of: ecommerce
```

**Arquivo:** `06-ecommerce-app/argocd/overlays/v1/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ecommerce

bases:
  - ../../base

# Labels específicos da v1
commonLabels:
  version: v1

# Patch do Deployment ecommerce-ui para garantir label v1
patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: ecommerce-ui
    spec:
      selector:
        matchLabels:
          version: v1
      template:
        metadata:
          labels:
            version: v1
```

**Arquivo:** `06-ecommerce-app/argocd/overlays/v2/kustomization.yaml`

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ecommerce

bases:
  - ../../base

# Adicionar recursos v2
resources:
  - ecommerce-ui-backend.yaml
  - ecommerce-ui-v2-proxy.yaml
  - configmap-nginx-v2.yaml

# Patch Service para apontar para v2
patchesStrategicMerge:
  - patch-service-v2.yaml

commonLabels:
  version: v2
```

**Arquivo:** `06-ecommerce-app/argocd/overlays/v2/patch-service-v2.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-ui
  namespace: ecommerce
spec:
  selector:
    app: ecommerce-ui
    version: v2  # ← Switch para v2
```

---

### 4️⃣ **Workflow GitOps Trigger**

**Estratégia:** Manter GitHub Actions CI, mas CD via ArgoCD

**Arquivo:** `.github/workflows/ci.yml` (já existe, manter)

**Novo Arquivo:** `.github/workflows/trigger-argocd.yml`

```yaml
name: Trigger ArgoCD Sync

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy (v1 or v2)'
        required: true
        type: choice
        options:
          - v1
          - v2

jobs:
  update-argocd:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      
      - name: Update ArgoCD Application target
        run: |
          # Atualizar path no Application CRD
          VERSION="${{ github.event.inputs.version }}"
          sed -i "s|path: .*|path: 06-ecommerce-app/argocd/overlays/$VERSION|" \
            03-argocd-apps/ecommerce-app.yaml
      
      - name: Commit & Push
        run: |
          git config user.name "GitHub Actions Bot"
          git config user.email "actions@github.com"
          git add 03-argocd-apps/ecommerce-app.yaml
          git commit -m "chore: switch ArgoCD to ${{ github.event.inputs.version }}"
          git push
      
      - name: Wait for ArgoCD sync
        run: |
          echo "⏳ ArgoCD will sync in ~3 minutes (poll interval)"
          echo "📊 Check status: kubectl get app ecommerce-app -n argocd"
```

---

## 🎬 PROCESSO DE IMPLEMENTAÇÃO

### **FASE 1: Setup ArgoCD (30 min)**

**Passos:**

1. **Atualizar Terraform EKS Stack**
   ```bash
   cd 02-eks-cluster
   
   # Criar arquivo argocd.tf (conforme template acima)
   # Adicionar variable em variables.tf
   
   terraform plan
   terraform apply
   ```

2. **Aguardar ArgoCD estar pronto**
   ```bash
   kubectl wait --for=condition=available \
     deployment/argocd-server -n argocd --timeout=300s
   
   kubectl get pods -n argocd
   ```

3. **Obter ArgoCD URL e Login**
   ```bash
   # URL
   kubectl get svc argocd-server -n argocd \
     -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   
   # User: admin
   # Password: AdminArgo2026! (ou bcrypt do que configurou)
   ```

---

### **FASE 2: Estruturar Kustomize (45 min)**

**Passos:**

1. **Criar estrutura de diretórios**
   ```bash
   cd 06-ecommerce-app
   mkdir -p argocd/base
   mkdir -p argocd/overlays/v1
   mkdir -p argocd/overlays/v2
   ```

2. **Copiar manifests para base**
   ```bash
   cp manifests/*.yaml argocd/base/
   ```

3. **Criar kustomization.yaml** (conforme templates acima)

4. **Testar Kustomize localmente**
   ```bash
   kubectl kustomize argocd/overlays/v1 | less
   kubectl kustomize argocd/overlays/v2 | less
   ```

---

### **FASE 3: Aplicar ArgoCD Application (15 min)**

**Passos:**

1. **Criar diretório ArgoCD Apps**
   ```bash
   mkdir -p 03-argocd-apps
   ```

2. **Criar ecommerce-app.yaml** (conforme template)
   - Atualizar `repoURL` com seu repositório GitHub

3. **Aplicar Application**
   ```bash
   cd 03-argocd-apps
   chmod +x setup.sh
   ./setup.sh
   ```

4. **Verificar status**
   ```bash
   kubectl get application -n argocd
   kubectl describe application ecommerce-app -n argocd
   ```

---

### **FASE 4: Teste do Fluxo GitOps (20 min)**

**Cenário 1: Deploy Automático v2**

1. **Editar Application CRD para apontar para v2**
   ```bash
   # Editar 03-argocd-apps/ecommerce-app.yaml
   # Mudar: path: 06-ecommerce-app/argocd/overlays/v2
   
   git add .
   git commit -m "feat: deploy v2 via ArgoCD"
   git push
   ```

2. **Aguardar ArgoCD detectar mudança (até 3 min)**
   ```bash
   # Via CLI
   kubectl get app ecommerce-app -n argocd -w
   
   # Via UI
   # Abrir ArgoCD UI e ver sync automático
   ```

3. **Verificar v2 deployed**
   ```bash
   kubectl get pods -n ecommerce -l version=v2
   kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep version
   ```

**Cenário 2: Rollback para v1**

1. **Reverter commit ou mudar path para v1**
   ```bash
   # Editar 03-argocd-apps/ecommerce-app.yaml
   # Mudar: path: 06-ecommerce-app/argocd/overlays/v1
   
   git add .
   git commit -m "rollback: back to v1"
   git push
   ```

2. **ArgoCD aplica rollback automaticamente**

---

## 📊 VALIDAÇÃO DA IMPLEMENTAÇÃO

### Checklist de Aprovação

- [ ] **Terraform aplica ArgoCD sem erros**
- [ ] **ArgoCD UI acessível via ALB**
- [ ] **ArgoCD Application criada e Healthy**
- [ ] **Deploy v1 inicial funciona via deploy.sh** (mantido)
- [ ] **ArgoCD detecta mudança Git em até 3 minutos**
- [ ] **Switch v1 → v2 automático após commit**
- [ ] **Rollback v2 → v1 automático após commit**
- [ ] **ALB continua funcionando após switch**
- [ ] **GitHub Actions CI continua funcionando** (builds images)
- [ ] **Apresentação: "hands-off" deploy mostra GitOps real**

---

## 🎤 ROTEIRO DE APRESENTAÇÃO ATUALIZADO

### **Demo Flow com ArgoCD**

**1. Setup Inicial (igual aprovado)**
```bash
# Terminal 1
cd 00-backend && terraform apply -auto-approve
cd ../01-networking && terraform apply -auto-approve
cd ../02-eks-cluster && terraform apply -auto-approve  # ← Agora instala ArgoCD
cd ../06-ecommerce-app && ./deploy.sh  # ← Deploy v1 inicial
```

**2. Acessar App v1**
- Abrir navegador no ALB
- Simular compra (mostra v1, sem banner)

**3. Mostrar ArgoCD UI** ← **NOVO**
- Abrir ArgoCD UI em outra aba
- Mostrar Application "ecommerce-app" Healthy em v1

**4. Simular Mudança no Código** ← **MODIFICADO**
```bash
# Terminal
cd 03-argocd-apps
vim ecommerce-app.yaml
# Mudar path: overlays/v1 → overlays/v2

git add .
git commit -m "deploy: update to v2"
git push
```

**5. ArgoCD Detecta e Aplica Automaticamente** ← **NOVO**
- Voltar para ArgoCD UI
- Mostrar status mudando para "OutOfSync"
- Aguardar até 3 min (ou force sync)
- Mostrar sync automático aplicando v2

**6. Verificar v2 no App**
- Refresh browser no ALB
- Mostrar banner "v2.1" apareceu! 🎉

**7. Rollback Automático** ← **MODIFICADO**
```bash
# Terminal
git revert HEAD  # Ou editar para v1 novamente
git push
```

- ArgoCD detecta e faz rollback automático
- Refresh app: banner sumiu

---

## 🎬 PASSO A PASSO DETALHADO DA APRESENTAÇÃO

### **Preparação Antes da Apresentação**

**Setup do Ambiente (30 min antes):**
```bash
# 1. Deploy completo da infra
cd ~/lab-argo/gitops-eks
terraform -chdir=00-backend apply -auto-approve
terraform -chdir=01-networking apply -auto-approve
terraform -chdir=02-eks-cluster apply -auto-approve

# 2. Aplicar ArgoCD Application
cd 03-argocd-apps
./setup.sh

# 3. Deploy v1 inicial
cd ../06-ecommerce-app
./deploy.sh

# 4. Obter URLs
echo "App URL:"
kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

echo "ArgoCD URL:"
kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**Abrir Abas do Navegador:**
1. Tab 1: App E-commerce (ALB URL)
2. Tab 2: ArgoCD UI (admin / AdminArgo2026!)
3. Tab 3: GitHub Repository (seu repo)

---

### **PARTE 1: Mostrar Estado Atual (v1)**

**Duração:** 2 minutos

**No Terminal:**
```bash
# Mostrar que está em v1
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version
# OUTPUT:
# NAME                            READY   VERSION
# ecommerce-ui-xxxxxxxxx-xxxxx    1/1     v1
# ecommerce-ui-xxxxxxxxx-xxxxx    1/1     v1

kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep -A 3 selector
# OUTPUT:
# selector:
#   app: ecommerce-ui
#   version: v1  # ← Apontando para v1
```

**No Navegador - Tab 1 (App):**
- Acessar site
- Navegar: Products → Add to Cart → Checkout
- **Destacar:** "Sem banner de versão" = v1

**No Navegador - Tab 2 (ArgoCD):**
- Mostrar dashboard
- Clicar em "ecommerce-app"
- **Destacar:** 
  - Status: "Synced" (verde)
  - Path: `06-ecommerce-app/argocd/overlays/v1`
  - All pods healthy

---

### **PARTE 2: Simular Atualização para v2**

**Duração:** 5 minutos

**Narrativa para audiência:**
> "Agora vamos simular que o time de desenvolvimento fez uma atualização no código e quer fazer deploy da versão 2. Com GitOps, basta atualizar o manifesto no Git e o ArgoCD aplica automaticamente. Vamos ver isso acontecer..."

**No Terminal:**
```bash
# 1. Ir para diretório do projeto
cd ~/lab-argo/gitops-eks/03-argocd-apps

# 2. Mostrar conteúdo atual do arquivo
cat ecommerce-app.yaml | grep -A 2 "path:"
# OUTPUT:
#   source:
#     repoURL: https://github.com/...
#     path: 06-ecommerce-app/argocd/overlays/v1  # ← v1

# 3. Editar arquivo (opção A: vim)
vim ecommerce-app.yaml
# OU (opção B: sed - mais rápido para demo)
sed -i 's|overlays/v1|overlays/v2|' ecommerce-app.yaml

# 4. Verificar mudança
cat ecommerce-app.yaml | grep -A 2 "path:"
# OUTPUT:
#   source:
#     repoURL: https://github.com/...
#     path: 06-ecommerce-app/argocd/overlays/v2  # ← v2 agora!

# 5. Git add + commit + push
git status
# OUTPUT: modified: 03-argocd-apps/ecommerce-app.yaml

git add 03-argocd-apps/ecommerce-app.yaml

git commit -m "feat: deploy version 2 via ArgoCD GitOps"
# OUTPUT: [main abc1234] feat: deploy version 2 via ArgoCD GitOps

git push origin main
# OUTPUT: 
# To https://github.com/seu-user/gitops-eks.git
#    old123..new456  main -> main

echo "✅ Push concluído! ArgoCD vai detectar em até 3 minutos..."
```

**Alternativa Rápida para Demo (script):**
```bash
# Criar script: switch-to-v2-gitops.sh
#!/bin/bash
echo "🔄 Atualizando para v2 via GitOps..."

cd ~/lab-argo/gitops-eks
sed -i 's|overlays/v1|overlays/v2|' 03-argocd-apps/ecommerce-app.yaml

git add 03-argocd-apps/ecommerce-app.yaml
git commit -m "feat: deploy v2 via ArgoCD"
git push origin main

echo "✅ Push realizado! Acompanhe no ArgoCD UI..."

# Durante apresentação:
./switch-to-v2-gitops.sh
```

---

### **PARTE 3: Mostrar ArgoCD Detectando e Aplicando**

**Duração:** 3 minutos

**No Navegador - Tab 3 (GitHub):**
```bash
# Refresh na página do repo
# Mostrar commit apareceu: "feat: deploy v2 via ArgoCD"
# Clicar no commit → mostrar diff do arquivo
```

**No Navegador - Tab 2 (ArgoCD):**
```bash
# Voltar para ArgoCD UI

# OPÇÃO A: Aguardar sync automático (até 3 min)
# - Mostrar status mudando: "Synced" → "OutOfSync" → "Syncing"
# - Explicar: "ArgoCD faz poll do Git a cada 3 minutos"

# OPÇÃO B: Force sync manual (para acelerar demo)
# - Clicar em "SYNC" button
# - Clicar em "SYNCHRONIZE"
# - Mostrar progress bar
```

**Enquanto sincroniza, no Terminal:**
```bash
# Watch dos pods em tempo real
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version --watch

# OUTPUT (exemplo):
# NAME                                READY   VERSION
# ecommerce-ui-xxxxxxxxx-xxxxx        1/1     v1
# ecommerce-ui-xxxxxxxxx-xxxxx        1/1     v1
# ecommerce-ui-backend-xxxxxx-xxxx    0/1     v2    # ← Criando v2
# ecommerce-ui-v2-xxxxxxxxxx-xxxxx    0/1     v2    # ← Criando v2
# ecommerce-ui-backend-xxxxxx-xxxx    1/1     v2    # ← v2 pronto
# ecommerce-ui-v2-xxxxxxxxxx-xxxxx    1/1     v2    # ← v2 pronto
```

**No Navegador - Tab 2 (ArgoCD):**
```bash
# Após sync completo (~2 min):
# - Status: "Synced" (verde) ✅
# - Path atualizado: overlays/v2
# - Mostrar pods v2 healthy no diagrama
# - Explicar: "Service automaticamente roteado para v2"
```

---

### **PARTE 4: Validar v2 no App**

**Duração:** 1 minuto

**No Terminal:**
```bash
# Verificar service apontando para v2
kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep -A 3 selector
# OUTPUT:
# selector:
#   app: ecommerce-ui
#   version: v2  # ← Agora v2! ✅

# Verificar pods v2
kubectl get pods -n ecommerce -l version=v2
# OUTPUT:
# NAME                                READY
# ecommerce-ui-backend-xxxxxx-xxxx    1/1
# ecommerce-ui-v2-xxxxxxxxxx-xxxxx    1/1
```

**No Navegador - Tab 1 (App):**
```bash
# Refresh na página (F5)
# 🎉 BANNER APARECE: "Version 2.1 - Now with advanced features!"

# Navegar novamente: Products → Cart
# Mostrar que app funciona normalmente em v2
```

**Destacar para audiência:**
> "Percebam que não cliquei em nenhum botão de deploy. Foi apenas: edit arquivo → git push → ArgoCD aplicou automaticamente. Isso é GitOps real!"

---

### **PARTE 5: Rollback Automático**

**Duração:** 3 minutos

**Narrativa:**
> "E se detectarmos um problema na v2? Rollback também é via Git..."

**No Terminal - OPÇÃO A (Git Revert):**
```bash
cd ~/lab-argo/gitops-eks

# Reverter último commit
git revert HEAD --no-edit
# OUTPUT: [main xyz7890] Revert "feat: deploy v2 via ArgoCD"

git push origin main

echo "✅ Revert pushed! ArgoCD vai fazer rollback..."
```

**No Terminal - OPÇÃO B (Edit Manual):**
```bash
cd ~/lab-argo/gitops-eks/03-argocd-apps

# Voltar para v1
sed -i 's|overlays/v2|overlays/v1|' ecommerce-app.yaml

git add ecommerce-app.yaml
git commit -m "rollback: emergency rollback to v1"
git push origin main
```

**No Navegador - Tab 2 (ArgoCD):**
```bash
# Aguardar ou force sync
# Mostrar:
# - Status: OutOfSync → Syncing
# - Path voltou: overlays/v1
# - Pods v2 sendo removidos
# - Pods v1 recebendo tráfego
```

**No Terminal:**
```bash
kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep -A 3 selector
# OUTPUT:
# selector:
#   version: v1  # ← Voltou para v1! ✅
```

**No Navegador - Tab 1 (App):**
```bash
# Refresh (F5)
# Banner sumiu → v1 restored! ✅
```

---

### **PARTE 6: Comparação com Método Anterior**

**Duração:** 1 minuto

**Slide ou Terminal:**
```
ANTES (GitHub Actions Manual):
┌────────────────────────────────────────┐
│ 1. Abrir GitHub                        │
│ 2. Ir em Actions tab                   │
│ 3. Selecionar workflow "CD"            │
│ 4. Clicar "Run workflow"               │
│ 5. Preencher inputs (environment, etc) │
│ 6. Clicar "Run"                        │
│ 7. Aguardar workflow executar          │
└────────────────────────────────────────┘
👆 Muitos cliques, processo manual


AGORA (ArgoCD GitOps):
┌────────────────────────────────────────┐
│ 1. Edit arquivo: v1 → v2               │
│ 2. git push                            │
│ 3. ✅ Done! ArgoCD aplica auto         │
└────────────────────────────────────────┘
👆 Simples, declarativo, GitOps real
```

---

## 💡 DICAS PARA APRESENTAÇÃO SUAVE

### **1. Scripts de Atalho**

Criar em `scripts/demo/`:

**`scripts/demo/1-show-v1.sh`:**
```bash
#!/bin/bash
echo "📊 Current State - Version 1"
echo ""
echo "Pods:"
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version
echo ""
echo "Service Selector:"
kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep -A 3 selector
echo ""
echo "App URL:"
kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

**`scripts/demo/2-deploy-v2.sh`:**
```bash
#!/bin/bash
echo "🚀 Deploying v2 via GitOps..."
cd ~/lab-argo/gitops-eks
sed -i 's|overlays/v1|overlays/v2|' 03-argocd-apps/ecommerce-app.yaml
git add 03-argocd-apps/ecommerce-app.yaml
git commit -m "feat: deploy v2 via ArgoCD"
git push origin main
echo "✅ Push done! Check ArgoCD UI..."
```

**`scripts/demo/3-rollback-v1.sh`:**
```bash
#!/bin/bash
echo "⏪ Rolling back to v1..."
cd ~/lab-argo/gitops-eks
git revert HEAD --no-edit
git push origin main
echo "✅ Rollback pushed! Check ArgoCD UI..."
```

### **2. Acelerar Sync para Demo (Webhook)**

Se configurar webhook GitHub → ArgoCD:
```bash
# Sync instantâneo após push!
# Sem esperar 3 minutos
```

**Setup rápido:**
```bash
# No ArgoCD Application
spec:
  source:
    repoURL: https://github.com/seu-user/gitops-eks.git
    targetRevision: main
    path: 06-ecommerce-app/argocd/overlays/v1
  
  # Webhook
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**No GitHub:**
- Settings → Webhooks → Add
- URL: `http://<argocd-alb>/api/webhook`
- Content type: `application/json`
- Events: `Just the push event`

### **3. Tela Dividida (tmux)**

```bash
# Terminal com 4 panes
tmux new-session \; \
  split-window -h \; \
  split-window -v \; \
  select-pane -t 0 \; \
  split-window -v

# Pane 1: kubectl get pods --watch
# Pane 2: kubectl get svc ecommerce-ui -o yaml | grep selector --watch
# Pane 3: git commands
# Pane 4: argocd app get ecommerce-app --watch
```

### **4. Fallback se ArgoCD Sync Demorar**

```bash
# No ArgoCD UI, clicar "REFRESH" para forçar check imediato
# Ou via CLI:
argocd app sync ecommerce-app --force
```

---

## 📸 SCREENSHOTS PARA SLIDES

**Antes da apresentação, capturar:**

1. **ArgoCD Dashboard:**
   - Application "ecommerce-app" Synced (verde)
   - Diagram mostrando pods v1

2. **App v1:**
   - Screenshot do site sem banner

3. **Git Diff:**
   - Highlight: `path: overlays/v1` → `path: overlays/v2`

4. **ArgoCD Syncing:**
   - Progress bar durante sync

5. **App v2:**
   - Screenshot com banner "Version 2.1"

---

## ⏱️ TIMELINE DA DEMO

| Tempo | Ação | O Que Mostrar |
|-------|------|---------------|
| 0:00 | Mostrar v1 | Pods, service selector, app funcionando |
| 2:00 | Edit arquivo | vim/sed mudando v1→v2 |
| 2:30 | Git push | Terminal mostrando commit + push |
| 3:00 | ArgoCD detecta | UI mudando OutOfSync → Syncing |
| 5:00 | v2 deployed | Pods v2, service v2, app com banner |
| 6:00 | Rollback | Git revert + push |
| 8:00 | v1 restored | App sem banner novamente |
| 9:00 | Comparação | Slide mostrando vantagens GitOps |

**Total:** ~10 minutos

**Diferencial:** "Sem clicar em GitHub Actions, tudo GitOps!"

---

## 🔧 CONFIGURAÇÕES OPCIONAIS

### **1. GitHub Webhook para Sync Instantâneo**

Em vez de poll (3 min), usar webhook:

```yaml
# Em 03-argocd-apps/ecommerce-app.yaml
spec:
  source:
    repoURL: https://github.com/<USER>/gitops-eks.git
    targetRevision: main
    path: 06-ecommerce-app/argocd/overlays/v1
  
  # ← Adicionar webhook
  webhook:
    github:
      secret: $GITHUB_WEBHOOK_SECRET
```

**No GitHub:**
- Settings → Webhooks → Add webhook
- URL: `http://<ARGOCD-ALB>/api/webhook`
- Secret: definir em Kubernetes Secret

**Resultado:** Deploy em segundos após push!

---

### **2. Notifications (Slack/Email)**

```yaml
# argocd-notifications ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  service.slack: |
    token: $SLACK_TOKEN
  
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} deployed to {{.app.spec.destination.namespace}}!
  
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
```

---

### **3. Multi-Environment (staging + production)**

```
03-argocd-apps/
├── ecommerce-staging.yaml   # Namespace: ecommerce-staging
├── ecommerce-production.yaml # Namespace: ecommerce
└── setup.sh
```

Cada Application aponta para branch diferente:
- Staging: `targetRevision: develop`
- Production: `targetRevision: main`

---

## 💰 CUSTOS ESTIMADOS

| Componente | Custo Mensal (USD) | Observação |
|------------|-------------------|------------|
| ArgoCD Pods | $0 | Roda no EKS existente |
| ArgoCD ALB | ~$16 | 1 ALB adicional |
| **TOTAL ADICIONAL** | **~$16/mês** | Mínimo |

**Nota:** Custo incremental baixo, ArgoCD usa recursos EKS já provisionados.

---

## ⚠️ RISCOS E MITIGAÇÕES

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| **ArgoCD auto-apply quebra prod** | Alto | 1. Testar em staging primeiro<br>2. Usar `syncPolicy.automated.prune: false` inicial<br>3. Manter GitHub Actions como fallback |
| **Poll 3 min muito lento para demo** | Médio | 1. Configurar webhook (sync instantâneo)<br>2. Ou fazer force sync manual na UI |
| **Conflito deploy.sh vs ArgoCD** | Médio | 1. `deploy.sh` só para v1 inicial<br>2. ArgoCD assume controle após setup<br>3. Documentar claramente |
| **Kustomize complexidade** | Baixo | 1. Manter estrutura simples<br>2. Testar `kubectl kustomize` localmente<br>3. Documentar overlays |

---

## 📚 DOCUMENTAÇÃO ADICIONAL

### **Arquivos a Criar/Atualizar**

1. **Criar:**
   - `02-eks-cluster/argocd.tf`
   - `03-argocd-apps/ecommerce-app.yaml`
   - `03-argocd-apps/setup.sh`
   - `06-ecommerce-app/argocd/base/kustomization.yaml`
   - `06-ecommerce-app/argocd/overlays/v1/kustomization.yaml`
   - `06-ecommerce-app/argocd/overlays/v2/kustomization.yaml`
   - `.github/workflows/trigger-argocd.yml`

2. **Atualizar:**
   - `README.md` - Adicionar seção ArgoCD
   - `06-ecommerce-app/README.md` - Atualizar fluxo GitOps
   - `.gitignore` - Ignorar ArgoCD secrets locais

3. **Manter Intacto:**
   - Todos os Terraform stacks (00, 01, 02 core)
   - `06-ecommerce-app/deploy.sh`
   - `06-ecommerce-app/manifests/*` (v1)
   - `.github/workflows/ci.yml`

---

## ✅ PRÓXIMOS PASSOS

### **Para Aprovar Este Plano:**

1. **Revisar arquitetura proposta**
   - Validar se mantém requisitos aprovados
   - Verificar se adiciona ArgoCD corretamente

2. **Verificar impacto em apresentação**
   - Demo ficará mais impressionante (GitOps real)
   - Tempo de apresentação similar (~15 min)

3. **Aprovar ou solicitar ajustes**
   - Se aprovado: iniciar Fase 1
   - Se ajustes: discutir pontos específicos

---

## 🎯 RESUMO EXECUTIVO

### **O Que Muda:**
- ✅ Adiciona ArgoCD para CD automático
- ✅ Commit → Git Push → ArgoCD detecta → Deploy automático
- ✅ Mantém 100% das funcionalidades aprovadas
- ✅ Demo fica mais "GitOps" (sem clicar em GitHub Actions)

### **O Que NÃO Muda:**
- ✅ Terraform stacks (apenas adiciona argocd.tf)
- ✅ Deploy inicial v1 via deploy.sh
- ✅ Blue/Green strategy (selector-based)
- ✅ GitHub Actions CI (build images)
- ✅ ALB + DNS + Ingress

### **Vantagens:**
- 🚀 CD 100% automático (GitOps real)
- 🎯 Apresentação mais profissional
- 📊 UI visual (ArgoCD Dashboard)
- 🔄 Rollback via Git (simples)
- 📈 Escalável para múltiplos ambientes

### **Esforço de Implementação:**
- **Tempo:** ~2 horas (4 fases)
- **Complexidade:** Média
- **Reversível:** Sim (manter GitHub Actions como fallback)

---

**Aguardando aprovação para iniciar implementação! 🚀**
