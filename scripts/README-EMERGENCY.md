# 🚨 Script de Emergência - Limpeza Forçada

## Problema

Quando o `rebuild-all.sh` falha no meio da execução, o Terraform state pode ficar inconsistente. Neste caso:

- ✅ O `destroy-all.sh` diz que destruiu tudo
- ❌ Mas recursos continuam ativos na AWS
- ❌ **Gerando cobranças contínuas**

### Exemplo do Problema

```bash
./destroy-all.sh
# Output: "✅ DESTRUIÇÃO COMPLETA!"
# Mas no AWS Console:
#   - EKS Cluster ativo
#   - EC2 Instances rodando  
#   - VPC com subnets
#   - S3 e DynamoDB existem
```

## Solução: emergency-cleanup.sh

Script que **força a deleção via AWS CLI**, independente do Terraform state.

### Uso

```bash
cd scripts
./emergency-cleanup.sh
# Digite: SIM (em maiúsculas)
```

### O que o Script Faz

1. **Deleta EKS Cluster**
   - Node Groups primeiro
   - Depois o Cluster
   - Aguarda deleção completa

2. **Deleta EC2 Instances**
   - Todas as instances do node group
   - Terminate forçado

3. **Deleta Network Resources**
   - Application Load Balancers (ALBs)
   - Target Groups
   - Security Groups (múltiplas tentativas)
   - NAT Gateways
   - Elastic IPs
   - Network Interfaces (ENIs)

4. **Deleta VPC**
   - Internet Gateway
   - Subnets
   - Route Tables
   - VPC

5. **Deleta Backend**
   - S3 Bucket (esvazia e deleta)
   - DynamoDB Table

6. **Verificação Final**
   - Reporta recursos remanescentes
   - Avisa se algo ainda existe

### Quando Usar

- ✅ Depois que `destroy-all.sh` falhou
- ✅ Quando ver recursos órfãos no AWS Console
- ✅ Antes de tentar `rebuild-all.sh` novamente
- ✅ Para evitar cobranças de recursos esquecidos

### ATENÇÃO

⚠️ **Este script DELETA TUDO relacionado ao projeto**
⚠️ **Não há volta - confirme antes de executar**
⚠️ **Verifique o AWS Console após executar**

### Tempo de Execução

- **Total**: ~8-12 minutos
- EKS Cluster: ~5 minutos
- VPC e componentes: ~3 minutos  
- Backend: ~1 minuto

### Verificação Pós-Limpeza

Sempre verifique no AWS Console:

1. **EC2 Dashboard**
   - Instances: 0
   - Load Balancers: 0

2. **VPC Dashboard**
   - VPCs: apenas default

3. **EKS Console**
   - Clusters: 0

4. **S3 Console**
   - Bucket `eks-devopsproject-state-files-*`: não existe

5. **DynamoDB Console**
   - Table `eks-devopsproject-terraform-locks`: não existe

## Depois da Limpeza

Agora sim, pode executar rebuild do zero:

```bash
cd /caminho/para/projeto
git pull origin main  # Pegar última versão
./scripts/rebuild-all.sh
```

## Se o Script de Emergência Falhar

Alguns recursos podem ter dependências complexas. Se o script reportar recursos remanescentes:

1. **Aguarde 5-10 minutos** (AWS pode estar processando)
2. **Execute novamente** o emergency-cleanup.sh
3. **Se persistir**, delete manualmente no AWS Console na ordem:
   - EC2 Instances
   - Load Balancers
   - EKS Cluster
   - NAT Gateways
   - ENIs
   - Security Groups
   - Subnets
   - Route Tables
   - Internet Gateway
   - VPC
   - S3 Bucket
   - DynamoDB Table

## Prevenção

Para evitar este problema no futuro:

- ✅ Sempre rode `destroy-all.sh` se rebuild falhar
- ✅ Se destroy falhar, use `emergency-cleanup.sh`
- ✅ Verifique AWS Console antes de novo rebuild
- ✅ Não interrompa (Ctrl+C) os scripts no meio
