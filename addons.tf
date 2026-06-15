################################################################################
# EKS Addons
#
# Create addons after Karpenter resources to avoid dependency issues
locals {
  cluster_addons = {
    coredns = {
      most_recent = true
      preserve    = false

      configuration_values = jsonencode({
        autoScaling = {
          enabled     = true
          minReplicas = 2
          maxReplicas = 10
        }
      })

      # Increase timeout to allow Karpenter time to provision nodes
      # Karpenter provisions nodes on-demand when pods are pending
      timeouts = {
        create = "20m"
        update = "20m"
      }
    }

    aws-ebs-csi-driver = {
      most_recent = true
      preserve    = false

      configuration_values = jsonencode({
        controller = {
          replicaCount = 1
        }
      })

      service_account_role_arn = module.ebs_csi_driver_irsa.arn

      # Increase timeout to allow Karpenter time to provision nodes
      # Karpenter provisions nodes on-demand when pods are pending
      timeouts = {
        create = "20m"
        update = "20m"
      }

      # Removing the IRSA role  does not work
      # BUG: https://github.com/hashicorp/terraform-provider-aws/issues/30645
      # pod_identity_association = [{
      #   role_arn        = module.aws_ebs_csi_pod_identity.iam_role_arn
      #   service_account = "ebs-csi-controller-sa"
      # }]
    }
  }

  # Per-capability "self-managed vs Auto Mode" toggles. Default to enabled unless
  # Auto Mode is on, but each can be overridden to migrate independently.
  create_self_managed_ebs_csi       = coalesce(var.enable_self_managed_ebs_csi, !var.enable_auto_mode)
  create_self_managed_lb_controller = coalesce(var.enable_self_managed_lb_controller, !var.enable_auto_mode)

  # Networking (VPC CNI, kube-proxy) and the Pod Identity agent run as node-level
  # services on Auto Mode nodes, but Auto Mode does NOT extend them to non-Auto-Mode
  # nodes. While the self-managed Karpenter stack runs, its nodes are ordinary EC2
  # nodes that need the traditional vpc-cni / kube-proxy DaemonSets (and the Pod
  # Identity agent) to get pod networking and become Ready — so these are retained
  # whenever enable_karpenter is true and dropped only in PURE Auto Mode, mirroring
  # the CoreDNS rule below. Not exposed as its own toggle: Auto Mode cannot serve a
  # self-managed node's data plane, so this strictly follows whether self-managed
  # compute exists. The addon DaemonSets exclude Auto Mode nodes via their own node
  # affinity, so they coexist with Auto Mode's managed copies.
  create_self_managed_networking = !var.enable_auto_mode || var.enable_karpenter

  # CoreDNS is dropped only in PURE Auto Mode, where Auto Mode provides cluster DNS
  # on its own nodes. In a mixed cluster (Auto Mode + self-managed Karpenter/Fargate
  # compute) those nodes are NOT served by Auto Mode's DNS and still need the cluster
  # CoreDNS Service, so the addon is retained while enable_karpenter is true.
  # Dropping it with preserve = false tears down the CoreDNS Deployment, leaving
  # every pod on the self-managed nodes without DNS. The EBS CSI driver follows its
  # own toggle so it can coexist with Auto Mode's managed EBS CSI.
  core_cluster_addons = merge(
    var.enable_auto_mode && !var.enable_karpenter ? {} : { coredns = local.cluster_addons.coredns },
    local.create_self_managed_ebs_csi ? { aws-ebs-csi-driver = local.cluster_addons.aws-ebs-csi-driver } : {},
  )

  extra_cluster_addons = merge(local.core_cluster_addons, var.extra_cluster_addons)
}

# Required for the self-managed EBS CSI Driver
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.6.1"

  create = local.create_self_managed_ebs_csi

  name            = "ebs-csi-driver-${local.id}"
  policy_name     = "ebs-csi-driver-${local.id}"
  use_name_prefix = false

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}

module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name       = module.eks.cluster_name
  kubernetes_version = module.eks.cluster_version

  cluster_addons          = local.extra_cluster_addons
  cluster_addons_timeouts = var.extra_cluster_addons_timeouts

  tags = var.tags

  depends_on = [
    time_sleep.wait_after_karpenter
  ]
}

################################################################################
# Pod Identity Roles
#
module "aws_ebs_csi_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.1"

  # Follows the self-managed EBS CSI toggle (Auto Mode provides its own managed
  # EBS CSI; keep both during a storage migration via enable_self_managed_ebs_csi).
  create = var.create_addon_pod_identity_roles && local.create_self_managed_ebs_csi

  name                    = "aws-ebs-csi-pod-identity-${local.id}"
  aws_ebs_csi_policy_name = "aws-ebs-csi-pod-identity-${local.id}"
  use_name_prefix         = false

  attach_aws_ebs_csi_policy = true

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "ebs-csi-controller-sa"
    }
  }

  tags = local.tags
}

module "aws_gateway_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.1"

  create = var.create_addon_pod_identity_roles

  name                               = "aws-gateway-controller-pod-identity-${local.id}"
  aws_gateway_controller_policy_name = "aws-gateway-controller-pod-identity-${local.id}"
  use_name_prefix                    = false

  attach_aws_gateway_controller_policy = true

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-gateway-api-controller"
    }
  }

  tags = local.tags
}

module "aws_lb_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.1"

  # Pod-identity role for the self-managed AWS Load Balancer Controller (deployed
  # via ArgoCD). Auto Mode has a built-in load balancer controller, but both can
  # coexist during a migration via enable_self_managed_lb_controller.
  create = var.create_addon_pod_identity_roles && local.create_self_managed_lb_controller

  name                          = "aws-lb-controller-pod-identity-${local.id}"
  aws_lb_controller_policy_name = "aws-lb-controller-pod-identity-${local.id}"
  use_name_prefix               = false

  attach_aws_lb_controller_policy = true

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "aws-loadbalancer-controller"
    }
  }
}

module "external_dns_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.1"

  create = var.create_addon_pod_identity_roles

  name                     = "external-dns-pod-identity-${local.id}"
  external_dns_policy_name = "external-dns-pod-identity-${local.id}"
  use_name_prefix          = false

  attach_external_dns_policy    = true
  external_dns_hosted_zone_arns = ["*"]

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-dns"
      service_account = "external-dns"
    }
  }
}

module "external_secrets_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.8.1"

  create = var.create_addon_pod_identity_roles

  name                         = "external-secrets-pod-identity-${local.id}"
  external_secrets_policy_name = "external-secrets-pod-identity-${local.id}"
  use_name_prefix              = false

  attach_external_secrets_policy        = true
  external_secrets_create_permission    = true
  external_secrets_ssm_parameter_arns   = ["*"]
  external_secrets_secrets_manager_arns = ["*"]

  policy_statements = [
    {
      sid       = "AssumeRole"
      actions   = ["sts:AssumeRole", "sts:TagSession"]
      resources = ["*"]
    }
  ]

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "external-secrets"
      service_account = "external-secrets"
    }
  }
}

################################################################################
# ArgoCD
module "argocd" {
  source = "./modules/argocd"

  create = var.enable_argocd

  cluster_name = module.eks.cluster_name
  namespace    = var.argocd.namespace

  enable_hub   = var.argocd.enable_hub
  enable_spoke = var.argocd.enable_spoke

  hub_iam_role_name = var.argocd.hub_iam_role_name
  hub_iam_role_arn  = var.argocd.hub_iam_role_arn
  hub_iam_role_arns = var.argocd.hub_iam_role_arns
}

################################################################################
# Fargate Fluent-bit
locals {
  fargate_fluentbit_cw_log_group_name   = "/aws/eks/${module.eks.cluster_name}/fargate"
  fargate_fluentbit_cwlog_stream_prefix = "fargate-logs-"
  fargate_fluentbit_policy_name         = "${module.eks.cluster_name}-fargate-fluentbit-logs"
}

resource "aws_cloudwatch_log_group" "fargate_fluentbit" {
  count = var.enable_fargate_fluentbit ? 1 : 0

  name              = local.fargate_fluentbit_cw_log_group_name
  retention_in_days = 90
  skip_destroy      = false
  tags              = local.tags
}

resource "aws_iam_policy" "fargate_fluentbit" {
  count = var.enable_fargate_fluentbit ? 1 : 0

  name   = local.fargate_fluentbit_policy_name
  policy = data.aws_iam_policy_document.fargate_fluentbit[0].json
}

data "aws_iam_policy_document" "fargate_fluentbit" {
  count = var.enable_fargate_fluentbit ? 1 : 0

  statement {
    sid = "PutLogEvents"
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.fargate_fluentbit[0].arn}:*",
      "${aws_cloudwatch_log_group.fargate_fluentbit[0].arn}:logstream:*"
    ]
  }
}
# Help on Fargate Logging with Fluentbit and CloudWatch
# https://docs.aws.amazon.com/eks/latest/userguide/fargate-logging.html
resource "kubernetes_namespace_v1" "aws_observability" {
  count = var.enable_fargate_fluentbit ? 1 : 0

  metadata {
    name = "aws-observability"

    labels = {
      aws-observability = "enabled"
    }
  }
}

# fluent-bit-cloudwatch value as the name of the CloudWatch log group that is automatically created as soon as your apps start logging
resource "kubernetes_config_map_v1" "aws_logging" {
  count = var.enable_fargate_fluentbit ? 1 : 0

  metadata {
    name      = "aws-logging"
    namespace = kubernetes_namespace_v1.aws_observability[0].id
  }

  data = {
    "parsers.conf" = (
      <<-EOT
        [PARSER]
          Name crio
          Format Regex
          Regex ^(?<time>[^ ]+) (?<stream>stdout|stderr) (?<logtag>P|F) (?<log>.*)$
          Time_Key    time
          Time_Format %Y-%m-%dT%H:%M:%S.%L%z
          Time_Keep On
      EOT
    )
    "filters.conf" = (
      <<-EOT
        [FILTER]
          Name parser
          Match *
          Key_name log
          Parser crio
        [FILTER]
          Name kubernetes
          Match kube.*
          Merge_Log On
          Keep_Log Off
          Buffer_Size 0
          Kube_Meta_Cache_TTL 300s
      EOT
    )
    "output.conf" = (
      <<-EOT
        [OUTPUT]
              Name cloudwatch
              Match kube.*
              region ${local.region}
              log_group_name ${aws_cloudwatch_log_group.fargate_fluentbit[0].name}
              log_stream_prefix ${local.fargate_fluentbit_cwlog_stream_prefix}
              auto_create_group true
        [OUTPUT]
              Name cloudwatch_logs
              Match *
              region ${local.region}
              log_group_name ${aws_cloudwatch_log_group.fargate_fluentbit[0].name}
              log_stream_prefix fargate-logs-fluent-bit-
              auto_create_group true

      EOT
    )
  }
}
