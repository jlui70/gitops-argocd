resource "aws_grafana_workspace" "this" {
  account_access_type      = "CURRENT_ACCOUNT"
  authentication_providers = ["AWS_SSO"]
  permission_type          = "SERVICE_MANAGED"
  role_arn                 = aws_iam_role.grafana.arn

  vpc_configuration {
    security_group_ids = [local.eks_cluster_security_group]
    subnet_ids         = data.aws_subnets.observability.ids
  }
}

# Criar API Key para Ansible
resource "aws_grafana_workspace_api_key" "ansible" {
  key_name        = "ansible-automation"
  key_role        = "ADMIN"
  seconds_to_live = 2592000  # 30 dias
  workspace_id    = aws_grafana_workspace.this.id
}
