# GitOps Pipeline - EKS com CI/CD Completo

<p align="center">
  <img src="https://img.shields.io/badge/GitOps-Enabled-00ADD8?style=for-the-badge&logo=git&logoColor=white" />
  <img src="https://img.shields.io/badge/CI/CD-GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions&logoColor=white" />
  <img src="https://img.shields.io/badge/IaC-Terraform-623CE4?style=for-the-badge&logo=terraform&logoColor=white" />
  <img src="https://img.shields.io/badge/Kubernetes-EKS-326CE5?style=for-the-badge&logo=kubernetes&logoColor=white" />
  <img src="https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazon-aws&logoColor=white" />
</p>

> Pipeline **GitOps** production-ready com **GitHub Actions**, **Amazon EKS**, **Terraform** e estratégia **Blue/Green Deployment** para zero downtime.

---

## 🎯 Visão Geral

Este projeto demonstra uma **pipeline GitOps completa** para deploy automatizado em Kubernetes (Amazon EKS) utilizando as melhores práticas de DevOps moderno:

- ✅ **CI/CD com GitHub Actions** - Pipelines automatizados (CI, CD, Rollback)
- ✅ **Blue/Green Deployment** - Zero downtime e rollback < 30 segundos
- ✅ **Infraestrutura como Código** - 3 stacks Terraform modulares
- ✅ **Container Registry** - Amazon ECR para images Docker
- ✅ **Segurança** - IAM + RBAC + GitHub Environment Secrets
- ✅ **Aplicação Demo** - E-commerce com 7 microserviços
- ✅ **Ingress Controller** - AWS Load Balancer Controller
- ✅ **DNS Automático** - External DNS com Route53

---

## 🏗️ Arquitetura GitOps

```
┌─────────────────────────────────────────────────────────────┐
│ Developer                                                   │
│  git commit → git push                                      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ CI Pipeline (GitHub Actions) - Automático                  │
├─────────────────────────────────────────────────────────────┤
│ ✅ Validate Kubernetes manifests                            │
│ ✅ Build Docker images (7 microservices)                    │
│ ✅ Security scan & tests                                    │
│ ✅ Push to Amazon ECR                                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ CD Pipeline (GitHub Actions) - Manual Approval             │
├─────────────────────────────────────────────────────────────┤
│ ✅ Deploy v2 (Blue/Green)                                   │
│ ✅ Health checks                                            │
│ ✅ Switch traffic (Service selector)                        │
│ ✅ Verify deployment                                        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│ Production (Amazon EKS)                                     │
│  Application live @ eks.devopsproject.com.br                │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Quick Start

### Pré-requisitos

- AWS Account com permissões administrativas
- AWS CLI configurado (v2.x)
- Terraform (v1.12+)
- kubectl (v1.28+)
- Conta GitHub (para Actions)
- Domínio próprio (opcional)

### 1. Configuração Inicial

Siga o guia detalhado de configuração:

📚 **[Configuração Inicial](./docs/Configuração-inicial.md)**

Este guia cobre:
- Configuração AWS CLI e credenciais
- Setup Terraform backend
- Criação de IAM roles necessárias
- Configuração Route53 (se usar domínio próprio)

### 2. Deploy da Infraestrutura

```bash
# Deploy automatizado (20-25 min)
./scripts/rebuild-all.sh
```

**O script provisiona:**
- Stack 00: Backend (S3 + DynamoDB)
- Stack 01: Networking (VPC + Subnets + NAT Gateways)
- Stack 02: EKS Cluster (Cluster + Node Group + ALB Controller)

### 3. Configurar GitHub Actions

**3.1. Criar repositório GitHub**
```bash
git remote add origin https://github.com/SEU-USUARIO/gitops-eks.git
git push -u origin main
```

**3.2. Configurar GitHub Environment Secrets**

Navegue: `Settings → Environments → New environment (production)`

Adicione os secrets:
```
AWS_ACCESS_KEY_ID: AKIA...
AWS_SECRET_ACCESS_KEY: ****
AWS_ACCOUNT_ID: 794038226274
```

📚 **[Guia CI/CD Pipeline](./docs/CI-CD-PIPELINE.md)** (instruções detalhadas)

### 4. Deploy da Aplicação

**Opção A: Via GitHub Actions (GitOps)**
1. Acesse: `github.com/SEU-USUARIO/gitops-eks/actions`
2. Selecione workflow: `CD - Deploy to EKS`
3. Click: `Run workflow`
4. Configure:
   - environment: `production`
   - strategy: `blue-green`
5. Click: `Run workflow`

**Opção B: Manual**
```bash
cd 06-ecommerce-app
./deploy.sh
```

### 5. Validar Deployment

```bash
# Ver pods
kubectl get pods -n ecommerce

# Ver ingress e ALB
kubectl get ingress -n ecommerce

# Acessar aplicação
# Via ALB direto
kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Via domínio (se configurado)
curl http://eks.devopsproject.com.br
```

---

## 📋 Estrutura do Projeto

```
gitops/
├── .github/
│   └── workflows/
│       ├── ci.yml           # CI Pipeline (validação + build)
│       ├── cd.yml           # CD Pipeline (deploy Blue/Green)
│       └── rollback.yml     # Rollback automático
├── 00-backend/              # Terraform: S3 + DynamoDB
├── 01-networking/           # Terraform: VPC + Networking
├── 02-eks-cluster/          # Terraform: EKS + Addons
├── 06-ecommerce-app/        # Aplicação demo
│   ├── manifests/           # Kubernetes manifests v1
│   ├── manifests-v2/        # Kubernetes manifests v2
│   ├── deploy.sh            # Script deploy manual
│   └── deploy-v2.sh         # Script deploy v2 (Blue/Green)
├── docs/
│   ├── Configuração-inicial.md       # Setup inicial
│   ├── CI-CD-PIPELINE.md             # Guia completo CI/CD
│   ├── GUIA-APRESENTACAO-CICD.md     # Roteiro demonstração
│   └── CONCEITOS-AVANCADOS-CICD.md   # TBD, strategies, etc
├── scripts/
│   ├── rebuild-all.sh       # Deploy completo automatizado
│   ├── destroy-all.sh       # Destroy tudo (limpar custos)
│   ├── setup-ecr.sh         # Criar repositórios ECR
│   └── backup-before-destroy.sh  # Backup completo
└── README.md
```

---

## 🔄 Workflows GitHub Actions

### CI - Build and Test

**Trigger:** Push em `main` ou Pull Request

**Pipeline:**
1. **Validate** - Validação de YAML e manifests Kubernetes
2. **Build** - Build de 7 imagens Docker (microservices)
3. **Test** - Testes automatizados (placeholder)
4. **Push** - Upload para Amazon ECR

**Tempo:** ~2 minutos

### CD - Deploy to EKS

**Trigger:** Manual (workflow_dispatch)

**Pipeline:**
1. **Deploy v2** - Aplica manifests Kubernetes v2
2. **Health Check** - Valida pods prontos
3. **Switch Traffic** - Altera Service selector (v1 → v2)
4. **Verify** - Testa endpoint público

**Tempo:** ~40 segundos

**Estratégia:** Blue/Green Deployment (zero downtime)

### Rollback Deployment

**Trigger:** Manual (workflow_dispatch)

**Pipeline:**
1. **Switch Traffic** - Reverte Service selector (v2 → v1)
2. **Verify** - Valida rollback bem-sucedido
3. **Cleanup** - Remove recursos v2 (opcional)

**Tempo:** < 30 segundos

---

## 🛡️ Segurança

### IAM (AWS)

```
IAM User: github-actions-eks
├── AmazonEC2ContainerRegistryFullAccess (managed)
├── AmazonEKSClusterPolicy (managed)
└── EKS-CICD-Access (inline)
```

**Princípio:** Least Privilege - apenas permissões necessárias

### RBAC (Kubernetes)

```yaml
# aws-auth ConfigMap
mapUsers:
  - userarn: arn:aws:iam::ACCOUNT:user/github-actions-eks
    username: github-actions-eks
    groups:
      - system:masters  # Cluster admin para CI/CD
```

### Secrets Management

- **GitHub Environment Secrets** - Credenciais AWS
- **Kubernetes Secrets** - Application secrets
- **ECR** - Container registry privado

---

## 🎨 Estratégia Blue/Green

**Como funciona:**

```
Estado Inicial:
├─ v1: 1 pod (ATIVO - 100% tráfego)
└─ v2: não existe

Durante Deploy:
├─ v1: 1 pod (ATIVO - 100% tráfego)
└─ v2: 2 pods (STANDBY - 0% tráfego)

Após Switch:
├─ v1: 1 pod (STANDBY - 0% tráfego)
└─ v2: 2 pods (ATIVO - 100% tráfego)

Rollback (<30s):
├─ v1: 1 pod (ATIVO - 100% tráfego)
└─ v2: 2 pods (STANDBY - 0% tráfego)
```

**Vantagens:**
- ✅ Zero downtime
- ✅ Rollback instantâneo (troca selector)
- ✅ Testes em produção sem impacto
- ✅ Duas versões simultâneas para validação

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
| **ECR Repositories** | 7 | Container images |
| **Route53 Records** | 1 | DNS (opcional) |

### Kubernetes

| Recurso | Quantidade | Descrição |
|---------|------------|-----------|
| **Deployments** | 8 | v1 + v2 + 6 microservices |
| **Services** | 8 | ClusterIP + LoadBalancer |
| **Ingress** | 1 | ALB Controller |
| **ConfigMaps** | 2 | NGINX v2 config |
| **Namespace** | 1 | ecommerce |

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

### ⚠️ Economia
```bash
# SEMPRE destruir após testes!
./scripts/destroy-all.sh

# Custos após destroy: $0/mês
```

**Dica:** Para laboratório, use por 2-4 horas (~$1-2 total)

---

## 📚 Documentação

### Guias Principais

- 📖 **[Configuração Inicial](./docs/Configuração-inicial.md)** - Setup AWS, Terraform, kubectl
- 🚀 **[CI/CD Pipeline](./docs/CI-CD-PIPELINE.md)** - Guia completo GitHub Actions
- 🎬 **[Guia de Apresentação](./docs/GUIA-APRESENTACAO-CICD.md)** - Roteiro demonstração
- 🎓 **[Conceitos Avançados](./docs/CONCEITOS-AVANCADOS-CICD.md)** - TBD, Strategies, Security

### Scripts Úteis

```bash
# Deploy completo (20-25 min)
./scripts/rebuild-all.sh

# Destroy tudo (10-15 min)
./scripts/destroy-all.sh

# Criar ECR repositories
./scripts/setup-ecr.sh

# Backup antes de destroy
./scripts/backup-before-destroy.sh
```

---

## 🧪 Demonstração

### Simular Deploy de Nova Versão

1. **Alterar banner** (v2.1 → v2.2)
   ```bash
   vim 06-ecommerce-app/manifests-v2/configmap-nginx-v2.yaml
   # Alterar: VERSION 2.1 → VERSION 2.2
   # Alterar cor: verde → azul
   ```

2. **Commit e push**
   ```bash
   git add .
   git commit -m "feat: release v2.2 with new features"
   git push
   ```

3. **CI roda automaticamente** (~2 min)

4. **Aprovar CD manualmente**
   - GitHub Actions → CD - Deploy to EKS → Run workflow

5. **Validar no navegador**
   ```bash
   curl http://eks.devopsproject.com.br
   # Banner azul: VERSION 2.2
   ```

### Testar Rollback

```bash
# Via GitHub Actions
Actions → Rollback Deployment → Run workflow
  reason: "Testing rollback"
  target_version: v2.1

# Ou via kubectl (emergência)
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v1"}}}'
```

**Tempo de rollback:** < 30 segundos

---

## 🔧 Troubleshooting

### CI Pipeline falha no build

**Erro:** `Docker Hub timeout`

**Solução:** Pipeline já configurada para usar ECR primeiro
```yaml
# Verifica se imagem existe no ECR antes de puxar do Docker Hub
aws ecr describe-images --repository-name ecommerce/ecommerce-ui
```

### CD Pipeline falha com "Unauthorized"

**Erro:** `User github-actions-eks is not authorized`

**Solução:** Verificar IAM user e aws-auth ConfigMap
```bash
# Ver IAM policies
aws iam list-attached-user-policies --user-name github-actions-eks

# Ver RBAC Kubernetes
kubectl describe configmap aws-auth -n kube-system
```

### ALB não é criado

**Erro:** `Ingress ADDRESS empty`

**Solução:** Verificar ALB Controller
```bash
# Ver logs ALB Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verificar service account
kubectl get serviceaccount aws-load-balancer-controller -n kube-system
```

### Pods em CrashLoopBackOff

**Erro:** `Pod keeps restarting`

**Solução:** Ver logs
```bash
kubectl logs -n ecommerce deployment/ecommerce-ui-v2
kubectl describe pod -n ecommerce -l version=v2
```

---

## 🎯 Roadmap

### Implementado ✅
- [x] Infraestrutura Terraform (3 stacks)
- [x] CI Pipeline (GitHub Actions)
- [x] CD Pipeline (Blue/Green)
- [x] Rollback automático
- [x] ECR integration
- [x] Segurança (IAM + RBAC)
- [x] Documentação completa

### Próximos Passos 🚀
- [ ] Ambiente Staging
- [ ] Canary Deployment
- [ ] ArgoCD (GitOps pull-based)
- [ ] Monitoring (Prometheus + Grafana)
- [ ] Service Mesh (Istio)
- [ ] Testes automatizados (E2E, Integration)
- [ ] Security scans (Snyk, Trivy)

---

## 🙏 Créditos

Infraestrutura base inspirada no trabalho de **[Kenerry Serain](https://github.com/kenerry-serain)**.

Pipeline GitOps e CI/CD desenvolvidos como evolução do projeto original.

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

**🚀 GitOps Pipeline Production-Ready**

[![GitOps](https://img.shields.io/badge/GitOps-Enabled-00ADD8?style=for-the-badge&logo=git)](https://www.gitops.tech/)
[![GitHub Actions](https://img.shields.io/badge/CI/CD-GitHub_Actions-2088FF?style=for-the-badge&logo=github-actions)](https://github.com/features/actions)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-623CE4?style=for-the-badge&logo=terraform)](https://www.terraform.io/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS-326CE5?style=for-the-badge&logo=kubernetes)](https://kubernetes.io/)

**Desenvolvido com ❤️ para a comunidade DevOps brasileira**

</div>
