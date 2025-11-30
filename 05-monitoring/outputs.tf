# Outputs da Stack 05-monitoring
output "prometheus_workspace_id" {
  description = "ID do workspace do Amazon Managed Prometheus"
  value       = aws_prometheus_workspace.this.id
}

output "prometheus_workspace_endpoint" {
  description = "Endpoint do workspace do Amazon Managed Prometheus"
  value       = aws_prometheus_workspace.this.prometheus_endpoint
}

output "grafana_workspace_id" {
  description = "ID do workspace do Amazon Managed Grafana"
  value       = aws_grafana_workspace.this.id
}

output "grafana_workspace_endpoint" {
  description = "URL do workspace do Amazon Managed Grafana"
  value       = aws_grafana_workspace.this.endpoint
}

output "grafana_workspace_url" {
  description = "URL completa do Grafana para acesso"
  value       = "https://${aws_grafana_workspace.this.endpoint}/"
}

output "prometheus_scraper_id" {
  description = "ID do scraper do Prometheus"
  value       = aws_prometheus_scraper.this.id
}

output "grafana_api_key" {
  value       = aws_grafana_workspace_api_key.ansible.key
  sensitive   = true
  description = "API Key do Grafana para automação Ansible"
}