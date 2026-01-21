# ✅ Checklist de Validação - Antes de Testar GitOps

Use este checklist para garantir que tudo está funcionando corretamente antes de iniciar os testes v1 → v2.

---

## 📋 Validação da Infraestrutura

### 1. AWS Resources

```bash
# ✅ Verificar EKS Cluster criado
aws eks describe-cluster \
  --name eks-devopsproject-cluster \
  --region us-east-1 \
  --profile devopsproject \
  --query 'cluster.status'

# Output esperado: "ACTIVE"
```

```bash
# ✅ Verificar Node Group
aws eks describe-nodegroup \
  --cluster-name eks-devopsproject-cluster \
  --nodegroup-name eks-devopsproject-node-group \
  --region us-east-1 \
  --profile devopsproject \
  --query 'nodegroup.status'

# Output esperado: "ACTIVE"
```

```bash
# ✅ Verificar VPC
aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=eks-devopsproject-vpc" \
  --profile devopsproject \
  --query 'Vpcs[0].VpcId'

# Output esperado: vpc-xxxxxxxxx
```

**Status:** [ ] Infraestrutura AWS OK

---

## 📋 Validação do Kubernetes

### 2. Cluster Access

```bash
# ✅ Verificar kubeconfig configurado
kubectl config current-context

# Output esperado: arn:aws:eks:us-east-1:ACCOUNT:cluster/eks-devopsproject-cluster
```

```bash
# ✅ Verificar nodes prontos
kubectl get nodes

# Output esperado: 3 nodes com STATUS=Ready
# NAME                          STATUS   ROLE    AGE   VERSION
# ip-10-0-x-x.ec2.internal      Ready    <none>  10m   v1.32.x
```

**Status:** [ ] Acesso ao cluster OK

### 3. ArgoCD Instalado

```bash
# ✅ Verificar namespace argocd
kubectl get namespace argocd

# Output esperado: NAME=argocd, STATUS=Active
```

```bash
# ✅ Verificar pods ArgoCD rodando
kubectl get pods -n argocd

# Output esperado: 7 pods com STATUS=Running
# argocd-application-controller-xxx    1/1  Running
# argocd-applicationset-controller-xxx 1/1  Running
# argocd-dex-server-xxx                1/1  Running
# argocd-notifications-controller-xxx  1/1  Running
# argocd-redis-xxx                     1/1  Running
# argocd-repo-server-xxx               1/1  Running
# argocd-server-xxx                    1/1  Running
```

```bash
# ✅ Verificar senha ArgoCD existe
kubectl get secret argocd-initial-admin-secret -n argocd

# Output esperado: NAME=argocd-initial-admin-secret, TYPE=Opaque
```

```bash
# ✅ Obter senha admin (guardar para uso posterior)
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Anote essa senha: ___________________________
```

**Status:** [ ] ArgoCD instalado e funcionando

### 4. Controllers AWS

```bash
# ✅ Verificar AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller

# Output esperado: READY=2/2, UP-TO-DATE=2, AVAILABLE=2
```

```bash
# ✅ Verificar External DNS
kubectl get deployment -n kube-system external-dns

# Output esperado: READY=1/1, UP-TO-DATE=1, AVAILABLE=1
```

```bash
# ✅ Verificar Metrics Server
kubectl get deployment -n kube-system metrics-server

# Output esperado: READY=2/2, UP-TO-DATE=2, AVAILABLE=2
```

**Status:** [ ] Controllers AWS OK

---

## 📋 Validação da Aplicação

### 5. Application ArgoCD

```bash
# ✅ Verificar Application criada
kubectl get application -n argocd

# Output esperado:
# NAME            SYNC STATUS   HEALTH STATUS
# ecommerce-app   Synced        Healthy
```

```bash
# ✅ Verificar detalhes da Application
kubectl get application ecommerce-app -n argocd -o yaml | grep -A 5 "repoURL"

# Output esperado:
# repoURL: https://github.com/jlui70/gitops-argocd
# path: 06-ecommerce-app/argocd/overlays/production
# targetRevision: main
```

**Status:** [ ] Application ArgoCD configurada

### 6. Namespace e Pods

```bash
# ✅ Verificar namespace ecommerce
kubectl get namespace ecommerce

# Output esperado: NAME=ecommerce, STATUS=Active
```

```bash
# ✅ Verificar pods da aplicação rodando
kubectl get pods -n ecommerce

# Output esperado: Todos pods com STATUS=Running
# ecommerce-ui-v1-xxx                1/1  Running
# order-management-xxx               1/1  Running
# product-catalog-xxx                1/1  Running
# product-inventory-xxx              1/1  Running
# profile-management-xxx             1/1  Running
# shipping-and-handling-xxx          1/1  Running
# team-contact-support-xxx           1/1  Running
```

```bash
# ✅ Contar pods rodando (deve ser exatamente 7)
kubectl get pods -n ecommerce --field-selector=status.phase=Running | grep -c "Running"

# Output esperado: 7
```

**Status:** [ ] Pods da aplicação rodando

### 7. Services

```bash
# ✅ Verificar Services criados
kubectl get svc -n ecommerce

# Output esperado: 8 services (1 LoadBalancer + 7 ClusterIP)
```

```bash
# ✅ Verificar Service principal
kubectl get svc ecommerce-ui-service -n ecommerce

# Output esperado: TYPE=ClusterIP, PORT=80
```

**Status:** [ ] Services configurados

### 8. Ingress e ALB

```bash
# ✅ Verificar Ingress criado
kubectl get ingress -n ecommerce

# Output esperado:
# NAME                 CLASS   HOSTS   ADDRESS                           PORTS   AGE
# ecommerce-ingress    alb     *       xxxx.elb.amazonaws.com            80      5m
```

```bash
# ✅ Obter URL do ALB
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "ALB URL: http://$ALB_URL"

# Anote essa URL: ___________________________
```

```bash
# ✅ Testar ALB respondendo
curl -I http://$ALB_URL

# Output esperado: HTTP/1.1 200 OK
```

```bash
# ✅ Verificar conteúdo v1 (sem banner)
curl -s http://$ALB_URL | grep -i "NEW FEATURES"

# Output esperado: NADA (v1 não tem banner)
```

**Status:** [ ] Ingress e ALB funcionando

---

## 📋 Validação do GitOps

### 9. Repositório Git

```bash
# ✅ Verificar repositório clonado
cd ~/lab-argo/gitops-argocd
git remote -v

# Output esperado:
# origin  https://github.com/jlui70/gitops-argocd (fetch)
# origin  https://github.com/jlui70/gitops-argocd (push)
```

```bash
# ✅ Verificar branch atual
git branch --show-current

# Output esperado: main
```

```bash
# ✅ Verificar Git atualizado
git pull origin main

# Output esperado: Already up to date
```

**Status:** [ ] Repositório Git OK

### 10. Arquivos Kustomize

```bash
# ✅ Verificar estrutura de arquivos
ls -la ~/lab-argo/gitops-argocd/06-ecommerce-app/argocd/overlays/production/

# Output esperado:
# kustomization.yaml
# ecommerce-ui-backend.yaml
# ecommerce-ui-v2-proxy.yaml
# configmap-nginx-v2.yaml
# README.md
```

```bash
# ✅ Verificar kustomization.yaml está em estado v1
cat ~/lab-argo/gitops-argocd/06-ecommerce-app/argocd/overlays/production/kustomization.yaml | grep -E "(ecommerce-ui-backend|ecommerce-ui-v2-proxy)"

# Output esperado: Linhas COMENTADAS (com # na frente)
# # - ecommerce-ui-backend.yaml
# # - ecommerce-ui-v2-proxy.yaml
```

**Status:** [ ] Arquivos Kustomize OK

### 11. ArgoCD Auto-Sync

```bash
# ✅ Verificar polling configurado
kubectl get configmap argocd-cm -n argocd -o yaml | grep timeout

# Output esperado: timeout.reconciliation: 30s
```

```bash
# ✅ Verificar hard refresh habilitado
kubectl get application ecommerce-app -n argocd -o yaml | grep "argocd.argoproj.io/refresh"

# Output esperado: argocd.argoproj.io/refresh: hard
```

```bash
# ✅ Verificar auto-sync habilitado
kubectl get application ecommerce-app -n argocd -o yaml | grep -A 2 "automated:"

# Output esperado:
# automated:
#   prune: true
#   selfHeal: true
```

**Status:** [ ] ArgoCD auto-sync configurado

---

## 📋 Validação Completa

### Resumo Final

- [ ] ✅ Infraestrutura AWS provisionada
- [ ] ✅ Cluster EKS acessível
- [ ] ✅ ArgoCD instalado e funcionando
- [ ] ✅ Controllers AWS rodando
- [ ] ✅ Application ArgoCD criada
- [ ] ✅ Pods da aplicação rodando (7 pods)
- [ ] ✅ Services configurados (8 services)
- [ ] ✅ Ingress e ALB funcionando
- [ ] ✅ Repositório Git configurado
- [ ] ✅ Arquivos Kustomize OK (v1 inicial)
- [ ] ✅ ArgoCD auto-sync configurado

---

## 🎯 Próximo Passo: Testar v1 → v2

Se todos os checkboxes acima estiverem marcados, você está pronto para testar GitOps!

**Siga o guia:**

📘 [06-ecommerce-app/argocd/overlays/production/README.md](./06-ecommerce-app/argocd/overlays/production/README.md)

**Resumo rápido:**

```bash
# 1. Editar kustomization.yaml
cd ~/lab-argo/gitops-argocd/06-ecommerce-app/argocd/overlays/production
vi kustomization.yaml

# 2. Descomentar 3 seções v2 (resources, configMapGenerator, images)

# 3. Commit e push
git add kustomization.yaml
git commit -m "Deploy v2 - Ativa banner"
git push origin main

# 4. Aguardar 30-45 segundos

# 5. Validar v2
curl http://$ALB_URL | grep "NEW FEATURES"
# Deve mostrar: "🚀 NEW FEATURES AVAILABLE!"
```

---

## 🐛 Troubleshooting

### Se algum item falhar:

**Infraestrutura AWS:**
- Verificar credenciais AWS: `aws sts get-caller-identity --profile devopsproject`
- Verificar Terraform state: `cd 02-eks-cluster && terraform show`

**Cluster Access:**
- Reconfigurar kubeconfig: `aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile devopsproject`

**ArgoCD não instalado:**
- Verificar Helm release: `helm list -n argocd`
- Reinstalar: `cd 02-eks-cluster && terraform apply -auto-approve`

**Pods não rodando:**
- Ver eventos: `kubectl get events -n ecommerce --sort-by='.lastTimestamp' | tail -20`
- Ver logs: `kubectl logs -n ecommerce <pod-name>`

**ALB não responde:**
- Verificar controller: `kubectl logs -n kube-system deployment/aws-load-balancer-controller`
- Verificar ingress: `kubectl describe ingress ecommerce-ingress -n ecommerce`

**ArgoCD não sincroniza:**
- Forçar refresh: `kubectl patch application ecommerce-app -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'`

---

## 📚 Documentação de Apoio

- [README.md](./README.md) - Documentação completa
- [QUICK-START.md](./QUICK-START.md) - Setup do zero
- [FLUXO-DEMO-GITOPS.md](./FLUXO-DEMO-GITOPS.md) - Fluxo detalhado
- [SOLUTION-ARGOCD-AUTOSYNC.md](./SOLUTION-ARGOCD-AUTOSYNC.md) - Detalhes técnicos

---

**✅ Boa sorte com os testes!** 🚀
