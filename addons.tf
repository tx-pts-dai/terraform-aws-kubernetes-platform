################################################################################
# EKS Addons
#

################################################################################
# EBS CSI Controller IAM Role for Service Accounts

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.55.0"

  create_role = var.create_addons

  role_name = "ebs-csi-driver-${local.id}"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

module "addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.21.1"

  create_kubernetes_resources = var.create_addons

  create_delay_dependencies = [
    helm_release.karpenter_release.status
  ]

  # Arbitrary delay to wait for Karpenter to create nodes before creating managed addons to avoid an isssue
  # where the managed addons are created before the nodes are ready and they fail
  create_delay_duration = "3m"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    coredns = {
      most_recent = true
      preserve    = false

      timeouts = {
        create = "3m"
        delete = "3m"
      }
    }

    aws-ebs-csi-driver = {
      most_recent = true
      preserve    = false

      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn

      configurations = {
        replicaCount = 1
      }

      timeouts = {
        create = "3m"
        delete = "3m"
      }
    }

    eks-pod-identity-agent = {
      most_recent = true
      preserve    = false

      configurations = {
        replicaCount = 2
      }

      timeouts = {
        create = "3m"
        delete = "3m"
      }
    }
  }

  # TODO: aws lb controller should be one of the last things deleted, so ing objects can be cleaned up
  enable_aws_load_balancer_controller = var.enable_aws_load_balancer_controller && var.create_addons
  aws_load_balancer_controller = {
    role_name        = "aws-load-balancer-controller-${local.id}"
    role_name_prefix = false

    # renovate: datasource=helm depName=aws-load-balancer-controller registryUrl=https://aws.github.io/eks-charts
    chart_version = "1.12.0"

    wait = true

    values = concat([
      <<-EOT
      clusterSecretsPermissions:
        allowAllSecrets: true
      serviceMutatorWebhookConfig:
        failurePolicy: Ignore
      EOT
    ], try(var.aws_load_balancer_controller.values, []))

    set = try(var.aws_load_balancer_controller.set, [])
  }

  enable_external_dns = var.enable_external_dns && var.create_addons
  external_dns_route53_zone_arns = [
    "arn:aws:route53:::hostedzone/*",
  ]
  external_dns = {
    role_name        = "external-dns-${local.id}"
    role_name_prefix = false

    values = try(var.external_dns.values, [])
    set = concat([{
      name  = "policy"
      value = "sync" # allows deletion of dns records
      }, {
      name  = "txtOwnerId"
      value = local.stack_name # avoid conflicts on the same hosted zone
    }], try(var.external_dns.set, []))
  }

  enable_external_secrets = var.enable_external_secrets && var.create_addons
  external_secrets = {
    wait             = true
    role_name        = "external-secrets-${local.id}"
    role_name_prefix = false

    values = try(var.external_secrets.values, [])
    set    = try(var.external_secrets.set, [])
  }

  enable_fargate_fluentbit = var.enable_fargate_fluentbit
  fargate_fluentbit = {
    fargate_fluentbit_cw_log_group_name = "/aws/eks/${module.eks.cluster_name}/fargate"
    role_name                           = "fargate-fluentbit-${local.id}"
    role_name_prefix                    = false

    values = try(var.fargate_fluentbit.values, [])
    set    = try(var.fargate_fluentbit.set, [])
  }

  enable_metrics_server = var.enable_metrics_server && var.create_addons
  metrics_server = {
    values = try(var.metrics_server.values, [])
    set = concat([{
      name  = "replicas",
      value = 2,
    }], try(var.metrics_server.set, []))
  }

  # Alternative Ingress
  enable_cert_manager = var.enable_cert_manager
  cert_manager        = var.cert_manager

  enable_ingress_nginx = var.enable_ingress_nginx
  ingress_nginx        = var.ingress_nginx

  depends_on = [
    helm_release.karpenter_release,
    helm_release.karpenter_resources
  ]
}

################################################################################
# Kube Downscaler

module "downscaler" {
  source  = "tx-pts-dai/downscaler/kubernetes"
  version = "0.3.1"

  count = var.enable_downscaler && var.create_addons ? 1 : 0

  image_version = try(var.downscaler.image_version, "23.2.0")
  dry_run       = try(var.downscaler.dry_run, false)
  custom_args   = try(var.downscaler.custom_args, [])
  node_selector = try(var.downscaler.node_selector, {})
  tolerations   = try(var.downscaler.tolerations, [])

  depends_on = [
    module.addons
  ]
}

################################################################################
# External Secrets Custom Resources
# TODO: move external secrets to dedicated module
resource "helm_release" "cluster_secret_store" {
  count = var.enable_external_secrets && var.create_addons ? 1 : 0

  name        = "cluster-secret-store-aws-secretsmanager"
  chart       = "custom-resources"
  version     = "0.1.2"
  repository  = "https://dnd-it.github.io/helm-charts"
  description = "External Secrets Cluster Secret Store for AWS Secrets Manager"
  namespace   = "external-secrets"

  values = [
    <<-EOT
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: aws-secretsmanager
    spec:
      provider:
        aws:
          service: SecretsManager
          region: ${local.region}
    EOT
  ]

  depends_on = [
    module.addons
  ]
}

################################################################################
# Reloader
resource "helm_release" "reloader" {
  count = var.create_addons && var.enable_reloader ? 1 : 0

  name        = "reloader"
  chart       = "reloader"
  version     = "2.1.3"
  repository  = "https://stakater.github.io/stakater-charts"
  description = "Reloader"
  namespace   = "reloader"

  create_namespace = true

  # https://github.com/stakater/Reloader/blob/master/deployments/kubernetes/chart/reloader/values.yaml

  dynamic "set" {
    for_each = try(var.reloader.set, [])

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  depends_on = [
    module.addons
  ]
}

################################################################################
# ArgoCD
module "argocd" {
  source = "./modules/argocd"

  create = var.create_addons && var.enable_argocd

  cluster_name = module.eks.cluster_name
  namespace    = var.argocd.namespace

  enable_hub   = var.argocd.enable_hub
  enable_spoke = var.argocd.enable_spoke

  hub_iam_role_name = var.argocd.hub_iam_role_name
  hub_iam_role_arn  = var.argocd.hub_iam_role_arn
  hub_iam_role_arns = var.argocd.hub_iam_role_arns

  helm_values = var.argocd.helm_values
  helm_set    = var.argocd.helm_set

  depends_on = [
    module.addons
  ]
}
