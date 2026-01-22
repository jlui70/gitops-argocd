#!/bin/bash

# Script de Emergência - Limpeza FORÇADA de TODOS os recursos AWS
# Use quando destroy-all.sh falhar e deixar recursos órfãos
# ATENÇÃO: Este script DELETA TUDO relacionado ao projeto, independente do Terraform state

set +e  # Continua mesmo com erros

AWS_PROFILE="devopsproject"
REGION="us-east-1"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║        🚨 LIMPEZA DE EMERGÊNCIA - FORÇADA VIA AWS CLI          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  Este script deleta TODOS os recursos do projeto via AWS CLI"
echo "⚠️  Use apenas quando destroy-all.sh falhar"
echo ""
read -p "Confirma limpeza FORÇADA? (digite SIM em maiúsculas): " confirm

if [ "$confirm" != "SIM" ]; then
    echo "❌ Cancelado pelo usuário"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "1️⃣ DELETANDO EKS CLUSTER (se existir)"
echo "═══════════════════════════════════════════════════════════════════"

CLUSTER_NAME="eks-devopsproject-cluster"
if aws eks describe-cluster --name $CLUSTER_NAME --profile $AWS_PROFILE &>/dev/null; then
    echo "  📦 Cluster encontrado: $CLUSTER_NAME"
    
    # Deletar node groups primeiro
    echo "  🗑️  Deletando Node Groups..."
    NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --profile $AWS_PROFILE --query 'nodegroups' --output text 2>/dev/null)
    for ng in $NODE_GROUPS; do
        echo "    → Deletando Node Group: $ng"
        aws eks delete-nodegroup --cluster-name $CLUSTER_NAME --nodegroup-name $ng --profile $AWS_PROFILE &>/dev/null
    done
    
    if [ -n "$NODE_GROUPS" ]; then
        echo "    ⏳ Aguardando Node Groups serem deletados (180s)..."
        sleep 180
    fi
    
    # Deletar cluster
    echo "  🗑️  Deletando EKS Cluster..."
    aws eks delete-cluster --name $CLUSTER_NAME --profile $AWS_PROFILE &>/dev/null
    echo "    ⏳ Aguardando cluster ser deletado (120s)..."
    sleep 120
    
    echo "  ✅ EKS Cluster em processo de deleção"
else
    echo "  ℹ️  EKS Cluster não encontrado"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "2️⃣ DELETANDO EC2 INSTANCES (Node Group)"
echo "═══════════════════════════════════════════════════════════════════"

INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:eks:cluster-name,Values=$CLUSTER_NAME" "Name=instance-state-name,Values=running,stopped,stopping" \
    --profile $AWS_PROFILE \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text 2>/dev/null)

if [ -n "$INSTANCES" ]; then
    echo "  🗑️  Terminando EC2 Instances..."
    for instance in $INSTANCES; do
        echo "    → Terminando: $instance"
        aws ec2 terminate-instances --instance-ids $instance --profile $AWS_PROFILE &>/dev/null
    done
    echo "    ⏳ Aguardando instances terminarem (60s)..."
    sleep 60
    echo "  ✅ Instances terminadas"
else
    echo "  ℹ️  Nenhuma EC2 instance encontrada"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "3️⃣ DELETANDO ALBs, TARGET GROUPS, SECURITY GROUPS"
echo "═══════════════════════════════════════════════════════════════════"

# ALBs
echo "  🗑️  Deletando Application Load Balancers..."
ALBS=$(aws elbv2 describe-load-balancers \
    --profile $AWS_PROFILE \
    --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-')].LoadBalancerArn" \
    --output text 2>/dev/null)

for alb in $ALBS; do
    echo "    → Deletando ALB: $alb"
    aws elbv2 delete-load-balancer --load-balancer-arn $alb --profile $AWS_PROFILE &>/dev/null
done

if [ -n "$ALBS" ]; then
    echo "    ⏳ Aguardando ALBs (30s)..."
    sleep 30
fi

# Target Groups
echo "  🗑️  Deletando Target Groups..."
TGS=$(aws elbv2 describe-target-groups \
    --profile $AWS_PROFILE \
    --query "TargetGroups[?starts_with(TargetGroupName, 'k8s-')].TargetGroupArn" \
    --output text 2>/dev/null)

for tg in $TGS; do
    echo "    → Deletando TG: $tg"
    aws elbv2 delete-target-group --target-group-arn $tg --profile $AWS_PROFILE &>/dev/null
done

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "4️⃣ DELETANDO VPC E COMPONENTES"
echo "═══════════════════════════════════════════════════════════════════"

VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=tag:Name,Values=eks-devopsproject-vpc" \
    --profile $AWS_PROFILE \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ "$VPC_ID" != "None" ] && [ -n "$VPC_ID" ]; then
    echo "  📦 VPC encontrada: $VPC_ID"
    
    # NAT Gateways
    echo "  🗑️  Deletando NAT Gateways..."
    NAT_GWS=$(aws ec2 describe-nat-gateways \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" \
        --profile $AWS_PROFILE \
        --query 'NatGateways[].NatGatewayId' \
        --output text 2>/dev/null)
    
    for nat in $NAT_GWS; do
        echo "    → Deletando NAT: $nat"
        aws ec2 delete-nat-gateway --nat-gateway-id $nat --profile $AWS_PROFILE &>/dev/null
    done
    
    if [ -n "$NAT_GWS" ]; then
        echo "    ⏳ Aguardando NAT Gateways (60s)..."
        sleep 60
    fi
    
    # EIPs
    echo "  🗑️  Liberando Elastic IPs..."
    EIPS=$(aws ec2 describe-addresses \
        --filters "Name=domain,Values=vpc" \
        --profile $AWS_PROFILE \
        --query 'Addresses[].AllocationId' \
        --output text 2>/dev/null)
    
    for eip in $EIPS; do
        echo "    → Liberando EIP: $eip"
        aws ec2 release-address --allocation-id $eip --profile $AWS_PROFILE &>/dev/null || true
    done
    
    # ENIs - TODAS as ENIs disponíveis na VPC
    echo "  🗑️  Deletando Network Interfaces..."
    ENIS=$(aws ec2 describe-network-interfaces \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text 2>/dev/null)
    
    for eni in $ENIS; do
        echo "    → Deletando ENI: $eni"
        aws ec2 delete-network-interface --network-interface-id $eni --profile $AWS_PROFILE &>/dev/null || true
    done
    
    sleep 10
    
    # Security Groups - TENTAR VÁRIAS VEZES
    echo "  🗑️  Deletando Security Groups (pode precisar de várias tentativas)..."
    for attempt in {1..3}; do
        echo "    Tentativa $attempt/3..."
        
        SGS=$(aws ec2 describe-security-groups \
            --filters "Name=vpc-id,Values=$VPC_ID" \
            --profile $AWS_PROFILE \
            --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
            --output text 2>/dev/null)
        
        if [ -z "$SGS" ]; then
            echo "    ✅ Todos os SGs deletados"
            break
        fi
        
        for sg in $SGS; do
            # Revogar todas as regras primeiro
            aws ec2 revoke-security-group-ingress --group-id $sg --profile $AWS_PROFILE \
                --ip-permissions "$(aws ec2 describe-security-groups --group-ids $sg --profile $AWS_PROFILE --query 'SecurityGroups[0].IpPermissions' 2>/dev/null)" &>/dev/null || true
            
            aws ec2 revoke-security-group-egress --group-id $sg --profile $AWS_PROFILE \
                --ip-permissions "$(aws ec2 describe-security-groups --group-ids $sg --profile $AWS_PROFILE --query 'SecurityGroups[0].IpPermissionsEgress' 2>/dev/null)" &>/dev/null || true
            
            # Tentar deletar
            aws ec2 delete-security-group --group-id $sg --profile $AWS_PROFILE &>/dev/null && \
                echo "      ✅ SG deletado: $sg" || \
                echo "      ⏳ SG ainda tem dependências: $sg"
        done
        
        if [ $attempt -lt 3 ]; then
            sleep 15
        fi
    done
    
    # IGW
    echo "  🗑️  Deletando Internet Gateway..."
    IGW=$(aws ec2 describe-internet-gateways \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'InternetGateways[0].InternetGatewayId' \
        --output text 2>/dev/null)
    
    if [ "$IGW" != "None" ] && [ -n "$IGW" ]; then
        aws ec2 detach-internet-gateway --internet-gateway-id $IGW --vpc-id $VPC_ID --profile $AWS_PROFILE &>/dev/null
        aws ec2 delete-internet-gateway --internet-gateway-id $IGW --profile $AWS_PROFILE &>/dev/null
        echo "    ✅ IGW deletado"
    fi
    
    # Subnets
    echo "  🗑️  Deletando Subnets..."
    SUBNETS=$(aws ec2 describe-subnets \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'Subnets[].SubnetId' \
        --output text 2>/dev/null)
    
    for subnet in $SUBNETS; do
        echo "    → Deletando Subnet: $subnet"
        aws ec2 delete-subnet --subnet-id $subnet --profile $AWS_PROFILE &>/dev/null || true
    done
    
    # Route Tables
    echo "  🗑️  Deletando Route Tables..."
    RTS=$(aws ec2 describe-route-tables \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --profile $AWS_PROFILE \
        --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' \
        --output text 2>/dev/null)
    
    for rt in $RTS; do
        echo "    → Deletando RT: $rt"
        aws ec2 delete-route-table --route-table-id $rt --profile $AWS_PROFILE &>/dev/null || true
    done
    
    # VPC - Última tentativa
    echo "  🗑️  Deletando VPC..."
    if aws ec2 delete-vpc --vpc-id $VPC_ID --profile $AWS_PROFILE 2>/dev/null; then
        echo "    ✅ VPC deletada com sucesso!"
    else
        echo "    ⚠️  VPC ainda não pôde ser deletada - verifique dependências manualmente"
        echo "    VPC ID: $VPC_ID"
    fi
else
    echo "  ℹ️  VPC não encontrada"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "5️⃣ DELETANDO S3 E DYNAMODB (Backend)"
echo "═══════════════════════════════════════════════════════════════════"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text --profile $AWS_PROFILE 2>/dev/null)
BUCKET_NAME="eks-devopsproject-state-files-${ACCOUNT_ID}"
TABLE_NAME="eks-devopsproject-terraform-locks"

# S3
if aws s3 ls "s3://$BUCKET_NAME" --profile $AWS_PROFILE &>/dev/null; then
    echo "  🗑️  Esvaziando e deletando bucket S3: $BUCKET_NAME"
    aws s3 rm "s3://$BUCKET_NAME" --recursive --profile $AWS_PROFILE &>/dev/null || true
    aws s3 rb "s3://$BUCKET_NAME" --force --profile $AWS_PROFILE &>/dev/null && \
        echo "    ✅ Bucket S3 deletado" || \
        echo "    ⚠️  Erro ao deletar bucket"
else
    echo "  ℹ️  Bucket S3 não encontrado"
fi

# DynamoDB
if aws dynamodb describe-table --table-name $TABLE_NAME --profile $AWS_PROFILE &>/dev/null; then
    echo "  🗑️  Deletando tabela DynamoDB: $TABLE_NAME"
    aws dynamodb delete-table --table-name $TABLE_NAME --profile $AWS_PROFILE &>/dev/null && \
        echo "    ✅ Tabela DynamoDB deletada" || \
        echo "    ⚠️  Erro ao deletar tabela"
else
    echo "  ℹ️  Tabela DynamoDB não encontrada"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════"
echo "6️⃣ VERIFICAÇÃO FINAL"
echo "═══════════════════════════════════════════════════════════════════"

# Verificar se ainda existem recursos
REMAINING_VPC=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eks-devopsproject-vpc" --profile $AWS_PROFILE --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
REMAINING_CLUSTER=$(aws eks describe-cluster --name $CLUSTER_NAME --profile $AWS_PROFILE --query 'cluster.name' --output text 2>/dev/null)
REMAINING_BUCKET=$(aws s3 ls "s3://$BUCKET_NAME" --profile $AWS_PROFILE 2>&1 | grep -v "NoSuchBucket" | wc -l)

if [ "$REMAINING_VPC" == "None" ] || [ -z "$REMAINING_VPC" ]; then
    echo "  ✅ VPC: Deletada"
else
    echo "  ❌ VPC: AINDA EXISTE - $REMAINING_VPC"
    echo "     Verifique no console AWS e delete manualmente"
fi

if [ "$REMAINING_CLUSTER" == "None" ] || [ -z "$REMAINING_CLUSTER" ]; then
    echo "  ✅ EKS Cluster: Deletado"
else
    echo "  ❌ EKS Cluster: AINDA EXISTE"
    echo "     Aguarde ou delete manualmente no console"
fi

if [ "$REMAINING_BUCKET" -eq 0 ]; then
    echo "  ✅ S3 Bucket: Deletado"
else
    echo "  ❌ S3 Bucket: AINDA EXISTE"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              🏁 LIMPEZA DE EMERGÊNCIA CONCLUÍDA                 ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "⚠️  IMPORTANTE: Verifique o AWS Console para confirmar que todos"
echo "   os recursos foram realmente deletados antes de rodar rebuild!"
echo ""
echo "🔍 Verificar no console:"
echo "   - EC2 > Instances"
echo "   - EC2 > Load Balancers"  
echo "   - VPC > Your VPCs"
echo "   - EKS > Clusters"
echo "   - S3 > Buckets"
echo "   - DynamoDB > Tables"
echo ""
