# 🚀 E-commerce App - Version 2.0 Deployment Guide

## 📋 Visão Geral

Esta versão 2.0 implementa **Blue/Green Deployment** usando NGINX como proxy reverso para adicionar features visuais sem modificar o código-fonte original.

## 🎨 O que mudou na v2?

### Mudanças Visuais
- 🎨 **Banner roxo no topo** com texto: "🚀 VERSION 2.0 - NEW FEATURES ENABLED! 🚀"
- 📱 Design responsivo do banner
- ✨ Gradiente moderno (roxo → lilás)

### Mudanças Técnicas
- 🔌 **Endpoint `/api/version`**: Retorna informações da versão
- 🏥 **Health check `/health`**: Endpoint de saúde
- 🔄 **NGINX Proxy**: Camada de proxy para inject de conteúdo
- 📊 **Métricas**: Preparado para monitoramento

## 🏗️ Arquitetura v2 (Blue/Green)

```
┌─────────────────────────────────────────────────────────────┐
│                        INGRESS (ALB)                        │
│                 eks.devopsproject.com.br                    │
└───────────────────────┬─────────────────────────────────────┘
                        │
            ┌───────────▼────────────┐
            │  Service: ecommerce-ui │
            │   (selector switch)    │
            └───────────┬────────────┘
                        │
        ┌───────────────┴────────────────┐
        │                                │
┌───────▼────────┐              ┌───────▼────────┐
│  v1 (BLUE)     │              │  v2 (GREEN)    │
│  Original App  │              │  NGINX Proxy   │
│  2 replicas    │              │  2 replicas    │
└────────────────┘              └───────┬────────┘
                                        │
                                ┌───────▼────────┐
                                │  v2 Backend    │
                                │  Original App  │
                                │  2 replicas    │
                                └────────────────┘
```

## 🚀 Como Usar

### 1️⃣ Deploy da Versão 2.0

```bash
cd /home/luiz7/Projects/gitops/06-ecommerce-app
./deploy-v2.sh
```

**O que acontece:**
- ✅ Deploy do ConfigMap NGINX
- ✅ Deploy do backend v2
- ✅ Deploy do proxy v2
- ✅ Validação de health
- ⏸️ **Tráfego ainda em v1** (Blue/Green staging)

**Tempo:** ~2 minutos

---

### 2️⃣ Testar v2 Antes do Switch

```bash
# Port-forward para testar localmente
kubectl port-forward -n ecommerce svc/ecommerce-ui-v2 8080:4000

# Abra no navegador:
# http://localhost:8080
```

**Você deve ver:**
- Banner roxo no topo: "🚀 VERSION 2.0 - NEW FEATURES ENABLED! 🚀"
- Aplicação funcionando normalmente

**Testar endpoint de versão:**
```bash
curl http://localhost:8080/api/version
# Resposta: {"version": "2.0", ...}
```

---

### 3️⃣ Switch de Tráfego (v1 → v2)

Quando estiver satisfeito com os testes:

```bash
./switch-to-v2.sh
```

**O que acontece:**
- 🔄 Service `ecommerce-ui` aponta para v2
- 🌐 TODO o tráfego vai para v2
- 🎯 v1 continua rodando (pronta para rollback)

**Validação:**
```bash
# Testar via DNS
curl http://eks.devopsproject.com.br/api/version

# Abrir no navegador
# Você verá o banner roxo!
```

---

### 4️⃣ Rollback (se necessário)

Se houver problemas com v2:

```bash
./rollback-to-v1.sh
```

**O que acontece:**
- 🔙 Service volta para v1
- ⚡ Instantâneo (< 10 segundos)
- 📝 Log do rollback registrado

---

## 📊 Comandos Úteis

### Verificar Status

```bash
# Ver todas as versões rodando
kubectl get pods -n ecommerce -l app=ecommerce-ui -o wide

# Ver deployments
kubectl get deployments -n ecommerce -l app=ecommerce-ui

# Ver para onde o service está apontando
kubectl get service ecommerce-ui -n ecommerce -o yaml | grep version
```

### Logs

```bash
# Logs v1
kubectl logs -n ecommerce -l version=v1 --tail=50

# Logs v2
kubectl logs -n ecommerce -l version=v2 --tail=50
```

### Métricas

```bash
# CPU/Memory v1
kubectl top pods -n ecommerce -l version=v1

# CPU/Memory v2
kubectl top pods -n ecommerce -l version=v2
```

---

## 🧪 Testes de Validação

### Teste 1: Health Check

```bash
# v1
kubectl exec -n ecommerce deployment/ecommerce-ui -- wget -qO- http://localhost:4000/

# v2
kubectl exec -n ecommerce deployment/ecommerce-ui-v2 -- wget -qO- http://localhost:4000/health
```

### Teste 2: Endpoint de Versão

```bash
# Via port-forward
kubectl port-forward -n ecommerce svc/ecommerce-ui-v2 8080:4000
curl http://localhost:8080/api/version | jq .
```

Resposta esperada:
```json
{
  "version": "2.0",
  "status": "active",
  "features": [
    "new-ui",
    "improved-performance",
    "enhanced-security"
  ]
}
```

### Teste 3: Visual do Banner

1. Abra http://eks.devopsproject.com.br
2. Deve aparecer banner roxo no topo
3. Texto: "🚀 VERSION 2.0 - NEW FEATURES ENABLED! 🚀"

---

## 🗑️ Limpeza Completa (Remover v2)

Se quiser remover v2 completamente após rollback:

```bash
kubectl delete deployment ecommerce-ui-v2 -n ecommerce
kubectl delete deployment ecommerce-ui-backend -n ecommerce
kubectl delete service ecommerce-ui-v2 -n ecommerce
kubectl delete service ecommerce-ui-backend -n ecommerce
kubectl delete configmap nginx-v2-config -n ecommerce
```

---

## 🎯 Próximos Passos (CI/CD)

Com v1 e v2 funcionando, agora você pode:

1. ✅ Criar repositório GitHub
2. ✅ Configurar GitHub Actions (CI/CD)
3. ✅ Automatizar deploy v2
4. ✅ Automatizar testes
5. ✅ Automatizar rollback

**Arquitetura CI/CD será criada na próxima fase!**

---

## 📝 Notas Importantes

- 🔵 **Blue (v1)**: Versão estável original
- 🟢 **Green (v2)**: Nova versão com banner
- 🔄 **Zero Downtime**: Ambas versões rodam simultaneamente
- ⚡ **Rollback Instantâneo**: < 10 segundos
- 💰 **Custo**: +2 pods = ~$2/mês adicional

---

## ❓ Troubleshooting

### Problema: v2 não inicia

```bash
# Verificar logs do proxy
kubectl logs -n ecommerce -l version=v2

# Verificar configmap
kubectl get configmap nginx-v2-config -n ecommerce -o yaml
```

### Problema: Banner não aparece

- Verifique se o switch foi feito: `kubectl get svc ecommerce-ui -n ecommerce -o yaml | grep version`
- Limpe cache do navegador (Ctrl+Shift+R)
- Teste com curl: `curl http://eks.devopsproject.com.br | grep VERSION`

### Problema: Service não muda

```bash
# Forçar patch
kubectl patch service ecommerce-ui -n ecommerce --type merge -p '{"spec":{"selector":{"version":"v2"}}}'
```

---

✅ **v2 pronta para demonstração CI/CD!**
# Test change
