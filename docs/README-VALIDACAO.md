# ✅ Validação Completa - Deploy do Zero

## 🎯 Teste de Validação Completo

Este documento descreve o processo completo para validar o deploy do zero, incluindo Blue/Green deployment e rollback.

---

## 📋 Pré-requisitos

- AWS Account configurada
- Git instalado
- AWS CLI configurado
- kubectl instalado
- Terraform instalado

---

## 🔄 Processo Completo de Validação

### 1️⃣ Destroy Completo (limpar tudo)

```bash
cd ~/gitops-eks
./scripts/destroy-all.sh
```

**Confirme:**
- Deletar ECR? `s`
- Deletar backend? `s` (ou `N` se quiser preservar)

**Aguarde:** ~5-10 minutos

---

### 2️⃣ Clone do Zero (simular novo ambiente)

```bash
# Sair do diretório atual
cd ~

# Remover diretório antigo
rm -rf gitops-eks

# Clonar repositório
git clone https://github.com/SEU-USUARIO/gitops-eks.git
cd gitops-eks
```

---

### 3️⃣ Rebuild da Infraestrutura

```bash
./scripts/rebuild-all.sh
```

**Provisiona:**
- Stack 00: Backend (S3 + DynamoDB)
- Stack 01: Networking (VPC + Subnets)
- Stack 02: EKS Cluster + ALB Controller

**Tempo:** ~20-25 minutos

**Aguarde até aparecer:**
```
✅ INFRAESTRUTURA COMPLETA RECRIADA!
```

---

### 4️⃣ Deploy da Aplicação E-commerce (v1)

```bash
cd 06-ecommerce-app
./deploy.sh
```

**Se namespace não existir:** Deploy automático  
**Se namespace existir:** Escolha `s` para deletar e recriar

**Aguarde até aparecer:**
```
✅ Aplicação respondendo: HTTP 200
```

---

### 5️⃣ Validar Versão v1

```bash
# Verificar pods com label version=v1
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version

# Deve mostrar:
# NAME                           READY   STATUS    VERSION
# ecommerce-ui-885d9c485-xxxxx   1/1     Running   v1
```

**Acessar via ALB:**
```bash
# Obter URL do ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "http://$ALB_URL"

# Testar
curl -I "http://$ALB_URL"
# Deve retornar: HTTP/1.1 200 OK
```

**✅ Checkpoint:** v1 ativo e respondendo HTTP 200

---

### 6️⃣ Deploy v2 (Blue/Green)

#### Opção A: Via GitHub Actions (Recomendado)

1. Acesse: `https://github.com/SEU-USUARIO/gitops-eks/actions`
2. Selecione workflow: `CD - Deploy to EKS`
3. Click: `Run workflow`
4. Configure:
   - **branch**: `main`
   - **environment**: `production`
   - **image_tag**: `v2.0`
   - **deployment_strategy**: `blue-green`
5. Click: `Run workflow`

**Aguarde:** ~1-2 minutos

#### Opção B: Via kubectl (Manual)

```bash
cd ~/gitops-eks/06-ecommerce-app

# Criar deployment v2
kubectl apply -f manifests-v2/ecommerce-ui-v2.yaml

# Aguardar pods v2 estarem prontos
kubectl wait --for=condition=available \
  deployment/ecommerce-ui-v2 -n ecommerce --timeout=180s

# Verificar que temos v1 E v2 rodando
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version

# Deve mostrar:
# NAME                              VERSION
# ecommerce-ui-885d9c485-xxxxx      v1       (1 pod)
# ecommerce-ui-v2-xxxxxxxxx-xxxxx   v2       (2 pods)
```

---

### 7️⃣ Switch Traffic (v1 → v2)

```bash
# Alterar service selector para v2
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v2"}}}'

# Aguardar alguns segundos
sleep 5

# Testar que v2 está recebendo tráfego
curl -I "http://$ALB_URL"
# Ainda deve retornar: HTTP/1.1 200 OK
```

**✅ Checkpoint:** v2 ativo e respondendo HTTP 200

---

### 8️⃣ Validar Blue/Green

```bash
# Verificar que temos:
# - v1 rodando (1 pod) mas SEM tráfego
# - v2 rodando (2 pods) COM tráfego

kubectl get pods -n ecommerce -l app=ecommerce-ui -L version

# Verificar service selector
kubectl get service ecommerce-ui -n ecommerce -o yaml | grep -A2 selector
# Deve mostrar: version: v2
```

---

### 9️⃣ Rollback (v2 → v1)

#### Opção A: Via GitHub Actions

1. Acesse: `https://github.com/SEU-USUARIO/gitops-eks/actions`
2. Selecione workflow: `Rollback Deployment`
3. Click: `Run workflow`
4. Configure:
   - **target_version**: `v1`
   - **reason**: `Testing rollback`
5. Click: `Run workflow`

**Tempo:** < 30 segundos

#### Opção B: Via kubectl (Manual)

```bash
# Reverter service selector para v1
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v1"}}}'

# Verificar que voltou para v1
kubectl get service ecommerce-ui -n ecommerce -o yaml | grep -A2 selector
# Deve mostrar: version: v1

# Testar conectividade
curl -I "http://$ALB_URL"
# Ainda deve retornar: HTTP/1.1 200 OK
```

**✅ Checkpoint:** Rollback para v1 bem-sucedido

---

## 📊 Checklist de Validação

Marque cada item ao completar:

- [ ] Destroy-all executado com sucesso
- [ ] Clone do repositório do zero
- [ ] Rebuild-all completado (20-25 min)
- [ ] Deploy v1 funcionando (HTTP 200)
- [ ] Pods têm label `version: v1`
- [ ] Service encontra pods v1
- [ ] Deploy v2 via GitHub Actions ou kubectl
- [ ] Pods v2 criados (2 replicas)
- [ ] Switch traffic v1 → v2 executado
- [ ] Aplicação respondendo via v2 (HTTP 200)
- [ ] Rollback v2 → v1 executado
- [ ] Aplicação respondendo via v1 novamente

---

## 🐛 Troubleshooting

### Problema: Deploy falha com "field is immutable"

**Solução:**
```bash
# Deletar namespace completamente
kubectl delete namespace ecommerce

# Aguardar ser removido
while kubectl get namespace ecommerce &>/dev/null; do
    sleep 2
done

# Executar deploy novamente
cd ~/gitops-eks/06-ecommerce-app
./deploy.sh
```

### Problema: Service sem endpoints (503)

**Causa:** Pods sem label `version: v1`

**Verificar:**
```bash
kubectl get pods -n ecommerce -l app=ecommerce-ui --show-labels
```

**Solução:**
```bash
# Deletar deployment e recriar
kubectl delete deployment ecommerce-ui -n ecommerce
kubectl apply -f manifests/ecommerce-ui.yaml
```

### Problema: ALB retorna 503

**Diagnóstico:**
```bash
cd ~/gitops-eks/06-ecommerce-app
./diagnose-503.sh
```

O script irá:
1. Verificar status dos pods
2. Verificar endpoints dos services
3. Verificar ingress/ALB
4. Testar conectividade interna
5. Fornecer recomendações

---

## 📝 Ordem Correta dos Manifests

O script `deploy.sh` aplica na ordem:

1. **00-namespace.yaml** - Namespace vazio
2. **ecommerce-ui.yaml** - Frontend (COM version: v1)
3. **Microserviços** - 6 serviços backend
4. **ingress.yaml** - ALB configuration

**Importante:** `01-namespace-ui.yaml` NÃO é usado (tinha conflito)

---

## ✅ Correções Implementadas

### Problema Original
- `01-namespace-ui.yaml` criava Deployment SEM `version: v1`
- `ecommerce-ui.yaml` criava Deployment COM `version: v1`
- Resultado: Erro "field is immutable"
- Pods criados sem label `version`
- Service não encontrava pods → **503 Error**

### Solução Implementada
1. ✅ Criado `00-namespace.yaml` - APENAS namespace
2. ✅ Aplicar `ecommerce-ui.yaml` UMA VEZ - COM version: v1
3. ✅ Garantir ordem correta de aplicação
4. ✅ Script valida namespace existente antes de deploy
5. ✅ Script de diagnóstico para troubleshooting

---

## 🎯 Resultado Esperado

Após seguir todos os passos:

```
✅ Infraestrutura provisionada do zero
✅ Aplicação v1 deployada e funcionando
✅ Blue/Green deployment executado (v1 → v2)
✅ Rollback testado e validado (v2 → v1)
✅ Zero downtime durante todo o processo
✅ Todos os pods com labels corretas
✅ Services com endpoints conectados
✅ ALB respondendo HTTP 200
```

---

## 🚀 Próximos Passos

Após validação completa:

1. **Documentar no README.md** principal
2. **Criar vídeo demonstrativo** (YouTube)
3. **Push para repositório GitHub**
4. **Compartilhar com comunidade**

---

## 📞 Suporte

Se encontrar problemas:

1. Execute: `./diagnose-503.sh`
2. Verifique logs: `kubectl logs -n ecommerce deployment/ecommerce-ui`
3. Documente o erro e abra issue no GitHub

---

**Última atualização:** 21 de Janeiro de 2026  
**Versão:** 2.0 - Corrigido deploy do zero
