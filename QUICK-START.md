# 🚀 Quick Start - Setup Completo em 30 Minutos

## ⚡ Resumo Rápido

1. **Clonar repositório** (único repo com tudo)
2. **Configurar AWS CLI** profile
3. **Deploy Terraform** (3 stacks: backend → networking → eks+argocd)
4. **Aplicar Application ArgoCD** (conecta Git → Cluster)
5. **Testar v1 → v2** via git push

**Tempo total:** ~30 minutos  
**Custo:** ~$1-2 para 2-4 horas de testes

---

## 📋 Pré-requisitos

Certifique-se de ter instalado:

```bash
# Verificar versões
aws --version        # AWS CLI v2.x
terraform --version  # Terraform v1.12+
kubectl version      # kubectl v1.28+
git --version        # Git configurado
```

---

## 1️⃣ Clonar Repositório (1 minuto)

```bash
# Criar diretório de trabalho
mkdir -p ~/lab-argo
cd ~/lab-argo

# Clonar repositório único (infraestrutura + manifestos)
git clone https://github.com/jlui70/gitops-argocd.git
cd gitops-argocd
```

**Estrutura do repositório:**
```
gitops-argocd/
├── 00-backend/          → Terraform: S3 + DynamoDB state
├── 01-networking/       → Terraform: VPC, Subnets, NAT
├── 02-eks-cluster/      → Terraform: EKS + ArgoCD via Helm
├── 03-argocd-apps/      → Application CRD
├── 06-ecommerce-app/
│   └── argocd/
│       ├── base/        → Manifestos base K8s
│       └── overlays/
│           └── production/  → Kustomize v1↔v2
├── scripts/             → Scripts auxiliares
└── docs/                → Documentação
```

---

## 2️⃣ Configurar AWS CLI (2 minutos)

```bash
# Configurar profile
aws configure --profile devopsproject

# Informações necessárias:
# AWS Access Key ID: [sua chave]
# AWS Secret Access Key: [seu secret]
# Default region: us-east-1
# Default output: json

# Testar credenciais
aws sts get-caller-identity --profile devopsproject

# Output esperado:
# {
#     "UserId": "AIDAXXXXX",
#     "Account": "794038226274",
#     "Arn": "arn:aws:iam::794038226274:user/seu-usuario"
# }
```

---

## 3️⃣ Deploy Infraestrutura Terraform (25 minutos)

### Stack 1: Backend (30 segundos)

```bash
cd ~/lab-argo/gitops-argocd/00-backend
terraform init
terraform apply -auto-approve
```

✅ **Criado:** S3 bucket + DynamoDB table para Terraform state

### Stack 2: Networking (5 minutos)

```bash
cd ../01-networking
terraform init
terraform apply -auto-approve
```

✅ **Criado:** VPC + 6 Subnets + 2 NAT Gateways + Internet Gateway

### Stack 3: EKS + ArgoCD (20 minutos)

⚠️ **IMPORTANTE:** Configure o kubeconfig ANTES de aplicar esta stack!

```bash
cd ../02-eks-cluster
terraform init

# Criar cluster primeiro (sem ArgoCD ainda)
terraform apply -target=aws_eks_cluster.cluster -auto-approve

# ⏱️ Aguardar ~10 minutos (cluster sendo criado)

# Configurar kubeconfig AGORA (antes de continuar)
aws eks update-kubeconfig \
  --name eks-devopsproject-cluster \
  --region us-east-1 \
  --profile devopsproject

# Testar conexão
kubectl get nodes
# Deve mostrar: No resources found (nodes ainda sendo criados)

# Agora aplicar o resto (node group + ArgoCD + controllers)
terraform apply -auto-approve
```

✅ **Criado:**
- EKS Cluster (Kubernetes 1.32)
- Node Group (3x t3.medium)
- ArgoCD instalado via Helm
- AWS Load Balancer Controller
- External DNS
- Metrics Server

✅ **Criado:**
- EKS Cluster (Kubernetes 1.32)
- Node Group (3x t3.medium)
- ArgoCD instalado via Helm
- AWS Load Balancer Controller
- External DNS
- Metrics Server

**⏱️ Tempo total do deploy Terraform:** ~25 minutos

---

## 4️⃣ Validar Cluster e kubectl (1 minuto)

Kubeconfig já foi configurado na stack anterior. Valide agora:

```bash
# Testar acesso
kubectl get nodes

# Output esperado: 3 nodes READY
# NAME                          STATUS   ROLE    AGE   VERSION
# ip-10-0-x-x.ec2.internal      Ready    <none>  2m    v1.32.x
```

### Verificar ArgoCD Instalado

```bash
# Ver pods ArgoCD
kubectl get pods -n argocd

# Output esperado: 7 pods rodando
# argocd-application-controller-xxx    1/1  Running
# argocd-applicationset-controller-xxx 1/1  Running
# argocd-dex-server-xxx                1/1  Running
# argocd-notifications-controller-xxx  1/1  Running
# argocd-redis-xxx                     1/1  Running
# argocd-repo-server-xxx               1/1  Running
# argocd-server-xxx                    1/1  Running
```

### Obter Senha ArgoCD

```bash
# Extrair senha admin
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Guardar essa senha para acessar UI
```

### Acessar ArgoCD UI

ArgoCD está exposto via **LoadBalancer** (acesso público):

```bash
# Obter URL pública do ArgoCD
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "🌐 ArgoCD UI: http://$ARGOCD_URL"

# Credenciais:
# User: admin
# Pass: Execute abaixo para ver a senha
cd ~/lab-argo/gitops-argocd/02-eks-cluster
terraform output -raw argocd_admin_password
```

**Alternativa: Port-forward local (opcional)**
```bash
# Se preferir acessar via localhost
kubectl port-forward svc/argocd-server -n argocd 8080:80 &

# Acesse: http://localhost:8080
```

---

#### 6️⃣ Aplicar Application ArgoCD (conecta Git → Cluster)

```bash
# Aplicar CRD do ArgoCD
cd ~/lab-argo/gitops-argocd
kubectl apply -f 03-argocd-apps/ecommerce-app.yaml

# Verificar Application criada
kubectl get application -n argocd

# Output esperado:
# NAME            SYNC STATUS   HEALTH STATUS
# ecommerce-app   Synced        Healthy
```

**O que aconteceu:**
- ArgoCD começou a monitorar o Git (polling 30s)
- Detectou manifests em `overlays/production`
- Aplicou automaticamente todos os recursos
- v1 da aplicação foi deployed

---

## 6️⃣ Validar v1 Rodando (2 minutos)

```bash
# Ver pods da aplicação
kubectl get pods -n ecommerce

# Output esperado: 7 pods rodando (v1)
# ecommerce-ui-v1-xxx                1/1  Running
# order-management-xxx               1/1  Running
# product-catalog-xxx                1/1  Running
# ...

# Obter URL do ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "🌐 Aplicação disponível em: http://$ALB_URL"

# Testar no navegador
curl -I http://$ALB_URL

# Output esperado: HTTP/1.1 200 OK
```

**✅ Setup completo!** Agora você tem:
- ✅ EKS Cluster funcionando
- ✅ ArgoCD instalado e monitorando Git
- ✅ Aplicação v1 deployed (sem banner)
- ✅ ALB funcionando

---

## 🎯 Próximos Passos - Testar GitOps

### Deploy v2 (Banner NEW FEATURES)

```bash
# 1. Editar manifesto
cd ~/lab-argo/gitops-argocd/06-ecommerce-app/argocd/overlays/production
vi kustomization.yaml

# 2. Descomentar 3 seções v2 (veja README.md nesta pasta)

# 3. Commit e push
git add kustomization.yaml
git commit -m "Deploy v2 - Ativa banner"
git push origin main

# 4. Aguardar 30-45s (ArgoCD detecta automaticamente)

# 5. Validar v2
curl http://$ALB_URL
# Banner deve aparecer: "🚀 NEW FEATURES AVAILABLE!"
```

### Rollback v1

```bash
# 1. Editar manifesto
vi kustomization.yaml

# 2. Comentar 3 seções v2 (reverter)

# 3. Commit e push
git add kustomization.yaml
git commit -m "Rollback v1"
git push origin main

# 4. ArgoCD reverte automaticamente (30-45s)
```

**🎉 Parabéns!** Você testou GitOps 100% real via ArgoCD!

---

## 🧹 Destruir Infraestrutura (20 minutos)

**⚠️ IMPORTANTE:** Sempre destruir após testes para evitar custos!

```bash
# 1. Deletar Application ArgoCD (limpa recursos K8s)
kubectl delete application ecommerce-app -n argocd

# Aguardar 2-3 minutos (ArgoCD remove pods, services, ingress)

# 2. Destruir EKS + ArgoCD
cd ~/lab-argo/gitops-eks/02-eks-cluster
terraform destroy -auto-approve
# ⏱️  ~10 minutos

# 3. Destruir Networking
cd ../01-networking
terraform destroy -auto-approve
# ⏱️  ~5 minutos

# 4. Destruir Backend
cd ../00-backend
terraform destroy -auto-approve
# ⏱️  ~30 segundos
```

**✅ Custos após destroy: $0/mês**

---

## 📚 Documentação Adicional

- **[README.md](./README.md)** - Documentação completa do projeto
- **[FLUXO-DEMO-GITOPS.md](./FLUXO-DEMO-GITOPS.md)** - Fluxo detalhado do demo
- **[RESUMO-SOLUCAO-FINAL.md](./RESUMO-SOLUCAO-FINAL.md)** - Resumo da solução
- **[SOLUTION-ARGOCD-AUTOSYNC.md](./SOLUTION-ARGOCD-AUTOSYNC.md)** - Detalhes técnicos

---

## ❓ Troubleshooting Rápido

### Pods não sobem

```bash
kubectl get events -n ecommerce --sort-by='.lastTimestamp' | tail -20
kubectl logs -n ecommerce <nome-pod>
```

### ArgoCD não detecta mudanças

```bash
# Forçar refresh
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### ALB não responde

```bash
# Verificar ALB Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Ver logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

---

## 🚨 Troubleshooting - Erros Comuns

### Erro: "connection refused" ao aplicar stack 02

**Sintoma:**
```
Error: Post "http://localhost/api/v1/namespaces/argocd/secrets": dial tcp 127.0.0.1:80: connect: connection refused
```

**Causa:** Kubeconfig não foi configurado antes da stack 02.

**Solução:**
```bash
# Configure kubeconfig
aws eks update-kubeconfig \
  --name eks-devopsproject-cluster \
  --region us-east-1 \
  --profile devopsproject

# Aplique novamente (vai criar apenas o que faltou)
cd ~/lab-argo/gitops-argocd/02-eks-cluster
terraform apply -auto-approve
```

### Erro: Policies ou Roles já existem

**Sintoma:**
```
Error: creating IAM Role: EntityAlreadyExists
```

**Causa:** Recursos de execução anterior ainda existem na AWS.

**Solução:**
```bash
# Deletar via console AWS ou CLI
aws iam delete-role --role-name <nome-da-role> --profile devopsproject
aws iam delete-policy --policy-arn <arn-da-policy> --profile devopsproject

# Aplicar novamente
terraform apply -auto-approve
```

---

## 🎓 Resumo do Fluxo GitOps

```
Developer            Git Repository          ArgoCD               EKS Cluster
    │                     │                      │                     │
    │ 1. Edit manifest    │                      │                     │
    │ ─────────────────> │                      │                     │
    │                     │                      │                     │
    │ 2. git push         │                      │                     │
    │ ─────────────────> │                      │                     │
    │                     │                      │                     │
    │                     │  3. Poll (30s)       │                     │
    │                     │ <──────────────────  │                     │
    │                     │                      │                     │
    │                     │  4. Detect change    │                     │
    │                     │ ───────────────────> │                     │
    │                     │                      │                     │
    │                     │                      │  5. Sync (kubectl)  │
    │                     │                      │ ─────────────────> │
    │                     │                      │                     │
    │                     │                      │  6. Health check    │
    │                     │                      │ <───────────────── │
    │                     │                      │                     │
    │                     │                      │  ✅ Synced+Healthy  │
    │                     │                      │ ─────────────────> │
```

**✅ Zero comandos kubectl manuais - Tudo via Git!**

---

**Dúvidas?** Veja documentação completa no [README.md](./README.md)
