# 🎬 Fluxo Demo GitOps - v1 → v2 → Rollback

## ⚠️ IMPORTANTE: Qual Repositório Usar?

### Repositórios:

1. **gitops-eks** (Infraestrutura)
   - Local: `/home/luiz7/lab-argo/gitops-eks`
   - Conteúdo: Terraform, scripts, docs
   - ❌ **NÃO edite aqui para demo GitOps**

2. **gitops-argocd** (Aplicação)
   - GitHub: `https://github.com/jlui70/gitops-argocd.git`
   - Conteúdo: Manifestos K8s (base + overlays)
   - ✅ **EDITE AQUI para ArgoCD detectar**

---

## 🎯 Roteiro Apresentação

### PREPARAÇÃO (Antes de Apresentar)

```bash
# 1. Clonar repo de aplicação (se não tiver)
cd ~
git clone https://github.com/jlui70/gitops-argocd.git
cd gitops-argocd

# 2. Garantir que está em v1
cd ~/lab-argo/gitops-eks
kubectl get application ecommerce-app -n argocd -o jsonpath='{.spec.source.path}'
# Deve mostrar: 06-ecommerce-app/argocd/overlays/v1
```

---

### PARTE 1: Mostrar v1 (Sem Banner)

**Fala:**
> "Aqui está a aplicação v1 rodando em produção..."

```bash
cd ~/lab-argo/gitops-eks
./scripts/demo/1-show-v1.sh
```

**Browser:**
- Abrir: `http://eks.devopsproject.com.br/`
- Mostrar: Sem banner ✅

**Fala:**
> "Não há banner promocional. Agora vou simular um desenvolvedor 
> fazendo uma mudança no código..."

---

### PARTE 2: Dev Altera Código (v1 → v2)

**Fala:**
> "O desenvolvedor quer ativar a versão 2 com o banner 'Frete Grátis'. 
> Vou editar o arquivo de configuração no Git..."

```bash
# Ir para o repo de aplicação
cd ~/gitops-argocd

# Verificar estado atual
cat 03-argocd-apps/ecommerce-app.yaml | grep path
# Mostra: path: 06-ecommerce-app/argocd/overlays/v1

# Editar arquivo
vi 03-argocd-apps/ecommerce-app.yaml
```

**No vi, editar:**
```yaml
# Mudar linha:
    path: 06-ecommerce-app/argocd/overlays/v1
# Para:
    path: 06-ecommerce-app/argocd/overlays/v2
```

**Fala enquanto edita:**
> "Estou alterando o path de v1 para v2. Isso simula o desenvolvedor 
> promovendo a nova versão. Vou salvar e fazer commit..."

```bash
# Salvar e sair do vi
:wq

# Ver diff
git diff

# Commit e push (GitOps!)
git add .
git commit -m "Deploy v2 - Add promotional banner"
git push
```

**Fala:**
> "Pronto! Fiz o git push. Agora o ArgoCD vai detectar essa mudança 
> automaticamente em até 30 segundos e fazer o deploy da v2..."

---

### PARTE 3: ArgoCD Detecta e Aplica

**Abrir ArgoCD UI:**
```bash
# URL já aberta em aba do browser
# http://k8s-argocd-argocdse-d33c7d0358...
```

**Fala:**
> "Vamos acompanhar no ArgoCD... Ele está fazendo polling do Git..."

**Mostrar na UI:**
- Status mudando: Synced → OutOfSync → Syncing
- Diff: path mudou de v1 para v2
- Resources: pods v2 sendo criados

**Ou via kubectl:**
```bash
cd ~/lab-argo/gitops-eks
kubectl get application ecommerce-app -n argocd -w
# Ver status mudando em tempo real

# Em outro terminal:
kubectl get pods -n ecommerce -L version -w
# Ver pods v2 subindo, v1 descendo
```

**Fala durante a espera (30-45s):**
> "O ArgoCD está:
> 1. Detectando a mudança no Git
> 2. Fazendo kustomize build do overlay v2
> 3. Comparando com o estado atual
> 4. Aplicando as diferenças
> 5. Criando pods v2 (backend + proxy)
> 6. Atualizando Service selector para v2
> 7. Mantendo o ALB preservado (zero downtime)"

---

### PARTE 4: Verificar v2 (Com Banner)

```bash
# Após sync completo
kubectl get application ecommerce-app -n argocd
# Status: Synced + Healthy

kubectl get pods -n ecommerce -L version | grep ui
# Pods v2 rodando
```

**Browser:**
- Refresh: `http://eks.devopsproject.com.br/`
- Mostrar: **Banner "🎉 Frete Grátis"** ✅

**Fala:**
> "E pronto! A versão 2 está rodando com o banner promocional. 
> Tudo isso sem nenhuma intervenção manual no cluster. 
> Foi apenas: edit → commit → push → ArgoCD detectou e aplicou!"

---

### PARTE 5: Rollback (v2 → v1)

**Fala:**
> "Agora vou demonstrar o rollback. Imaginem que encontramos um bug 
> e precisamos voltar para v1..."

```bash
# Ir para repo de aplicação
cd ~/gitops-argocd

# Editar arquivo
vi 03-argocd-apps/ecommerce-app.yaml
```

**No vi, editar:**
```yaml
# Mudar linha:
    path: 06-ecommerce-app/argocd/overlays/v2
# Para:
    path: 06-ecommerce-app/argocd/overlays/v1
```

```bash
# Commit e push
git add .
git commit -m "Rollback to v1 - Remove banner"
git push
```

**Fala:**
> "Git push feito. Aguardando ArgoCD detectar..."

**Aguardar 30-45s:**
- Mostrar ArgoCD fazendo sync reverso
- Pods v1 voltando, v2 sendo removidos

```bash
kubectl get pods -n ecommerce -L version -w
```

**Browser:**
- Refresh: Banner desaparece ✅

**Fala:**
> "Voltamos para v1! O rollback é tão simples quanto o deploy original. 
> É só reverter o commit no Git e o ArgoCD aplica automaticamente."

---

## 📋 Resumo dos Comandos

### Setup Inicial (Fazer 1x)
```bash
cd ~
git clone https://github.com/jlui70/gitops-argocd.git
```

### Durante a Apresentação

**v1 → v2:**
```bash
cd ~/gitops-argocd
vi 03-argocd-apps/ecommerce-app.yaml  # Mudar v1 → v2
git add . && git commit -m "Deploy v2" && git push
# Aguardar 45s
```

**v2 → v1 (Rollback):**
```bash
cd ~/gitops-argocd
vi 03-argocd-apps/ecommerce-app.yaml  # Mudar v2 → v1
git add . && git commit -m "Rollback v1" && git push
# Aguardar 45s
```

---

## ⚡ Comandos Úteis Durante Demo

```bash
# Ver status ArgoCD
kubectl get application ecommerce-app -n argocd -w

# Ver pods em tempo real
kubectl get pods -n ecommerce -L version -w

# Ver ALB (confirmar não mudou)
kubectl get ingress -n ecommerce

# Ver path atual
kubectl get application ecommerce-app -n argocd \
  -o jsonpath='{.spec.source.path}'
```

---

## 🎯 Pontos Chave

1. **Git é a fonte da verdade**
   - Desenvolvedor só edita Git
   - Não usa kubectl apply manualmente

2. **ArgoCD detecta automaticamente**
   - Polling a cada 30s
   - Sem intervenção humana

3. **ALB preservado**
   - Mesmo URL em todos os deploys
   - DNS continua funcionando

4. **Auditável**
   - Todo deploy tem commit no Git
   - Histórico completo

5. **Rollback trivial**
   - É só reverter o commit
   - Mesmo fluxo do deploy normal

---

## ✅ Checklist Pré-Demo

- [ ] Repo gitops-argocd clonado em ~/gitops-argocd
- [ ] Application em v1 (sem banner)
- [ ] ArgoCD UI aberta em aba do browser
- [ ] App aberta em aba do browser
- [ ] Terminal em ~/gitops-argocd (pronto para vi)
- [ ] Kubectl get pods -w em terminal separado

---

**Dúvidas?**
- ✅ Edito no **~/gitops-argocd** (repo Git)
- ❌ NÃO edito no ~/lab-argo/gitops-eks (apenas infra/scripts)
- ✅ Arquivo: `03-argocd-apps/ecommerce-app.yaml`
- ✅ Linha: `path: overlays/v1` ↔ `overlays/v2`

**Está pronto! 🚀**
