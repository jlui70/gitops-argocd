# ══════════════════════════════════════════════════════════════════════
# ARGOCD - GitOps Continuous Delivery
# ══════════════════════════════════════════════════════════════════════

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"
  namespace  = "argocd"
  create_namespace = true

  # Wait for resources to be ready
  wait          = true
  wait_for_jobs = true
  timeout       = 600

  # High Availability Configuration
  set {
    name  = "controller.replicas"
    value = "1"
  }

  set {
    name  = "server.replicas"
    value = "2"
  }

  set {
    name  = "repoServer.replicas"
    value = "2"
  }

  # Service Configuration - LoadBalancer via ALB
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = "external"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-scheme"
    value = "internet-facing"
  }

  set {
    name  = "server.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-nlb-target-type"
    value = "ip"
  }

  # Insecure mode for demo (no TLS required)
  set {
    name  = "server.extraArgs[0]"
    value = "--insecure"
  }

  # Sync Configuration - Use configs.params instead of env vars
  set {
    name  = "configs.params.timeout\\.reconciliation"
    value = "180s"
  }

  set {
    name  = "configs.params.timeout\\.hard\\.reconciliation"
    value = "0"
  }

  depends_on = [
    aws_eks_cluster.this,
    aws_eks_node_group.this,
    helm_release.load_balancer_controller
  ]
}

# ══════════════════════════════════════════════════════════════════════
# ARGOCD CLI Secret (admin password)
# ══════════════════════════════════════════════════════════════════════

resource "kubernetes_secret" "argocd_initial_admin_secret" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }

  data = {
    # Default password: AdminArgo2026! (bcrypt hash)
    # Use: argocd account update-password
    password = "JDJhJDEwJHZxcVlEWnAuV0tMQmFZLlVOdjQuNE9YaFJpZ25oSlJWWkZMNGJZeTIuaS94eGdMNjRvTVEu"
  }

  depends_on = [helm_release.argocd]
}

# ══════════════════════════════════════════════════════════════════════
# OUTPUTS
# ══════════════════════════════════════════════════════════════════════

output "argocd_server_url" {
  description = "ArgoCD Server URL"
  value       = "http://argocd-server.argocd.svc.cluster.local"
}

output "argocd_admin_password" {
  description = "ArgoCD admin password (initial)"
  value       = "AdminArgo2026!"
  sensitive   = true
}
