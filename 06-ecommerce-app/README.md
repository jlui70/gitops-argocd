# 🛒 E-commerce Application - Deployment

Aplicação de demonstração de microserviços para EKS com estratégia Blue/Green.

## 📦 Componentes

- **Frontend:** React UI (ecommerce-ui)
- **Microserviços:**
  - Product Catalog
  - Order Management
  - Product Inventory
  - Profile Management
  - Shipping and Handling
  - Contact Support Team

## 🚀 Deploy Rápido

### Deploy v1 (Versão Inicial)

```bash
cd 06-ecommerce-app
./deploy.sh
```

O script irá:
1. Criar namespace `ecommerce`
2. Aplicar manifests Kubernetes
3. Aguardar pods estarem prontos
4. Testar conectividade via ALB

### Acessar Aplicação

```bash
# Obter URL do ALB
kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Acesse via navegador: `http://<ALB-URL>`

---

## 🔄 Blue/Green Deployment

### 1. Deploy v2 (Blue/Green)

```bash
# Aplicar deployment v2 (2 réplicas)
kubectl apply -f manifests-v2/ecommerce-ui-v2.yaml

# Aguardar pods prontos
kubectl wait --for=condition=available \
  deployment/ecommerce-ui-v2 -n ecommerce --timeout=180s
```

Neste ponto você terá:
- **v1:** 1 pod (recebendo tráfego)
- **v2:** 2 pods (standby)

### 2. Switch Traffic (v1 → v2)

```bash
./switch-to-v2.sh
```

Ou manualmente:
```bash
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v2"}}}'
```

### 3. Rollback (v2 → v1)

```bash
./rollback-to-v1.sh
```

Ou manualmente:
```bash
kubectl patch service ecommerce-ui -n ecommerce \
  -p '{"spec":{"selector":{"version":"v1"}}}'
```

---

## 🔍 Troubleshooting

### Diagnóstico Rápido

```bash
./diagnose-503.sh
```

O script verifica:
- Status dos pods
- Labels dos pods (version: v1 ou v2)
- Endpoints do Service
- Status do Ingress/ALB
- Conectividade interna

### Comandos Úteis

```bash
# Ver pods com versão
kubectl get pods -n ecommerce -l app=ecommerce-ui -L version

# Verificar endpoints do service
kubectl get endpoints ecommerce-ui -n ecommerce

# Ver selector do service
kubectl get service ecommerce-ui -n ecommerce -o yaml | grep -A2 selector

# Logs do pod
kubectl logs -n ecommerce deployment/ecommerce-ui --tail=50
```

### Problema: 503 Error

**Causa comum:** Service selector não encontra pods

**Solução:**
```bash
# Verificar labels dos pods
kubectl get pods -n ecommerce -l app=ecommerce-ui --show-labels

# Deve ter: app=ecommerce-ui,version=v1
```

Se não tiver label `version`, delete o namespace e refaça deploy:
```bash
kubectl delete namespace ecommerce
./deploy.sh
```

---

## 📁 Estrutura de Arquivos

```
06-ecommerce-app/
├── manifests/              # Manifests v1 (produção)
│   ├── 00-namespace.yaml
│   ├── ecommerce-ui.yaml
│   ├── order-management.yaml
│   ├── product-catalog.yaml
│   ├── product-inventory.yaml
│   ├── profile-management.yaml
│   ├── shipping-and-handling.yaml
│   ├── team-contact-support.yaml
│   └── ingress.yaml
├── manifests-v2/           # Manifests v2 (Blue/Green)
│   └── ecommerce-ui-v2.yaml
├── deploy.sh               # Deploy principal
├── deploy-v2.sh            # Deploy v2 específico
├── switch-to-v2.sh         # Trocar tráfego para v2
├── rollback-to-v1.sh       # Rollback para v1
└── diagnose-503.sh         # Diagnóstico de erros
```

---

## ⚙️ Configuração dos Manifests

### Version Label (Importante!)

Os deployments usam label `version` para Blue/Green:

```yaml
spec:
  selector:
    matchLabels:
      app: ecommerce-ui
      version: v1  # ← CRÍTICO para roteamento
  template:
    metadata:
      labels:
        app: ecommerce-ui
        version: v1  # ← CRÍTICO para roteamento
```

### Service Selector

O Service roteia tráfego baseado no label `version`:

```yaml
spec:
  selector:
    app: ecommerce-ui
    version: v1  # ← Mudar para 'v2' para trocar versão
```

---

## ✅ Checklist de Deploy

- [ ] Cluster EKS ativo e acessível
- [ ] ALB Controller instalado (helm)
- [ ] kubectl configurado para o cluster
- [ ] Deploy v1 executado com sucesso
- [ ] Pods com label `version: v1`
- [ ] Service com endpoints conectados
- [ ] ALB respondendo HTTP 200
- [ ] (Opcional) Deploy v2 para Blue/Green
- [ ] (Opcional) Traffic switch testado
- [ ] (Opcional) Rollback validado

---

## 📚 Documentação Adicional

Ver pasta `/docs`:
- **BLUE-GREEN-DEPLOYMENT.md** - Estratégia detalhada
- **CI-CD-PIPELINE.md** - Integração com GitHub Actions
- **KUBERNETES-CONCEPTS.md** - Conceitos K8s
- **README-VALIDACAO.md** - Processo completo de validação

---

**Projeto:** EKS DevOps - Microservices Demo  
**Versão:** 2.0  
**Última atualização:** Janeiro 2026
