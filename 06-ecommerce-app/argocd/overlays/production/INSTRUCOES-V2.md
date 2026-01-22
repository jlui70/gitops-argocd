# 🚀 Como Ativar v2 - Instruções Detalhadas

## ⚠️ ATENÇÃO: Indentação YAML é CRÍTICA!

Ao descomentar as linhas, **MANTENHA EXATAMENTE 2 ESPAÇOS** antes do hífen `-`.

---

## 📝 Passo a Passo para Ativar v2

### 1️⃣ Editar arquivo
```bash
cd ~/lab-argo/gitops-argocd/06-ecommerce-app/argocd/overlays/production
vi kustomization.yaml
```

### 2️⃣ DESCOMENTAR Linhas (remover `# ` do início)

**SEÇÃO 1: Resources (linhas 11-13)**
```yaml
# ANTES (v1 - comentado):
  # - ecommerce-ui-backend.yaml
  # - ecommerce-ui-v2-proxy.yaml
  # - configmap-nginx-v2.yaml

# DEPOIS (v2 - descomentado) - ATENÇÃO: 2 ESPAÇOS ANTES DO HÍFEN:
  - ecommerce-ui-backend.yaml
  - ecommerce-ui-v2-proxy.yaml
  - configmap-nginx-v2.yaml
```

**SEÇÃO 2: Patches (linha 16)**
```yaml
# ANTES:
# patches:

# DEPOIS:
patches:
```

**SEÇÃO 3: Service Selector Patch (linhas 19-27)**
```yaml
# ANTES:
  # - patch: |-
  #     - op: replace
  #       path: /spec/selector
  #       value:
  #         app: ecommerce-ui
  #         version: v2
  #   target:
  #     kind: Service
  #     name: ecommerce-ui

# DEPOIS (ATENÇÃO: manter indentação original):
  - patch: |-
      - op: replace
        path: /spec/selector
        value:
          app: ecommerce-ui
          version: v2
    target:
      kind: Service
      name: ecommerce-ui
```

**SEÇÃO 4: Delete v1 Deployment (linhas 31-39)**
```yaml
# ANTES:
  # - patch: |-
  #     apiVersion: apps/v1
  #     kind: Deployment
  #     metadata:
  #       name: ecommerce-ui
  #     $patch: delete
  #   target:
  #     kind: Deployment
  #     name: ecommerce-ui

# DEPOIS (ATENÇÃO: manter indentação original):
  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: ecommerce-ui
      $patch: delete
    target:
      kind: Deployment
      name: ecommerce-ui
```

### 3️⃣ Salvar e sair
```
:wq
```

### 4️⃣ Commit e Push
```bash
git add kustomization.yaml
git commit -m "Deploy v2 - Ativa banner"
git push origin main
```

### 5️⃣ Aguardar ArgoCD (30-45s)
ArgoCD detecta mudanças automaticamente a cada 30 segundos.

### 6️⃣ Verificar
```bash
# Ver status
kubectl get application ecommerce-app -n argocd

# Ver pods (deve mostrar v2)
kubectl get pods -n ecommerce

# Testar ALB (deve mostrar banner)
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_URL | grep "NEW FEATURES"
```

---

## 🐛 Troubleshooting

### Erro: "did not find expected '-' indicator"
**Causa:** Indentação errada (4 espaços em vez de 2)

**Solução:**
```bash
# Verificar arquivo
cat kustomization.yaml | head -15

# Se as linhas 11-13 tiverem 4 espaços, corrigir:
vi kustomization.yaml
# Remover 2 espaços extras de cada linha descomentada
```

### ArgoCD fica "Unknown" ou "OutOfSync"
```bash
# Forçar refresh
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

---

## 🔄 Rollback para v1

1. Editar `kustomization.yaml`
2. **COMENTAR** novamente as 4 seções (adicionar `# ` no início)
3. Commit e push
4. Aguardar 30-45s
5. v1 volta (sem banner)

---

## ✅ Exemplo Completo (v2 ATIVO)

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ecommerce

resources:
  - ../../base
  - ecommerce-ui-backend.yaml
  - ecommerce-ui-v2-proxy.yaml
  - configmap-nginx-v2.yaml

patches:
  - patch: |-
      - op: replace
        path: /spec/selector
        value:
          app: ecommerce-ui
          version: v2
    target:
      kind: Service
      name: ecommerce-ui

  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: ecommerce-ui
      $patch: delete
    target:
      kind: Deployment
      name: ecommerce-ui
```
