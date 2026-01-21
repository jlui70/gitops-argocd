# 🎯 ArgoCD Auto-Sync - Production Safe Solution

## ❌ Problema Identificado

**O que NÃO funciona (método anterior):**
```bash
kubectl delete application ecommerce-app -n argocd
kubectl apply -f 03-argocd-apps/ecommerce-app.yaml
```

**Por quê NÃO funciona:**
1. ❌ Deleta o Ingress → Recria novo ALB com URL diferente
2. ❌ Quebra o DNS (`eks.devopsproject.com.br` CNAME aponta para ALB antigo)
3. ❌ Aplicação fica fora do ar até atualizar o DNS
4. ❌ **NÃO é GitOps real** - requer intervenção manual

---

## ✅ Solução Implementada

### Configurações ArgoCD

**1. Polling Rápido (30 segundos)**
```bash
kubectl patch configmap argocd-cm -n argocd --type merge \
  -p '{"data":{"timeout.reconciliation":"30s"}}'
```

**2. Hard Refresh na Application**
```yaml
# 03-argocd-apps/ecommerce-app.yaml
metadata:
  annotations:
    argocd.argoproj.io/refresh: hard
```

**3. Restart dos Pods ArgoCD**
```bash
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart deployment argocd-server -n argocd
```

---

## 🎬 Fluxos de Deploy

### Opção 1: Auto-Sync Automático (Recomendado)

**Aguardar ~30-45 segundos**

```bash
# 1. Alterar path na Application
kubectl patch application ecommerce-app -n argocd --type merge \
  --patch '{"spec":{"source":{"path":"06-ecommerce-app/argocd/overlays/v2"}}}'

# 2. Aguardar 45 segundos (ArgoCD faz polling a cada 30s)
sleep 45

# 3. Verificar status
kubectl get application ecommerce-app -n argocd
kubectl get pods -n ecommerce -L version
```

**✅ Resultado:**
- Application: Synced e Healthy
- Pods v2 rodando (backend + proxy)
- ALB preservado: `k8s-ecommerc-ecommerc-f905cb5bda-1356497416...`
- DNS funcionando: `eks.devopsproject.com.br`

---

### Opção 2: Manual Sync via UI (Alternativa)

**Instantâneo - Sem esperar**

```bash
# 1. Alterar path na Application
kubectl patch application ecommerce-app -n argocd --type merge \
  --patch '{"spec":{"source":{"path":"06-ecommerce-app/argocd/overlays/v2"}}}'

# 2. Abrir ArgoCD UI
# URL: http://k8s-argocd-argocdse-d33c7d0358-722224aad9442902.elb.us-east-1.amazonaws.com
# User: admin
# Pass: n-cTptt61OW75sv1

# 3. Na UI:
#    - Clicar em REFRESH (atualiza do Git)
#    - Clicar em SYNC (aplica mudanças)
```

**✅ Resultado:**
- Sync instantâneo
- ALB preservado
- DNS funcionando

---

### Opção 3: Force Sync via Script (Emergência)

```bash
./scripts/demo/force-sync-safe.sh
```

**O que faz:**
1. Adiciona annotation para hard refresh
2. Triggera sync via kubectl patch
3. Aguarda 10s e verifica status
4. **NÃO deleta a Application**

---

## 📊 Comparação: Antes vs Depois

| Aspecto | ❌ Antes (Delete) | ✅ Depois (Patch) |
|---------|------------------|-------------------|
| **ALB** | Recriado (novo URL) | Preservado (mesmo URL) |
| **DNS** | Quebra (CNAME inválido) | Funciona (CNAME válido) |
| **Downtime** | Sim (até update DNS) | Não |
| **GitOps** | Não (manual) | Sim (automático) |
| **Tempo sync** | Instantâneo | 30-45s |
| **Apresentação** | ❌ Falha | ✅ Aprovado |

---

## 🧪 Script de Teste Completo

```bash
./scripts/demo/test-auto-sync.sh
```

**O que testa:**
1. Switch v1 → v2 via patch (sem delete)
2. Aguarda 45s para auto-sync
3. Verifica pods v2 rodando
4. Confirma ALB não mudou
5. Valida DNS permanece funcional

---

## 📝 Demo para Apresentação

### Fluxo Recomendado:

**1. Mostrar v1 rodando**
```bash
./scripts/demo/1-show-v1.sh
# Acessar: eks.devopsproject.com.br
# Resultado: Sem banner
```

**2. Fazer deploy v2**
```bash
./scripts/demo/2-deploy-v2.sh
# Aguardar ~45 segundos (mostrar logs do ArgoCD)
```

**3. Verificar v2 ativo**
```bash
# Acessar: eks.devopsproject.com.br
# Resultado: Banner "Frete Grátis" aparece
kubectl get pods -n ecommerce -L version
```

**4. Mostrar ALB preservado**
```bash
kubectl get ingress -n ecommerce
# Confirmar URL do ALB não mudou
```

---

## ⚡ Comandos Úteis

### Ver status do sync
```bash
kubectl get application ecommerce-app -n argocd -w
```

### Ver logs do ArgoCD
```bash
kubectl logs -n argocd deployment/argocd-repo-server -f
```

### Forçar refresh
```bash
kubectl annotate application ecommerce-app -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

### Ver histórico de deploys
```bash
kubectl get application ecommerce-app -n argocd -o yaml | grep -A 10 history
```

---

## 🎓 Explicação Técnica

### Por que funciona agora?

**1. Polling Configurado (30s)**
- ArgoCD verifica Git a cada 30 segundos
- Detecta mudança no path da Application
- Inicia sync automático

**2. Hard Refresh Annotation**
- Ignora cache do repo-server
- Força Git fetch direto do repositório
- Garante estado mais recente

**3. Application Não Deletada**
- Ingress não é recriado
- ALB permanece o mesmo
- DNS (CNAME) continua válido

### Fluxo Interno:

```
User altera path → ArgoCD detecta (30s) → Hard refresh do Git 
→ Compara manifests → Aplica diff → Pods atualizam 
→ ALB preservado → DNS funciona ✅
```

---

## 🚀 Vantagens da Solução

✅ **GitOps Real:** Deploy automático sem intervenção  
✅ **Zero Downtime:** ALB preservado, DNS funcional  
✅ **Production Safe:** Não recria recursos críticos  
✅ **Auditável:** Histórico no ArgoCD  
✅ **Rollback Fácil:** Só alterar path de volta  
✅ **Demo Friendly:** Funciona na apresentação  

---

## 📌 Importante

**NUNCA USE:**
```bash
kubectl delete application ecommerce-app -n argocd  # ❌ QUEBRA DNS
```

**SEMPRE USE:**
```bash
kubectl patch application ecommerce-app -n argocd ...  # ✅ PRESERVA DNS
```

---

## ✅ Checklist de Validação

Antes de apresentar, verificar:

- [ ] ArgoCD polling configurado (30s)
- [ ] Hard refresh annotation presente
- [ ] Application em estado Synced
- [ ] ALB preservado após deploys
- [ ] DNS resolvendo corretamente
- [ ] Scripts de demo funcionando
- [ ] v1 → v2 → v1 testado

---

**Solução validada em:** 21/01/2026  
**Configuração final:** Polling 30s + Hard Refresh  
**Status:** ✅ APROVADO PARA PRODUÇÃO
