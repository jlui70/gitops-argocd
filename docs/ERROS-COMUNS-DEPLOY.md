# Erros Comuns Durante Deploy - Guia de Troubleshooting

## 📚 Para Professores e Alunos

Este documento explica as mensagens de erro que **são normais e esperadas** durante o deploy da aplicação e-commerce, além de erros reais que você pode encontrar.

---

## ✅ MENSAGENS NORMAIS (Não são problemas!)

Estas mensagens aparecem durante o deploy mas **NÃO impedem** o sucesso da aplicação:

### 1. "The Deployment 'ecommerce-ui' is invalid: spec.selector: field is immutable"

#### 📌 O que significa?

**Mensagem completa**:
```
The Deployment "ecommerce-ui" is invalid: spec.selector: Invalid value: v1.LabelSelector{MatchLabels:map[string]string{"app":"ecommerce-ui", "version":"v1"}, MatchExpressions:[]v1.LabelSelectorRequirement(nil)}: field is immutable
```

#### 🔍 Por que acontece?

**Conceito**: O campo `spec.selector` de um Deployment é **imutável** (não pode ser alterado depois de criado).

**Cenário**:
1. Você fez um deploy anterior do `ecommerce-ui`
2. Está executando `kubectl apply` novamente
3. Kubernetes detecta que o Deployment **já existe**
4. Se houver tentativa de mudar o `selector`, essa mensagem aparece

**Por que é normal**:
- ✅ Kubernetes **rejeita a mudança** mas **mantém o Deployment funcionando**
- ✅ Se o `selector` é o mesmo, o Deployment é apenas **atualizado** (imagem, réplicas, etc)
- ✅ Seu pod continua rodando normalmente

#### 🎓 Explicação para Alunos

**Analogia**: É como tentar mudar o CPF de uma pessoa - não pode! O `selector` é a "identidade" do Deployment no Kubernetes.

**O que o selector faz**:
```yaml
# Deployment usa selector para encontrar SEUS pods
selector:
  matchLabels:
    app: ecommerce-ui     # ← "Gerencio pods com essa label"
    version: v1

# Pods são marcados com essas labels
template:
  metadata:
    labels:
      app: ecommerce-ui   # ← Deployment encontra por aqui
      version: v1
```

#### 🛠️ Como evitar essa mensagem?

**Opção 1**: Delete o Deployment antes de recriar
```bash
kubectl delete deployment ecommerce-ui -n ecommerce
kubectl apply -f manifests/ecommerce-ui.yaml
```

**Opção 2**: Use `kubectl replace --force`
```bash
kubectl replace --force -f manifests/ecommerce-ui.yaml
```

**Opção 3**: Ignore a mensagem (recomendado!)
- Se o deploy termina com sucesso, essa mensagem pode ser ignorada
- Verifique: `kubectl get pods -n ecommerce` → se está `Running`, está OK

---

### 2. "Error from server (NotFound): deployments.apps 'mongodb' not found"

#### 📌 O que significa?

**Mensagem completa**:
```
Error from server (NotFound): deployments.apps "mongodb" not found
```

#### 🔍 Por que acontece?

**No script deploy.sh linha 44**:
```bash
# Aguardar MongoDB estar pronto
echo "   📊 Aguardando MongoDB inicializar..."
kubectl wait --for=condition=available deployment/mongodb -n ecommerce --timeout=300s
```

**O problema**: 
- ❌ O script tenta aguardar o Deployment `mongodb`
- ❌ Mas **não existe** um arquivo `mongodb.yaml` na pasta `manifests/`
- ❌ Logo, o Deployment nunca foi criado

**Por que aparece**:
```bash
ls 06-ecommerce-app/manifests/
# Resultado:
# 01-namespace-ui.yaml
# ecommerce-ui.yaml
# ingress.yaml
# order-management.yaml
# product-catalog.yaml
# product-inventory.yaml
# profile-management.yaml
# shipping-and-handling.yaml
# team-contact-support.yaml
# ← Nota: NÃO há mongodb.yaml!
```

#### 🎓 Explicação para Alunos

**Por que o MongoDB não está no projeto?**

Este projeto usa uma **arquitetura simplificada** sem banco de dados persistente:

1. **Microserviços "stateless"**: Guardam dados em memória (para demo)
2. **Sem MongoDB**: Aplicação de demonstração não precisa de banco real
3. **Foco em Kubernetes**: O objetivo é ensinar orquestração, não databases

**Se fosse produção**, você teria:
```yaml
# 📝 Exemplo: mongodb.yaml (NÃO existe neste projeto)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb
  namespace: ecommerce
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:5.0
        ports:
        - containerPort: 27017
        volumeMounts:
        - name: mongo-storage
          mountPath: /data/db
      volumes:
      - name: mongo-storage
        persistentVolumeClaim:
          claimName: mongodb-pvc
```

#### 🛠️ Como corrigir?

**Opção 1**: Remover a linha do script (recomendado)

Edite `06-ecommerce-app/deploy.sh`, remova:
```bash
# Linha 44-45
kubectl wait --for=condition=available deployment/mongodb -n ecommerce --timeout=300s
```

**Opção 2**: Adicionar verificação condicional
```bash
# Aguardar MongoDB se existir
if kubectl get deployment mongodb -n ecommerce >/dev/null 2>&1; then
    echo "   📊 Aguardando MongoDB inicializar..."
    kubectl wait --for=condition=available deployment/mongodb -n ecommerce --timeout=300s
else
    echo "   ⏭️  MongoDB não configurado (modo demo sem persistência)"
fi
```

#### ⚠️ Impacto?

**Nenhum!** A mensagem de erro aparece mas o script **continua executando** normalmente porque:
- ✅ `kubectl wait` retorna erro, mas bash não para execução
- ✅ Próximos comandos continuam rodando
- ✅ Aplicação sobe sem problemas

---

### 3. "Error from server (NotFound): deployments.apps 'shipping-handling' not found"

#### 📌 O que significa?

**Mensagem completa**:
```
Error from server (NotFound): deployments.apps "shipping-handling" not found
```

#### 🔍 Por que acontece?

**No script deploy.sh linha 52**:
```bash
kubectl wait --for=condition=available deployment/shipping-handling -n ecommerce --timeout=300s
```

**O problema**: Nome errado!
- ❌ Script busca: `shipping-handling` (com hífen)
- ✅ Deployment real: `shipping-and-handling` (com "and")

**Verificação**:
```bash
# O que o script procura:
kubectl get deployment shipping-handling -n ecommerce
# Error: não existe

# O que realmente existe:
kubectl get deployment shipping-and-handling -n ecommerce
# NAME                      READY   UP-TO-DATE   AVAILABLE
# shipping-and-handling     1/1     1            1
```

**No arquivo** [manifests/shipping-and-handling.yaml](../06-ecommerce-app/manifests/shipping-and-handling.yaml):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shipping-and-handling  # ← Nome correto com "and"
  namespace: ecommerce
```

#### 🎓 Explicação para Alunos

**Tipo de erro**: Typo (erro de digitação) - muito comum em DevOps!

**Lição importante**:
- ⚠️ Nomes de recursos devem ser **consistentes** em todos os lugares
- ⚠️ Kubernetes diferencia maiúsculas/minúsculas e caracteres especiais
- ⚠️ Sempre verifique: `kubectl get all -n ecommerce` para ver nomes reais

#### 🛠️ Como corrigir?

Edite `06-ecommerce-app/deploy.sh`, linha 52:

**Antes**:
```bash
kubectl wait --for=condition=available deployment/shipping-handling -n ecommerce --timeout=300s
```

**Depois**:
```bash
kubectl wait --for=condition=available deployment/shipping-and-handling -n ecommerce --timeout=300s
```

---

### 4. "Error from server (NotFound): deployments.apps 'contact-support' not found"

#### 📌 O que significa?

**Mensagem completa**:
```
Error from server (NotFound): deployments.apps "contact-support" not found
```

#### 🔍 Por que acontece?

**No script deploy.sh linha 53**:
```bash
kubectl wait --for=condition=available deployment/contact-support -n ecommerce --timeout=300s
```

**O problema**: Nome errado novamente!
- ❌ Script busca: `contact-support`
- ✅ Deployment real: `contact-support-team` (faltou "team")

**No arquivo** [manifests/team-contact-support.yaml](../06-ecommerce-app/manifests/team-contact-support.yaml):
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: contact-support-team  # ← Nome correto com "team"
  namespace: ecommerce
```

#### 🛠️ Como corrigir?

Edite `06-ecommerce-app/deploy.sh`, linha 53:

**Antes**:
```bash
kubectl wait --for=condition=available deployment/contact-support -n ecommerce --timeout=300s
```

**Depois**:
```bash
kubectl wait --for=condition=available deployment/contact-support-team -n ecommerce --timeout=300s
```

---

## 🔧 CORREÇÕES COMPLETAS NO SCRIPT

### Script Corrigido (06-ecommerce-app/deploy.sh)

**Mudanças necessárias** (linhas 44-53):

```bash
# ❌ ANTES (com erros)
echo "   📊 Aguardando MongoDB inicializar..."
kubectl wait --for=condition=available deployment/mongodb -n ecommerce --timeout=300s

echo "   🔧 Aguardando microserviços iniciarem..."
kubectl wait --for=condition=available deployment/product-catalog -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/order-management -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/product-inventory -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/profile-management -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/shipping-handling -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/contact-support -n ecommerce --timeout=300s
```

```bash
# ✅ DEPOIS (corrigido)
echo "   🔧 Aguardando microserviços iniciarem..."
kubectl wait --for=condition=available deployment/product-catalog -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/order-management -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/product-inventory -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/profile-management -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/shipping-and-handling -n ecommerce --timeout=300s
kubectl wait --for=condition=available deployment/contact-support-team -n ecommerce --timeout=300s
```

**O que mudou**:
1. ❌ Removido: linha do MongoDB (não existe)
2. ✅ Corrigido: `shipping-handling` → `shipping-and-handling`
3. ✅ Corrigido: `contact-support` → `contact-support-team`

---

## ❌ ERROS REAIS (Que indicam problemas)

Estes **SIM** são problemas que você deve investigar:

### 1. CrashLoopBackOff

```bash
kubectl get pods -n ecommerce
# NAME                          READY   STATUS              RESTARTS
# ecommerce-ui-xxx              0/1     CrashLoopBackOff    5
```

**Causa**: Container inicia e morre repetidamente

**Como investigar**:
```bash
kubectl logs ecommerce-ui-xxx -n ecommerce
kubectl describe pod ecommerce-ui-xxx -n ecommerce
```

**Causas comuns**:
- Imagem Docker com erro na aplicação
- Porta errada configurada
- Variáveis de ambiente faltando

---

### 2. ImagePullBackOff

```bash
kubectl get pods -n ecommerce
# NAME                          READY   STATUS              RESTARTS
# ecommerce-ui-xxx              0/1     ImagePullBackOff    0
```

**Causa**: Kubernetes não consegue baixar a imagem Docker

**Como investigar**:
```bash
kubectl describe pod ecommerce-ui-xxx -n ecommerce
# Procure por: Failed to pull image "rslim087/ecommerce-ui:latest"
```

**Causas comuns**:
- Imagem não existe no Docker Hub
- Nome da imagem errado
- Problemas de rede/autenticação

---

### 3. Pending (Node sem recursos)

```bash
kubectl get pods -n ecommerce
# NAME                          READY   STATUS    RESTARTS
# ecommerce-ui-xxx              0/1     Pending   0
```

**Causa**: Não há node com recursos suficientes

**Como investigar**:
```bash
kubectl describe pod ecommerce-ui-xxx -n ecommerce
# Procure por: 0/3 nodes are available: insufficient cpu, insufficient memory
```

**Solução**: Escalar o node group ou reduzir resource requests

---

### 4. Ingress sem ADDRESS

```bash
kubectl get ingress -n ecommerce
# NAME                CLASS   HOSTS   ADDRESS   PORTS   AGE
# ecommerce-ingress   <none>  ...     <none>    80      5m
```

**Causa**: ALB não foi provisionado pelo aws-load-balancer-controller

**Como investigar**:
```bash
# Ver logs do controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Ver eventos do ingress
kubectl describe ingress ecommerce-ingress -n ecommerce
```

**Causas comuns**:
- IAM Role do controller sem permissões
- Subnets não taggeadas corretamente
- Controller não está rodando

---

## 📊 CHECKLIST DE VERIFICAÇÃO PÓS-DEPLOY

Use este checklist para validar o deploy:

### ✅ 1. Namespace criado
```bash
kubectl get namespace ecommerce
# STATUS: Active
```

### ✅ 2. Todos os pods rodando
```bash
kubectl get pods -n ecommerce
# Todos devem estar: Running, READY: 1/1
```

Esperado: **8 pods**
- ✅ contact-support-team
- ✅ ecommerce-ui (2 réplicas)
- ✅ order-management
- ✅ product-catalog
- ✅ product-inventory
- ✅ profile-management
- ✅ shipping-and-handling

### ✅ 3. Todos os services criados
```bash
kubectl get svc -n ecommerce
# Todos com ClusterIP alocado
```

Esperado: **7 services**

### ✅ 4. Ingress com ALB provisionado
```bash
kubectl get ingress -n ecommerce
# ADDRESS deve ter um DNS do ALB (k8s-ecommerc-...)
```

### ✅ 5. ALB respondendo
```bash
# Pegar DNS do ALB
ALB=$(kubectl get ingress ecommerce-ingress -n ecommerce -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Testar
curl -I "http://$ALB"
# HTTP/1.1 200 OK
```

---

## 🎓 CONCEITOS PARA EXPLICAR EM AULA

### 1. kubectl wait

**O que faz**: Aguarda uma condição ser verdadeira antes de continuar

```bash
kubectl wait --for=condition=available deployment/ecommerce-ui -n ecommerce --timeout=300s
```

**Parâmetros**:
- `--for=condition=available`: Aguarda deployment estar "disponível" (réplicas prontas)
- `--timeout=300s`: Desiste após 5 minutos

**Condições possíveis**:
- `available`: Deployment tem réplicas rodando
- `ready`: Pod está pronto para receber tráfego
- `complete`: Job terminou com sucesso

---

### 2. kubectl apply vs kubectl create

| Comando | Comportamento | Uso |
|---------|---------------|-----|
| `kubectl create` | Cria recurso (erro se já existe) | Primeira vez |
| `kubectl apply` | Cria OU atualiza recurso | GitOps, CI/CD |
| `kubectl replace --force` | Deleta e recria | Quando apply não funciona |

**Neste projeto**: Usamos `kubectl apply` (idempotente - pode rodar múltiplas vezes)

---

### 3. Imutabilidade no Kubernetes

**Campos imutáveis** (não podem mudar):
- ✅ `spec.selector` em Deployments
- ✅ `type` em Services (ClusterIP ↔ LoadBalancer)
- ✅ `storageClassName` em PVCs

**Campos mutáveis** (podem mudar):
- ✅ `spec.replicas`
- ✅ `spec.template.spec.containers[].image`
- ✅ `spec.template.spec.containers[].env`

**Por que**: Garantir integridade dos recursos. Se precisa mudar, deleta e recria.

---

## 🧪 EXERCÍCIOS PRÁTICOS

### Nível 1: Identificação
1. Execute `kubectl get pods -n ecommerce -o wide` e identifique em qual node cada pod está
2. Qual é a diferença entre `kubectl get pods` e `kubectl get pods -n ecommerce`?
3. Por que o ALB demora 2-3 minutos para ficar pronto?

### Nível 2: Debugging
4. Delete o pod do ecommerce-ui e observe o que acontece (ReplicaSet recria)
5. Cause um erro proposital: mude a imagem para `invalid:tag` e observe ImagePullBackOff
6. Use `kubectl logs` e `kubectl describe` para investigar erros

### Nível 3: Correção
7. Corrija os 3 erros no script deploy.sh
8. Teste o script corrigido fazendo um novo deploy
9. Adicione validações no script para verificar se recursos existem antes de aguardar

---

## 📚 REFERÊNCIAS

- **Kubernetes Docs - kubectl wait**: https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#wait
- **Deployment Spec**: https://kubernetes.io/docs/concepts/workloads/controllers/deployment/
- **Troubleshooting Guide**: [KUBERNETES-CONCEPTS.md](KUBERNETES-CONCEPTS.md)

---

## 📝 RESUMO EXECUTIVO

### Para a apresentação/aula, diga:

> "Durante o deploy, algumas mensagens de erro aparecem mas são **normais e esperadas**:
> 
> 1. **'field is immutable'**: Kubernetes protege o `selector` do Deployment de mudanças. A aplicação continua funcionando.
> 
> 2. **'mongodb not found'**: O script procura um banco de dados que não existe neste projeto demo. Não afeta a aplicação.
> 
> 3. **'shipping-handling not found'** e **'contact-support not found'**: Erros de digitação no script (nomes errados). Os deployments reais têm nomes ligeiramente diferentes e foram criados com sucesso.
> 
> ✅ **Resultado final**: Todos os 8 pods rodando, 7 services ativos, 1 ingress com ALB funcionando. Aplicação 100% operacional!"

---

## ⚠️ NOTA: Monitoramento com Grafana

**Status**: Não implementado neste projeto

A mensagem que aparecia no final do script mencionando Grafana (`https://g-b774166fa1.grafana-workspace.us-east-1.amazonaws.com/`) foi **removida** porque:

- ❌ Stack `05-monitoring` não existe no projeto
- ❌ Amazon Managed Grafana não foi provisionado
- ❌ URL era hardcoded e não funcionava

**Para implementar monitoramento** (opcional para alunos avançados):

1. **Prometheus + Grafana** (self-hosted):
   ```bash
   # Instalar via Helm
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
   
   # Acessar Grafana
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   # http://localhost:3000 (admin/prom-operator)
   ```

2. **Amazon Managed Grafana** (custo adicional):
   - Criar workspace na AWS Console
   - Configurar data source (Amazon Managed Prometheus)
   - Importar dashboards para Kubernetes

3. **CloudWatch Container Insights** (alternativa):
   ```bash
   # Instalar via eksctl
   eksctl utils install-cloudwatch-insights \
     --cluster eks-devopsproject-cluster \
     --region us-east-1
   ```

**Referência**: Ver [docs/CI-CD-PIPELINE.md](CI-CD-PIPELINE.md) linha 434 para roadmap de monitoramento.

---

*Documento criado para fins educacionais - GitOps EKS Project*  
*Última atualização: Janeiro 2026*
