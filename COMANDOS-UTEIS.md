# 🎯 Comandos Úteis - Referência Rápida

Comandos mais usados durante setup, testes e troubleshooting.

---

## 🔧 AWS CLI

```bash
# Verificar conta atual
aws sts get-caller-identity --profile devopsproject

# Listar clusters EKS
aws eks list-clusters --region us-east-1 --profile devopsproject

# Descrever cluster
aws eks describe-cluster --name eks-devopsproject-cluster --region us-east-1 --profile devopsproject

# Atualizar kubeconfig
aws eks update-kubeconfig --name eks-devopsproject-cluster --region us-east-1 --profile devopsproject
```

---

## ☸️ Kubernetes - Básicos

```bash
# Ver nodes
kubectl get nodes
kubectl get nodes -o wide

# Ver todos os recursos
kubectl get all -A

# Ver namespaces
kubectl get namespaces

# Mudar contexto
kubectl config get-contexts
kubectl config use-context <context-name>
```

---

## 📦 Pods e Deployments

```bash
# Ver pods (todos namespaces)
kubectl get pods -A

# Ver pods da aplicação
kubectl get pods -n ecommerce
kubectl get pods -n ecommerce -o wide
kubectl get pods -n ecommerce -w  # watch mode

# Ver pods com labels
kubectl get pods -n ecommerce -l app=ecommerce-ui
kubectl get pods -n ecommerce -l version=v1
kubectl get pods -n ecommerce -l version=v2

# Descrever pod
kubectl describe pod <pod-name> -n ecommerce

# Ver logs
kubectl logs <pod-name> -n ecommerce
kubectl logs <pod-name> -n ecommerce -f  # follow
kubectl logs <pod-name> -n ecommerce --previous  # logs anteriores

# Exec no pod
kubectl exec -it <pod-name> -n ecommerce -- /bin/sh

# Ver deployments
kubectl get deployments -n ecommerce
kubectl describe deployment <deployment-name> -n ecommerce
```

---

## 🌐 Services e Ingress

```bash
# Ver services
kubectl get svc -n ecommerce
kubectl describe svc ecommerce-ui-service -n ecommerce

# Ver selector do service (importante para Blue/Green)
kubectl get svc ecommerce-ui-service -n ecommerce -o yaml | grep -A 3 selector

# Ver ingress
kubectl get ingress -n ecommerce
kubectl describe ingress ecommerce-ingress -n ecommerce

# Obter URL do ALB
kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## 🎨 ArgoCD

### ArgoCD CLI (se instalado)

```bash
# Login
argocd login localhost:8080 --username admin --password <senha>

# Listar apps
argocd app list

# Ver detalhes
argocd app get ecommerce-app

# Sync manual
argocd app sync ecommerce-app

# Forçar refresh
argocd app sync ecommerce-app --hard-refresh
```

### Via kubectl

```bash
# Ver Applications
kubectl get application -n argocd
kubectl get application ecommerce-app -n argocd -o yaml

# Ver status detalhado
kubectl get application ecommerce-app -n argocd -o jsonpath='{.status.sync.status}'
kubectl get application ecommerce-app -n argocd -o jsonpath='{.status.health.status}'

# Forçar refresh hard
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Ver histórico de syncs
kubectl get application ecommerce-app -n argocd -o json | jq '.status.history'

# Ver pods ArgoCD
kubectl get pods -n argocd

# Ver logs do ArgoCD server
kubectl logs -n argocd deployment/argocd-server

# Ver logs do repo server (onde acontece o Kustomize build)
kubectl logs -n argocd deployment/argocd-repo-server

# Ver senha admin
kubectl get secret argocd-initial-admin-secret -n argocd \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

---

## 📊 Eventos e Troubleshooting

```bash
# Ver eventos recentes
kubectl get events -n ecommerce --sort-by='.lastTimestamp'
kubectl get events -n ecommerce --sort-by='.lastTimestamp' | tail -20

# Ver eventos de um pod específico
kubectl get events -n ecommerce --field-selector involvedObject.name=<pod-name>

# Ver métricas (requer metrics-server)
kubectl top nodes
kubectl top pods -n ecommerce

# Descrever recursos (ver eventos + config)
kubectl describe pod <pod-name> -n ecommerce
kubectl describe deployment <deployment-name> -n ecommerce
kubectl describe ingress ecommerce-ingress -n ecommerce
```

---

## 🔍 Controllers AWS

```bash
# AWS Load Balancer Controller
kubectl get deployment -n kube-system aws-load-balancer-controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# External DNS
kubectl get deployment -n kube-system external-dns
kubectl logs -n kube-system deployment/external-dns

# Metrics Server
kubectl get deployment -n kube-system metrics-server
kubectl logs -n kube-system deployment/metrics-server
```

---

## 🎯 Validação v1 vs v2

```bash
# Verificar qual versão está ativa (via Service selector)
kubectl get svc ecommerce-ui-service -n ecommerce -o yaml | grep "version:"

# Ver pods v1
kubectl get pods -n ecommerce -l version=v1

# Ver pods v2
kubectl get pods -n ecommerce -l version=v2
kubectl get pods -n ecommerce -l app=ecommerce-ui-backend
kubectl get pods -n ecommerce -l app=ecommerce-ui-v2-proxy

# Testar endpoint (verificar banner)
ALB_URL=$(kubectl get ingress ecommerce-ingress -n ecommerce \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl -s http://$ALB_URL | grep "NEW FEATURES"
# Se v1: sem output
# Se v2: mostra "🚀 NEW FEATURES AVAILABLE!"

# Testar com header detalhado
curl -I http://$ALB_URL
```

---

## 📝 ConfigMaps e Secrets

```bash
# Ver ConfigMaps
kubectl get configmap -n ecommerce

# Ver ConfigMap v2
kubectl describe configmap nginx-v2-config -n ecommerce

# Ver conteúdo do ConfigMap
kubectl get configmap nginx-v2-config -n ecommerce -o yaml

# Ver secrets
kubectl get secrets -n ecommerce
kubectl get secrets -n argocd
```

---

## 🔄 Git Operations

```bash
# Navegar para manifestos
cd ~/lab-argo/gitops-argocd/06-ecommerce-app/argocd/overlays/production

# Status
git status

# Ver diff
git diff kustomization.yaml

# Ver histórico
git log --oneline
git log --oneline -10

# Ver último commit
git show HEAD

# Reverter arquivo (uncommitted)
git checkout kustomization.yaml

# Reverter último commit (mantém mudanças)
git reset --soft HEAD~1

# Reverter último commit (descarta mudanças)
git reset --hard HEAD~1

# Push
git push origin main

# Pull
git pull origin main

# Ver remote
git remote -v
```

---

## 🧹 Cleanup e Reset

```bash
# Deletar Application ArgoCD (remove recursos)
kubectl delete application ecommerce-app -n argocd

# Deletar namespace (remove tudo)
kubectl delete namespace ecommerce

# Restart deployment
kubectl rollout restart deployment <deployment-name> -n ecommerce

# Scale deployment
kubectl scale deployment <deployment-name> -n ecommerce --replicas=0
kubectl scale deployment <deployment-name> -n ecommerce --replicas=2

# Deletar pod (recria automaticamente)
kubectl delete pod <pod-name> -n ecommerce
```

---

## 🏗️ Terraform

```bash
# Ver recursos criados
terraform show

# Ver state
terraform state list

# Ver output
terraform output

# Refresh state
terraform refresh

# Validar configuração
terraform validate

# Planejar mudanças
terraform plan

# Aplicar
terraform apply -auto-approve

# Destruir
terraform destroy -auto-approve

# Ver workspace
terraform workspace list
```

---

## 🎬 Fluxo Completo v1 → v2 → v1

```bash
# 1. Estado inicial v1
kubectl get pods -n ecommerce -l app=ecommerce-ui
curl -s http://$ALB_URL | grep "NEW FEATURES"  # sem output

# 2. Editar kustomization.yaml (descomentar v2)
cd ~/lab-argo/gitops-argocd/06-ecommerce-app/argocd/overlays/production
vi kustomization.yaml  # descomentar 3 seções v2

# 3. Push
git add kustomization.yaml
git commit -m "Deploy v2"
git push origin main

# 4. Aguardar 30-45s e validar
watch kubectl get application ecommerce-app -n argocd
kubectl get pods -n ecommerce -l app=ecommerce-ui
curl -s http://$ALB_URL | grep "NEW FEATURES"  # deve mostrar banner

# 5. Rollback (comentar v2)
vi kustomization.yaml  # comentar 3 seções v2
git add kustomization.yaml
git commit -m "Rollback v1"
git push origin main

# 6. Aguardar 30-45s e validar
kubectl get pods -n ecommerce -l app=ecommerce-ui
curl -s http://$ALB_URL | grep "NEW FEATURES"  # sem output
```

---

## 🚨 Emergency Commands

```bash
# Forçar sync imediato ArgoCD
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"operation":{"sync":{"revision":"HEAD"}}}'

# Desabilitar auto-sync temporariamente
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"spec":{"syncPolicy":{"automated":null}}}'

# Reabilitar auto-sync
kubectl patch application ecommerce-app -n argocd \
  --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true,"selfHeal":true}}}}'

# Deletar pod travado (force)
kubectl delete pod <pod-name> -n ecommerce --force --grace-period=0

# Ver recursos sendo deletados
kubectl get pods -n ecommerce --field-selector=status.phase!=Running

# Corrigir finalizers travados
kubectl patch deployment <deployment-name> -n ecommerce \
  -p '{"metadata":{"finalizers":null}}'
```

---

## 📊 Monitoring e Debug

```bash
# Ver uso de recursos
kubectl top nodes
kubectl top pods -n ecommerce

# Ver todos os recursos de um namespace
kubectl api-resources --verbs=list --namespaced -o name \
  | xargs -n 1 kubectl get --show-kind --ignore-not-found -n ecommerce

# Dump completo de um recurso
kubectl get deployment <deployment-name> -n ecommerce -o yaml > deployment.yaml

# Debug de DNS
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup ecommerce-ui-service.ecommerce.svc.cluster.local

# Debug de conectividade
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://ecommerce-ui-service.ecommerce.svc.cluster.local
```

---

## 💡 Dicas Úteis

```bash
# Alias úteis (adicionar no ~/.bashrc)
alias k='kubectl'
alias kge='kubectl get events --sort-by=".lastTimestamp"'
alias kgp='kubectl get pods'
alias kgpa='kubectl get pods -A'
alias kga='kubectl get all -A'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'

# Watch em múltiplos recursos
watch -n 2 'kubectl get pods -n ecommerce && echo "" && kubectl get application -n argocd'

# Salvar kubeconfig backup
cp ~/.kube/config ~/.kube/config.backup

# Ver YAML renderizado do Kustomize (local)
cd ~/lab-argo/gitops-argocd/06-ecommerce-app/argocd/overlays/production
kustomize build .

# Ver diff antes de aplicar
kubectl diff -f manifest.yaml
```

---

## 📚 Links Rápidos

- [README.md](./README.md)
- [QUICK-START.md](./QUICK-START.md)
- [VALIDACAO.md](./VALIDACAO.md)
- [FLUXO-DEMO-GITOPS.md](./FLUXO-DEMO-GITOPS.md)
