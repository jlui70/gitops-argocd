# GitOps Pipeline - EKS com ArgoCD

<p align="center">
  <img src="https://img.shields.io/badge/GitOps-ArgoCD-00ADD8?style=for-the-badge&logo=argo&logoColor=white" />
  <img src="https://img.shields.io/badge/CD-ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white" />
  <img src="https://img.shields.io/badge/IaC-Terraform-623CE4?style=for-the-badge&logo=terraform&logoColor=white" />
  <img src="https://img.shields.io/badge/Kubernetes-EKS-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" />
  <img src="https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white" />
</p>

> Pipeline **GitOps 100% Real** com **ArgoCD**, **Amazon EKS**, **Terraform** e estratégia **Blue/Green Deployment** para zero downtime. Deploy automático via `git push`.

---

## 📦 Repositórios do Projeto

Este projeto usa **dois repositórios** separados (GitOps best practice):

### 🏗️ Infraestrutura (você está aqui)
```
📁 gitops-eks (este repo)
   └─ Terraform: VPC, EKS Cluster, ArgoCD via Helm
   └─ Provisioning: Cria infraestrutura AWS
   └─ Imutável: Não muda depois de criado
```
🔗 **https://github.com/jlui70/gitops-eks**

### 📱 Manifestos Kubernetes (ArgoCD monitora aqui)
```
📁 gitops-argocd (repo separado)
   └─ Kustomize: Base + Overlays (v1/v2)
   └─ Application: CRD do ArgoCD
   └─ Muda frequentemente: A cada deploy/rollback
```
🔗 **https://github.com/jlui70/gitops-argocd**

**Por que separar?**
- ArgoCD monitora apenas manifestos (evita re-deploy quando Terraform muda)
- Infraestrutura é provisionada uma vez (Terraform)
- Aplicação muda sempre (GitOps via ArgoCD)

---

## 🎯 Visão Geral

Este projeto demonstra uma **pipeline GitOps 100% real** para deploy automatizado em Kubernetes (Amazon EKS) utilizando **ArgoCD** e as melhores práticas de DevOps moderno:

- ✅ **GitOps com ArgoCD** - Deploy automático via `git push` (polling 30s)
- ✅ **Blue/Green Deployment** - Zero downtime e rollback instantâneo
- ✅ **Infraestrutura como Código** - Terraform modular (Backend, Networking, EKS+ArgoCD)
- ✅ **Kustomize Overlays** - Gerenciamento declarativo de ambientes (v1/v2)
- ✅ **Segurança** - IAM + RBAC + OIDC
- ✅ **Aplicação Demo** - E-commerce com 7 microserviços
- ✅ **Ingress Controller** - AWS Load Balancer Controller
- ✅ **DNS Automático** - External DNS com Route53
- ✅ **Auto-Sync** - ArgoCD detecta mudanças no Git e aplica automaticamente

---

## 🏗️ Arquitetura GitOps com ArgoCD

```
┌─────────────────────────────────────────────────────────────┐
│ Developer                                                   │
│  1. Edit: overlays/production/kustomization.yaml (v1→v2)    │
│  2. git commit -am "Deploy v2"                              │
│  3. git push                                                │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ GitHub Repository                                           │
│  https://github.com/jlui70/gitops-argocd                    │
│  Branch: main                                               │
│  Path: 06-ecommerce-app/argocd/overlays/production/        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼ (polling 30s)
┌─────────────────────────────────────────────────────────────┐
│ ArgoCD (running in EKS)                                     │
├─────────────────────────────────────────────────────────────┤
│ ✅ Detecta mudança no Git                                   │
│ ✅ Renderiza Kustomize overlay                              │
│ ✅ Compara desired state vs atual                           │
│ ✅ Aplica diff automaticamente                              │
│ ✅ Executa health checks                                    │
│ ⏱️  Tempo total: 30-45 segundos                             │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Production (Amazon EKS)                                     │
│  v2 deployed @ eks.devopsproject.com.br                     │
│  ALB preservado (sem recriar DNS)                           │
└─────────────────────────────────────────────────────────────┘
```

**Fluxo Completo:**
1. Developer edita `kustomization.yaml` (descomenta seção v2)
2. Git push para branch main
3. ArgoCD detecta mudança automaticamente (30s)
4. ArgoCD aplica Blue/Green deployment (v2 sobe, tráfego muda)
5. Aplicação atualizada sem downtime

**Rollback:**
1. Edita `kustomization.yaml` (comenta seção v2, descomenta v1)
2. Git push
3. ArgoCD reverte para v1 automaticamente (30-45s)

---

## 🚀 Quick Start - Setup Completo do Zero

### Pré-requisitos

- **AWS Account** com permissões administrativas
- **AWS CLI** configurado (v2.x) com profile
- **Terraform** (v1.12+)
- **kubectl** (v1.28+)
- **Git** configurado com GitHub
- Domínio próprio registrado (opcional, para DNS)

---

### 🎬 Passo a Passo Completo

#### 1️⃣ Clonar Repositórios

```bash
# Clonar repositório de manifestos (ArgoCD lê daqui)
git clone https://github.com/jlui70/gitops-argocd.git
cd gitops-argocd

# Clonar repositório de infraestrutura Terraform
git clone https://github.com/jlui70/gitops-eks.git
cd gitops-eks
```

#### 2️⃣ Configurar AWS CLI

```bash
# Criar profile AWS (se ainda não tem)
aws configure --profile devopsproject

# Testar credenciais
aws sts get-caller-identity --profile devopsproject

# Output esperado:
# {
#     "UserId": "AIDAXXXXX",
#     "Account": "794038226274",
#     "Arn": "arn:aws:iam::794038226274:user/seu-usuario"
# }
```

#### 3️⃣ Deploy Infraestrutura com Terraform

**Stack 1: Backend (S3 + DynamoDB para Terraform state)**
```bash
cd 00-backend
terraform init
terraform apply -auto-approve
# ✅ Cria: S3 bucket + DynamoDB table
# ⏱️  Tempo: ~30 segundos
```

**Stack 2: Networking (VPC + Subnets + NAT)**
```bash
cd ../01-networking
terraform init
terraform apply -auto-approve
# ✅ Cria: VPC + 6 Subnets + 2 NAT Gateways + IGW
# ⏱️  Tempo: ~5 minutos
```

**Stack 3: EKS + ArgoCD (Cluster + Node Group + ArgoCD instalado)**
```bash
cd ../02-eks-cluster
terraform init
terraform apply -auto-approve
# ✅ Cria: EKS Cluster + Node Group + ArgoCD via Helm + ALB Controller + External DNS
# ⏱️  Tempo: ~15-20 minutos
```

**Tempo total do deploy:** ~25 minutos

#### 4️⃣ Configurar kubectl

```bash
# Configurar kubeconfig para acessar o cluster
aws eks update-kubeconfig \
  --name eks-devopsproject-cluster \
  --region us-east-1 \
  --profile devopsproject

# Testar acesso
kubectl get nodes
# Output esperado: 3 nodes t3.medium READY

# Ver ArgoCD instalado
kubectl get pods -n argocd
# Output esperado: 7 pods ArgoCD rodando
```

#### 5️⃣ Acessar ArgoCD UI

```bash
# Obter senha do admin
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward para acessar UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Abrir navegador:
# URL: https://localhost:8080
# User: admin
# Pass: [senha do comando anterior]
```

#### 6️⃣ Aplicar Application ArgoCD (conecta Git → Cluster)

```bash
# Voltar para repositório de manifestos
cd ~/gitops-argocd

# Aplicar Application CRD (aponta ArgoCD para o Git)
kubectl apply -f 03-argocd-apps/ecommerce-app.yaml

# Verificar Application criada
kubectl get application -n argocd
# Output esperado: ecommerce-app | Synced | Healthy
```

#### 7️⃣ Validar Deployment

```bash
# Ver pods da aplicação
kubectl get pods -n ecommerce
# Output esperado: 7 pods rodando (v1 inicial)

# Ver ingress e ALB
kubectl get ingress -n ecommerce
# Output esperado: ADDRESS aponta para ALB

# Obter URL do ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "🌐 Aplicação disponível em: http://$ALB_URL"

# Testar endpoint
curl -I http://$ALB_URL
# Output esperado: HTTP/1.1 200 OK
```

**✅ Setup completo! Agora você tem:**
- ✅ EKS Cluster rodando
- ✅ ArgoCD instalado e configurado
- ✅ Aplicação v1 deployed (7 microserviços)
- ✅ ALB funcionando
- ✅ DNS automático (se configurou Route53)

---

## 🔄 Testes GitOps - Deploy v1 → v2 → Rollback

### 📋 Cenário: Atualizar aplicação via Git Push

**Estado Atual:** v1 rodando (sem banner "NEW FEATURES")

#### Deploy v2 (com banner)

```bash
# 1. Editar manifesto Kustomize
cd ~/gitops-argocd/06-ecommerce-app/argocd/overlays/production
vi kustomization.yaml

# 2. Descomentar seção v2 (3 blocos):
#
# A) Descomentar patches v2:
#   - ecommerce-ui-backend.yaml
#   - ecommerce-ui-v2-proxy.yaml
#
# B) Descomentar configMapGenerator v2:
#   - configmap-nginx-v2.yaml
#
# C) Descomentar imagem v2:
#   - newTag: v2
#
# Veja o arquivo README.md nesta pasta para instruções detalhadas

# 3. Commit e push
git add kustomization.yaml
git commit -m "Deploy v2 - adiciona banner NEW FEATURES"
git push origin main

# 4. Aguardar ArgoCD detectar mudança
# ⏱️  Tempo: 30-45 segundos (polling automático)

# 5. Acompanhar deploy no ArgoCD UI
# URL: https://localhost:8080 (se fez port-forward)
# Ou via CLI:
kubectl get application ecommerce-app -n argocd -w
```

**O que acontece automaticamente:**
1. ✅ ArgoCD detecta commit no Git (30s)
2. ✅ Renderiza Kustomize overlay (v2)
3. ✅ Aplica novos recursos:
   - `ecommerce-ui-backend` deployment (2 replicas)
   - `ecommerce-ui-v2-proxy` deployment (1 replica)
   - ConfigMap nginx v2
4. ✅ Aguarda pods prontos (health check)
5. ✅ Altera Service selector: `version: v2`
6. ✅ Tráfego migra para v2 (banner aparece)

**Validar v2:**
```bash
# Ver pods v1 + v2 rodando simultaneamente
kubectl get pods -n ecommerce -l app=ecommerce-ui
# Output esperado:
# ecommerce-ui-v1-xxxx    1/1  Running  (STANDBY)
# ecommerce-ui-backend-xxxx  1/1  Running  (ATIVO)
# ecommerce-ui-v2-proxy-xxxx 1/1  Running  (ATIVO)

# Testar no navegador
curl http://$ALB_URL
# Deve exibir banner: "🚀 NEW FEATURES AVAILABLE!"
```

#### Rollback v2 → v1

```bash
# 1. Editar manifesto
cd ~/gitops-argocd/06-ecommerce-app/argocd/overlays/production
vi kustomization.yaml

# 2. Comentar seção v2 (reverter mudanças)
# Veja README.md para instruções

# 3. Commit e push
git add kustomization.yaml
git commit -m "Rollback para v1 - remove banner"
git push origin main

# 4. ArgoCD detecta e reverte automaticamente (30-45s)
```

**O que acontece automaticamente:**
1. ✅ ArgoCD detecta rollback no Git
2. ✅ Altera Service selector: `version: v1`
3. ✅ Tráfego migra para v1 (banner desaparece)
4. ✅ Remove recursos v2 (prune enabled)

**Validar v1:**
```bash
curl http://$ALB_URL
# Banner NÃO deve aparecer (v1 puro)

kubectl get pods -n ecommerce -l app=ecommerce-ui
# Apenas v1 deve estar rodando
```

### ⚡ Características do GitOps Real

- ✅ **Zero comandos kubectl** - Tudo via `git push`
- ✅ **Auto-sync** - 30s polling + hard refresh
- ✅ **Source of truth** - Git é a única verdade
- ✅ **Auditoria** - Todos os deploys trackados no Git
- ✅ **Rollback** - Reverter commit = rollback automático
- ✅ **Blue/Green** - Duas versões simultâneas, zero downtime

---

## 🛡️ Segurança

### IAM (AWS)

```
EKS Cluster Role: eks-devopsproject-cluster-role
├── AmazonEKSClusterPolicy (managed)
├── AmazonEKSVPCResourceController (managed)
└── Permite EKS gerenciar recursos AWS

Node Group Role: eks-devopsproject-node-group-role
├── AmazonEKSWorkerNodePolicy (managed)
├── AmazonEC2ContainerRegistryReadOnly (managed)
├── AmazonEKS_CNI_Policy (managed)
└── Permite nodes acessar ECR e gerenciar networking

ArgoCD OIDC Role: (auto-configurado via Terraform)
├── Permissions boundary definido
├── Trust relationship com EKS OIDC provider
└── Permite ArgoCD gerenciar recursos do cluster
```

**Princípio:** Least Privilege - apenas permissões necessárias

### RBAC (Kubernetes)

```yaml
# ArgoCD tem acesso cluster-wide via ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-application-controller
  namespace: argocd

# ClusterRole com permissões para sync
---
kind: ClusterRoleBinding
metadata:
  name: argocd-application-controller
roleRef:
  kind: ClusterRole
  name: cluster-admin  # ArgoCD precisa criar/deletar recursos
subjects:
  - kind: ServiceAccount
    name: argocd-application-controller
    namespace: argocd
```

### Secrets Management

- **Kubernetes Secrets** - Application secrets
- **ArgoCD Credentials** - Armazenado em Secret no namespace argocd
- **AWS Credentials** - IAM Roles via OIDC (sem chaves estáticas)

---

## 🎨 Estratégia Blue/Green com ArgoCD

**Como funciona:**

```
Estado Inicial (v1):
├─ Deployment: ecommerce-ui-v1 (1 replica)
├─ Service selector: version: v1
└─ Tráfego: 100% → v1

Git Push (deploy v2):
├─ Deployment: ecommerce-ui-v1 (1 replica) ← mantém
├─ Deployment: ecommerce-ui-backend (2 replicas) ← ArgoCD cria
├─ Deployment: ecommerce-ui-v2-proxy (1 replica) ← ArgoCD cria
├─ Service selector: version: v2 ← ArgoCD altera
└─ Tráfego: 100% → v2 (ZERO DOWNTIME)

Estado Após Deploy v2:
├─ v1: rodando mas sem tráfego (STANDBY)
├─ v2: rodando e recebendo tráfego (ATIVO)
└─ ALB: não recriado, DNS preservado ✅

Git Push (rollback):
├─ Service selector: version: v1 ← ArgoCD reverte
├─ Deployments v2: deletados (prune: true) ← ArgoCD limpa
└─ Tráfego: 100% → v1 (ROLLBACK <30s)
```

**Vantagens:**
- ✅ **Zero downtime** - Troca instantânea de selector
- ✅ **Rollback rápido** - Reverter commit = rollback automático
- ✅ **ALB preservado** - DNS nunca muda
- ✅ **Validação segura** - Testar v2 antes de migrar tráfego
- ✅ **Auditoria Git** - Histórico completo de deploys
- ✅ **Declarativo 100%** - Sem scripts, apenas manifests

---

## 📊 Recursos Provisionados

### AWS

| Recurso | Quantidade | Descrição |
|---------|------------|-----------|
| **EKS Cluster** | 1 | Kubernetes 1.32 |
| **EC2 Instances** | 3 | t3.medium (Node Group) |
| **VPC** | 1 | 10.0.0.0/16 |
| **Subnets** | 6 | 2 public + 4 private |
| **NAT Gateways** | 2 | High availability |
| **Application Load Balancer** | 1 | Ingress traffic |
| **Route53 Records** | 1 | DNS (opcional) |
| **S3 Bucket** | 1 | Terraform state |
| **DynamoDB Table** | 1 | Terraform state lock |

### Kubernetes

| Recurso | Quantidade | Descrição |
|---------|------------|-----------|
| **ArgoCD** | 1 | GitOps controller (7 pods) |
| **Deployments** | 7-10 | v1 + v2 (quando deployd) + 6 microservices |
| **Services** | 8 | ClusterIP + LoadBalancer |
| **Ingress** | 1 | ALB Controller |
| **ConfigMaps** | 2 | NGINX v2 config |
| **Namespaces** | 2 | argocd + ecommerce |
| **Application CRD** | 1 | ArgoCD Application resource |

---

## 💰 Custos AWS

### Por Hora
- EKS Cluster: $0.10/h
- EC2 (3x t3.medium): $0.125/h
- NAT Gateway (2x): $0.09/h
- ALB: $0.025/h
- **Total: ~$0.34/hora**

### Mensal (24/7)
- EKS Cluster: ~$73/mês
- EC2 (3x t3.medium): ~$90/mês
- NAT Gateways: ~$65/mês
- ALB: ~$18/mês
- **Total: ~$246/mês**

### ⚠️ IMPORTANTE: Destruir Após Testes

```bash
# Deletar aplicação ArgoCD primeiro
kubectl delete application ecommerce-app -n argocd

# Aguardar 2-3 minutos (ArgoCD limpa recursos)

# Destruir infraestrutura Terraform (ordem reversa)
cd ~/gitops-eks/02-eks-cluster
terraform destroy -auto-approve  # ~10 min

cd ../01-networking
terraform destroy -auto-approve  # ~5 min

cd ../00-backend
terraform destroy -auto-approve  # ~30s

# ✅ Custos após destroy: $0/mês
```

**Dica para laboratório:**
- 2-4 horas de testes: ~$1-2 total
- **SEMPRE destruir** ao finalizar para evitar cobranças
- Backend S3 tem custo mínimo mesmo após destroy (~$0.02/mês)

---

## 📚 Documentação Detalhada

### 📖 Guias no Repositório

- **[FLUXO-DEMO-GITOPS.md](./FLUXO-DEMO-GITOPS.md)** - Fluxo completo do demo GitOps com ArgoCD
- **[RESUMO-SOLUCAO-FINAL.md](./RESUMO-SOLUCAO-FINAL.md)** - Resumo da solução implementada
- **[ROTEIRO-APRESENTACAO.md](./ROTEIRO-APRESENTACAO.md)** - Roteiro para apresentação (15-17 min)
- **[SOLUTION-ARGOCD-AUTOSYNC.md](./SOLUTION-ARGOCD-AUTOSYNC.md)** - Documentação técnica do auto-sync

### 🎯 Arquivos Principais

#### Infraestrutura (gitops-eks)
```
00-backend/          # Terraform state backend (S3+DynamoDB)
01-networking/       # VPC, Subnets, NAT Gateways
02-eks-cluster/      # EKS + ArgoCD via Helm + ALB Controller
```

#### Manifestos Kubernetes (gitops-argocd)
```
06-ecommerce-app/argocd/
├── base/                          # Recursos base (deployments, services)
└── overlays/
    └── production/
        ├── kustomization.yaml     # ⭐ Controla v1 ↔ v2 (editar aqui)
        ├── ecommerce-ui-backend.yaml
        ├── ecommerce-ui-v2-proxy.yaml
        └── configmap-nginx-v2.yaml

03-argocd-apps/
└── ecommerce-app.yaml             # Application CRD (conecta Git → Cluster)
```

### 🔑 Conceitos Chave

**GitOps Declarativo:**
- Source of Truth: Git repository
- Desired State: Manifests no Git
- Atual State: Recursos no cluster
- Reconciliation: ArgoCD sincroniza automaticamente

**Kustomize Overlays:**
- `base/`: Recursos comuns (não altera)
- `overlays/production/`: Customizações por ambiente
- Edita apenas `kustomization.yaml` para v1↔v2

**ArgoCD Auto-Sync:**
- Polling: 30 segundos
- Hard Refresh: Ignora cache
- Prune: Remove recursos deletados do Git
- Self-Heal: Restaura drift automático

---

## � Troubleshooting

### ArgoCD não detecta mudanças no Git

```bash
# Forçar refresh manual
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Verificar configuração de polling
kubectl get configmap argocd-cm -n argocd -o yaml | grep timeout

# Deve mostrar: timeout.reconciliation: 30s
```

### Pods v2 não sobem

```bash
# Ver eventos
kubectl get events -n ecommerce --sort-by='.lastTimestamp'

# Ver logs do pod com problema
kubectl logs -n ecommerce <pod-name>

# Verificar imagens
kubectl describe pod -n ecommerce <pod-name> | grep Image
```

### ALB não responde

```bash
# Verificar ALB Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Ver logs do controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verificar ingress
kubectl describe ingress ecommerce-ingress -n ecommerce
```

### Rollback não funciona

```bash
# Verificar Application status
kubectl get application ecommerce-app -n argocd -o yaml

# Ver histórico de syncs
kubectl get application ecommerce-app -n argocd -o json | jq '.status.history'

# Forçar sync
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'
```

---

## 🎓 Conhecimentos Demonstrados

Este projeto demonstra proficiência em:

- ✅ **GitOps Principles** - Declarative, versioned, pulled
- ✅ **ArgoCD** - Application lifecycle management
- ✅ **Kubernetes** - Deployments, Services, Ingress, Kustomize
- ✅ **Terraform** - IaC modular, state management
- ✅ **AWS** - EKS, VPC, ALB, Route53, IAM
- ✅ **Blue/Green Deployment** - Zero downtime releases
- ✅ **Kustomize** - Overlay management
- ✅ **RBAC & Security** - IAM Roles, OIDC
- ✅ **Observability** - Metrics Server, ArgoCD UI

---

## ❓ FAQ - Perguntas Frequentes

### Por que dois repositórios?

**Separação de responsabilidades:**
- **gitops-eks** (este repo): Infraestrutura Terraform (imutável)
- **gitops-argocd**: Manifestos Kubernetes (muda frequentemente)

ArgoCD monitora apenas o repo de manifestos, evitando re-deploys desnecessários quando Terraform muda.

### Posso usar um repositório só?

Sim, mas não é recomendado. GitOps puro separa infraestrutura (provisioning) de aplicação (configuration).

### Como funciona o auto-sync exatamente?

1. ArgoCD faz polling no Git a cada 30s
2. Detecta mudança em `overlays/production/kustomization.yaml`
3. Renderiza Kustomize com as mudanças
4. Compara desired state (Git) vs actual state (cluster)
5. Aplica diff automaticamente
6. Aguarda health checks
7. Marca sync como "Synced" na UI

### Preciso ter domínio próprio?

Não. O projeto funciona com ALB direto. Domínio é opcional para DNS amigável.

### Quanto tempo leva o setup completo do zero?

- **Deploy infraestrutura**: ~25 minutos
- **Aplicar Application ArgoCD**: ~2 minutos
- **Total**: ~30 minutos

### E se eu quiser adicionar mais microserviços?

1. Adicionar deployment/service em `base/`
2. Referenciar no `kustomization.yaml` do overlay
3. Commit + push
4. ArgoCD detecta e aplica automaticamente

### Como testar sem gastar muito na AWS?

- Provisione por 2-4 horas (~$1-2)
- Faça todos os testes de v1↔v2
- Destrua com `terraform destroy`
- Total: **$1-2 para laboratório completo**

### O banner v2 é só exemplo?

Sim! Representa qualquer mudança real:
- Nova funcionalidade
- Fix de bug
- Atualização de configuração
- Nova versão de imagem

O importante é demonstrar Blue/Green deployment via GitOps.

---

## 📋 Checklist para Apresentação

Use esta lista para validar antes de demonstrar:

- [ ] EKS cluster rodando (`kubectl get nodes`)
- [ ] ArgoCD instalado (`kubectl get pods -n argocd`)
- [ ] Application criada (`kubectl get application -n argocd`)
- [ ] v1 deployed (`kubectl get pods -n ecommerce`)
- [ ] ALB respondendo (`curl http://$ALB_URL`)
- [ ] Git clone do gitops-argocd feito
- [ ] Credenciais Git configuradas
- [ ] ArgoCD UI acessível (port-forward)
- [ ] Banner v1 não aparece (baseline)

**Durante demo:**
- [ ] Editar `kustomization.yaml` (descomentar v2)
- [ ] Commit + push
- [ ] Mostrar ArgoCD UI detectando mudança (~30s)
- [ ] Pods v2 sobem (Green)
- [ ] Tráfego muda para v2 (Blue→Green)
- [ ] Banner aparece no navegador ✅
- [ ] Rollback: comentar v2, commit + push
- [ ] Banner desaparece (v1 volta)

---

## 🙏 Créditos

Infraestrutura base inspirada no trabalho de **[Kenerry Serain](https://github.com/kenerry-serain)**.

GitOps com ArgoCD e overlays Kustomize desenvolvidos como evolução do projeto original.

---

## 📞 Contato

### 🌐 Links

- 📹 **YouTube:** [DevOps Project](https://www.youtube.com/@devops-project)
- 💼 **Portfólio:** [devopsproject.com.br](https://devopsproject.com.br/)
- 💻 **GitHub:** [@jlui70](https://github.com/jlui70)

### 🌟 Contribua

Se este projeto foi útil:
- ⭐ Star no repositório
- 🔄 Fork e contribua
- 📹 Compartilhe o conhecimento
- 🤝 Abra issues e PRs

---

## 📜 Licença

MIT License - Veja [LICENSE](LICENSE) para detalhes.

---

<div align="center">

**🚀 GitOps Pipeline com ArgoCD - Production-Ready**

[![GitOps](https://img.shields.io/badge/GitOps-ArgoCD-00ADD8?style=for-the-badge&logo=argo)](https://argo-cd.readthedocs.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5?style=for-the-badge&logo=kubernetes)](https://kubernetes.io/)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Kustomize](https://img.shields.io/badge/Config-Kustomize-326CE5?style=for-the-badge&logo=kubernetes)](https://kustomize.io/)

**Desenvolvido com ❤️ para a comunidade DevOps brasileira**

</div>
