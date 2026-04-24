locals {
  file_path = "configs/argocd/hub/${var.argocd_hub_environment}/clusters/${var.cluster_name}.yaml"

  argocd_config = jsonencode({
    awsAuthConfig = {
      clusterName = var.cluster_name
      roleARN     = var.argocd_spoke_role_arn
    }
    tlsClientConfig = {
      insecure = false
      caData   = var.cluster_ca_data
    }
  })

  # Build the full label map — only include enable-* flags that are true
  labels = merge(
    {
      "argocd.argoproj.io/secret-type" = "cluster"
      "region"                         = var.aws_region
      "cluster-name"                   = var.cluster_name
      "aws-account-id"                 = var.aws_account_id
      "cluster-group"                  = var.cluster_labels.cluster_group
      "environment"                    = var.cluster_labels.environment
      "team"                           = var.cluster_labels.team
      "promotion-tier"                 = var.cluster_labels.promotion_tier
    },
    var.cluster_labels.enable_ack ? { "enable-ack" = "true" } : {},
    var.cluster_labels.enable_adapter ? { "enable-adapter" = "true" } : {},
    var.cluster_labels.enable_aws_load_balancer_controller ? { "enable-aws-load-balancer-controller" = "true" } : {},
    var.cluster_labels.enable_cert_manager ? { "enable-cert-manager" = "true" } : {},
    var.cluster_labels.enable_datadog_operator ? { "enable-datadog-operator" = "true" } : {},
    var.cluster_labels.enable_downscaler ? { "enable-downscaler" = "true" } : {},
    var.cluster_labels.enable_exporters ? { "enable-exporters" = "true" } : {},
    var.cluster_labels.enable_external_dns ? { "enable-external-dns" = "true" } : {},
    var.cluster_labels.enable_external_dns_crossaccount ? { "enable-external-dns-crossaccount" = "true" } : {},
    var.cluster_labels.enable_external_secrets ? { "enable-external-secrets" = "true" } : {},
    var.cluster_labels.enable_grafana ? { "enable-grafana" = "true" } : {},
    var.cluster_labels.enable_kargo ? { "enable-kargo" = "true" } : {},
    var.cluster_labels.enable_kube_prometheus_stack ? { "enable-kube-prometheus-stack" = "true" } : {},
    var.cluster_labels.enable_metrics_server ? { "enable-metrics-server" = "true" } : {},
    var.cluster_labels.enable_reloader ? { "enable-reloader" = "true" } : {},
    var.cluster_labels.enable_tailscale_operator ? { "enable-tailscale-operator" = "true" } : {},
  )

  cluster_secret_content = templatefile("${path.module}/templates/cluster-secret.yaml.tpl", {
    cluster_name     = var.cluster_name
    labels           = local.labels
    vpc_cidr         = var.vpc_cidr
    cluster_endpoint = var.cluster_endpoint
    argocd_config    = local.argocd_config
  })
}

resource "github_repository_file" "cluster_secret" {
  count = var.create ? 1 : 0

  repository          = split("/", var.github_repository)[1]
  branch              = var.github_branch
  file                = local.file_path
  content             = local.cluster_secret_content
  commit_message      = "chore(argocd): register cluster ${var.cluster_name} [terraform]"
  commit_author       = "Terraform"
  commit_email        = "terraform@noreply"
  overwrite_on_create = true

  lifecycle {
    # Deregistration is intentionally manual to prevent accidental cluster removal.
    # To deregister: delete the file from Git, then remove this resource from state.
    prevent_destroy = true

    precondition {
      condition     = var.argocd_spoke_role_arn != ""
      error_message = "argocd_spoke_role_arn must be set. Ensure enable_argocd = true and argocd.enable_spoke = true in the parent module."
    }
  }
}
