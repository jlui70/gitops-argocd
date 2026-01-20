# Troubleshooting de Erro 503 no EKS - Caso Real de Estudo

## 📚 Guia Completo para Aulas de Troubleshooting

Este documento apresenta um **caso real** de troubleshooting de aplicação em EKS, demonstrando metodologia, comandos e técnicas para diagnosticar e resolver problemas de conectividade.

---

## 🚨 PROBLEMA REPORTADO

### Sintoma Inicial

```
URL: http://k8s-ecommerc-ecommerc-f905cb5bda-1212578790.us-east-1.elb.amazonaws.com/
Erro: HTTP 503 Service Unavailable
```

**Contexto**:
- ✅ Deploy executado com sucesso (sem erros críticos)
- ✅ Todos os pods mostravam status `Running`
- ✅ ALB provisionado e acessível
- ❌ Aplicação não responde (503)

### O que é HTTP 503?

**Definição**: "Service Unavailable" - O Load Balancer está funcionando mas **não consegue** entregar a requisição para os backends.

**Causas comuns**:
- ❌ Nenhum target saudável no Target Group
- ❌ Pods não estão prontos para receber tráfego
- ❌ Health check falhando
- ❌ Problemas de rede/Security Groups

---

## 🔍 METODOLOGIA DE TROUBLESHOOTING

### Abordagem Top-Down (da camada mais alta para baixo)

```
Internet → ALB → Target Group → Service → Endpoints → Pods → Container
   ↑         ↑         ↑            ↑          ↑          ↑        ↑
   OK       OK?      Vazio?      OK?       Vazio?     OK?    Rodando?
```

**Estratégia**: Começar validando cada camada até encontrar onde está quebrado.

---

## 📋 PASSO A PASSO DA INVESTIGAÇÃO

### PASSO 1: Validar Estado dos Pods

**Objetivo**: Confirmar que os pods estão rodando.

#### Comando Usado:
```bash
kubectl get pods -n ecommerce
```

#### Saída Obtida:
```
NAME                                     READY   STATUS    RESTARTS   AGE
contact-support-team-5994b9df87-h8gqc    1/1     Running   0          24m
ecommerce-ui-7678c74958-d2rpx            1/1     Running   0          24m
ecommerce-ui-7678c74958-xq6r4            1/1     Running   0          24m
order-management-548fc9f65c-swxkh        1/1     Running   0          24m
product-catalog-64fbd65d58-kkrss         1/1     Running   0          24m
product-inventory-5bd688f46-qb554        1/1     Running   0          24m
profile-management-55c6595b8d-tnwpm      1/1     Running   0          24m
shipping-and-handling-77ff6d4bf9-t8tvb   1/1     Running   0          24m
```

#### Análise:
✅ **Todos os pods**: `READY 1/1`, `STATUS Running`  
✅ **Conclusão**: Pods estão saudáveis

**O que procurar**:
- ❌ `CrashLoopBackOff` → Container morrendo repetidamente
- ❌ `ImagePullBackOff` → Não consegue baixar imagem
- ❌ `Pending` → Não consegue agendar em node
- ❌ `Error` → Algum erro na execução
- ❌ `READY 0/1` → Container não passou readiness probe

---

### PASSO 2: Validar Configuração do Ingress

**Objetivo**: Verificar como o Ingress está configurado e se o ALB foi criado.

#### Comando Usado:
```bash
kubectl get ingress -n ecommerce -o yaml
```

#### Saída Relevante:
```yaml
spec:
  rules:
  - host: eks.devopsproject.com.br
    http:
      paths:
      - backend:
          service:
            name: ecommerce-ui
            port:
              number: 4000  # ← Ingress espera porta 4000
        path: /
        pathType: Prefix
status:
  loadBalancer:
    ingress:
    - hostname: k8s-ecommerc-ecommerc-f905cb5bda-1212578790.us-east-1.elb.amazonaws.com
```

#### Análise:
✅ **ALB criado**: Hostname presente  
✅ **Rota configurada**: `/` → `ecommerce-ui:4000`  
✅ **Conclusão**: Ingress configurado corretamente

**O que procurar**:
- ❌ `loadBalancer: {}` (vazio) → ALB não provisionado
- ❌ Service name errado no backend
- ❌ Porta errada no backend
- ❌ Annotations incorretas

---

### PASSO 3: Validar Service

**Objetivo**: Verificar se o Service está configurado corretamente.

#### Comando Usado:
```bash
kubectl get svc ecommerce-ui -n ecommerce -o yaml
```

#### Saída Relevante:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-ui
  namespace: ecommerce
spec:
  clusterIP: 172.20.73.114
  ports:
  - name: http
    port: 4000          # ← Service expõe porta 4000
    protocol: TCP
    targetPort: 4000    # ← Encaminha para porta 4000 do container
  selector:
    app: ecommerce-ui   # ← Busca pods com essas labels
    version: v1         # ← IMPORTANTE: Busca version=v1 também!
  type: ClusterIP
```

#### Análise:
✅ **Porta correta**: 4000 → 4000  
⚠️ **Selector suspeito**: Busca `app=ecommerce-ui` **E** `version=v1`  
❓ **Dúvida**: Os pods têm ambas as labels?

**O que procurar**:
- ❌ ClusterIP vazio → Service não criou IP
- ❌ Porta errada (ex: Service na 4000 mas container na 3000)
- ❌ Selector não bate com labels dos pods
- ❌ Type errado (deve ser ClusterIP para Ingress)

---

### PASSO 4: Verificar Logs do ALB Controller (🔍 INVESTIGAÇÃO PROFUNDA)

**Objetivo**: Ver se há erros na criação/manutenção do ALB.

#### Comando Usado:
```bash
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=30
```

#### Saída Obtida:
```json
{"level":"info","msg":"successfully deployed model","ingressGroup":"ecommerce/ecommerce-ingress"}
{"level":"info","msg":"created targetGroup","arn":"arn:aws:elasticloadbalancing:..."}
{"level":"info","msg":"created loadBalancer","arn":"arn:aws:elasticloadbalancing:..."}
{"level":"info","msg":"Successfully reconciled","tgb":{"name":"k8s-ecommerc-ecommerc-42ff35d27a"}}
```

#### Análise:
✅ **Target Group criado**  
✅ **Load Balancer criado**  
✅ **Reconciliation bem-sucedida**  
✅ **Conclusão**: ALB Controller funcionando normalmente

**O que procurar**:
- ❌ Erros de permissão IAM
- ❌ Subnet não encontrada
- ❌ Security Group não criado
- ❌ Failed to reconcile

---

### PASSO 5: Verificar Endpoints do Service (🎯 MOMENTO EUREKA!)

**Objetivo**: Validar se o Service conseguiu encontrar os pods.

#### Comando Usado:
```bash
kubectl get endpoints ecommerce-ui -n ecommerce
```

#### Saída Obtida:
```
NAME           ENDPOINTS   AGE
ecommerce-ui   <none>      24m
```

#### Análise:
❌ **ENDPOINTS: `<none>`** → **PROBLEMA ENCONTRADO!**  
❌ Service **NÃO está encontrando** os pods  
❌ ALB não tem targets para rotear tráfego  
❌ **Causa do erro 503 identificada!**

**O que são Endpoints?**

Endpoints são os **IPs dos pods** que o Service deve rotear tráfego. Quando você cria um Service, o Kubernetes automaticamente:

1. Busca pods com labels que batem com o `selector`
2. Cria objetos `Endpoints` com os IPs desses pods
3. Mantém essa lista atualizada dinamicamente

Se `ENDPOINTS: <none>`, significa que **nenhum pod foi encontrado** com as labels esperadas.

**Comando para comparar**:
```bash
# Ver todos os endpoints
kubectl get endpoints -n ecommerce

# Saída esperada (para serviços funcionando):
NAME                    ENDPOINTS         AGE
contact-support-team    10.0.1.121:8000   25m  ✅
ecommerce-ui            <none>            25m  ❌
order-management        10.0.1.89:9090    25m  ✅
product-catalog         10.0.1.90:3001    25m  ✅
```

---

### PASSO 6: Comparar Labels dos Pods vs Selector do Service

**Objetivo**: Identificar o mismatch entre labels.

#### Comando Usado:
```bash
kubectl get pods -n ecommerce --show-labels | grep ecommerce-ui
```

#### Saída Obtida:
```
ecommerce-ui-7678c74958-d2rpx   1/1   Running   0   25m   app=ecommerce-ui,pod-template-hash=7678c74958
ecommerce-ui-7678c74958-xq6r4   1/1   Running   0   25m   app=ecommerce-ui,pod-template-hash=7678c74958
```

#### Análise das Labels:

**Labels nos Pods**:
- ✅ `app=ecommerce-ui`
- ❌ `version=v1` (NÃO existe!)

**Selector no Service** (do PASSO 3):
- ✅ `app=ecommerce-ui`
- ❌ `version=v1` (exigido mas não existe!)

**🎯 CAUSA RAIZ IDENTIFICADA**: Service busca pods com `app=ecommerce-ui` **E** `version=v1`, mas os pods só têm `app=ecommerce-ui`.

---

### PASSO 7: Investigar o Deployment

**Objetivo**: Entender por que o Deployment não criou pods com a label `version: v1`.

#### Comando Usado:
```bash
kubectl get deployment ecommerce-ui -n ecommerce -o yaml | grep -A 10 "selector:"
```

#### Saída Obtida:
```yaml
selector:
  matchLabels:
    app: ecommerce-ui
    # ← Nota: NO deployment atual, o selector NÃO tem version: v1
```

#### Analisando o Manifesto Original:

```yaml
# Arquivo: manifests/ecommerce-ui.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-ui
spec:
  selector:
    matchLabels:
      app: ecommerce-ui
      version: v1         # ← Manifesto QUER version: v1
  template:
    metadata:
      labels:
        app: ecommerce-ui
        version: v1       # ← Pods DEVERIAM ter version: v1
```

**🔍 O que aconteceu?**

1. **Deploy inicial**: Deployment foi criado SEM `version: v1` no selector
2. **Tentativa de update**: Usuário rodou `kubectl apply` com manifesto contendo `version: v1`
3. **Erro "field is immutable"**: Kubernetes **rejeitou** a mudança do selector
4. **Resultado**: Deployment mantém selector antigo, pods não têm `version: v1`

#### Verificando Mensagem de Erro Original:

```
The Deployment "ecommerce-ui" is invalid: spec.selector: Invalid value: 
v1.LabelSelector{MatchLabels:map[string]string{"app":"ecommerce-ui", "version":"v1"}, 
MatchExpressions:[]v1.LabelSelectorRequirement(nil)}: field is immutable
```

**Tradução**: "Você tentou mudar o `selector` de um Deployment existente, mas isso não é permitido!"

---

### PASSO 8: Validar Target Group Binding

**Objetivo**: Confirmar que o problema está mesmo nos endpoints, não no ALB.

#### Comando Usado:
```bash
kubectl describe targetgroupbindings -n ecommerce
```

#### Saída Relevante:
```yaml
Name:         k8s-ecommerc-ecommerc-42ff35d27a
Spec:
  Service Ref:
    Name:            ecommerce-ui
    Port:            4000
  Target Group ARN:  arn:aws:elasticloadbalancing:us-east-1:...
  Target Type:       ip
Status:
  Observed Generation:  1
Events:
  Type    Reason                  Age   From                Message
  ----    ------                  ----  ----                -------
  Normal  SuccessfullyReconciled  24m   targetGroupBinding  Successfully reconciled
```

#### Análise:
✅ **TargetGroupBinding criado**: AWS sabe que deve registrar targets  
✅ **Service Ref correto**: Aponta para `ecommerce-ui:4000`  
⚠️ **MAS**: Como Service não tem endpoints, não há IPs para registrar no Target Group  
❌ **Resultado**: Target Group sem targets saudáveis → 503

**Verificação na AWS Console**:
- EC2 → Target Groups → `k8s-ecommerc-ecommerc-42ff35d27a`
- Aba "Targets": **0 healthy targets** (ou todos unhealthy)

---

## 🛠️ SOLUÇÃO APLICADA

### ⚠️ IMPORTANTE: Projeto usa Blue/Green Deployment

**NOTA CRÍTICA**: Este projeto implementa estratégia **Blue/Green** que depende das labels `version: v1` e `version: v2`.

**Por que precisamos manter `version: v1`**:
- Scripts `switch-to-v2.sh` e `rollback-to-v1.sh` alteram o selector do Service
- Selector muda entre `version: v1` (atual) ↔ `version: v2` (nova versão)
- Sem `version: v1`, a estratégia de deployment falha

**Solução Correta**: Manter `version: v1` mas **recriar** o Deployment (não apenas aplicar).

### Estratégia de Correção

**Situação inicial**:
- Deployment criado SEM `version: v1`
- Manifesto tentou adicionar `version: v1` via `kubectl apply`
- Kubernetes rejeitou: "field is immutable"
- Resultado: Pods sem label, Service não encontra endpoints → 503

### Passo 1: Editar o Manifesto

#### Arquivo: `06-ecommerce-app/manifests/ecommerce-ui.yaml`

**ANTES** (com problema):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-ui
  namespace: ecommerce
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ecommerce-ui
      version: v1         # ← Removido
  template:
    metadata:
      labels:
        app: ecommerce-ui
        version: v1       # ← Removido
    spec:
      containers:
      - name: ecommerce-ui
        image: rslim087/ecommerce-ui:latest
        ports:
        - containerPort: 4000
---
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-ui
  namespace: ecommerce
spec:
  ports:
  - port: 4000
    name: http
  selector:
    app: ecommerce-ui
    version: v1           # ← Removido
```

**DEPOIS** (corrigido - mantendo v1 para Blue/Green):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ecommerce-ui
  namespace: ecommerce
spec:
  replicas: 2             # ← Aumentado para 2 (HA)
  selector:
    matchLabels:
      app: ecommerce-ui
      version: v1         # ← MANTIDO para Blue/Green strategy!
  template:
    metadata:
      labels:
        app: ecommerce-ui
        version: v1       # ← MANTIDO para Blue/Green strategy!
    spec:
      containers:
      - name: ecommerce-ui
        image: rslim087/ecommerce-ui:latest
        ports:
        - containerPort: 4000
---
apiVersion: v1
kind: Service
metadata:
  name: ecommerce-ui
  namespace: ecommerce
spec:
  ports:
  - port: 4000
    name: http
  selector:
    app: ecommerce-ui
    version: v1           # ← MANTIDO para Blue/Green strategy!
```

### Passo 2: Deletar e Recriar o Deployment

**Por que deletar?**
- Kubernetes não permite mudar `spec.selector` de um Deployment existente
- Precisamos recriar para aplicar o novo selector COM `version: v1`
- Não podemos apenas fazer `kubectl apply` porque selector é imutável

#### Comandos Executados:
```bash
# Deletar deployment antigo (sem version: v1)
kubectl delete deployment ecommerce-ui -n ecommerce

# Aplicar manifesto corrigido (COM version: v1)
kubectl apply -f 06-ecommerce-app/manifests/ecommerce-ui.yaml
```

#### Saída:
```
deployment.apps "ecommerce-ui" deleted
deployment.apps/ecommerce-ui created
service/ecommerce-ui configured
```

### Passo 3: Verificar Pods e Endpoints

#### Aguardar pods subirem:
```bash
kubectl get pods -n ecommerce | grep ecommerce-ui
```

**Saída**:
```
ecommerce-ui-885d9c485-97t9h   1/1   Running   0   29s   app=ecommerce-ui,version=v1
ecommerce-ui-885d9c485-lzjv6   1/1   Running   0   29s   app=ecommerce-ui,version=v1
ecommerce-ui-885d9c485-d2rpx   1/1   Terminating   0   26m (antigo sem v1)
ecommerce-ui-885d9c485-xq6r4   1/1   Terminating   0   26m (antigo sem v1)
```

**✅ Agora tem `version=v1`!**

#### Verificar endpoints:
```bash
kubectl get endpoints ecommerce-ui -n ecommerce
```

**Saída**:
```
NAME           ENDPOINTS        AGE
ecommerce-ui   10.0.1.37:4000   26m  ✅ Agora tem IP!
```

**Após segundo pod pronto**:
```
NAME           ENDPOINTS                        AGE
ecommerce-ui   10.0.1.104:4000,10.0.1.37:4000   26m  ✅ 2 IPs!
```

### Passo 4: Testar Conectividade

#### Comando:
```bash
curl -I http://k8s-ecommerc-ecommerc-f905cb5bda-1212578790.us-east-1.elb.amazonaws.com/
```

#### Saída:
```
HTTP/1.1 200 OK
Date: Tue, 20 Jan 2026 11:27:06 GMT
Content-Type: text/html; charset=UTF-8
Content-Length: 644
Connection: keep-alive
X-Powered-By: Express
Access-Control-Allow-Origin: *
```

🎉 **PROBLEMA RESOLVIDO!** HTTP 200 OK

---

## 📊 DIAGRAMA DO FLUXO DE TROUBLESHOOTING

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Problema Reportado: HTTP 503                            │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Verificar Pods: kubectl get pods                        │
│    Resultado: ✅ Todos Running 1/1                          │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Verificar Ingress: kubectl get ingress -o yaml          │
│    Resultado: ✅ ALB criado, rotas OK                       │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Verificar Service: kubectl get svc -o yaml              │
│    Resultado: ✅ Configurado, mas selector suspeito         │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Verificar ALB Logs: kubectl logs deployment/alb-ctrl    │
│    Resultado: ✅ Sem erros, reconciliation OK               │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Verificar Endpoints: kubectl get endpoints              │
│    Resultado: ❌ <none> ← PROBLEMA ENCONTRADO!              │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. Comparar Labels: kubectl get pods --show-labels         │
│    Resultado: ❌ Pods sem label "version: v1"               │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Investigar Deployment: kubectl get deployment -o yaml   │
│    Resultado: ❌ Selector diferente do manifesto            │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 9. CAUSA RAIZ: Conflito de labels (immutable field error)  │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 10. SOLUÇÃO: Deletar + recriar Deployment sem version:v1   │
└─────────────────┬───────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────────────────────┐
│ 11. VALIDAÇÃO: curl ALB → HTTP 200 ✅                       │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎓 COMANDOS ESSENCIAIS DE TROUBLESHOOTING

### 1️⃣ Nível Básico - Visão Geral

#### Ver todos os recursos
```bash
# Todos os recursos do namespace
kubectl get all -n ecommerce

# Todos os recursos de todos namespaces
kubectl get all -A

# Recursos específicos
kubectl get pods,svc,ingress -n ecommerce
```

#### Status rápido dos pods
```bash
# Lista simples
kubectl get pods -n ecommerce

# Com mais detalhes (node, IP)
kubectl get pods -n ecommerce -o wide

# Com labels
kubectl get pods -n ecommerce --show-labels

# Filtrar por label
kubectl get pods -l app=ecommerce-ui -n ecommerce

# Ordenar por tempo de criação
kubectl get pods -n ecommerce --sort-by=.metadata.creationTimestamp
```

---

### 2️⃣ Nível Intermediário - Investigação

#### Descrever recursos (detalhes + eventos)
```bash
# Pod específico
kubectl describe pod <pod-name> -n ecommerce

# Deployment
kubectl describe deployment ecommerce-ui -n ecommerce

# Service
kubectl describe service ecommerce-ui -n ecommerce

# Ingress
kubectl describe ingress ecommerce-ingress -n ecommerce

# Node
kubectl describe node <node-name>
```

**O que procurar em `describe`**:
- **Events**: Últimos eventos (Errors, Warnings)
- **Conditions**: Estado do recurso (Ready, Available)
- **Labels**: Se batem com selectors
- **Annotations**: Configurações especiais

#### Ver configuração completa (YAML)
```bash
# Pod
kubectl get pod <pod-name> -n ecommerce -o yaml

# Deployment
kubectl get deployment ecommerce-ui -n ecommerce -o yaml

# Service
kubectl get svc ecommerce-ui -n ecommerce -o yaml

# Ver apenas parte específica (usando jsonpath)
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}'
```

#### Logs de containers
```bash
# Logs atuais
kubectl logs <pod-name> -n ecommerce

# Logs anteriores (se pod crashou)
kubectl logs <pod-name> --previous -n ecommerce

# Seguir logs em tempo real
kubectl logs -f <pod-name> -n ecommerce

# Logs de todos os pods de um deployment
kubectl logs -f deployment/ecommerce-ui -n ecommerce

# Logs de container específico (se pod tem múltiplos)
kubectl logs <pod-name> -c <container-name> -n ecommerce

# Últimas 50 linhas
kubectl logs <pod-name> -n ecommerce --tail=50

# Logs desde 1 hora atrás
kubectl logs <pod-name> -n ecommerce --since=1h
```

---

### 3️⃣ Nível Avançado - Debugging Profundo

#### Entrar no container (debug interativo)
```bash
# Bash
kubectl exec -it <pod-name> -n ecommerce -- /bin/bash

# Sh (se não tiver bash)
kubectl exec -it <pod-name> -n ecommerce -- /bin/sh

# Executar comando único
kubectl exec <pod-name> -n ecommerce -- env
kubectl exec <pod-name> -n ecommerce -- curl localhost:4000
kubectl exec <pod-name> -n ecommerce -- cat /etc/resolv.conf
```

#### Port-forward (testar serviço localmente)
```bash
# Encaminhar porta do pod
kubectl port-forward <pod-name> 8080:4000 -n ecommerce

# Encaminhar porta do service
kubectl port-forward svc/ecommerce-ui 8080:4000 -n ecommerce

# Agora acesse: http://localhost:8080
```

#### Debug de rede
```bash
# Ver endpoints (IPs dos pods que Service enxerga)
kubectl get endpoints -n ecommerce

# Ver endpoints com detalhes
kubectl get endpoints ecommerce-ui -n ecommerce -o yaml

# Testar DNS interno
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup ecommerce-ui.ecommerce.svc.cluster.local

# Testar conectividade entre pods
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://ecommerce-ui.ecommerce.svc.cluster.local:4000
```

#### Eventos do cluster
```bash
# Todos os eventos recentes
kubectl get events -A --sort-by='.lastTimestamp'

# Eventos de um namespace
kubectl get events -n ecommerce --sort-by='.lastTimestamp'

# Apenas warnings e errors
kubectl get events -n ecommerce --field-selector type=Warning
```

---

### 4️⃣ Troubleshooting de Ingress/ALB

#### Verificar ALB Controller
```bash
# Pods do controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Logs do controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Logs seguindo em tempo real
kubectl logs -n kube-system deployment/aws-load-balancer-controller -f

# Ver últimas 100 linhas
kubectl logs -n kube-system deployment/aws-load-balancer-controller --tail=100
```

#### Target Group Bindings
```bash
# Listar TGBs
kubectl get targetgroupbindings -n ecommerce

# Detalhes do TGB
kubectl describe targetgroupbindings -n ecommerce

# Ver TGB em YAML
kubectl get targetgroupbindings -n ecommerce -o yaml
```

#### Ingress
```bash
# Status do ingress
kubectl get ingress -n ecommerce

# Detalhes + eventos
kubectl describe ingress ecommerce-ingress -n ecommerce

# Ver configuração completa
kubectl get ingress ecommerce-ingress -n ecommerce -o yaml

# Ver apenas o endereço do ALB
kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

### 5️⃣ Troubleshooting de Services

#### Verificar Service
```bash
# Lista de services
kubectl get svc -n ecommerce

# Detalhes do service
kubectl describe svc ecommerce-ui -n ecommerce

# Ver selector do service
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}'

# Ver ClusterIP
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.clusterIP}'
```

#### Validar Selector vs Labels
```bash
# 1. Ver selector do Service
kubectl get svc ecommerce-ui -n ecommerce -o jsonpath='{.spec.selector}' | jq

# 2. Ver labels dos pods
kubectl get pods -n ecommerce --show-labels

# 3. Filtrar pods com mesmo selector do service
kubectl get pods -l app=ecommerce-ui -n ecommerce

# Se retornar vazio → Service não encontra pods!
```

#### Testar Service internamente
```bash
# Criar pod temporário para testar
kubectl run test-curl --image=curlimages/curl -i --rm --restart=Never -- \
  curl -v http://ecommerce-ui.ecommerce.svc.cluster.local:4000

# Se funcionar → Service OK, problema está no Ingress/ALB
# Se não funcionar → Problema no Service ou Pods
```

---

### 6️⃣ Troubleshooting de Deployments

#### Status do Deployment
```bash
# Ver deployments
kubectl get deployments -n ecommerce

# Detalhes + eventos
kubectl describe deployment ecommerce-ui -n ecommerce

# Ver replicas
kubectl get deployment ecommerce-ui -n ecommerce -o jsonpath='{.status.replicas}'

# Ver condições
kubectl get deployment ecommerce-ui -n ecommerce -o jsonpath='{.status.conditions[*].type}'
```

#### ReplicaSets
```bash
# Ver ReplicaSets (criados pelo Deployment)
kubectl get replicasets -n ecommerce

# Detalhes do RS
kubectl describe rs <replicaset-name> -n ecommerce

# Ver qual RS está ativo
kubectl get rs -n ecommerce -l app=ecommerce-ui
```

#### Histórico de rollouts
```bash
# Ver histórico de versões
kubectl rollout history deployment/ecommerce-ui -n ecommerce

# Status do rollout atual
kubectl rollout status deployment/ecommerce-ui -n ecommerce

# Voltar para versão anterior
kubectl rollout undo deployment/ecommerce-ui -n ecommerce

# Voltar para revisão específica
kubectl rollout undo deployment/ecommerce-ui -n ecommerce --to-revision=2
```

---

### 7️⃣ Troubleshooting de Rede

#### DNS
```bash
# Testar resolução DNS
kubectl run -it --rm debug-dns --image=busybox --restart=Never -- nslookup kubernetes.default

# Ver configuração DNS do pod
kubectl exec <pod-name> -n ecommerce -- cat /etc/resolv.conf

# Testar resolução de service
kubectl run -it --rm debug-dns --image=busybox --restart=Never -- \
  nslookup ecommerce-ui.ecommerce.svc.cluster.local
```

#### CoreDNS (servidor DNS do cluster)
```bash
# Pods do CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Logs do CoreDNS
kubectl logs -n kube-system -l k8s-app=kube-dns

# Verificar ConfigMap do CoreDNS
kubectl get configmap coredns -n kube-system -o yaml
```

#### Conectividade entre Pods
```bash
# Pegar IP de um pod
POD_IP=$(kubectl get pod <pod-name> -n ecommerce -o jsonpath='{.status.podIP}')

# Testar conectividade de outro pod
kubectl run -it --rm netshoot --image=nicolaka/netshoot --restart=Never -- curl $POD_IP:4000

# Testar com wget
kubectl run -it --rm netshoot --image=nicolaka/netshoot --restart=Never -- wget -O- $POD_IP:4000
```

---

### 8️⃣ Monitoramento e Métricas

#### Consumo de recursos
```bash
# CPU e memória dos nodes
kubectl top nodes

# CPU e memória dos pods
kubectl top pods -n ecommerce

# Pod consumindo mais CPU
kubectl top pods -n ecommerce --sort-by=cpu

# Pod consumindo mais memória
kubectl top pods -n ecommerce --sort-by=memory

# Containers de um pod específico
kubectl top pod <pod-name> -n ecommerce --containers
```

#### Capacidade do cluster
```bash
# Ver recursos alocados vs disponíveis
kubectl describe nodes | grep -A 5 "Allocated resources"

# Contar pods por node
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c

# Ver pods que NÃO estão rodando
kubectl get pods -A --field-selector=status.phase!=Running
```

---

### 9️⃣ Troubleshooting de Volumes/Storage

#### Verificar PVCs
```bash
# Listar PersistentVolumeClaims
kubectl get pvc -n ecommerce

# Detalhes do PVC
kubectl describe pvc <pvc-name> -n ecommerce

# Ver PVs (Persistent Volumes)
kubectl get pv
```

#### Verificar CSI Driver
```bash
# Pods do EBS CSI
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Logs do controller
kubectl logs -n kube-system deployment/ebs-csi-controller

# Logs dos node agents (DaemonSet)
kubectl logs -n kube-system daemonset/ebs-csi-node
```

---

### 🔟 Troubleshooting de Autenticação/Permissões

#### RBAC
```bash
# Ver ServiceAccounts
kubectl get serviceaccounts -n ecommerce

# Ver quais permissões um SA tem
kubectl auth can-i --list --as=system:serviceaccount:ecommerce:default

# Verificar se você pode executar uma ação
kubectl auth can-i create pods -n ecommerce

# Ver Roles e RoleBindings
kubectl get roles,rolebindings -n ecommerce
kubectl get clusterroles,clusterrolebindings
```

#### IAM Roles for Service Accounts (IRSA)
```bash
# Ver anotação IRSA no ServiceAccount
kubectl get sa <sa-name> -n ecommerce -o jsonpath='{.metadata.annotations}'

# Ver variáveis de ambiente AWS no pod
kubectl exec <pod-name> -n ecommerce -- env | grep AWS

# Testar credenciais AWS de dentro do pod
kubectl exec <pod-name> -n ecommerce -- aws sts get-caller-identity
```

---

### 1️⃣1️⃣ Comandos Úteis de Filtro e Formatação

#### Filtros avançados
```bash
# Pods em erro
kubectl get pods -n ecommerce --field-selector=status.phase=Failed

# Pods não prontos
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Services sem ClusterIP
kubectl get svc -A -o json | jq '.items[] | select(.spec.clusterIP=="None") | .metadata.name'

# Pods com mais de 3 restarts
kubectl get pods -A -o json | jq '.items[] | select(.status.containerStatuses[0].restartCount > 3)'
```

#### Formatação customizada
```bash
# Tabela customizada
kubectl get pods -n ecommerce -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName,IP:.status.podIP

# Ver apenas nomes
kubectl get pods -n ecommerce -o name

# Ver em JSON
kubectl get pod <pod-name> -n ecommerce -o json

# Ver campo específico
kubectl get pod <pod-name> -n ecommerce -o jsonpath='{.status.podIP}'

# Loop em todos os pods
kubectl get pods -n ecommerce -o json | jq -r '.items[].metadata.name'
```

---

### 1️⃣2️⃣ Comandos de Emergência

#### Forçar delete de recursos travados
```bash
# Delete com --force
kubectl delete pod <pod-name> -n ecommerce --force --grace-period=0

# Remover finalizer (se pod não deletar)
kubectl patch pod <pod-name> -n ecommerce -p '{"metadata":{"finalizers":null}}'
```

#### Escalar rapidamente
```bash
# Escalar deployment
kubectl scale deployment ecommerce-ui -n ecommerce --replicas=0  # Parar
kubectl scale deployment ecommerce-ui -n ecommerce --replicas=3  # Escalar

# Restart de deployment (recria todos os pods)
kubectl rollout restart deployment/ecommerce-ui -n ecommerce
```

#### Cordon/Drain de nodes (manutenção)
```bash
# Marcar node para não receber novos pods
kubectl cordon <node-name>

# Drenar pods de um node (para manutenção)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Voltar node para uso normal
kubectl uncordon <node-name>
```

---

## 🧪 EXERCÍCIOS PRÁTICOS PARA ALUNOS

### Exercício 1: Simular o Problema

**Tarefa**: Recriar o problema de labels para entender o troubleshooting.

```bash
# 1. Criar um deployment simples
kubectl create deployment test-app --image=nginx --replicas=2 -n default

# 2. Expor com service
kubectl expose deployment test-app --port=80 -n default

# 3. Verificar que funciona
kubectl get endpoints test-app -n default  # Deve ter IPs

# 4. Editar service para buscar label inexistente
kubectl edit svc test-app -n default
# Adicione no selector: version: v999

# 5. Verificar endpoints novamente
kubectl get endpoints test-app -n default  # Agora <none>!

# 6. Corrigir removendo a label
kubectl edit svc test-app -n default
```

### Exercício 2: Debug de Pod CrashLoop

**Tarefa**: Criar pod com erro e debugar.

```bash
# 1. Criar pod com comando que falha
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: crashpod
spec:
  containers:
  - name: app
    image: busybox
    command: ["sh", "-c", "exit 1"]  # Sempre sai com erro
EOF

# 2. Observar CrashLoopBackOff
kubectl get pod crashpod

# 3. Ver logs
kubectl logs crashpod

# 4. Ver eventos
kubectl describe pod crashpod

# 5. Identificar o problema no describe
```

### Exercício 3: Troubleshooting de Ingress

**Tarefa**: Criar Ingress e debugar problemas.

```bash
# 1. Criar deployment e service
kubectl create deployment web --image=nginx
kubectl expose deployment web --port=80

# 2. Criar Ingress com erro proposital
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: webWRONG  # Nome errado!
            port:
              number: 80
EOF

# 3. Debugar
kubectl describe ingress web-ingress
kubectl logs -n kube-system deployment/aws-load-balancer-controller | grep error

# 4. Identificar e corrigir o nome do service
```

---

## 📖 LIÇÕES APRENDIDAS

### 1. **Labels são Críticas**
- Service encontra pods através de labels
- Se labels não batem com selector → Endpoints vazios → 503
- Sempre validar: `kubectl get pods --show-labels`

### 2. **Endpoints são Indicadores-Chave**
- `<none>` em endpoints = problema garantido
- Verificar endpoints deve ser um dos primeiros passos

### 3. **Imutabilidade de Selectors**
- `spec.selector` em Deployments não pode ser mudado
- Se precisa mudar → deletar e recriar
- Planejar labels desde o início

### 4. **Metodologia Top-Down Funciona**
- Começar pela camada mais alta (ALB)
- Descer até encontrar o problema
- Não pular camadas (cada uma tem seu papel)

### 5. **Logs + Describe + Get**
- Combinação poderosa para debug
- `get` = visão geral
- `describe` = detalhes + eventos
- `logs` = o que está acontecendo dentro

---

## 🔗 RECURSOS ADICIONAIS

### Documentação Oficial
- **Kubernetes Troubleshooting**: https://kubernetes.io/docs/tasks/debug/
- **AWS Load Balancer Controller**: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- **EKS Best Practices**: https://aws.github.io/aws-eks-best-practices/

### Tools Recomendadas
- **k9s**: CLI interativa para Kubernetes (`brew install k9s`)
- **stern**: Multi-pod log tailing (`brew install stern`)
- **kubectx/kubens**: Trocar contextos facilmente
- **kubectl plugins**: krew (gerenciador de plugins kubectl)

### Comandos de Instalação
```bash
# k9s - Dashboard interativo no terminal
brew install k9s
# Uso: apenas digite 'k9s'

# stern - Ver logs de múltiplos pods
brew install stern
# Uso: stern ecommerce-ui -n ecommerce

# kubectx/kubens - Trocar contextos e namespaces
brew install kubectx
# Uso: kubens ecommerce (muda namespace padrão)

# krew - Plugin manager
brew install krew
kubectl krew install neat  # Remove campos desnecessários do YAML
kubectl get pod <name> -o yaml | kubectl neat
```

---

## 📝 CHECKLIST DE TROUBLESHOOTING

Use este checklist em qualquer problema de conectividade:

- [ ] **1. Pods estão Running?** → `kubectl get pods -n <namespace>`
- [ ] **2. Pods passam readiness probe?** → `kubectl describe pod <pod>`
- [ ] **3. Service tem ClusterIP?** → `kubectl get svc -n <namespace>`
- [ ] **4. Service tem Endpoints?** → `kubectl get endpoints -n <namespace>` ⭐
- [ ] **5. Labels dos pods batem com selector?** → Compare `--show-labels` vs `describe svc`
- [ ] **6. Ingress foi criado?** → `kubectl get ingress -n <namespace>`
- [ ] **7. ALB foi provisionado?** → Verificar `status.loadBalancer` no ingress
- [ ] **8. Target Groups têm targets saudáveis?** → AWS Console ou logs do ALB Controller
- [ ] **9. Security Groups permitem tráfego?** → Verificar SGs do ALB e nodes
- [ ] **10. DNS está resolvendo?** → Testar com pod temporário

---

## 🎬 CONCLUSÃO

Este caso real demonstrou:

✅ **Metodologia sistemática** de troubleshooting  
✅ **Comandos essenciais** para cada camada  
✅ **Como identificar** a causa raiz  
✅ **Como corrigir** o problema  
✅ **Lições aprendidas** para prevenir no futuro  

**Mensagem Final**: Troubleshooting é uma habilidade que se desenvolve com prática. Cada erro é uma oportunidade de aprender mais sobre como o Kubernetes funciona internamente!

---

*Documento criado para fins educacionais - GitOps EKS Project*  
*Caso real resolvido em: 20 de Janeiro de 2026*  
*Tempo de resolução: ~15 minutos*
