# 🎓 Conceitos Avançados - CI/CD e DevOps

## 📋 Índice
1. [Estratégias de Deployment](#estratégias-de-deployment)
2. [Segurança em Pipelines](#segurança-em-pipelines)
3. [Fluxo CI/CD Detalhado](#fluxo-cicd-detalhado)
4. [Trunk-Based Development](#trunk-based-development-tbd)
5. [Docker Hub vs ECR](#docker-hub-vs-ecr)

---

## 1️⃣ Estratégias de Deployment

### 🔵 Blue/Green (Nossa Implementação)

**Funcionamento:**
- Duas versões completas em produção (blue=atual, green=nova)
- Switch instantâneo via Service selector
- Rollback < 30s

**Vantagens:**
- ✅ Zero downtime
- ✅ Rollback instantâneo
- ✅ Testes em produção sem impacto

**Desvantagens:**
- ❌ Custo 2x durante deploy
- ❌ Requer orquestração

**Quando usar:** E-commerce, Banking, SaaS crítico

---

### 🔄 Rolling Update

**Funcionamento:**
- Atualiza pods gradualmente (1 de cada vez)
- K8s mantém disponibilidade mínima

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1
    maxSurge: 1
```

**Vantagens:**
- ✅ Sem downtime
- ✅ Não dobra custo
- ✅ Padrão Kubernetes

**Desvantagens:**
- ❌ Rollback mais lento
- ❌ Duas versões simultâneas
- ❌ Alguns usuários veem erros

**Quando usar:** APIs internas, apps com alta tolerância

---

### 🕯️ Canary Deployment

**Funcionamento:**
- 5% tráfego → v2, 95% → v1
- Aumenta gradualmente: 5% → 25% → 50% → 100%

```yaml
# Istio/Nginx
http:
  - destination:
      host: app-v2
    weight: 10
  - destination:
      host: app-v1
    weight: 90
```

**Vantagens:**
- ✅ Risco minimizado
- ✅ Validação real em produção

**Desvantagens:**
- ❌ Requer Service Mesh
- ❌ Monitoramento complexo

**Quando usar:** Netflix, Google, grandes aplicações

---

### 📊 Comparação

| Estratégia | Uso Mercado | Downtime | Complexidade | Rollback |
|------------|-------------|----------|--------------|----------|
| **Rolling** | 60% | Zero | Baixa | Lento |
| **Blue/Green** | 25% | Zero | Média | Instantâneo |
| **Canary** | 10% | Zero | Alta | Parcial |
| **Recreate** | 5% | Alto | Baixa | N/A |

---

## 2️⃣ Segurança em Pipelines

### 🔐 IAM (AWS Identity Management)

**Nossa implementação:**
```
IAM User: github-actions-eks
├── AmazonEC2ContainerRegistryFullAccess
├── AmazonEKSClusterPolicy
└── EKS-CICD-Access (inline)
```

**Princípios:**
- ✅ Least Privilege (apenas permissões necessárias)
- ❌ Nunca AdministratorAccess
- 🔄 Rotação de Access Keys

**Produção (melhor prática):**
```yaml
# OIDC - Sem credenciais estáticas!
aws-actions/configure-aws-credentials@v4:
  role-to-assume: arn:aws:iam::ACCOUNT:role/GitHubRole
```

---

### 🛡️ RBAC (Kubernetes)

**Nossa implementação:**
```yaml
# aws-auth ConfigMap
mapUsers:
  - userarn: arn:aws:iam::794038226274:user/github-actions-eks
    username: github-actions-eks
    groups:
      - system:masters  # Admin total
```

**Groups Kubernetes:**
- `system:masters` → God mode (tudo)
- `view` → Read-only
- `edit` → Create/Update/Delete
- `cluster-admin` → Admin via ClusterRole

**Produção (Least Privilege):**
```yaml
kind: Role
metadata:
  name: cicd-deployer
  namespace: ecommerce
rules:
- apiGroups: ["apps", ""]
  resources: ["deployments", "services"]
  verbs: ["get", "list", "create", "update"]
```

---

### 🔑 Secrets Management

**Nossa implementação:**
- GitHub Environment Secrets (production)
- AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY

**Produção enterprise:**
- HashiCorp Vault
- AWS Secrets Manager
- Rotação automática

---

## 3️⃣ Fluxo CI/CD Detalhado

### 📊 Pipeline Atual (Simplificada)

```
Developer → git push → CI (2min)
                        ├─ Validate YAML (15s)
                        ├─ Build Image (45s)
                        └─ Push to ECR (30s)
                        ↓
              Manual Approval ⏸️
                        ↓
              CD (40s)
                        ├─ Deploy v2 (15s)
                        ├─ Health Check (10s)
                        ├─ Switch Traffic (5s)
                        └─ Verify (10s)
```

### 🏢 Pipeline Produção Real (Completa)

**CI (15-30 min):**
```yaml
├── Lint & Format (30s)
├── Unit Tests (2min)
├── Build Image (2min)
├── Security Scan (3min)
│   ├── Snyk (dependências)
│   ├── Trivy (container)
│   └── SonarQube (SAST)
├── Integration Tests (5min)
├── Contract Tests (3min)
└── Push to Registry (1min)
```

**CD (10-20 min):**
```yaml
├── Deploy to Staging (2min)
├── Smoke Tests (1min)
├── E2E Tests (10min)
│   └── Cypress/Playwright
├── Performance Tests (5min)
│   └── K6/JMeter
├── Manual Approval ⏸️
├── Deploy Prod (2min)
└── Monitor (5min)
```

### 🧪 Testes em Produção Real

```yaml
# Unit Tests
- pytest tests/
- npm test
- go test ./...

# Security
- npm audit --audit-level=high
- snyk test
- trivy image $IMAGE

# Code Quality
- eslint src/
- jest --coverage  # min 80%

# Load Testing
- k6 run --vus 100 --duration 30s
```

### 📝 Para Apresentação

**"Pipeline simplificada para demonstração:**
- ✅ YAML validation
- ✅ Build & Push ECR
- ✅ Blue/Green Deploy

**Produção adicionaria:**
- Unit/Integration/E2E tests
- Security scans (Snyk, Trivy)
- Code quality (coverage 80%)
- Performance tests (K6)
- Canary deployment
- Observability (ELK, Prometheus)"

---

## 4️⃣ Trunk-Based Development (TBD)

### 🌳 O Que É TBD?

**⚠️ NÃO é estratégia de deployment!** É **metodologia de branching Git**.

**Git Flow tradicional:**
```
main
├── develop
│   ├── feature/login (7 dias)
│   ├── feature/dashboard (10 dias)
│   └── hotfix/bug-123 (2 horas)
```

**Trunk-Based Development:**
```
main (trunk) ← TODOS commitam aqui
├── feature/login (<24h)
├── feature/dashboard (<24h)
└── Release tags (v1.0, v2.0)
```

---

### ✨ Características

| Git Flow | Trunk-Based |
|----------|-------------|
| Branches longas (semanas) | Branches curtas (<24h) |
| Merge complexo | Integração contínua |
| Deploy esporádico | Deploy frequente |
| Feature completa = deploy | Feature flags |

---

### 🚀 Como Funciona na Prática

#### **Dia 1: Nova Feature**

**Developer A:**
```bash
# Manhã: Pega task "Login com Google"
git checkout main
git pull
git checkout -b feature/google-login

# Implementa 50% da feature
git add .
git commit -m "feat: add Google OAuth skeleton"
git push origin feature/google-login

# Cria PR
# ⏰ Tempo de vida da branch: 8 horas
```

**CI/CD automático:**
```yaml
PR criado → CI roda:
  ├─ Tests ✅
  ├─ Security scan ✅
  └─ Build ✅

Code Review (30min) ✅
Merge to main (auto)
```

**Feature incompleta?** → **Feature Flag!**

```javascript
// código com feature flag
if (featureFlags.googleLogin) {
  return <GoogleLoginButton />
} else {
  return <EmailLoginButton />
}

// Deploy: Feature vai pra produção DESABILITADA
// Habilita via admin panel quando 100% pronta
```

---

#### **Dia 2: Continuação**

**Developer A:**
```bash
# Manhã: Continua feature
git checkout main  # ← SEMPRE main!
git pull
git checkout -b feature/google-login-callback

# Completa os 50% restantes
git commit -m "feat: complete Google OAuth flow"
git push

# Merge (2 horas depois)
# Feature 100% completa
```

**Admin habilita feature flag:**
```javascript
// Produção
featureFlags.googleLogin = true
// Rollout gradual: 5% → 50% → 100%
```

---

### 🔥 Hotfix Urgente

**Bug crítico em produção:**

```bash
# 09:00 - Bug detectado
git checkout main
git checkout -b hotfix/payment-error

# 09:15 - Fix implementado
git commit -m "fix: correct payment validation"
git push

# 09:20 - CI passa
# 09:25 - Code review (rápido!)
# 09:30 - Merge to main
# 09:35 - Deploy automático
# 09:40 - Bug resolvido!

# ⏱️ Tempo total: 40 minutos
```

**Git Flow levaria 2-4 horas:**
```
hotfix branch → develop → staging → main → deploy
```

---

### 🏢 Empresas que Usam TBD

| Empresa | Deploy/Dia | Branch Max |
|---------|------------|------------|
| **Google** | 16.000 | < 1 dia |
| **Facebook** | 1.000 | < 1 dia |
| **Amazon** | Cont. | < 24h |
| **Netflix** | Cont. | < 24h |

---

### ⚙️ Ferramentas para TBD

**Feature Flags:**
- LaunchDarkly (SaaS, $$$)
- Unleash (Open Source)
- AWS AppConfig

**Exemplo com Unleash:**
```javascript
// Frontend
const unleash = useUnleash();
if (unleash.isEnabled('new-dashboard')) {
  return <NewDashboard />
}

// Backend API
if featureClient.is_enabled("new-payment-gateway"):
    return process_with_stripe()
```

---

### 📊 TBD + Deployment Strategies

**Combinação mais usada:**

```
TBD (branch strategy)
  ↓
CI/CD Pipeline
  ↓
Canary Deployment (5% → 100%)
  +
Feature Flags (control granular)
```

**Fluxo completo:**
1. Dev commita em `main` (feature 50% pronta)
2. CI/CD roda, deploy automático
3. Feature flag **OFF** → usuários não veem
4. Dev completa feature, nova PR
5. Merge → deploy automático
6. Admin ativa flag: 5% usuários
7. Monitora métricas (latency, errors)
8. Aumenta gradualmente: 25% → 50% → 100%
9. Remove feature flag (código limpo)

---

### 🎯 Vantagens TBD

**Para Developers:**
- ✅ Sem merge conflicts complexos
- ✅ Código sempre atualizado
- ✅ Feedback rápido (CI em cada commit)

**Para Negócio:**
- ✅ Deploy frequente = valor rápido
- ✅ Bugs em produção? Rollback < 5min
- ✅ A/B testing nativo (feature flags)

**Para DevOps:**
- ✅ Pipeline simples (uma branch)
- ✅ Rollback = desabilitar flag
- ✅ Zero downtime sempre

---

### ⚠️ Desafios

**Requer disciplina:**
- ❌ Branches > 24h quebram TBD
- ❌ Commits grandes causam conflitos
- ❌ Feature flags não removidas = dívida técnica

**Mitigação:**
```yaml
# CI enforcement
pre-commit:
  - branch age check (< 24h)
  - commit size check (< 400 linhas)
  
# Automação
cron job: "Delete feature flags > 30 dias"
```

---

### 🆚 TBD vs Git Flow - Comparação Prática

**Cenário:** Adicionar integração com Stripe

**Git Flow (6 dias):**
```
Dia 1: Create feature/stripe-integration
Dia 2-3: Desenvolve (branch isolada)
Dia 4: Merge conflicts! (main mudou)
Dia 5: Resolve conflicts + testes
Dia 6: Code review → merge → deploy
```

**Trunk-Based (2 dias):**
```
Dia 1 manhã:
  - feature/stripe-api (<4h)
  - Feature flag OFF
  - Merge + deploy (prod, invisível)
  
Dia 1 tarde:
  - feature/stripe-ui (<4h)
  - Merge + deploy
  
Dia 2:
  - Admin ativa flag 5%
  - Monitora → 100%
  - Remove flag
```

---

## 5️⃣ Docker Hub vs ECR

### 🐳 Docker Hub (Tradicional)

```
Developer → Build → Push Docker Hub → EKS Pull
```

**Por que é popular:**
- ✅ Grátis (imagens públicas)
- ✅ Hub central compartilhado
- ✅ Cache global

**Problemas:**
- ❌ Rate limits (100 pulls/6h)
- ❌ Latência (global)
- ❌ Custo (private repos)

---

### 🏢 ECR Direto (Nossa escolha)

```
Developer → Build → Push ECR → EKS Pull
```

**Por que escolhemos:**
- ✅ Baixa latência (mesma região)
- ✅ IAM nativo
- ✅ Sem rate limits
- ✅ Custo otimizado

---

### 📊 Comparação

| Aspecto | Docker Hub | ECR |
|---------|------------|-----|
| Latência | Alta | Baixa |
| Rate Limits | ⚠️ 100/6h | ✅ Ilimitado |
| Custo Private | $$$ | $ (500MB free) |
| Segurança | Token | IAM |
| Integração AWS | Manual | Nativa |

---

### 🎯 GitOps Próximo Nível

**Com ArgoCD:**
```
Git Push (manifestos) → ArgoCD monitora
                         ↓
                    Auto sync
                         ↓
                  kubectl apply (automático)
```

**Diferença:**
- Build de imagens continua igual (ECR ou Docker Hub)
- **Deploy muda:** ArgoCD ao invés de GitHub Actions
- Git = single source of truth
- Rollback = git revert

---

## 📝 Resumo para Apresentação

### Nossa Pipeline

| Conceito | Implementação | Justificativa |
|----------|---------------|---------------|
| **CD Trigger** | Manual | Controle em produção |
| **Deployment** | Blue/Green | Zero downtime + rollback rápido |
| **Testes** | YAML validation | Simplificado para demo |
| **Registry** | ECR direto | Latência + segurança AWS |
| **Branching** | Main + PR | Preparado para TBD |

### Evolução Futura

**Próximos passos (mencionar na apresentação):**
- ✅ Adicionar testes (unit, integration, e2e)
- ✅ Security scans (Snyk, Trivy)
- ✅ Canary deployment gradual
- ✅ Migrar para Trunk-Based Development
- ✅ GitOps com ArgoCD
- ✅ Observability completa (ELK, Prometheus)

---

## 🎓 Mensagens Chave

**Para o avaliador:**

1. "Pipeline simplificada mas **escalável**"
2. "Segurança em camadas: IAM + RBAC"
3. "Blue/Green escolhido por **zero downtime**"
4. "ECR direto otimiza **latência** AWS"
5. "Preparado para evoluir para **TBD + GitOps**"

**Diferencial:**
- 💡 Conhecimento de TBD (Google, Facebook usam)
- 💡 Feature flags para deploy seguro
- 💡 Comparação objetiva de estratégias

---

**Data**: Janeiro 16, 2026  
**Autor**: DevOps Project
