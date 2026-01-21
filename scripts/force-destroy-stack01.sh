#!/bin/bash

# Script para forçar a destruição da Stack 01 - Networking
# Versão: 1.0
# Data: 19 de Janeiro de 2026
# Uso: Quando a Stack 01 não foi destruída corretamente

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROFILE="terraform"
REGION="us-east-1"

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║     🗑️  FORÇAR DESTRUIÇÃO - STACK 01 NETWORKING                ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""

cd "$PROJECT_ROOT/01-networking"

echo "📍 Diretório atual: $(pwd)"
echo ""

# Verificar se há terraform state
echo "🔍 Verificando Terraform state..."
if ! terraform state list &>/dev/null 2>&1; then
    echo "❌ Erro: Não foi possível acessar o Terraform state"
    echo ""
    echo "Possíveis causas:"
    echo "  1. State lock travado"
    echo "  2. Backend S3 inacessível"
    echo "  3. State corrompido"
    echo ""
    read -p "Tentar forçar unlock do state? (s/N): " force_unlock
    
    if [[ $force_unlock =~ ^[Ss]$ ]]; then
        echo ""
        echo "Para desbloquear, você precisa do Lock ID"
        echo "Você pode encontrá-lo no DynamoDB ou no erro anterior"
        echo ""
        read -p "Digite o Lock ID (ou deixe em branco para pular): " lock_id
        
        if [ -n "$lock_id" ]; then
            terraform force-unlock -force "$lock_id"
            echo "✅ State desbloqueado"
        fi
    fi
    echo ""
fi

# Listar recursos no state
echo "📋 Recursos no Terraform state:"
if terraform state list 2>/dev/null; then
    RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l)
    echo ""
    echo "Total de recursos: $RESOURCE_COUNT"
else
    echo "⚠️  Nenhum recurso encontrado no state (ou state inacessível)"
    RESOURCE_COUNT=0
fi
echo ""

# Verificar recursos reais na AWS
echo "🔍 Verificando recursos reais na AWS..."
VPC_NAME="eks-devopsproject-vpc"
VPC_ID=$(aws ec2 describe-vpcs \
    --region $REGION \
    --profile $PROFILE \
    --filters "Name=tag:Name,Values=$VPC_NAME" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || echo "")

if [ -n "$VPC_ID" ] && [ "$VPC_ID" != "None" ]; then
    echo "   ✅ VPC encontrada: $VPC_ID"
    HAS_VPC=true
else
    echo "   ℹ️  VPC não encontrada (pode já ter sido deletada)"
    HAS_VPC=false
fi
echo ""

# Escolher método de destruição
if [ "$RESOURCE_COUNT" -gt 0 ]; then
    echo "═══════════════════════════════════════════════════════════════════"
    echo "MÉTODO 1: Terraform Destroy (Recomendado)"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "Este método usa o Terraform para destruir os recursos de forma"
    echo "organizada, respeitando as dependências."
    echo ""
    read -p "Executar 'terraform destroy'? (s/N): " use_terraform
    
    if [[ $use_terraform =~ ^[Ss]$ ]]; then
        echo ""
        echo "🗑️  Executando terraform destroy..."
        echo ""
        
        # Tentar destroy normal primeiro
        if terraform destroy -auto-approve; then
            echo ""
            echo "✅ Stack 01 destruída com sucesso via Terraform!"
            exit 0
        else
            echo ""
            echo "⚠️  Terraform destroy falhou"
            echo ""
            
            # Oferecer tentar com -refresh=false
            read -p "Tentar novamente com -refresh=false? (s/N): " retry_no_refresh
            
            if [[ $retry_no_refresh =~ ^[Ss]$ ]]; then
                echo ""
                terraform destroy -auto-approve -refresh=false || {
                    echo ""
                    echo "❌ Destroy falhou novamente"
                }
            fi
        fi
    fi
fi

# Método manual se terraform falhar ou não for usado
if [ "$HAS_VPC" = true ]; then
    echo ""
    echo "═══════════════════════════════════════════════════════════════════"
    echo "MÉTODO 2: Deleção Manual via AWS CLI"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    echo "⚠️  ATENÇÃO: Este método irá deletar recursos diretamente via AWS CLI"
    echo "   sem atualizar o Terraform state. Use apenas se o Terraform falhar."
    echo ""
    read -p "Continuar com deleção manual? (s/N): " manual_delete
    
    if [[ ! $manual_delete =~ ^[Ss]$ ]]; then
        echo "❌ Operação cancelada"
        exit 0
    fi
    
    echo ""
    echo "🗑️  Deletando recursos manualmente..."
    echo ""
    
    # 1. Deletar NAT Gateways
    echo "═══ NAT Gateways ═══"
    NAT_IDS=$(aws ec2 describe-nat-gateways \
        --region $REGION \
        --profile $PROFILE \
        --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available,pending" \
        --query 'NatGateways[].NatGatewayId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$NAT_IDS" ]; then
        for nat_id in $NAT_IDS; do
            echo "🗑️  Deletando NAT Gateway: $nat_id"
            aws ec2 delete-nat-gateway \
                --nat-gateway-id "$nat_id" \
                --region $REGION \
                --profile $PROFILE && \
                echo "   ✅ Deletado" || \
                echo "   ❌ Erro ao deletar"
        done
        echo "⏳ Aguardando NAT Gateways serem deletados (60s)..."
        sleep 60
    else
        echo "ℹ️  Nenhum NAT Gateway encontrado"
    fi
    echo ""
    
    # 2. Liberar Elastic IPs
    echo "═══ Elastic IPs ═══"
    # Buscar EIPs associados aos NAT Gateways deletados
    EIP_IDS=$(aws ec2 describe-addresses \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=domain,Values=vpc" \
        --query 'Addresses[?AssociationId==null].AllocationId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$EIP_IDS" ]; then
        for eip_id in $EIP_IDS; do
            echo "🗑️  Liberando Elastic IP: $eip_id"
            aws ec2 release-address \
                --allocation-id "$eip_id" \
                --region $REGION \
                --profile $PROFILE && \
                echo "   ✅ Liberado" || \
                echo "   ❌ Erro ao liberar"
        done
    else
        echo "ℹ️  Nenhum Elastic IP desassociado encontrado"
    fi
    echo ""
    
    # 3. Deletar ENIs órfãos
    echo "═══ Network Interfaces ═══"
    ENI_IDS=$(aws ec2 describe-network-interfaces \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=vpc-id,Values=$VPC_ID" "Name=status,Values=available" \
        --query 'NetworkInterfaces[].NetworkInterfaceId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$ENI_IDS" ]; then
        for eni_id in $ENI_IDS; do
            echo "🗑️  Deletando ENI: $eni_id"
            aws ec2 delete-network-interface \
                --network-interface-id "$eni_id" \
                --region $REGION \
                --profile $PROFILE && \
                echo "   ✅ Deletado" || \
                echo "   ⚠️  Erro ao deletar (pode estar em uso)"
        done
    else
        echo "ℹ️  Nenhum ENI disponível encontrado"
    fi
    echo ""
    
    # 4. Deletar Security Groups (exceto default)
    echo "═══ Security Groups ═══"
    SG_IDS=$(aws ec2 describe-security-groups \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'SecurityGroups[?GroupName!=`default`].GroupId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$SG_IDS" ]; then
        # Primeiro remover regras de ingress que referenciam outros SGs
        echo "🧹 Removendo regras de ingress..."
        for sg_id in $SG_IDS; do
            aws ec2 describe-security-groups \
                --group-ids "$sg_id" \
                --region $REGION \
                --profile $PROFILE \
                --query 'SecurityGroups[0].IpPermissions' 2>/dev/null | \
            aws ec2 revoke-security-group-ingress \
                --group-id "$sg_id" \
                --region $REGION \
                --profile $PROFILE \
                --ip-permissions file:///dev/stdin 2>/dev/null || true
        done
        
        # Depois deletar os SGs
        echo "🗑️  Deletando Security Groups..."
        for sg_id in $SG_IDS; do
            echo "   → $sg_id"
            aws ec2 delete-security-group \
                --group-id "$sg_id" \
                --region $REGION \
                --profile $PROFILE && \
                echo "      ✅ Deletado" || \
                echo "      ⚠️  Erro ao deletar (pode ter dependências)"
        done
    else
        echo "ℹ️  Nenhum Security Group encontrado"
    fi
    echo ""
    
    # 5. Deletar Route Tables (exceto main)
    echo "═══ Route Tables ═══"
    RT_IDS=$(aws ec2 describe-route-tables \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'RouteTables[?Associations[0].Main==`false`].RouteTableId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$RT_IDS" ]; then
        for rt_id in $RT_IDS; do
            echo "🗑️  Route Table: $rt_id"
            
            # Desassociar subnets
            ASSOC_IDS=$(aws ec2 describe-route-tables \
                --region $REGION \
                --profile $PROFILE \
                --route-table-ids "$rt_id" \
                --query 'RouteTables[].Associations[?!Main].RouteTableAssociationId' \
                --output text 2>/dev/null || echo "")
            
            for assoc_id in $ASSOC_IDS; do
                echo "   → Desassociando: $assoc_id"
                aws ec2 disassociate-route-table \
                    --association-id "$assoc_id" \
                    --region $REGION \
                    --profile $PROFILE 2>/dev/null || true
            done
            
            # Deletar route table
            aws ec2 delete-route-table \
                --route-table-id "$rt_id" \
                --region $REGION \
                --profile $PROFILE && \
                echo "   ✅ Deletado" || \
                echo "   ❌ Erro ao deletar"
        done
    else
        echo "ℹ️  Nenhuma Route Table encontrada"
    fi
    echo ""
    
    # 6. Deletar Internet Gateway
    echo "═══ Internet Gateway ═══"
    IGW_IDS=$(aws ec2 describe-internet-gateways \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=attachment.vpc-id,Values=$VPC_ID" \
        --query 'InternetGateways[].InternetGatewayId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$IGW_IDS" ]; then
        for igw_id in $IGW_IDS; do
            echo "🗑️  Internet Gateway: $igw_id"
            echo "   → Desanexando da VPC..."
            aws ec2 detach-internet-gateway \
                --internet-gateway-id "$igw_id" \
                --vpc-id "$VPC_ID" \
                --region $REGION \
                --profile $PROFILE 2>/dev/null || true
            
            echo "   → Deletando..."
            aws ec2 delete-internet-gateway \
                --internet-gateway-id "$igw_id" \
                --region $REGION \
                --profile $PROFILE && \
                echo "   ✅ Deletado" || \
                echo "   ❌ Erro ao deletar"
        done
    else
        echo "ℹ️  Nenhum Internet Gateway encontrado"
    fi
    echo ""
    
    # 7. Deletar Subnets
    echo "═══ Subnets ═══"
    SUBNET_IDS=$(aws ec2 describe-subnets \
        --region $REGION \
        --profile $PROFILE \
        --filters "Name=vpc-id,Values=$VPC_ID" \
        --query 'Subnets[].SubnetId' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$SUBNET_IDS" ]; then
        for subnet_id in $SUBNET_IDS; do
            SUBNET_NAME=$(aws ec2 describe-subnets \
                --subnet-ids "$subnet_id" \
                --region $REGION \
                --profile $PROFILE \
                --query 'Subnets[0].Tags[?Key==`Name`].Value' \
                --output text 2>/dev/null || echo "")
            
            echo "🗑️  Deletando Subnet: $subnet_id ($SUBNET_NAME)"
            aws ec2 delete-subnet \
                --subnet-id "$subnet_id" \
                --region $REGION \
                --profile $PROFILE && \
                echo "   ✅ Deletado" || \
                echo "   ❌ Erro ao deletar"
        done
    else
        echo "ℹ️  Nenhuma Subnet encontrada"
    fi
    echo ""
    
    # 8. Deletar VPC
    echo "═══ VPC ═══"
    echo "🗑️  Deletando VPC: $VPC_ID"
    echo "⏳ Aguardando propagação (5s)..."
    sleep 5
    
    aws ec2 delete-vpc \
        --vpc-id "$VPC_ID" \
        --region $REGION \
        --profile $PROFILE && \
        echo "✅ VPC deletada com sucesso!" || \
        echo "❌ Erro ao deletar VPC (pode ter recursos dependentes ainda ativos)"
    echo ""
fi

# Limpar o Terraform state
if [ "$RESOURCE_COUNT" -gt 0 ]; then
    echo "═══════════════════════════════════════════════════════════════════"
    echo "🧹 Limpeza do Terraform State"
    echo "═══════════════════════════════════════════════════════════════════"
    echo ""
    read -p "Remover todos os recursos do Terraform state? (s/N): " clean_state
    
    if [[ $clean_state =~ ^[Ss]$ ]]; then
        echo ""
        echo "🗑️  Removendo recursos do state..."
        terraform state list 2>/dev/null | while read resource; do
            echo "   → Removendo: $resource"
            terraform state rm "$resource" 2>/dev/null || true
        done
        echo "✅ State limpo"
    fi
    echo ""
fi

echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║              ✅ PROCESSO CONCLUÍDO                              ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo ""
echo "🔍 Para verificar se ainda há recursos:"
echo "   ./scripts/check-resources.sh"
echo ""
