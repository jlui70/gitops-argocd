#!/bin/bash
# Script para alternar entre v1 e v2 via renomeação de arquivos
# Alternativa para quem não domina editores como vi

set -e

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  🔄 ALTERNADOR v1 ↔ v2 (via renomeação de arquivos)     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

# Detectar versão atual
if grep -q "^  - ecommerce-ui-backend.yaml" kustomization.yaml 2>/dev/null; then
    VERSAO_ATUAL="v2"
else
    VERSAO_ATUAL="v1"
fi

echo "📌 Versão atual: $VERSAO_ATUAL"
echo ""

# Menu
echo "Escolha uma opção:"
echo "  1) Ativar v2 (banner NEW FEATURES)"
echo "  2) Voltar para v1 (sem banner)"
echo "  3) Cancelar"
echo ""
read -p "Opção: " OPCAO

case $OPCAO in
    1)
        if [ "$VERSAO_ATUAL" == "v2" ]; then
            echo "⚠️  v2 já está ativa!"
            exit 0
        fi
        
        echo ""
        echo "🔄 Ativando v2..."
        
        # Backup da v1 atual
        cp kustomization.yaml kustomization_v1_backup.yaml
        
        # Substituir por v2
        cp kustomization_v2.yaml kustomization.yaml
        
        echo "✅ v2 ativada!"
        echo ""
        echo "📝 Próximos passos:"
        echo "   git add kustomization.yaml"
        echo "   git commit -m 'Deploy v2 - Ativa banner'"
        echo "   git push origin main"
        echo ""
        echo "⏳ Aguardar 30-45s para ArgoCD detectar"
        ;;
        
    2)
        if [ "$VERSAO_ATUAL" == "v1" ]; then
            echo "⚠️  v1 já está ativa!"
            exit 0
        fi
        
        echo ""
        echo "🔄 Voltando para v1..."
        
        # Backup da v2 atual
        cp kustomization.yaml kustomization_v2_backup.yaml
        
        # Substituir por v1
        cp kustomization_v1.yaml kustomization.yaml
        
        echo "✅ v1 ativada (rollback)!"
        echo ""
        echo "📝 Próximos passos:"
        echo "   git add kustomization.yaml"
        echo "   git commit -m 'Rollback v1 - Remove banner'"
        echo "   git push origin main"
        echo ""
        echo "⏳ Aguardar 30-45s para ArgoCD detectar"
        ;;
        
    3)
        echo "❌ Cancelado"
        exit 0
        ;;
        
    *)
        echo "❌ Opção inválida!"
        exit 1
        ;;
esac
