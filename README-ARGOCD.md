# 🚀 GitOps EKS com ArgoCD - Continuous Deployment Automático

<p align="center">
  <img src="https://img.shields.io/badge/ArgoCD-GitOps-00ADD8?style=for-the-badge&logo=argo&logoColor=white" />
  <img src="https://img.shields.io/badge/CD-Automated-success?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Terraform-IaC-623CE4?style=for-the-badge&logo=terraform&logoColor=white" />
  <img src="https://img.shields.io/badge/Kubernetes-EKS-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" />
  <img src="https://img.shields.io/badge/AWS-Cloud-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white" />
</p>

> Pipeline **GitOps completo** com **ArgoCD**, **Amazon EKS**, **Terraform** e **Blue/Green Deployment** para deployments 100% automáticos via Git.

---

## 🎯 Objetivo

Demonstrar implementação GitOps real onde:
- ✅ **Git é a fonte única da verdade**
- ✅ **ArgoCD monitora repositório continuamente**
- ✅ **Deploy automático** após `git push` (sem intervenção manual)
- ✅ **Rollback via Git** (git revert)
- ✅ **Blue/Green deployment** para zero downtime
- ✅ **Infrastructure as Code** completa via Terraform

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│ Developer                                                   │
│  git commit → git push                                      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Git Repository (GitHub)                                     │
│  Source of Truth: Manifests Kubernetes                     │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼ (Poll every 3 min)
┌─────────────────────────────────────────────────────────────┐
│ ArgoCD (EKS Cluster)                                        │
│  ✅ Detecta mudanças no Git automaticamente                 │
│  ✅ Aplica kubectl apply sem intervenção                    │
│  ✅ Self-heal (corrige drift)                               │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Amazon EKS Cluster                                          │
│  📦 App E-commerce v1 ou v2                                 │
│  🔄 Blue/Green deployment via Service selector             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 Estrutura do Projeto

```
gitops-argocd/
├── 00-backend/              # Terraform: S3 + DynamoDB para tfstate
├── 01-networking/           # Terraform: VPC, Subnets, NAT, IGW
├── 02-eks-cluster/          # Terraform: EKS + Node Groups + ArgoCD
│   ├── argocd.tf            # ← ArgoCD Helm installation
│   └── *.tf
├── 03-argocd-apps/          # ← ArgoCD Applications (CRD)
│   ├── ecommerce-app.yaml   # Application manifest
│   └── setup.sh             # Setup script
├── 06-ecommerce-app/
│   ├── argocd/              # ← Kustomize GitOps structure
│   │   ├── base/            # Manifests base (7 microserviços)
│   │   └── overlays/
│   │       ├── v1/          # Overlay v1
│   │       └── v2/          # Overlay v2 (Blue/Green)
│   ├── manifests/           # (Legacy) Manifests originais
│   └── deploy.sh            # (Legacy) Deploy inicial
├── scripts/
│   └── demo/                # ← Scripts de apresentação
│       ├── 1-show-v1.sh
│       ├── 2-deploy-v2.sh
│       ├── 2b-force-sync.sh
│       ├── 3-rollback-v1.sh
│       └── 4-argocd-info.sh
└── .github/workflows/
    └── ci.yml               # (Mantido) Build images
```

---

## 🚀 Instalação Completa

### **Pré-requisitos:**
- AWS CLI configurado
- kubectl
- Terraform >= 1.0
- Git

### **Passo 1: Deploy Terraform (Infra + ArgoCD)**

```bash
# Clone repositório
git clone https://github.com/jlui70/gitops-argocd.git
cd gitops-argocd

# Deploy backend (tfstate)
cd 00-backend
terraform init
terraform apply -auto-approve

# Deploy networking (VPC)
cd ../01-networking
terraform init
terraform apply -auto-approve

# Deploy EKS + ArgoCD
cd ../02-eks-cluster
terraform init
terraform apply -auto-approve

# Configurar kubeconfig
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1
```

### **Passo 2: Setup ArgoCD Application**

```bash
cd ../03-argocd-apps
./setup.sh
```

Isso irá:
- ✅ Aguardar ArgoCD estar pronto
- ✅ Criar Application `ecommerce-app`
- ✅ ArgoCD faz deploy automático da v1

### **Passo 3: Verificar Deploy**

```bash
# Ver pods
kubectl get pods -n ecommerce -L version

# Ver Application
kubectl get application -n argocd

# Obter URLs
kubectl get ingress ecommerce-ingress -n ecommerce
kubectl get svc argocd-server -n argocd
```

---

## 🎬 Demo - Fluxo GitOps

### **Cenário: Atualizar para v2**

**1. Simular mudança de código (git push):**
```bash
cd /home/luiz7/lab-argo/gitops-argocd
./scripts/demo/2-deploy-v2.sh
```

Isso faz:
- Atualiza `03-argocd-apps/ecommerce-app.yaml` (path: v1 → v2)
- Git commit + push

**2. ArgoCD detecta automaticamente:**
- Aguardar ~3 min (polling)
- Ou force sync: `./scripts/demo/2b-force-sync.sh`

**3. Deploy v2 aplicado:**
- Pods v2 criados
- Service selector muda para `version: v2`
- App mostra banner "v2.1"

### **Cenário: Rollback para v1**

```bash
./scripts/demo/3-rollback-v1.sh
./scripts/demo/2b-force-sync.sh
```

- Git revert (desfaz commit)
- ArgoCD detecta e aplica rollback
- App volta para v1 (sem banner)

---

## 📊 Comparação: Antes vs Depois

### **ANTES (GitHub Actions Manual)**
```
Developer → Git Push → CI Build (auto)
                    ↓
            Developer vai no GitHub Actions
                    ↓
            Clica "Run workflow" + inputs
                    ↓
            GitHub Actions executa kubectl
                    ↓
            Deploy manual finalizado
```

### **DEPOIS (ArgoCD GitOps)** ✅
```
Developer → Git Push
           ↓
    ArgoCD detecta automaticamente (3 min)
           ↓
    ArgoCD aplica kubectl automaticamente
           ↓
    Deploy 100% automático! 🎉
```

**Vantagem:** Zero cliques, GitOps real, single source of truth!

---

## 🔐 ArgoCD Access

```bash
# Ver informações
./scripts/demo/4-argocd-info.sh

# Ou manualmente:
# URL
kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

**User:** `admin`

---

## 🛠️ Scripts de Demo

Todos os scripts estão em [`scripts/demo/`](scripts/demo/):

| Script | Função |
|--------|--------|
| `1-show-v1.sh` | Mostra estado v1 atual |
| `2-deploy-v2.sh` | Deploy v2 via GitOps |
| `2b-force-sync.sh` | Force sync imediato |
| `3-rollback-v1.sh` | Rollback para v1 |
| `4-argocd-info.sh` | Info ArgoCD (URL + password) |

Ver detalhes: [scripts/demo/README.md](scripts/demo/README.md)

---

## 🔄 Blue/Green Deployment

O projeto usa **Blue/Green via Service Selector:**

**v1 (Blue):**
```yaml
spec:
  selector:
    app: ecommerce-ui
    version: v1  # ← Roteia para pods v1
```

**v2 (Green):**
```yaml
spec:
  selector:
    app: ecommerce-ui
    version: v2  # ← Switch para pods v2
```

ArgoCD gerencia essa transição automaticamente via Kustomize overlays.

---

## 📝 Kustomize Structure

```
06-ecommerce-app/argocd/
├── base/                    # Manifests compartilhados
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── ecommerce-ui.yaml
│   ├── product-catalog.yaml
│   └── ... (7 microserviços)
│
└── overlays/
    ├── v1/                  # Overlay v1
    │   └── kustomization.yaml
    │       - Patch: version: v1
    │       - Service selector: v1
    │
    └── v2/                  # Overlay v2
        ├── kustomization.yaml
        │   - Patch: version: v2
        │   - Service selector: v2
        ├── ecommerce-ui-backend.yaml
        ├── ecommerce-ui-v2-proxy.yaml
        └── configmap-nginx-v2.yaml
```

**Switch v1 ↔ v2:** Mudar `path` no ArgoCD Application CRD

---

## 🧪 Validação

### **Verificar v1 deployado:**
```bash
kubectl get pods -n ecommerce -L version
# Deve mostrar: version: v1

kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector.version}'
# Output: v1
```

### **Após deploy v2:**
```bash
kubectl get pods -n ecommerce -L version
# Deve mostrar: version: v2

kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector.version}'
# Output: v2
```

---

## 🗑️ Limpeza (Destroy)

```bash
# Deletar Application
kubectl delete application ecommerce-app -n argocd

# Destroy Terraform (ordem inversa)
cd 02-eks-cluster && terraform destroy -auto-approve
cd ../01-networking && terraform destroy -auto-approve
cd ../00-backend && terraform destroy -auto-approve
```

---

## 📚 Documentação Adicional

- **[PLANO-ARGOCD-IMPLEMENTATION.md](PLANO-ARGOCD-IMPLEMENTATION.md)** - Plano completo de implementação
- **[scripts/demo/README.md](scripts/demo/README.md)** - Guia detalhado dos scripts de demo
- **[06-ecommerce-app/README.md](06-ecommerce-app/README.md)** - Documentação da aplicação

---

## ✅ Checklist de Validação

- [ ] Terraform aplicou ArgoCD sem erros
- [ ] ArgoCD UI acessível via ALB
- [ ] Application `ecommerce-app` criada e Healthy
- [ ] Deploy v1 funcionando (pods + service)
- [ ] Git push para v2 → ArgoCD detecta e aplica
- [ ] Service selector muda v1 → v2 automaticamente
- [ ] App mostra banner v2
- [ ] Git revert → Rollback automático para v1
- [ ] App volta sem banner (v1 restored)

---

## 💡 Conceitos Demonstrados

✅ **GitOps:** Git como única fonte da verdade  
✅ **Declarative:** Manifests Kubernetes declarativos  
✅ **Automated:** CD sem intervenção humana  
✅ **Auditable:** Histórico completo no Git  
✅ **Rollback:** Git revert = rollback automático  
✅ **Self-Healing:** ArgoCD corrige drift automaticamente  
✅ **Blue/Green:** Zero downtime deployments  
✅ **IaC:** Infraestrutura 100% Terraform  

---

## 🎓 Projeto

**Autor:** Luis Junior  
**Repositório:** https://github.com/jlui70/gitops-argocd  
**Repositório Original (sem ArgoCD):** https://github.com/jlui70/gitops-eks  
**Data:** Janeiro 2026  

**Objetivo:** Demonstração completa de GitOps com ArgoCD em ambiente real AWS EKS

---

## 📞 Suporte

Para dúvidas ou problemas:
1. Ver [PLANO-ARGOCD-IMPLEMENTATION.md](PLANO-ARGOCD-IMPLEMENTATION.md) - Troubleshooting
2. Verificar logs: `kubectl logs -n argocd deployment/argocd-application-controller`
3. ArgoCD UI: Ver detalhes da Application

---

**🎉 GitOps Completo Implementado com Sucesso!**
