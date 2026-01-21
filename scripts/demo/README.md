# 🎬 Demo Scripts - ArgoCD GitOps

Scripts prontos para apresentação do projeto com ArgoCD.

## 📂 Scripts Disponíveis

### 1️⃣ **1-show-v1.sh** - Mostrar Estado Atual (v1)
Exibe informações sobre o deployment v1:
- Pods com labels `version`
- Service selector
- Status do ArgoCD Application
- URLs (App + ArgoCD UI)

```bash
./1-show-v1.sh
```

---

### 2️⃣ **2-deploy-v2.sh** - Deploy v2 via GitOps
Simula mudança de código e deploy automático:
- Atualiza manifesto ArgoCD (v1 → v2)
- Git commit + push
- ArgoCD detecta e aplica automaticamente

```bash
./2-deploy-v2.sh
```

**Aguarde ~3 min** para ArgoCD detectar (polling) ou use script 2b.

---

### ⚡ **2b-force-sync.sh** - Sync Imediato (Demo Rápido)
Força sync imediato do ArgoCD (para apresentações):
- Deleta e recria Application
- Sync instantâneo (sem esperar polling)

```bash
./2b-force-sync.sh
```

**Use este durante apresentação** para não esperar 3 min!

---

### 3️⃣ **3-rollback-v1.sh** - Rollback para v1
Reverte para versão anterior:
- Git revert (desfaz último commit)
- Push automático
- ArgoCD detecta e faz rollback

```bash
./3-rollback-v1.sh
```

Use **2b-force-sync.sh** depois para aplicar rollback imediato.

---

### 4️⃣ **4-argocd-info.sh** - Informações do ArgoCD
Mostra credenciais e status:
- URL do ArgoCD UI
- Username/Password
- Status das Applications
- Pods do ArgoCD

```bash
./4-argocd-info.sh
```

---

## 🎤 Roteiro de Apresentação

### **Preparação (antes da demo):**
```bash
# 1. Garantir que está em v1
cd /home/luiz7/lab-argo/gitops-eks
./scripts/demo/4-argocd-info.sh

# 2. Abrir 3 abas do navegador:
#    - Tab 1: App E-commerce (ALB)
#    - Tab 2: ArgoCD UI
#    - Tab 3: GitHub (repo gitops-argocd)
```

---

### **Durante a Apresentação:**

**1. Mostrar Estado v1 (2 min)**
```bash
./scripts/demo/1-show-v1.sh
```
- Mostrar pods v1
- Navegar no app (sem banner)
- Mostrar ArgoCD UI (Synced + Healthy)

**2. Simular Mudança e Deploy v2 (5 min)**
```bash
./scripts/demo/2-deploy-v2.sh
```
- Mostrar git push
- Abrir GitHub: mostrar commit
- Voltar ArgoCD UI: aguardar sync

**3. Forçar Sync (para acelerar)**
```bash
./scripts/demo/2b-force-sync.sh
```
- Pods v2 sendo criados
- Service mudou para v2
- Refresh app: banner aparece! 🎉

**4. Rollback (3 min)**
```bash
./scripts/demo/3-rollback-v1.sh
./scripts/demo/2b-force-sync.sh  # Force sync do rollback
```
- Git revert
- ArgoCD aplica rollback
- Banner some

---

## ⚙️ Comandos Úteis Durante Demo

### Watch em Tempo Real:
```bash
# Pods
watch kubectl get pods -n ecommerce -L version

# Application status
watch kubectl get application -n argocd

# Service selector
watch "kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}' | jq '.'"
```

### Verificações Manuais:
```bash
# Ver pods v2
kubectl get pods -n ecommerce -l version=v2

# Ver service selector
kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep -A 5 selector

# Logs do ArgoCD
kubectl logs -n argocd deployment/argocd-application-controller --tail=50
```

---

## 🔧 Troubleshooting

### **ArgoCD não detecta mudança:**
```bash
# Force refresh
kubectl delete application ecommerce-app -n argocd
kubectl apply -f /home/luiz7/lab-argo/gitops-eks/03-argocd-apps/ecommerce-app.yaml
```

### **Resetar para v1:**
```bash
cd /home/luiz7/lab-argo/gitops-eks
git reset --hard origin/main
git pull origin main
```

### **Recriar tudo do zero:**
```bash
# 1. Deletar namespace
kubectl delete namespace ecommerce

# 2. Deletar Application
kubectl delete application ecommerce-app -n argocd

# 3. Aplicar novamente
cd /home/luiz7/lab-argo/gitops-eks/03-argocd-apps
./setup.sh
```

---

## 📊 Diferencial da Apresentação

### **ANTES (GitHub Actions Manual):**
```
1. Desenvolvedor faz commit
2. CI roda automaticamente ✅
3. Desenvolvedor vai no GitHub Actions
4. Clica "Run workflow" 
5. Preenche inputs
6. Aguarda deploy
```

### **AGORA (ArgoCD GitOps):**
```
1. Desenvolvedor faz commit + push
2. ArgoCD detecta automaticamente
3. Deploy aplicado sem intervenção ✅
4. Single source of truth (Git)
```

**Destaque:** "Sem clicar em nada, apenas git push!"

---

**Projeto:** GitOps EKS com ArgoCD  
**Repositório:** https://github.com/jlui70/gitops-argocd  
**Data:** Janeiro 2026
