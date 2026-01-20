# Conceitos Fundamentais - Kubernetes no EKS

## 📚 Guia Educacional para Professores e Alunos

Este documento explica os conceitos fundamentais observados no cluster EKS criado por este projeto, ideal para uso em aulas e treinamentos.

---

## 🖥️ NODES (Worker Nodes)

### Por que 3 Nodes?

**Conceito**: Nodes são as máquinas (EC2 instances) que executam os containers/pods.

**Por que 3?**
- ✅ **Alta Disponibilidade (HA)**: Se 1 node falhar, os outros 2 continuam funcionando
- ✅ **Distribuição de Carga**: Workloads são distribuídos entre os 3 nodes
- ✅ **Best Practice**: Número ímpar previne "split-brain" em decisões de cluster
- ✅ **Zonas de Disponibilidade**: Cada node em uma AZ diferente (us-east-1a, 1b, 1c)

**Analogia**: Como ter 3 servidores físicos em um data center, se 1 cair, os outros 2 mantêm o serviço.

**Verificação no projeto**:
```bash
kubectl get nodes
# Mostra: ip-10-0-1-110, ip-10-0-1-15, ip-10-0-1-68
# Cada um em uma subnet/AZ diferente
```

---

## 📦 PODS

### O que é um Pod?

**Conceito**: Menor unidade no Kubernetes. Um "envelope" que contém 1 ou mais containers.

### Por que múltiplos Pods do mesmo tipo?

#### 1. **Deployments (2-3 réplicas)** - Para **Alta Disponibilidade**

| Pod | Réplicas | Motivo |
|-----|----------|--------|
| `aws-load-balancer-controller` | 2 | Se 1 cair, o outro assume |
| `coredns` | 2 | DNS sempre disponível |
| `ebs-csi-controller` | 2 | Gerenciamento de volumes resiliente |
| `metrics-server` | 2 | Monitoramento contínuo |

**Analogia**: Como ter 2 atendentes no caixa - se 1 tirar pausa, o outro continua atendendo.

#### 2. **DaemonSets (1 por node = 3 total)** - Para **Cobertura em Todos os Nodes**

| Pod | Quantidade | Motivo |
|-----|------------|--------|
| `aws-node` | 3 (1/node) | Networking em cada node |
| `kube-proxy` | 3 (1/node) | Roteamento em cada node |
| `ebs-csi-node` | 3 (1/node) | Acesso a volumes EBS em cada node |

**Analogia**: Como ter 1 segurança em cada andar de um prédio - cada andar precisa de cobertura.

---

## 🔄 REPLICASETS

### O que são?

**Conceito**: Mecanismo que **garante que X réplicas de um pod estejam sempre rodando**.

### Relação: Deployment → ReplicaSet → Pods

```
Deployment (desejado: 2 réplicas)
    ↓
ReplicaSet (gerencia: 2 pods)
    ↓
Pods (executa: 2 containers)
```

### Exemplo Prático:

```yaml
# Você define no Deployment:
replicas: 2

# Kubernetes cria automaticamente:
ReplicaSet → cria 2 pods
             ↓
Se 1 pod morrer → ReplicaSet cria outro automaticamente
```

### Os 4 ReplicaSets no projeto:

1. **aws-load-balancer-controller**: Mantém 2 pods gerenciando ALBs
2. **coredns**: Mantém 2 pods fazendo DNS resolution
3. **ebs-csi-controller**: Mantém 2 pods gerenciando volumes EBS
4. **metrics-server**: Mantém 2 pods coletando métricas

**Verificação**:
```bash
kubectl get replicasets -n kube-system
# Mostra: DESIRED 2, CURRENT 2, READY 2
```

---

## 🚀 DEPLOYMENTS

### O que são?

**Conceito**: Forma **declarativa** de gerenciar aplicações. Você diz "quero 2 réplicas" e o Kubernetes garante isso.

### Os 4 Deployments no Console AWS:

#### 1. **aws-load-balancer-controller** (2 réplicas)
- **Função**: Gerencia Application Load Balancers (ALBs) da AWS
- **Por quê?**: Quando você cria um Ingress, este controller provisiona um ALB automaticamente
- **Sem ele**: Você teria que criar ALBs manualmente na AWS Console
- **Arquivos relacionados**: `02-eks-cluster/eks.cluster.external.alb.tf`

#### 2. **coredns** (2 réplicas)
- **Função**: DNS interno do cluster
- **Por quê?**: Resolve nomes como `service-name.namespace.svc.cluster.local`
- **Exemplo**: Pod chama `product-catalog` → CoreDNS resolve para IP do serviço
- **Sem ele**: Pods não conseguem se comunicar por nome

#### 3. **ebs-csi-controller** (2 réplicas)
- **Função**: Controlador para volumes EBS (storage)
- **Por quê?**: Permite criar/attach/detach volumes EBS dinamicamente
- **Exemplo**: Banco de dados MongoDB precisa de disco persistente
- **Arquivos relacionados**: `02-eks-cluster/eks.cluster.addons.csi.tf`

#### 4. **metrics-server** (2 réplicas)
- **Função**: Coleta métricas de CPU/Memória dos pods
- **Por quê?**: Habilita `kubectl top pods` e Horizontal Pod Autoscaling (HPA)
- **Comando**: `kubectl top nodes` / `kubectl top pods`
- **Arquivos relacionados**: `02-eks-cluster/eks.cluster.addons.metrics-server.tf`

### Diagrama do Fluxo:

```
Você → kubectl apply deployment.yaml
         ↓
    Deployment (define: 2 réplicas)
         ↓
    ReplicaSet (cria: 2 pods)
         ↓
    Pods (executam: containers)
         ↓
    Nodes (hospedam: pods)
```

---

## 👹 DAEMONSETS

### O que são?

**Conceito**: Garante que **1 pod rode em CADA node** do cluster.

**Diferença para Deployments**:
- **Deployment**: "Quero 2 réplicas no cluster" (Kubernetes escolhe onde)
- **DaemonSet**: "Quero 1 réplica em CADA node" (obrigatório em todos)

### Os 4 DaemonSets no projeto:

#### 1. **aws-node** (3 pods - 1 por node)
- **Função**: Plugin CNI (Container Network Interface) da AWS VPC
- **Por quê?**: Atribui IPs da VPC aos pods
- **Como funciona**: Cada pod no node recebe um IP do range da subnet
- **Sem ele**: Pods não teriam conectividade de rede
- **Add-on relacionado**: Amazon VPC CNI

#### 2. **kube-proxy** (3 pods - 1 por node)
- **Função**: Gerencia regras de rede (iptables/IPVS) para Services
- **Por quê?**: Permite comunicação entre pods através de Services
- **Exemplo**: Request para `http://product-catalog:8080` → kube-proxy roteia para pod correto
- **Sem ele**: Services não funcionariam

#### 3. **ebs-csi-node** (3 pods - 1 por node)
- **Função**: Agent que monta volumes EBS nos nodes
- **Por quê?**: Trabalha com ebs-csi-controller para attach volumes
- **Exemplo**: Pod com PVC → este agent monta o EBS no node → pod acessa disco
- **Add-on relacionado**: Amazon EBS CSI Driver

#### 4. **ebs-csi-node-windows** (0 pods - porque não temos nodes Windows)
- **Função**: Mesma do ebs-csi-node, mas para Windows nodes
- **Por quê?**: Opcional, só roda se você tiver nodes Windows no cluster
- **Status**: 0 pods porque este projeto usa apenas Linux nodes

### Diagrama DaemonSet:

```
Cluster com 3 nodes:
    
Node 1 (us-east-1a)          Node 2 (us-east-1b)          Node 3 (us-east-1c)
├── aws-node                 ├── aws-node                 ├── aws-node
├── kube-proxy               ├── kube-proxy               ├── kube-proxy
├── ebs-csi-node             ├── ebs-csi-node             ├── ebs-csi-node
└── [seus apps]              └── [seus apps]              └── [seus apps]

DaemonSet garante: 1 pod em CADA node
```

### Caso de Uso - Adicionando um 4º Node:

```bash
# Se você adicionar um 4º node ao cluster:
# DaemonSets automaticamente criam pods no novo node:
Node 4 (us-east-1a)
├── aws-node      ← criado automaticamente
├── kube-proxy    ← criado automaticamente
└── ebs-csi-node  ← criado automaticamente
```

---

## 🧩 ADD-ONS

### O que são?

**Conceito**: Extensões **opcionais** que adicionam funcionalidades ao cluster EKS.

**Diferença**: 
- **Core Kubernetes**: kubectl, API server, scheduler (vem por padrão)
- **Add-ons**: Funcionalidades extras instaladas separadamente

### Os 3 Add-ons no projeto:

#### 1. **Amazon VPC CNI** 
```
Categoria: Networking
Função: Integração de rede entre pods e VPC AWS
```

**O que faz**:
- Atribui IPs da VPC diretamente aos pods
- Permite pods se comunicarem com recursos AWS (RDS, S3, etc) nativamente
- Implementa Security Groups para pods

**Por quê é necessário**:
- EKS roda na AWS VPC
- Pods precisam IPs válidos na VPC para se comunicar
- Alternativas (Calico, Flannel) não têm integração nativa com AWS

**Componente relacionado**: DaemonSet `aws-node`

**Arquivo Terraform**: `02-eks-cluster/eks.cluster.addons.csi.tf`

---

#### 2. **Amazon EBS CSI Driver**
```
Categoria: Storage
Função: Gerenciamento de volumes persistentes (EBS)
```

**O que faz**:
- Cria/attach/detach volumes EBS dinamicamente
- Permite usar StorageClasses para provisionamento automático
- Suporta snapshots e resize de volumes

**Por quê é necessário**:
- Aplicações stateful (bancos de dados) precisam de storage persistente
- Volumes devem sobreviver se o pod morrer
- EBS é o storage nativo da AWS

**Componentes relacionados**: 
- Deployment: `ebs-csi-controller` (2 réplicas)
- DaemonSet: `ebs-csi-node` (1 por node)

**Exemplo de uso**:
```yaml
# PersistentVolumeClaim para MongoDB
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-data
spec:
  storageClassName: gp3  # ← EBS CSI provisiona automaticamente
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
```

**Arquivo de exemplo**: `02-eks-cluster/samples/csi-sample-deployment.yml`

---

#### 3. **Metrics Server**
```
Categoria: Monitoring
Função: Coleta métricas de recursos (CPU/Memória)
```

**O que faz**:
- Coleta métricas de nodes e pods
- Expõe API para `kubectl top` e HPA
- Armazena dados em memória (curto prazo, últimos minutos)

**Por quê é necessário**:
- Visualizar consumo: `kubectl top nodes` / `kubectl top pods`
- Horizontal Pod Autoscaling (HPA): escala pods baseado em CPU/memória
- Debugging: identificar pods consumindo muitos recursos

**Componente relacionado**: Deployment `metrics-server` (2 réplicas)

**Comandos úteis**:
```bash
# Ver consumo dos nodes
kubectl top nodes

# Ver consumo dos pods
kubectl top pods -A

# Ver consumo de um namespace específico
kubectl top pods -n kube-system
```

**Arquivo Terraform**: `02-eks-cluster/eks.cluster.addons.metrics-server.tf`

---

### Comparação: Add-ons vs Instalação Manual

| Método | Vantagem | Desvantagem |
|--------|----------|-------------|
| **EKS Add-ons** | Gerenciado pela AWS, atualizações automáticas | Menos flexibilidade |
| **Helm Charts** | Mais controle, customizável | Você gerencia updates |
| **Manifests YAML** | Controle total | Trabalhoso de manter |

**Neste projeto**: Usamos EKS Add-ons (managed) via Terraform para facilitar manutenção.

---

## 🏗️ ARQUITETURA COMPLETA DO PROJETO

### Diagrama de Camadas:

```
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 0: Backend (S3 + DynamoDB)                               │
│  Função: Armazena Terraform state de forma remota e segura      │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 1: Networking (VPC + Subnets + NAT Gateways)            │
│  Função: Cria rede isolada com 3 AZs                            │
│  ├── Public Subnets (us-east-1a, 1b, 1c)                        │
│  └── Private Subnets (us-east-1a, 1b, 1c) ← Nodes ficam aqui   │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 2: EKS Cluster                                           │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Control Plane (gerenciado pela AWS)                       │ │
│  │ ├── API Server                                            │ │
│  │ ├── Scheduler                                             │ │
│  │ └── Controller Manager                                    │ │
│  └───────────────────────────────────────────────────────────┘ │
│                            ↓                                    │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ Worker Nodes (3 EC2 instances)                            │ │
│  │                                                           │ │
│  │  Node 1 (us-east-1a)   Node 2 (us-east-1b)   Node 3 (1c) │ │
│  │  ├── aws-node          ├── aws-node          ├── aws-node │ │
│  │  ├── kube-proxy        ├── kube-proxy        ├── kube-pro │ │
│  │  ├── ebs-csi-node      ├── ebs-csi-node      ├── ebs-csi- │ │
│  │  └── [app pods]        └── [app pods]        └── [app pod │ │
│  └───────────────────────────────────────────────────────────┘ │
│                            ↓                                    │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │ System Pods (kube-system namespace)                       │ │
│  │                                                           │ │
│  │  Deployments (2 réplicas cada):                          │ │
│  │  ├── aws-load-balancer-controller                        │ │
│  │  ├── coredns                                             │ │
│  │  ├── ebs-csi-controller                                  │ │
│  │  └── metrics-server                                      │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│  LAYER 3: Applications (não criado ainda)                       │
│  Função: Deploy do e-commerce (06-ecommerce-app)               │
│  ├── Frontend (ecommerce-ui)                                    │
│  ├── Backend Services (product-catalog, order-management, etc)  │
│  └── Ingress → ALB (criado pelo aws-load-balancer-controller)   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔍 FLUXOS DE FUNCIONAMENTO

### 1. Fluxo de Networking (Request HTTP chega no cluster)

```
Internet
   ↓
Route 53 (DNS: exemplo.com → ALB IP)
   ↓
Application Load Balancer (criado pelo Ingress)
   ↓
Target Group (apontando para nodes)
   ↓
kube-proxy (no node) → roteia para pod correto
   ↓
Pod (container da aplicação)
```

### 2. Fluxo de Storage (Pod precisa de volume persistente)

```
Desenvolvedor → cria PersistentVolumeClaim (PVC)
   ↓
ebs-csi-controller → cria volume EBS na AWS
   ↓
ebs-csi-node → attach o volume no node
   ↓
Kubelet → monta o volume no pod
   ↓
Pod → acessa o disco em /data
```

### 3. Fluxo de Comunicação entre Pods

```
Pod A (frontend) quer chamar Pod B (backend)
   ↓
Frontend chama: http://product-catalog:8080
   ↓
CoreDNS → resolve "product-catalog" → retorna IP do Service
   ↓
kube-proxy → roteia para um dos pods do backend (load balance)
   ↓
Pod B (backend) → processa request → retorna resposta
```

---

## 📊 CONTADORES E MATEMÁTICA

### Por que 17 pods no total?

```
Deployments (2 réplicas cada):
  2 × aws-load-balancer-controller
  2 × coredns
  2 × ebs-csi-controller
  2 × metrics-server
  = 8 pods

DaemonSets (1 por node × 3 nodes):
  3 × aws-node
  3 × kube-proxy
  3 × ebs-csi-node
  = 9 pods

TOTAL: 8 + 9 = 17 pods ✓
```

### E se escalarmos para 5 nodes?

```
Deployments: 8 pods (não muda, são 2 réplicas fixas)
DaemonSets: 5 × 3 = 15 pods (1 de cada tipo por node)

TOTAL: 8 + 15 = 23 pods
```

---

## 🎓 CONCEITOS EXTRAS IMPORTANTES

### 1. **Namespaces** (Isolamento Lógico)

**O que são**: "Pastas virtuais" dentro do cluster.

**No projeto**:
```bash
# Pods de sistema
kube-system → aws-load-balancer-controller, coredns, etc

# Aplicações (será criado depois)
default → onde você coloca suas apps
ecommerce → namespace customizado para o e-commerce
```

**Por quê usar**:
- Organização: separar ambientes (dev, staging, prod)
- Segurança: RBAC por namespace
- Resource Quotas: limitar CPU/memória por namespace

---

### 2. **Services** (Abstração de Rede)

**O que são**: IP fixo e DNS name para acessar pods (que têm IPs dinâmicos).

**Tipos**:
```yaml
# ClusterIP (padrão): acessível apenas dentro do cluster
kind: Service
type: ClusterIP

# NodePort: expõe porta em todos os nodes
type: NodePort

# LoadBalancer: cria ALB/NLB na AWS
type: LoadBalancer
```

**Exemplo do projeto** (será criado no deploy):
```yaml
# 06-ecommerce-app/manifests/product-catalog.yaml
apiVersion: v1
kind: Service
metadata:
  name: product-catalog
spec:
  type: ClusterIP
  selector:
    app: product-catalog
  ports:
  - port: 8080
    targetPort: 8080
```

---

### 3. **Ingress** (Roteamento HTTP/HTTPS)

**O que é**: Regras de roteamento para expor múltiplos serviços via 1 ALB.

**Sem Ingress**:
- Cada serviço = 1 LoadBalancer = 1 ALB = $$$ (caro!)

**Com Ingress**:
- 1 ALB para todos os serviços
- Roteamento por path: `/api` → backend, `/` → frontend

**Exemplo do projeto** (`06-ecommerce-app/manifests/ingress.yaml`):
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - host: ecommerce.exemplo.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ecommerce-ui
            port: 80
```

**Como funciona**:
1. Você cria o Ingress
2. aws-load-balancer-controller detecta
3. Controller cria ALB automaticamente na AWS
4. ALB roteia para Services → Pods

---

### 4. **OIDC (OpenID Connect)** - Autenticação para Pods

**O que é**: Permite pods assumirem IAM Roles sem precisar de access keys.

**Problema sem OIDC**:
```python
# Pod precisa acessar S3
# Ruim: hardcodear credentials
aws_access_key = "AKIAIOSFODNN7EXAMPLE"
aws_secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

**Solução com OIDC**:
```yaml
# Associar ServiceAccount com IAM Role
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456:role/pod-s3-role
```

**Usado no projeto**: 
- ALB Controller precisa criar ALBs → usa OIDC + IAM Role
- External DNS precisa modificar Route53 → usa OIDC + IAM Role

**Arquivo**: `02-eks-cluster/eks.cluster.oidc.tf`

---

### 5. **External DNS** (Automação de DNS)

**O que faz**: Cria/atualiza registros DNS no Route53 automaticamente.

**Fluxo**:
1. Você cria Ingress com `host: api.exemplo.com`
2. External DNS detecta a anotação
3. Cria registro no Route53: `api.exemplo.com → ALB DNS`
4. Usuário acessa `api.exemplo.com` → Route53 → ALB → Pods

**Arquivo**: `02-eks-cluster/eks.cluster.external.dns.tf`

---

## 🔐 SEGURANÇA E BOAS PRÁTICAS

### 1. **RBAC (Role-Based Access Control)**

```yaml
# Exemplo: dar permissão para um usuário apenas ler pods
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
```

**No projeto**: Configurado via `02-eks-cluster/eks.cluster.access.tf`

---

### 2. **Secrets** (Credenciais Seguras)

```bash
# Criar secret
kubectl create secret generic db-password \
  --from-literal=password=supersecret

# Usar no pod
env:
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-password
      key: password
```

---

### 3. **Resource Limits** (Prevenir um pod consumir tudo)

```yaml
resources:
  requests:    # Mínimo garantido
    cpu: 100m
    memory: 128Mi
  limits:      # Máximo permitido
    cpu: 500m
    memory: 512Mi
```

---

## 📝 COMANDOS ÚTEIS PARA AULAS

### Exploração Básica

```bash
# Listar todos os recursos
kubectl get all -A

# Ver detalhes de um pod
kubectl describe pod <pod-name> -n kube-system

# Ver logs de um pod
kubectl logs <pod-name> -n kube-system

# Entrar em um pod (debug)
kubectl exec -it <pod-name> -n kube-system -- /bin/bash

# Ver eventos do cluster
kubectl get events -A --sort-by='.lastTimestamp'
```

### Monitoramento

```bash
# Ver consumo de recursos
kubectl top nodes
kubectl top pods -A

# Ver capacidade do cluster
kubectl describe nodes | grep -A 5 "Allocated resources"

# Ver quais pods estão em qual node
kubectl get pods -A -o wide
```

### Debugging

```bash
# Por que um pod não está rodando?
kubectl describe pod <pod-name> -n <namespace>

# Ver logs com follow
kubectl logs -f <pod-name> -n <namespace>

# Ver logs anteriores (se pod crashou)
kubectl logs <pod-name> --previous -n <namespace>

# Port-forward para testar serviço localmente
kubectl port-forward svc/<service-name> 8080:80 -n <namespace>
```

### Inspeção de Configurações

```bash
# Ver o YAML completo de um recurso
kubectl get deployment aws-load-balancer-controller -n kube-system -o yaml

# Ver apenas as labels
kubectl get pods -n kube-system --show-labels

# Filtrar por label
kubectl get pods -l app=coredns -n kube-system

# Ver todos os Services
kubectl get svc -A

# Ver todos os Ingress
kubectl get ingress -A
```

---

## 🎯 EXERCÍCIOS PARA ALUNOS

### Nível 1: Observação

1. Liste todos os nodes e identifique em qual subnet cada um está
2. Conte quantos pods de cada DaemonSet existem e explique o número
3. Identifique qual pod consome mais CPU/memória

### Nível 2: Investigação

4. Descubra qual IAM Role o aws-load-balancer-controller está usando
5. Encontre quais portas o CoreDNS está escutando
6. Identifique qual imagem Docker cada pod está usando

### Nível 3: Experimentação

7. Delete um pod do coredns e observe o que acontece (ReplicaSet recria)
8. Faça port-forward de um serviço e teste localmente
9. Tente criar um pod simples (nginx) e veja em qual node ele foi alocado

### Nível 4: Troubleshooting

10. Simule um problema: escale coredns para 0 réplicas e teste resolução DNS
11. Remova o aws-load-balancer-controller e tente criar um Ingress
12. Analise os logs do metrics-server para entender como coleta dados

---

## 📚 REFERÊNCIAS E MATERIAIS EXTRAS

### Documentação Oficial

- **Kubernetes**: https://kubernetes.io/docs/
- **Amazon EKS**: https://docs.aws.amazon.com/eks/
- **AWS Load Balancer Controller**: https://kubernetes-sigs.github.io/aws-load-balancer-controller/
- **EBS CSI Driver**: https://github.com/kubernetes-sigs/aws-ebs-csi-driver

### Arquivos do Projeto Relacionados

| Conceito | Arquivo |
|----------|---------|
| Configuração do Cluster | [02-eks-cluster/eks.cluster.tf](../02-eks-cluster/eks.cluster.tf) |
| Node Groups | [02-eks-cluster/eks.cluster.node-group.tf](../02-eks-cluster/eks.cluster.node-group.tf) |
| Add-ons (CSI) | [02-eks-cluster/eks.cluster.addons.csi.tf](../02-eks-cluster/eks.cluster.addons.csi.tf) |
| Metrics Server | [02-eks-cluster/eks.cluster.addons.metrics-server.tf](../02-eks-cluster/eks.cluster.addons.metrics-server.tf) |
| ALB Controller | [02-eks-cluster/eks.cluster.external.alb.tf](../02-eks-cluster/eks.cluster.external.alb.tf) |
| External DNS | [02-eks-cluster/eks.cluster.external.dns.tf](../02-eks-cluster/eks.cluster.external.dns.tf) |
| OIDC | [02-eks-cluster/eks.cluster.oidc.tf](../02-eks-cluster/eks.cluster.oidc.tf) |
| Subnets | [01-networking/vpc.private-subnets.tf](../01-networking/vpc.private-subnets.tf) |

---

## 🎬 CONCLUSÃO

Este cluster EKS foi construído seguindo **AWS Well-Architected Framework**:

✅ **Confiabilidade**: 3 nodes em 3 AZs, réplicas de pods críticos  
✅ **Segurança**: OIDC, RBAC, pods em private subnets  
✅ **Eficiência de Performance**: Metrics Server, HPA, resource limits  
✅ **Otimização de Custos**: Add-ons managed (menos overhead operacional)  
✅ **Excelência Operacional**: IaC com Terraform, GitOps ready  

**Próximos Passos**: Deploy das aplicações e observação dos Ingress/ALB em ação!

---

*Documento criado para fins educacionais - GitOps EKS Project*  
*Última atualização: Janeiro 2026*
