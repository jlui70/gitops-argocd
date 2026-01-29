# GitOps Pipeline - EKS com ArgoCD

<p align="center">
  <img src="Diagrama completo gitops-argocd.png" alt="Arquitetura GitOps com ArgoCD" />
</p>

<p align="center">
  <img src="https://img.shields.io/badge/GitOps-ArgoCD-00ADD8?style=for-the-badge&logo=argo&logoColor=white" />
  <img src="https://img.shields.io/badge/CD-ArgoCD-EF7B4D?style=for-the-badge&logo=argo&logoColor=white" />
  <img src="https://img.shields.io/badge/IaC-Terraform-623CE4?style=for-the-badge&logo=terraform&logoColor=white" />
  <img src="https://img.shields.io/badge/Kubernetes-EKS-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" />
  <img src="https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white" />
</p>

> Pipeline **GitOps 100% Real** com **ArgoCD**, **Amazon EKS**, **Terraform** e estratégia **Blue/Green Deployment** para zero downtime. Deploy automático via `git push`.

---

## 📋 Sobre o Projeto

Este projeto demonstra a implementação de uma **pipeline GitOps 100% funcional** utilizando ArgoCD e Amazon EKS, onde deploys acontecem automaticamente via `git push` sem intervenção manual.

Para validar a solução, desenvolvi uma infraestrutura completa em AWS, onde:

🏗️ **Terraform** provisiona toda a infraestrutura de forma modular (Backend, VPC, EKS)  
🔄 **ArgoCD** monitora o repositório Git e sincroniza automaticamente as mudanças no cluster  
🎯 **Objetivo**: Demonstrar a eficácia do GitOps com deploy contínuo, zero downtime e rollback instantâneo  

### 🔄 Fluxo GitOps Validado

**Deploy Automático**: Ao fazer `git push` com mudanças nos manifestos Kubernetes, o ArgoCD detecta (polling 30s) e aplica automaticamente no cluster EKS  
**Blue/Green Deployment**: Estratégia com Kustomize Overlays permite alternar entre versões (v1/v2) sem downtime, preservando o ALB  
**Rollback Instantâneo**: Reverter para versão anterior é simples como editar `kustomization.yaml` e fazer push  

✅ **Resultado**: O projeto comprova que GitOps com ArgoCD oferece uma pipeline moderna, declarativa e confiável, eliminando deploys manuais e garantindo que o estado do cluster sempre reflita o Git como única fonte da verdade.

### 🛠️ Stack Tecnológica

- ✅ **GitOps com ArgoCD** - Deploy automático via `git push` (polling 30s)
- ✅ **Amazon EKS** - Cluster Kubernetes gerenciado na AWS
- ✅ **Terraform** - Infraestrutura como Código modular (Backend, Networking, EKS+ArgoCD)
- ✅ **Kustomize** - Gerenciamento declarativo de ambientes (overlays v1/v2)
- ✅ **AWS Load Balancer Controller** - Ingress nativo AWS com ALB
- ✅ **External DNS** - Gerenciamento automático de registros Route53
- ✅ **IAM + RBAC + OIDC** - Segurança e controle de acesso
- ✅ **Blue/Green Deployment** - Zero downtime e rollback instantâneo

---

## 🏗️ Arquitetura GitOps com ArgoCD

```
┌─────────────────────────────────────────────────────────────┐
│ Developer                                                   │
│  1. cd gitops-argocd/06-ecommerce-app/argocd/overlays/...  │
│  2. Edit: kustomization.yaml (v1→v2)                        │
│  3. git commit -am "Deploy v2"                              │
│  4. git push                                                │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ GitHub Repository (único)                                   │
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

### 🎬 Passo a Passo Completo

#### 1️⃣ Clonar Repositório
```bash

git clone https://github.com/jlui70/gitops-argocd.git
cd gitops-argocd

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

#### 3️⃣ Deploy Completo - Backend → Networking → EKS + ArgoCD via Terraform

```bash
./scripts/rebuild-all.sh

# ✅ Cria automaticamente:
#    - Stack 00: S3 bucket + DynamoDB table
#    - Stack 01: VPC + 6 Subnets + 2 NAT Gateways + IGW
#    - Stack 02: EKS Cluster + Node Group + ArgoCD via Helm + Controllers
# ⏱️  Tempo total: ~25 minutos
# 📝 Mostra URLs e senhas no final
```

#### 4️⃣ ArgoCD

```bash
# Obter senha user admin para acesso ArgoCD
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

#### 5️⃣ Acessar ArgoCD UI

**Via LoadBalancer (já exposto publicamente):**
```bash
### Obter URL do ArgoCD
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "🌐 ArgoCD UI: http://$ARGOCD_URL"

# User: admin
# Pass: [use comando da etapa anterior]
```

#### 6️⃣ Acessar Aplicação Ecommerce via ALB

```bash
# Obter URL do ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "🌐 Aplicação disponível em: http://$ALB_URL"
```


**✅ Setup completo! Agora você tem:**
- ✅ EKS Cluster rodando
- ✅ ArgoCD instalado e configurado
- ✅ Aplicação v1 deployed (7 microserviços)
- ✅ ALB funcionando

---

#### 🔄 Testes GitOps - Deploy v1 → v2 → Rollback

### 📋 Três Formas de Alternar Versões

Você pode escolher qualquer um dos métodos abaixo para alternar entre v1 e v2:

<details>
<summary><strong>🎯 OPÇÃO 1: Script Helper (Mais Fácil)</strong></summary>

```bash
cd gitops-argocd/06-ecommerce-app/argocd/overlays/production
./switch-version.sh
# Menu interativo:
# 1 - Ativar v2 (banner)
# 2 - Voltar para v1
# 3 - Cancelar
```

**Vantagens:** Detecção automática da versão atual, cria backup, mostra comandos git prontos.

</details>

<details>
<summary><strong>📁 OPÇÃO 2: Copiar Template (Simples)</strong></summary>

```bash
cd gitops-argocd/06-ecommerce-app/argocd/overlays/production

# Para ativar v2 (banner):
cp kustomization_v2.yaml kustomization.yaml

# Para voltar v1 (sem banner):
cp kustomization_v1.yaml kustomization.yaml
```

**Vantagens:** Sem erro de indentação YAML, copy-paste seguro, não precisa conhecer vi.

</details>

<details>
<summary><strong>✏️ OPÇÃO 3: Edição Manual (Avançado)</strong></summary>

```bash
vi gitops-argocd/06-ecommerce-app/argocd/overlays/production/kustomization.yaml
```

Descomentar/comentar seções:
- **Resources:** `ecommerce-ui-backend.yaml`, `ecommerce-ui-v2-proxy.yaml`, `configmap-nginx-v2.yaml`
- **Patches:** Service selector e deployment deletion

Veja [INSTRUCOES-V2.md](06-ecommerce-app/argocd/overlays/production/INSTRUCOES-V2.md) para passo-a-passo detalhado.
</details>

---

### Cenário Completo: v1 → v2 → Rollback

**Estado Inicial:** v1 rodando (sem banner "NEW FEATURES")

#### Deploy v2 (com Banner)

```bash
# 1. Editar manifesto Kustomize (escolha uma das 3 opções acima)
cd ~/gitops-argocd/06-ecommerce-app/argocd/overlays/production

# Exemplo usando OPÇÃO 2 (recomendado para iniciantes):
cp kustomization_v2.yaml kustomization.yaml

# 2. Commit e push
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
# 1. Editar manifesto (escolha uma das 3 opções)
cd ~/gitops-argocd/06-ecommerce-app/argocd/overlays/production

# Exemplo usando OPÇÃO 2:
cp kustomization_v1.yaml kustomization.yaml

# 2. Commit e push
git add kustomization.yaml
git commit -m "Rollback para v1 - remove banner"
git push origin main

# 3. ArgoCD detecta e reverte automaticamente (30-45s)
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
# Usar script automatizado (recomendado)
./scripts/destroy-all.sh

# O script destrói automaticamente (ordem reversa):
# 1. Stack 02: EKS Cluster + Node Group + ArgoCD (~10 min)
# 2. Stack 01: VPC + Subnets + NAT Gateways (~5 min)
# 3. Stack 00: S3 bucket + DynamoDB table (~30s)

# ✅ Custos após destroy: $0/mês
```

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
