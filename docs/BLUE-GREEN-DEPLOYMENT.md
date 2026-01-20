# Blue/Green Deployment Strategy - Guia Completo

## 📚 Complemento ao Troubleshooting

Este documento explica por que a label `version: v1` é **essencial** neste projeto e como funciona a estratégia Blue/Green.

---

## ⚠️ ALERTA IMPORTANTE

### Por que NÃO remover `version: v1`?

Durante o troubleshooting do erro 503, a solução **inicial** foi remover a label `version: v1`. **Isso estava ERRADO!**

**Problema**: Este projeto implementa **Blue/Green Deployment** que depende dessa label.

### Correção Aplicada

✅ **Solução correta**: Manter `version: v1` mas **recriar** o Deployment (não apenas aplicar).

```bash
# ❌ ERRADO: Aplicar manifesto com selector diferente
kubectl apply -f manifests/ecommerce-ui.yaml
# Erro: "field is immutable"

# ✅ CORRETO: Deletar e recriar
kubectl delete deployment ecommerce-ui -n ecommerce
kubectl apply -f manifests/ecommerce-ui.yaml
```

---

## 🔵🟢 O QUE É BLUE/GREEN DEPLOYMENT?

### Conceito

**Definição**: Estratégia de deploy onde duas versões completas da aplicação rodam simultaneamente:

- 🔵 **Blue (v1)**: Versão atual em produção (recebe tráfego)
- 🟢 **Green (v2)**: Nova versão em staging (não recebe tráfego ainda)

### Como funciona

```
                     ┌─────────────────────┐
                     │   INGRESS (ALB)     │
                     │  eks.example.com    │
                     └──────────┬──────────┘
                                │
                    ┌───────────▼────────────┐
                    │ Service: ecommerce-ui  │
                    │ selector: version = ?? │ ← Controla tráfego
                    └───────────┬────────────┘
                                │
              ┌─────────────────┴──────────────────┐
              │                                    │
      ┌───────▼────────┐                  ┌───────▼────────┐
      │  Blue (v1)     │                  │  Green (v2)    │
      │  version: v1   │                  │  version: v2   │
      │  2 replicas    │                  │  2 replicas    │
      │  ✅ RECEBE     │                  │  ⏸️  STANDBY   │
      │     TRÁFEGO    │                  │                │
      └────────────────┘                  └────────────────┘
```

### Vantagens

✅ **Zero downtime**: Switch instantâneo entre versões  
✅ **Rollback rápido**: Reverter é só mudar selector de volta  
✅ **Teste seguro**: v2 pode ser testada sem afetar usuários  
✅ **Confidence**: v1 permanece como fallback  
✅ **Simples**: Apenas muda selector do Service

### Desvantagens

❌ **Custo 2x**: Precisa de recursos para rodar ambas versões  
❌ **Dados**: Requer database compatível com ambas versões  
❌ **All-or-nothing**: Não permite rollout gradual (use Canary para isso)

---

## 🏗️ ARQUITETURA DO PROJETO

### Estado Inicial (após deploy.sh)

```yaml
# Deployment v1 (Blue)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-ui
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ecommerce-ui
      version: v1         # ← ESSENCIAL para Blue/Green!
  template:
    metadata:
      labels:
        app: ecommerce-ui
        version: v1       # ← Pods recebem essa label
---
# Service aponta para v1
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-ui
  namespace: ecommerce
spec:
  selector:
    app: ecommerce-ui
    version: v1           # ← Roteia para pods v1
  ports:
  - port: 4000
```

### Após deploy-v2.sh

```yaml
# Deployment v2 (Green) - NOVO!
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-ui-v2  # ← Nome diferente
  namespace: ecommerce
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ecommerce-ui
      version: v2         # ← Label diferente!
  template:
    metadata:
      labels:
        app: ecommerce-ui
        version: v2
```

**Resultado**: Agora temos **4 pods** rodando:
- 2 pods v1 (Blue) ✅ recebendo tráfego
- 2 pods v2 (Green) ⏸️ em standby

### Após switch-to-v2.sh

**O que muda**: Apenas o **selector do Service**!

```bash
# Comando executado pelo script
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v2"}}}'
```

**Service agora**:
```yaml
spec:
  selector:
    app: ecommerce-ui
    version: v2           # ← Mudou de v1 para v2!
  ports:
  - port: 4000
```

**Resultado**:
- Tráfego muda **instantaneamente** de v1 → v2
- v1 continua rodando (para rollback se necessário)
- v2 agora está em produção ✅

### Após rollback-to-v1.sh

```bash
# Reverte selector para v1
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v1"}}}'
```

**Resultado**:
- Tráfego volta para v1 instantaneamente
- v2 continua rodando (pode ser deletada depois)

---

## 🚀 PASSO A PASSO COMPLETO

### 1️⃣ Estado Inicial (v1 em produção)

```bash
# Ver deployment v1
kubectl get deployment ecommerce-ui -n ecommerce

# Ver pods v1
kubectl get pods -n ecommerce -l version=v1 --show-labels

# Verificar selector do Service
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}'
# Output: {"app":"ecommerce-ui","version":"v1"}

# Acessar aplicação
curl http://eks.devopsproject.com.br
# Aplicação sem banner roxo (v1)
```

---

### 2️⃣ Deploy da Versão 2 (Green)

```bash
cd 06-ecommerce-app

# Executar script de deploy v2
./deploy-v2.sh
```

**O que o script faz**:
1. ✅ Aplica ConfigMap do NGINX (banner roxo, endpoint /api/version)
2. ✅ Cria Deployment `ecommerce-ui-backend` (app original)
3. ✅ Cria Deployment `ecommerce-ui-v2` (NGINX proxy)
4. ✅ Aguarda pods ficarem Ready

**Resultado**:
```bash
# Listar todos os deployments
kubectl get deployments -n ecommerce -l app=ecommerce-ui

NAME                    READY   UP-TO-DATE   AVAILABLE   AGE
ecommerce-ui            2/2     2            2           1h    ← v1 (Blue)
ecommerce-ui-v2         2/2     2            2           30s   ← v2 (Green)
ecommerce-ui-backend    2/2     2            2           30s   ← Backend v2

# Ver pods
kubectl get pods -n ecommerce -l app=ecommerce-ui --show-labels

NAME                           READY   STATUS    LABELS
ecommerce-ui-xxx               1/1     Running   app=ecommerce-ui,version=v1
ecommerce-ui-xxx               1/1     Running   app=ecommerce-ui,version=v1
ecommerce-ui-v2-xxx            1/1     Running   app=ecommerce-ui,version=v2
ecommerce-ui-v2-xxx            1/1     Running   app=ecommerce-ui,version=v2
ecommerce-ui-backend-xxx       1/1     Running   app=ecommerce-ui-backend
ecommerce-ui-backend-xxx       1/1     Running   app=ecommerce-ui-backend
```

**Importante**: Service ainda aponta para v1, então usuários NÃO veem mudanças!

---

### 3️⃣ Testar v2 Antes do Switch (Opcional mas Recomendado)

```bash
# Port-forward para pod v2 (testar localmente)
POD_V2=$(kubectl get pod -n ecommerce -l version=v2 -o jsonpath='{.items[0].metadata.name}')
kubectl port-forward -n ecommerce $POD_V2 8080:4000

# Abrir no navegador: http://localhost:8080
# Deve ver banner roxo: "🚀 VERSION 2.0 - NEW FEATURES ENABLED! 🚀"

# Testar endpoint novo
curl http://localhost:8080/api/version
# {"version":"2.0.0","deployed":"2026-01-20","features":["banner","health-check"]}

# Testar health check
curl http://localhost:8080/health
# {"status":"healthy","timestamp":"2026-01-20T12:00:00Z"}

# Ctrl+C para parar port-forward
```

**Se v2 está OK**: Prosseguir para switch  
**Se v2 tem problemas**: Corrigir antes de fazer switch

---

### 4️⃣ Switch de Tráfego (v1 → v2)

```bash
# Executar script de switch
./switch-to-v2.sh
```

**O que o script faz**:
1. ✅ Verifica se v2 está healthy (todos pods Ready)
2. ⚠️ Pede confirmação do usuário
3. 🔄 Muda selector do Service: `version: v1` → `version: v2`
4. ⏳ Aguarda propagação (10s)
5. 🧪 Testa endpoint público

**Saída do script**:
```
╔═══════════════════════════════════════════════════════════════╗
║      🔄 SWITCHING TRAFFIC: v1 → v2                           ║
╚═══════════════════════════════════════════════════════════════╝

✅ v2 está healthy (2/2 replicas)

⚠️  Esta ação irá redirecionar TODO o tráfego de v1 para v2

Deseja continuar? (S/n): S

🔄 Switching traffic...

service/ecommerce-ui patched

✅ Tráfego redirecionado para v2!

⏳ Aguardando propagação (10s)...

🧪 Testando endpoint público...
ALB URL: http://k8s-ecommerc-ecommerc-f905cb5bda-1212578790.us-east-1.elb.amazonaws.com

Testando /api/version:
{
  "version": "2.0.0",
  "deployed": "2026-01-20",
  "features": ["banner", "health-check"]
}

╔═══════════════════════════════════════════════════════════════╗
║              ✅ TRAFFIC SWITCHED TO V2!                       ║
╚═══════════════════════════════════════════════════════════════╝

📊 Status atual:
NAME                           READY   STATUS    AGE
ecommerce-ui-xxx               1/1     Running   1h     ← v1 (não recebe mais tráfego)
ecommerce-ui-xxx               1/1     Running   1h
ecommerce-ui-v2-xxx            1/1     Running   5m     ← v2 (agora em produção!)
ecommerce-ui-v2-xxx            1/1     Running   5m

🌐 Acesse a aplicação:
   http://eks.devopsproject.com.br

👀 Você deve ver o banner: '🚀 VERSION 2.0 - NEW FEATURES ENABLED! 🚀'

🔙 Para fazer rollback:
   ./rollback-to-v1.sh
```

**Validar**:
```bash
# Acessar aplicação no navegador
# Deve ver banner roxo no topo

# Ou via curl
curl http://eks.devopsproject.com.br/api/version
```

---

### 5️⃣ Monitoramento Pós-Switch

```bash
# Ver métricas dos pods v2
kubectl top pods -n ecommerce -l version=v2

# Ver logs do NGINX
kubectl logs -f -n ecommerce -l version=v2

# Ver eventos
kubectl get events -n ecommerce --sort-by='.lastTimestamp' | grep ecommerce-ui

# Verificar health checks
POD_V2=$(kubectl get pod -n ecommerce -l version=v2 -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n ecommerce $POD_V2 -- wget -qO- http://127.0.0.1:4000/health
```

**Indicadores de sucesso**:
- ✅ Pods v2 sem restarts
- ✅ Logs sem erros
- ✅ CPU/Memória estáveis
- ✅ Health check retorna 200 OK
- ✅ Usuários veem v2 (banner roxo)

---

### 6️⃣ Rollback (se necessário)

**Cenários para rollback**:
- ❌ Bugs descobertos em v2
- ❌ Performance pior que v1
- ❌ Reclamações de usuários
- ❌ Erro não previsto

```bash
# Executar script de rollback
./rollback-to-v1.sh
```

**O que o script faz**:
1. ⚠️ Pede motivo do rollback (documentação)
2. ⚠️ Pede confirmação
3. 🔄 Muda selector do Service: `version: v2` → `version: v1`
4. ⏳ Aguarda propagação
5. ✅ Valida que v1 está respondendo

**Saída do script**:
```
╔═══════════════════════════════════════════════════════════════╗
║      🔙 ROLLBACK: v2 → v1                                    ║
╚═══════════════════════════════════════════════════════════════╝

⚠️  ROLLBACK ALERT!

Motivo do rollback: Bug na renderização do banner em mobile

📝 Motivo: Bug na renderização do banner em mobile

Deseja prosseguir com o rollback? (S/n): S

🔄 Executando rollback...

service/ecommerce-ui patched

✅ Tráfego redirecionado para v1!

⏳ Aguardando propagação (10s)...

🧪 Validando rollback...
✅ v1 respondendo: ecommerce-ui-885d9c485-97t9h

╔═══════════════════════════════════════════════════════════════╗
║            ✅ ROLLBACK CONCLUÍDO!                             ║
╚═══════════════════════════════════════════════════════════════╝

📊 Status atual:
NAME                           READY   STATUS    AGE
ecommerce-ui-xxx               1/1     Running   1h     ← v1 (voltou a produção)
ecommerce-ui-xxx               1/1     Running   1h
ecommerce-ui-v2-xxx            1/1     Running   10m    ← v2 (standby novamente)
ecommerce-ui-v2-xxx            1/1     Running   10m

🌐 Aplicação voltou para v1

📝 Log do rollback:
   Data: 2026-01-20 12:15:30
   Motivo: Bug na renderização do banner em mobile
   v2 ainda está rodando (pode ser removida com kubectl delete)

🗑️  Para remover v2 completamente:
   kubectl delete deployment ecommerce-ui-v2 -n ecommerce
   kubectl delete deployment ecommerce-ui-backend -n ecommerce
   kubectl delete service ecommerce-ui-v2 -n ecommerce
   kubectl delete service ecommerce-ui-backend -n ecommerce
```

**Vantagem**: Rollback em **segundos**, não minutos!

---

### 7️⃣ Cleanup (após confirmar v1 está OK)

```bash
# Remover v2 completamente
kubectl delete deployment ecommerce-ui-v2 -n ecommerce
kubectl delete deployment ecommerce-ui-backend -n ecommerce
kubectl delete service ecommerce-ui-v2 -n ecommerce
kubectl delete service ecommerce-ui-backend -n ecommerce
kubectl delete configmap nginx-v2-config -n ecommerce

# Verificar que só v1 ficou
kubectl get all -n ecommerce -l app=ecommerce-ui
```

---

## 🔍 TROUBLESHOOTING DA ESTRATÉGIA

### Problema 1: "Removi version: v1, agora scripts não funcionam!"

**Sintoma**:
```bash
./switch-to-v2.sh
# Service não encontra pods v1
# Rollback impossível
```

**Causa**: Deployment v1 foi criado SEM label `version: v1`

**Solução**:
```bash
# 1. Verificar se manifesto tem version: v1
cat manifests/ecommerce-ui.yaml | grep version

# 2. Se não tiver, adicionar:
spec:
  selector:
    matchLabels:
      app: ecommerce-ui
      version: v1         # ← Adicionar
  template:
    metadata:
      labels:
        app: ecommerce-ui
        version: v1       # ← Adicionar

# 3. IMPORTANTE: Não pode apenas aplicar (selector é imutável)
# Precisa deletar e recriar!
kubectl delete deployment ecommerce-ui -n ecommerce
kubectl apply -f manifests/ecommerce-ui.yaml

# 4. Verificar labels
kubectl get pods -n ecommerce --show-labels | grep version=v1
```

---

### Problema 2: "Switch não muda nada, usuários ainda veem v1"

**Sintoma**: Executou `switch-to-v2.sh` mas usuários não veem banner roxo

**Possíveis causas**:

#### Causa A: Cache do navegador
```bash
# Testar com curl (sem cache)
curl -I http://eks.devopsproject.com.br
# Deve ter header: X-Version: 2.0 (se configurado)

# Ou forçar refresh: Ctrl+Shift+R (Chrome) / Cmd+Shift+R (Mac)
```

#### Causa B: Service não mudou selector
```bash
# Verificar selector atual
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}'

# Se ainda está em v1, mudar manualmente:
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v2"}}}'
```

#### Causa C: Pods v2 não estão Ready
```bash
# Ver pods v2
kubectl get pods -n ecommerce -l version=v2

# Se não estão Ready, ver por quê
kubectl describe pod <pod-v2-name> -n ecommerce
kubectl logs <pod-v2-name> -n ecommerce
```

---

### Problema 3: "Rollback não funciona"

**Sintoma**: Executou `rollback-to-v1.sh` mas erro 503

**Possíveis causas**:

#### Causa A: Pods v1 foram deletados
```bash
# Verificar se v1 existe
kubectl get pods -n ecommerce -l version=v1

# Se vazio, v1 foi deletada! Precisa fazer rollback do deployment:
kubectl rollout undo deployment/ecommerce-ui -n ecommerce
```

#### Causa B: Service selector não voltou
```bash
# Verificar selector
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}'

# Forçar v1:
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v1"}}}'
```

---

### Problema 4: "Deploy v2 falha com 'already exists'"

**Sintoma**:
```
./deploy-v2.sh
Error: deployment "ecommerce-ui-v2" already exists
```

**Causa**: v2 já foi deployada antes (não foi removida após rollback)

**Solução**:
```bash
# Opção 1: Remover v2 antiga e fazer novo deploy
kubectl delete deployment ecommerce-ui-v2 -n ecommerce
kubectl delete deployment ecommerce-ui-backend -n ecommerce
./deploy-v2.sh

# Opção 2: Atualizar v2 existente (se só mudou código)
kubectl set image deployment/ecommerce-ui-v2 \
  nginx-proxy=nginx:1.25-alpine -n ecommerce
kubectl rollout restart deployment/ecommerce-ui-v2 -n ecommerce
```

---

## 📊 COMANDOS ÚTEIS

### Visualizar Estado da Estratégia

```bash
# Ver todas as versões rodando
kubectl get deployments -n ecommerce -l app=ecommerce-ui

# Ver pods separados por versão
kubectl get pods -n ecommerce -l version=v1
kubectl get pods -n ecommerce -l version=v2

# Ver qual versão está em produção (selector do Service)
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}' | jq

# Ver endpoints de cada versão
kubectl get endpoints -n ecommerce

# Dashboard completo
kubectl get all -n ecommerce -l app=ecommerce-ui -o wide
```

### Monitoramento

```bash
# Métricas por versão
kubectl top pods -n ecommerce -l version=v1
kubectl top pods -n ecommerce -l version=v2

# Logs em tempo real
kubectl logs -f -n ecommerce -l version=v1
kubectl logs -f -n ecommerce -l version=v2

# Comparar consumo
echo "=== v1 ===" && kubectl top pods -n ecommerce -l version=v1
echo "=== v2 ===" && kubectl top pods -n ecommerce -l version=v2
```

### Testes

```bash
# Testar v1 diretamente (bypass Service)
kubectl run test-v1 --image=curlimages/curl -i --rm --restart=Never -- \
  curl -s ecommerce-ui.ecommerce.svc.cluster.local:4000

# Testar v2 diretamente
kubectl run test-v2 --image=curlimages/curl -i --rm --restart=Never -- \
  curl -s ecommerce-ui-v2.ecommerce.svc.cluster.local:4000

# Port-forward para testar localmente
kubectl port-forward -n ecommerce svc/ecommerce-ui 8080:4000     # v1
kubectl port-forward -n ecommerce svc/ecommerce-ui-v2 8081:4000  # v2
```

---

## 📖 LIÇÕES APRENDIDAS

### 1. Labels são Fundamentais

✅ **DO**: Planejar labels desde o início  
✅ **DO**: Usar labels semânticas (`version: v1`, `version: v2`)  
❌ **DON'T**: Mudar labels depois (selector é imutável)  
❌ **DON'T**: Remover labels sem entender impacto

### 2. Selector é Imutável

✅ **DO**: Deletar e recriar se precisa mudar selector  
❌ **DON'T**: Tentar `kubectl apply` com selector diferente  
💡 **TIP**: Use `kubectl delete` + `kubectl apply`, não `replace --force`

### 3. Testar Antes de Fazer Switch

✅ **DO**: Usar port-forward para testar v2 localmente  
✅ **DO**: Validar health checks e endpoints novos  
✅ **DO**: Fazer smoke tests em v2 antes do switch  
❌ **DON'T**: Fazer switch sem validar v2

### 4. Documentar Rollbacks

✅ **DO**: Sempre registrar motivo do rollback  
✅ **DO**: Manter log de deploys e rollbacks  
💡 **TIP**: Script `rollback-to-v1.sh` já pede motivo!

### 5. Monitorar Pós-Switch

✅ **DO**: Observar métricas por 15-30 minutos após switch  
✅ **DO**: Ter alertas configurados (CPU, erros, latência)  
✅ **DO**: Manter v1 rodando até ter certeza  
❌ **DON'T**: Deletar v1 logo após switch

---

## 🎯 RESUMO EXECUTIVO

### Para Apresentar em Aulas

> "Este projeto usa **Blue/Green Deployment** para fazer updates com zero downtime:
>
> 1. **Deploy v2**: Cria nova versão ao lado da v1 (ambas rodando)
> 2. **Test v2**: Valida nova versão sem afetar usuários
> 3. **Switch**: Muda selector do Service (`version: v1` → `v2`)
> 4. **Monitor**: Observa métricas da v2 em produção
> 5. **Rollback**: Se necessário, volta para v1 em segundos
> 6. **Cleanup**: Remove v1 depois de confirmar v2 OK
>
> **Vantagem**: Rollback instantâneo (só muda selector!)  
> **Desvantagem**: Precisa de 2x recursos (duas versões rodando)
>
> ⚠️ **CRÍTICO**: Label `version: v1` é ESSENCIAL para essa estratégia funcionar!"

---

*Documento criado para fins educacionais - GitOps EKS Project*  
*Última atualização: Janeiro 2026*
