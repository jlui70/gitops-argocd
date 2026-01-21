# Production Overlay - GitOps com ArgoCD

## 🎯 Propósito

Este overlay controla qual versão da aplicação está rodando em produção através do arquivo `kustomization.yaml`. 

**GitOps 100% Real:**
- ✅ Edita `kustomization.yaml` localmente
- ✅ Faz `git push`
- ✅ ArgoCD detecta mudança automaticamente (30s)
- ✅ Deploy acontece sem intervenção manual
- ✅ Rollback = reverter commit

---

## 🚀 Deploy v1 → v2 (Ativar Banner "NEW FEATURES")

### Estado Atual: v1 rodando
- 1 pod `ecommerce-ui-v1`
- Banner NÃO aparece

### Objetivo: Migrar para v2
- 2 pods `ecommerce-ui-backend` + `ecommerce-ui-v2-proxy`
- Banner aparece

### Passo a Passo

**1. Editar kustomization.yaml**

```bash
cd ~/gitops-argocd/06-ecommerce-app/argocd/overlays/production
vi kustomization.yaml
```

**2. Fazer 3 mudanças no arquivo:**

#### A) Descomentar recursos v2 (linhas ~20-22)

**ANTES:**
```yaml
resources:
  - ../../base
  # - ecommerce-ui-backend.yaml
  # - ecommerce-ui-v2-proxy.yaml
```

**DEPOIS:**
```yaml
resources:
  - ../../base
  - ecommerce-ui-backend.yaml
  - ecommerce-ui-v2-proxy.yaml
```

#### B) Descomentar ConfigMap v2 (linhas ~28-31)

**ANTES:**
```yaml
configMapGenerator: []
# - name: nginx-v2-config
#   files:
#     - configmap-nginx-v2.yaml
```

**DEPOIS:**
```yaml
configMapGenerator:
  - name: nginx-v2-config
    files:
      - configmap-nginx-v2.yaml
```

#### C) Descomentar patch de imagem v2 (linhas ~35-44)

**ANTES:**
```yaml
images: []
# - name: luiz7/ecommerce-ui
#   newName: luiz7/ecommerce-ui
#   newTag: v2
```

**DEPOIS:**
```yaml
images:
  - name: luiz7/ecommerce-ui
    newName: luiz7/ecommerce-ui
    newTag: v2
```

**3. Commit e Push**

```bash
git add kustomization.yaml
git commit -m "Deploy v2 - Ativa banner NEW FEATURES"
git push origin main
```

**4. Aguardar ArgoCD (30-45 segundos)**

```bash
# Acompanhar sync no terminal
kubectl get application ecommerce-app -n argocd -w

# Ou abrir ArgoCD UI:
# https://localhost:8080 (se fez port-forward)
```

**5. Validar v2 rodando**

```bash
# Ver pods v2 ativos
kubectl get pods -n ecommerce -l app=ecommerce-ui

# Testar banner no navegador
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://$ALB_URL
# Deve mostrar banner: "🚀 NEW FEATURES AVAILABLE!"
```

---

## 🔄 Rollback v2 → v1 (Remover Banner)

### Objetivo: Voltar para v1
- Remove pods v2
- Tráfego volta para v1
- Banner desaparece

### Passo a Passo

**1. Editar kustomization.yaml**

```bash
vi kustomization.yaml
```

**2. Comentar as 3 seções v2** (reverter mudanças anteriores)

#### A) Comentar recursos v2
```yaml
resources:
  - ../../base
  # - ecommerce-ui-backend.yaml
  # - ecommerce-ui-v2-proxy.yaml
```

#### B) Comentar ConfigMap v2
```yaml
configMapGenerator: []
# - name: nginx-v2-config
#   files:
#     - configmap-nginx-v2.yaml
```

#### C) Comentar imagem v2
```yaml
images: []
# - name: luiz7/ecommerce-ui
#   newName: luiz7/ecommerce-ui
#   newTag: v2
```

**3. Commit e Push**

```bash
git add kustomization.yaml
git commit -m "Rollback v1 - Remove banner"
git push origin main
```

**4. ArgoCD detecta e reverte automaticamente (30-45s)**

**5. Validar v1 rodando**

```bash
# Banner NÃO deve aparecer
curl http://$ALB_URL

# Apenas pods v1 rodando
kubectl get pods -n ecommerce -l app=ecommerce-ui
```

---

## ⚡ Características GitOps

### O que acontece automaticamente

**Durante Deploy v2:**
1. ✅ ArgoCD detecta mudança no Git (polling 30s)
2. ✅ Renderiza Kustomize com novos recursos v2
3. ✅ Cria pods `ecommerce-ui-backend` e `ecommerce-ui-v2-proxy`
4. ✅ Aguarda pods ficarem Ready
5. ✅ Altera Service selector para `version: v2`
6. ✅ Tráfego migra para v2 (Blue→Green)
7. ✅ Pods v1 continuam rodando (STANDBY)

**Durante Rollback v1:**
1. ✅ ArgoCD detecta reversão no Git
2. ✅ Altera Service selector para `version: v1`
3. ✅ Tráfego volta para v1 (Green→Blue)
4. ✅ Remove pods v2 (prune enabled)

### Vantagens

- ✅ **Zero kubectl apply manual** - Tudo via Git
- ✅ **Zero downtime** - Blue/Green deployment
- ✅ **Rollback rápido** - Reverter commit = rollback automático
- ✅ **Auditável** - Git log = histórico de deploys
- ✅ **Declarativo** - Desired state no Git
- ✅ **Self-healing** - ArgoCD corrige drift automaticamente

---

## 📊 Estrutura do Overlay

```
overlays/production/
├── kustomization.yaml           # ⭐ Arquivo principal (editar aqui)
├── ecommerce-ui-backend.yaml    # Deployment v2 backend
├── ecommerce-ui-v2-proxy.yaml   # Deployment v2 proxy (com banner)
├── configmap-nginx-v2.yaml      # Config nginx do proxy
└── README.md                    # Este arquivo
```

**Regra de ouro:** 
- Edita APENAS `kustomization.yaml` (comentar/descomentar)
- NÃO altera arquivos `*.yaml` individuais
- NÃO altera arquivos no `base/`

---

## 🔍 Troubleshooting

### ArgoCD não detectou mudança

```bash
# Forçar refresh manual
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Pods v2 não sobem

```bash
# Ver eventos
kubectl get events -n ecommerce --sort-by='.lastTimestamp' | tail -20

# Ver logs do pod
kubectl logs -n ecommerce <nome-do-pod>
```

### Banner não aparece

```bash
# Verificar selector do Service
kubectl get svc ecommerce-ui-service -n ecommerce -o yaml | grep version

# Deve mostrar: version: v2 (se v2 deployed)
```

---

## 📚 Links Úteis

- [Repositório Infraestrutura](https://github.com/jlui70/gitops-eks) - Terraform EKS + ArgoCD
- [Repositório Manifestos](https://github.com/jlui70/gitops-argocd) - Este repo (ArgoCD monitora)
- [Documentação ArgoCD](https://argo-cd.readthedocs.io/)
- [Documentação Kustomize](https://kustomize.io/)

