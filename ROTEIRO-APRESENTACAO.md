# 🎬 Roteiro de Apresentação - ArgoCD GitOps

## 🎯 Objetivo da Demo

Demonstrar deploy automatizado v1 → v2 usando ArgoCD (GitOps) sem intervenção manual, preservando ALB e DNS.

---

## 📋 Preparação (Antes da Apresentação)

### 1. Verificar cluster ativo
```bash
kubectl get nodes
# Deve mostrar: 3 nodes Ready
```

### 2. Verificar ArgoCD rodando
```bash
kubectl get pods -n argocd
# Deve mostrar: 9 pods Running
```

### 3. Garantir que está em v1
```bash
./scripts/demo/0-reset-to-v1.sh
```

### 4. Obter URLs
```bash
./scripts/demo/get-urls.sh
```

**Anote:**
- App URL: `http://eks.devopsproject.com.br/`
- ArgoCD URL: `http://k8s-argocd-argocdse-d33c7d0358...`
- ArgoCD User: `admin`
- ArgoCD Pass: `n-cTptt61OW75sv1`

---

## 🎤 Roteiro Passo a Passo

### PARTE 1: Introdução (2 min)

**Fala:**
> "Neste projeto implementei um pipeline GitOps completo usando ArgoCD no Amazon EKS. 
> Vou demonstrar como funciona o deploy automatizado de uma aplicação e-commerce 
> com estratégia Blue/Green, mantendo zero downtime e preservando a infraestrutura de DNS."

**Mostrar:**
- Diagrama da arquitetura (se tiver)
- Repositório Git: https://github.com/jlui70/gitops-argocd

---

### PARTE 2: Aplicação Versão 1 (3 min)

**1. Mostrar aplicação rodando**
```bash
./scripts/demo/1-show-v1.sh
```

**Fala:**
> "Aqui temos a aplicação v1 rodando. Vou abrir no navegador..."

**Abrir browser:**
- URL: `http://eks.devopsproject.com.br/`
- Navegar: Home, Products, Cart

**Fala:**
> "Notem que não há nenhum banner promocional. Esta é a versão 1."

---

**2. Mostrar pods v1**
```bash
kubectl get pods -n ecommerce -L version
```

**Fala:**
> "Temos 7 microserviços rodando, incluindo o ecommerce-ui versão 1. 
> O tráfego está sendo roteado apenas para os pods com label version: v1."

---

**3. Mostrar ArgoCD UI**

**Abrir ArgoCD:**
- URL: `http://k8s-argocd-argocdse-d33c7d0358...`
- Login: `admin` / `n-cTptt61OW75sv1`

**Fala:**
> "No ArgoCD vemos a aplicação sincronizada (Synced) e saudável (Healthy). 
> O path atual aponta para overlays/v1 no repositório Git."

**Mostrar:**
- Status: Synced + Healthy
- Source: `overlays/v1`
- Topology view (recursos K8s)

---

### PARTE 3: Deploy Automático v2 (5 min)

**1. Executar deploy**
```bash
./scripts/demo/2-deploy-v2.sh
```

**Fala:**
> "Vou agora fazer o deploy da versão 2 usando o método GitOps. 
> Vou alterar o path da Application no Kubernetes, e o ArgoCD vai 
> detectar essa mudança automaticamente e fazer o deploy SEM 
> nenhuma intervenção manual."

---

**2. Mostrar ArgoCD detectando mudança**

**No ArgoCD UI:**
- Clicar em REFRESH (se necessário)
- Mostrar status mudando

**Fala:**
> "O ArgoCD está configurado para fazer polling a cada 30 segundos. 
> Ele detectou que o path mudou de v1 para v2 e está iniciando o sync..."

**Mostrar:**
- Status: "Syncing" ou "OutOfSync"
- Diff: recursos sendo criados/atualizados
- Logs em tempo real

---

**3. Aguardar sync (30-45s)**

**Fala durante a espera:**
> "Durante este processo, o ArgoCD está:
> 1. Fazendo git fetch do repositório
> 2. Executando Kustomize para gerar os manifests v2
> 3. Comparando com o estado atual do cluster
> 4. Aplicando apenas as diferenças (diff)
> 5. Criando os pods v2 (backend + proxy)
> 6. Atualizando o Service selector para v2
> 7. Mantendo o ALB e Ingress existentes"

---

**4. Verificar sync completo**
```bash
kubectl get application ecommerce-app -n argocd
# Status: Synced
```

**Fala:**
> "Sync completo! Vamos verificar os pods..."

```bash
kubectl get pods -n ecommerce -L version | grep ui
```

**Mostrar:**
- Pods v2: `ecommerce-ui-backend` (2 réplicas)
- Pods v2: `ecommerce-ui-v2` (2 réplicas) - proxy Nginx
- Pods v1: ZERO (removidos)

**Fala:**
> "Agora temos apenas os pods v2 rodando. O Service está roteando 
> tráfego apenas para eles através do label selector version: v2."

---

**5. Testar aplicação v2**

**Refresh browser:**
- URL: `http://eks.devopsproject.com.br/`
- **BANNER DEVE APARECER:** "🎉 Frete Grátis para Todo Brasil!"

**Fala:**
> "E aqui está! O banner promocional 'Frete Grátis' agora está visível. 
> Esta é a versão 2 da aplicação, deployada automaticamente via GitOps."

---

### PARTE 4: Validação de Infraestrutura (3 min)

**1. Verificar ALB preservado**
```bash
kubectl get ingress -n ecommerce -o wide
```

**Fala:**
> "Um ponto crítico: o ALB (Application Load Balancer) não foi recriado. 
> Ele permanece o mesmo:"

**Mostrar:**
```
k8s-ecommerc-ecommerc-f905cb5bda-1356497416.us-east-1.elb.amazonaws.com
```

**Fala:**
> "Isso é fundamental porque nosso DNS eks.devopsproject.com.br está 
> configurado com um CNAME apontando para este ALB. Se o ALB mudasse, 
> o DNS quebraria e a aplicação ficaria fora do ar."

---

**2. Mostrar estratégia Blue/Green**

**Fala:**
> "A estratégia Blue/Green funciona assim:
> - Blue (v1): Pods com label version: v1
> - Green (v2): Pods com label version: v2
> - Service selector: muda de v1 para v2
> - Ingress e ALB: permanecem inalterados
> - Resultado: zero downtime, DNS preservado"

---

**3. Mostrar configuração ArgoCD**
```bash
kubectl get configmap argocd-cm -n argocd -o yaml | grep timeout.reconciliation
# Output: timeout.reconciliation: 30s
```

**Fala:**
> "O ArgoCD está configurado para fazer polling a cada 30 segundos. 
> Também configurei hard refresh para evitar problemas de cache."

---

### PARTE 5: Rollback (Opcional - 2 min)

**Se houver tempo:**
```bash
./scripts/demo/3-rollback-v1.sh
```

**Fala:**
> "O rollback é igualmente simples. Vou voltar para v1..."

**Aguardar 45s:**
- Mostrar ArgoCD fazendo sync reverso
- Refresh browser: banner desaparece
- Pods v1 voltam, pods v2 são removidos

**Fala:**
> "Voltamos para v1. O processo é idêntico, apenas invertido. 
> Isso demonstra a facilidade de rollback em caso de problemas."

---

### PARTE 6: Conclusão (2 min)

**Fala:**
> "Resumindo o que implementamos:
>
> ✅ **GitOps com ArgoCD**: Deploy automatizado sem intervenção manual
> ✅ **Blue/Green**: Zero downtime na mudança de versões
> ✅ **DNS preservado**: ALB não recria, CNAME continua válido
> ✅ **Infraestrutura como Código**: Tudo em Terraform + Kustomize
> ✅ **Auditável**: Histórico completo no Git e ArgoCD
> ✅ **Rollback fácil**: Voltar versão é só um git commit
>
> Diferente da abordagem anterior com kubectl delete application, 
> que quebrava o DNS, esta solução é production-ready e mantém a 
> aplicação sempre disponível."

**Mostrar arquivos:**
```bash
tree 06-ecommerce-app/argocd/
```

**Fala:**
> "Toda a configuração está versionada no Git:
> - base/: manifestos base dos microserviços
> - overlays/v1/: customizações para v1
> - overlays/v2/: customizações para v2 (backend + proxy)
>
> Qualquer mudança é um git commit que o ArgoCD detecta e aplica automaticamente."

---

## 📊 Métricas para Mencionar

- **Tempo de sync:** ~30-45 segundos (automático)
- **Downtime:** Zero
- **Pods v1:** 2 réplicas ecommerce-ui
- **Pods v2:** 2 backend + 2 proxy = 4 réplicas
- **Microserviços:** 7 (product-catalog, order-management, etc)
- **Estratégia:** Blue/Green via Service selector
- **GitOps:** 100% declarativo

---

## 🎯 Pontos Chave para Enfatizar

1. **GitOps Real**
   - "Não é só usar ArgoCD, é ter deploy verdadeiramente automático"
   - "Git é a single source of truth"

2. **Production Safe**
   - "ALB preservado = DNS funcionando"
   - "Método antigo (delete application) quebraria tudo"

3. **Zero Downtime**
   - "Blue/Green garante transição suave"
   - "Pods v2 sobem antes de v1 descer"

4. **Auditável e Rollback**
   - "Todo deploy tem histórico no Git"
   - "Rollback é só um git revert"

5. **Escalável**
   - "Mesma estrutura funciona para 10+ microserviços"
   - "Fácil adicionar novos ambientes (staging, prod)"

---

## ⚠️ Possíveis Perguntas

**P: "Por que não usar Helm?"**
> R: "Kustomize é mais simples para overlay de ambientes. Não precisa templating, 
> é pure YAML. Mas ArgoCD suporta Helm também."

**P: "E se o ArgoCD cair?"**
> R: "A aplicação continua rodando normalmente. ArgoCD só gerencia deploys. 
> Quando voltar, sincroniza automaticamente."

**P: "Como garantir que v2 está OK antes de direcionar tráfego?"**
> R: "Nesta demo é automático, mas em produção eu adicionaria health checks 
> e testes de smoke antes de mudar o Service selector. Posso usar Argo Rollouts 
> para progressive delivery."

**P: "E secrets? Estão no Git?"**
> R: "Não! Usaria Sealed Secrets ou External Secrets Operator para integrar 
> com AWS Secrets Manager. Nunca secrets em plain text no Git."

---

## ✅ Checklist Pré-Apresentação

- [ ] Cluster EKS rodando (3 nodes)
- [ ] ArgoCD healthy (9 pods)
- [ ] App em v1 (sem banner)
- [ ] URLs funcionando (app + ArgoCD)
- [ ] Browser aberto (app + ArgoCD UI em abas)
- [ ] Terminal pronto (scripts/demo/)
- [ ] Credenciais ArgoCD anotadas

---

## 🚀 Dica Final

**Pratique o timing:**
- Parte 1-2: ~5 min
- Parte 3 (deploy): ~5 min (incluindo espera)
- Parte 4 (validação): ~3 min
- Parte 5 (rollback): ~2 min (opcional)
- Parte 6 (conclusão): ~2 min
- **Total: ~15-17 minutos**

**Durante a espera de 45s (sync):**
- Não fique em silêncio
- Explique o que está acontecendo internamente
- Mostre logs no ArgoCD UI
- Mencione benefícios do GitOps

**Seja confiante:**
- Você testou múltiplas vezes
- ALB está preservado
- DNS funciona
- **Está pronto! 🎯**

---

Boa apresentação! 🚀
