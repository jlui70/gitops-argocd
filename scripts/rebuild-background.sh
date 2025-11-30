#!/bin/bash

# Script para rebuild em background com log
# Versão: 1.0

LOG_FILE="/tmp/eks-rebuild-$(date +%Y%m%d_%H%M%S).log"

echo "🚀 Iniciando rebuild em background..."
echo "📝 Log: $LOG_FILE"
echo ""

# Executar rebuild em background com log
nohup ./rebuild-all.sh > "$LOG_FILE" 2>&1 &
PID=$!

echo "✅ Processo iniciado! PID: $PID"
echo ""
echo "🔍 Monitorar progresso:"
echo "   tail -f $LOG_FILE"
echo ""
echo "🛑 Parar execução:"
echo "   kill $PID"
echo ""
echo "📊 Verificar se está rodando:"
echo "   ps aux | grep $PID"
echo ""

# Salvar PID para referência
echo "$PID" > /tmp/rebuild.pid
echo "PID salvo em: /tmp/rebuild.pid"
