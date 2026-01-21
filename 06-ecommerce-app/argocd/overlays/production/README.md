# Production Overlay - GitOps Demo

## 🎯 Como usar na apresentação

### Deploy v1 → v2 (Ativar banner)

Editar `kustomization.yaml`:

```bash
vi kustomization.yaml
```

**Mudanças:**

1. **Descomentar recursos v2** (linhas ~20-22):
```yaml
- ecommerce-ui-backend.yaml
- ecommerce-ui-v2-proxy.yaml
- configmap-nginx-v2.yaml
```

2. **Mudar Service selector** (linha ~32):
```yaml
version: v2  # Era v1
```

3. **Descomentar patch de delete** (linhas ~40-47):
```yaml
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

4. **Commit e push:**
```bash
git add .
git commit -m "Deploy v2 - Add promotional banner"
git push
```

5. **Aguardar 30-45s** - ArgoCD detecta e aplica automaticamente!

---

### Rollback v2 → v1 (Remover banner)

**Reverter as mudanças:**

1. **Comentar recursos v2** (adicionar # nas linhas 20-22)
2. **Mudar Service selector** para `version: v1`
3. **Comentar patch de delete** (adicionar # nas linhas 40-47)
4. **Commit e push**

---

## ✅ Vantagens

- GitOps 100% puro (ArgoCD detecta automaticamente)
- Application path FIXO (overlays/production)
- ALB preservado (DNS funcionando)
- Zero downtime

