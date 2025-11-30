# Política de Segurança

## 🔒 Informações Sensíveis

Este projeto **NÃO** contém:
- ❌ Credenciais AWS (Access Keys, Secret Keys)
- ❌ Tokens de API hardcoded
- ❌ Senhas ou chaves privadas
- ❌ Account IDs reais
- ❌ Arquivos `.tfstate` (state do Terraform)

## ⚠️ ANTES DE USAR

**VOCÊ PRECISA SUBSTITUIR:**

1. **Account ID:** Substitua `620958830769` pelo ID da sua conta AWS em todos os arquivos `.tf`
2. **Bucket S3:** Substitua `eks-devopsproject-state-files-620958830769` pelo nome do seu bucket
3. **IAM User:** Edite `02-eks-cluster/locals.tf` e substitua `<YOUR_IAM_USER>` pelo seu usuário IAM
4. **SSO Role:** Se usar SSO, substitua `AWSReservedSSO_AdministratorAccess_xxxxx` pelo ARN correto

**Comandos de substituição no README.md** - Siga as seções 5.1 a 5.4

## 🛡️ Boas Práticas

1. **Nunca commite:**
   - Arquivos `.tfstate` ou `.tfstate.backup`
   - Arquivos `.tfvars` com valores reais
   - Diretório `.terraform/`
   - Credentials ou API keys

2. **Use `.gitignore`:**
   - O projeto já inclui `.gitignore` configurado
   - Arquivos sensíveis são automaticamente ignorados

3. **Variáveis Dinâmicas:**
   - Account ID é obtido via `data.aws_caller_identity`
   - API Keys são geradas dinamicamente pelo Terraform
   - Tokens são obtidos via data sources AWS

## 📝 Reportar Vulnerabilidades

Se você encontrar alguma informação sensível exposta neste repositório:

1. **NÃO** crie uma issue pública
2. Entre em contato diretamente com o mantenedor
3. Forneça detalhes da vulnerabilidade

## ✅ Checklist de Segurança Antes do Deploy

- [ ] Substituí todos os Account IDs
- [ ] Configurei meu próprio bucket S3
- [ ] Atualizei `locals.tf` com meu usuário IAM
- [ ] Verifiquei que `.gitignore` está ativo
- [ ] Não commitei arquivos `.tfstate`
- [ ] Não commitei arquivos `.tfvars` com valores reais
- [ ] Revisei que não há credenciais no código

---

**Última atualização:** Novembro 2025
