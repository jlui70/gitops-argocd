# Changelog dos Scripts - Versão 5.0 (ArgoCD GitOps)

## 📅 Data: 22 de Janeiro de 2026

## 🎯 Objetivo
Adaptar scripts `destroy-all.sh` e `rebuild-all.sh` do projeto base (gitops-eks) para o novo projeto com **ArgoCD GitOps** (gitops-argocd).

---

## 📝 Mudanças Principais

### **1. destroy-all.sh (v4.0 → v5.0)**

#### ✅ Adições
- **PASSO 0 (NOVO):** Deletar ArgoCD Application ANTES de destruir cluster
  - `kubectl delete application ecommerce-app -n argocd`
  - Aguarda 60s para ArgoCD remover recursos (ALB, Services, Pods)
  - Força delete de namespace `ecommerce` se necessário
  
- **Limpeza Helm Releases:** Adiciona remoção do ArgoCD do state
  - `terraform state rm helm_release.argocd`
  - `terraform state rm helm_release.metrics_server`

#### 🔄 Modificações
- **Profile AWS:** Alterado de `terraform` → `devopsproject` (via variável `$AWS_PROFILE`)
- **Título:** Atualizado para refletir "EKS + ARGOCD"
- **ECR/IAM:** Mantido como opcional (recursos manuais de CI/CD)

#### 🐛 Correções
- Todas as referências `--profile terraform` substituídas por `--profile $AWS_PROFILE`
- Melhor tratamento de erros em recursos órfãos

---

### **2. rebuild-all.sh (v4.0 → v5.0)**

#### ✅ Adições Principais

##### **A) Limpeza Preventiva de Recursos Órfãos**
```bash
# NOVO: Limpa IAM roles/policies órfãas ANTES de começar
delete_orphan_role "eks-devopsproject-cluster-role"
delete_orphan_role "aws-load-balancer-controller"
delete_orphan_policy "AWSLoadBalancerControllerIAMPolicy"
```

**Problema Resolvido:**
- ❌ Erro: `EntityAlreadyExists` quando roles/policies ficavam de builds anteriores
- ✅ Agora: Limpa tudo antes de começar (detach policies → remove profiles → delete)

##### **B) Tratamento de S3/DynamoDB Já Existentes**
```bash
# NOVO: Tenta importar se recursos já existirem
if terraform apply falhar; then
    terraform import aws_s3_bucket.terraform_state "$BUCKET_NAME"
    terraform import aws_dynamodb_table.terraform_lock "$TABLE_NAME"
    terraform apply -auto-approve  # Reaplicar
fi
```

**Problema Resolvido:**
- ❌ Erro: `BucketAlreadyOwnedByYou` quando S3 já existe
- ✅ Agora: Importa recursos existentes e continua

##### **C) Aguardar ArgoCD Estar Pronto**
```bash
# NOVO: Aguarda ArgoCD antes de aplicar Application
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=argocd-server \
    -n argocd \
    --timeout=300s
```

##### **D) Deploy Automatizado via GitOps**
```bash
# NOVO: Aplica ArgoCD Application automaticamente
kubectl apply -f 03-argocd-apps/ecommerce-app.yaml

# Aguarda sync inicial
sleep 45

# Verifica status
APP_STATUS=$(kubectl get application ecommerce-app -n argocd -o jsonpath='{.status.sync.status}')
```

**Problema Resolvido:**
- ❌ Antes: Deploy manual necessário (`./deploy.sh`)
- ✅ Agora: 100% automatizado via GitOps

#### 🔄 Modificações

##### **Output Final:**
- Mostra **ArgoCD Admin Password** do Terraform output
- URLs prontas para acessar:
  - ArgoCD UI (LoadBalancer)
  - Aplicação E-commerce (ALB via Ingress)
- Instruções de GitOps v1→v2

##### **Profile AWS:**
- Variável `$AWS_PROFILE="devopsproject"` configurável no início

---

## 🆚 Comparação: Antes vs Depois

### **destroy-all.sh**

| Aspecto | v4.0 (gitops-eks) | v5.0 (gitops-argocd) |
|---------|-------------------|----------------------|
| **Profile AWS** | `terraform` hardcoded | `$AWS_PROFILE` variável |
| **ArgoCD Application** | ❌ Não deleta | ✅ Deleta ANTES do cluster |
| **Helm Releases** | 2 (ALB, DNS) | 4 (ArgoCD, ALB, DNS, Metrics) |
| **Namespace ecommerce** | Delete direto | Via ArgoCD (GitOps) + força se necessário |

### **rebuild-all.sh**

| Aspecto | v4.0 (gitops-eks) | v5.0 (gitops-argocd) |
|---------|-------------------|----------------------|
| **Limpeza Prévia** | ❌ Nenhuma | ✅ IAM roles/policies órfãs |
| **S3/DynamoDB existentes** | ❌ Falha com erro | ✅ Importa e continua |
| **ArgoCD Wait** | ❌ Não aguarda | ✅ Aguarda pods prontos (300s) |
| **Application Deploy** | ❌ Manual (`./deploy.sh`) | ✅ Automático (GitOps) |
| **Output Final** | ℹ️ Básico | 📊 Completo (URLs, senha, status) |

---

## 🎯 Exigências do Projeto Atendidas

### ✅ **1. Configuração Automatizada (Rebuild)**
- [x] Limpa recursos órfãos automaticamente
- [x] Trata S3/DynamoDB já existentes (import)
- [x] Aguarda ArgoCD estar pronto
- [x] Aplica Application ArgoCD automaticamente
- [x] Verifica status do deploy
- [x] **Zero intervenção manual necessária**

### ✅ **2. Destruição Segura (Destroy)**
- [x] Deleta Application ArgoCD via GitOps
- [x] Aguarda ArgoCD remover recursos AWS (ALB)
- [x] Remove helm releases do state
- [x] Limpa recursos órfãos
- [x] **Evita erros em próximo rebuild**

---

## 🚀 Como Usar

### **Rebuild Completo (do Zero)**
```bash
cd ~/lab-argo/gitops-eks/scripts
./rebuild-all.sh
```

**O que faz:**
1. Limpa IAM roles/policies órfãs
2. Aplica stacks 00 → 01 → 02 (Terraform)
3. Aguarda ArgoCD estar pronto
4. Aplica Application ArgoCD (GitOps)
5. Mostra URLs e senha

**Tempo:** ~25-30 minutos

---

### **Destroy Completo**
```bash
cd ~/lab-argo/gitops-eks/scripts
./destroy-all.sh
```

**O que faz:**
1. Deleta Application ArgoCD (GitOps)
2. Aguarda recursos serem removidos (ALB)
3. Deleta ECR/IAM user (opcional)
4. Destroy stacks 02 → 01 → 00 (Terraform)
5. Pergunta se deleta backend (S3/DynamoDB)

**Tempo:** ~20 minutos

---

## ⚠️ Problemas Resolvidos

### **Erro 1: EntityAlreadyExists (IAM)**
**Antes:**
```
Error: creating IAM Role (eks-devopsproject-cluster-role): EntityAlreadyExists
```

**Solução:**
- `rebuild-all.sh` limpa roles/policies órfãs ANTES de começar
- Função `delete_orphan_role()` detach policies → remove profiles → delete

### **Erro 2: BucketAlreadyOwnedByYou (S3)**
**Antes:**
```
Error: creating S3 Bucket (eks-devopsproject-state-files-123): BucketAlreadyOwnedByYou
```

**Solução:**
- `rebuild-all.sh` tenta `terraform import` se apply falhar
- Importa S3 bucket e DynamoDB table antes de reaplicar

### **Erro 3: Recursos AWS Órfãos (ALB)**
**Antes:**
- ALB ficava ativo após `terraform destroy` (criado por Ingress)
- Causava custos inesperados

**Solução:**
- `destroy-all.sh` deleta Application ArgoCD VIA GitOps
- ArgoCD remove Ingress → ALB é deletado pela AWS
- Aguarda 60s antes de destruir cluster

---

## 📌 Configurações

### **Alterar AWS Profile:**
Edite o início dos scripts:
```bash
# destroy-all.sh e rebuild-all.sh
AWS_PROFILE="devopsproject"  # Mude aqui
```

### **Alterar Região:**
Edite em `rebuild-all.sh`:
```bash
aws eks update-kubeconfig \
    --name eks-devopsproject-cluster \
    --region us-east-1 \              # Mude aqui
    --profile $AWS_PROFILE
```

---

## 📚 Referências
- **Projeto Base:** gitops-eks (v4.0)
- **Projeto Atual:** gitops-argocd (v5.0)
- **Documentação:** [README.md](../README.md)
- **Quick Start:** [QUICK-START.md](../QUICK-START.md)

---

## ✅ Checklist de Testes

Antes de considerar scripts prontos para produção:

- [x] `rebuild-all.sh` funciona do zero (sem recursos AWS)
- [ ] `rebuild-all.sh` funciona com S3/DynamoDB já existentes
- [ ] `rebuild-all.sh` funciona com IAM roles órfãs
- [x] `destroy-all.sh` remove todos os recursos AWS
- [ ] `destroy-all.sh` + `rebuild-all.sh` (ciclo completo)
- [ ] ArgoCD Application é aplicada automaticamente
- [ ] URLs e senha são exibidas corretamente
- [ ] GitOps v1→v2 funciona após rebuild

---

**Versão:** 5.0  
**Autor:** Adaptado para ArgoCD GitOps  
**Status:** ✅ Pronto para testes
