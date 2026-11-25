################################################################################
# EKS Addon resources
#
# Defaults per add-on and container; var.addon_resources overrides them per
# attribute, and a null container drops its resources block.
locals {
  addon_resources_defaults = {
    vpc-cni = {
      aws-node          = { memory_request = "192Mi", memory_limit = "384Mi", cpu_request = "50m" }
      aws-eks-nodeagent = { memory_request = "32Mi", memory_limit = "64Mi", cpu_request = "10m" }
    }
    kube-proxy = {
      kube-proxy = { memory_request = "48Mi", memory_limit = "160Mi", cpu_request = "40m" }
    }
    eks-pod-identity-agent = {
      eks-pod-identity-agent = { memory_request = "32Mi", memory_limit = "64Mi", cpu_request = "10m" }
    }
    coredns = {
      coredns = { memory_request = "64Mi", memory_limit = "128Mi", cpu_request = "100m" }
    }
    aws-ebs-csi-driver = {
      controller            = { memory_request = "48Mi", memory_limit = "96Mi", cpu_request = "10m" }
      node                  = { memory_request = "48Mi", memory_limit = "96Mi", cpu_request = "10m" }
      csi-provisioner       = { memory_request = "32Mi", memory_limit = "64Mi", cpu_request = "10m" }
      csi-attacher          = { memory_request = "32Mi", memory_limit = "64Mi", cpu_request = "10m" }
      csi-resizer           = { memory_request = "32Mi", memory_limit = "64Mi", cpu_request = "10m" }
      csi-snapshotter       = { memory_request = "32Mi", memory_limit = "64Mi", cpu_request = "10m" }
      liveness-probe        = { memory_request = "16Mi", memory_limit = "32Mi", cpu_request = "10m" }
      node-driver-registrar = { memory_request = "16Mi", memory_limit = "32Mi", cpu_request = "10m" }
    }
    aws-efs-csi-driver = {
      controller            = { memory_request = "48Mi", memory_limit = "96Mi", cpu_request = "10m" }
      node                  = { memory_request = "112Mi", memory_limit = "512Mi", cpu_request = "30m" }
      csi-provisioner       = { memory_request = "32Mi", memory_limit = "64Mi", cpu_request = "10m" }
      liveness-probe        = { memory_request = "16Mi", memory_limit = "32Mi", cpu_request = "10m" }
      node-driver-registrar = { memory_request = "16Mi", memory_limit = "32Mi", cpu_request = "10m" }
    }
  }

  # Effective values: null = container opted out.
  addon_resources = {
    for addon, containers in local.addon_resources_defaults : addon => {
      for name, defaults in containers : name => try(var.addon_resources[addon][name], "unset") == null ? null : {
        for k in ["memory_request", "memory_limit", "cpu_request", "cpu_limit"] :
        k => try(var.addon_resources[addon][name][k], null) != null ? var.addon_resources[addon][name][k] : lookup(defaults, k, null)
      }
    }
  }

  # Kubernetes `resources` block per container, {} when opted out.
  addon_resources_cfg = {
    for addon, containers in local.addon_resources : addon => {
      for name, r in containers : name => {
        for k, v in {
          resources = r == null ? null : {
            requests = { for rk, rv in { cpu = r.cpu_request, memory = r.memory_request } : rk => rv if rv != null }
            limits   = { for rk, rv in { cpu = r.cpu_limit, memory = r.memory_limit } : rk => rv if rv != null }
          }
        } : k => v if v != null
      }
    }
  }
}

################################################################################
# EKS Addons
#
# Create addons after Karpenter resources to avoid dependency issues
locals {
  cluster_addons = {
    coredns = {
      most_recent = true
      preserve    = false

      configuration_values = jsonencode(merge({
        autoScaling = {
          enabled     = true
          minReplicas = 2
          maxReplicas = 10
        }
      }, local.addon_resources_cfg["coredns"]["coredns"]))

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
        controller = merge({ replicaCount = 1 }, local.addon_resources_cfg["aws-ebs-csi-driver"]["controller"])
        node       = local.addon_resources_cfg["aws-ebs-csi-driver"]["node"]
        sidecars = {
          provisioner         = local.addon_resources_cfg["aws-ebs-csi-driver"]["csi-provisioner"]
          attacher            = local.addon_resources_cfg["aws-ebs-csi-driver"]["csi-attacher"]
          resizer             = local.addon_resources_cfg["aws-ebs-csi-driver"]["csi-resizer"]
          snapshotter         = local.addon_resources_cfg["aws-ebs-csi-driver"]["csi-snapshotter"]
          livenessProbe       = local.addon_resources_cfg["aws-ebs-csi-driver"]["liveness-probe"]
          nodeDriverRegistrar = local.addon_resources_cfg["aws-ebs-csi-driver"]["node-driver-registrar"]
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

  # Self-managed vs Auto Mode toggles: default to enabled unless Auto Mode is on,
  # overridable per capability to migrate independently.
  create_self_managed_ebs_csi       = coalesce(var.enable_self_managed_ebs_csi, !var.enable_auto_mode)
  create_self_managed_lb_controller = coalesce(var.enable_self_managed_lb_controller, !var.enable_auto_mode)

  # Auto Mode only serves its own nodes: while self-managed Karpenter nodes run
  # (enable_karpenter), they still need vpc-cni/kube-proxy/pod-identity and coredns;
  # both are dropped only in pure Auto Mode (enable_karpenter = false).
  create_self_managed_networking = !var.enable_auto_mode || var.enable_karpenter

  core_cluster_addons = merge(
    var.enable_auto_mode && !var.enable_karpenter ? {} : { coredns = local.cluster_addons.coredns },
    local.create_self_managed_ebs_csi ? { aws-ebs-csi-driver = local.cluster_addons.aws-ebs-csi-driver } : {},
  )

  efs_cluster_addon = var.enable_efs_csi_driver ? {
    aws-efs-csi-driver = {
      most_recent = true
      preserve    = false

      configuration_values = jsonencode({
        controller = merge({ replicaCount = 1 }, local.addon_resources_cfg["aws-efs-csi-driver"]["controller"])
        node       = local.addon_resources_cfg["aws-efs-csi-driver"]["node"]
        sidecars = {
          csiProvisioner      = local.addon_resources_cfg["aws-efs-csi-driver"]["csi-provisioner"]
          livenessProbe       = local.addon_resources_cfg["aws-efs-csi-driver"]["liveness-probe"]
          nodeDriverRegistrar = local.addon_resources_cfg["aws-efs-csi-driver"]["node-driver-registrar"]
        }
      })

      # Increase timeout to allow Karpenter time to provision nodes
      # Karpenter provisions nodes on-demand when pods are pending
      timeouts = {
        create = "20m"
        update = "20m"
      }
    }
  } : {}

  extra_cluster_addons = merge(local.core_cluster_addons, local.efs_cluster_addon, var.extra_cluster_addons)
}

# Required for the self-managed EBS CSI Driver
module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.8.2"

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
  version = "2.10.0"

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

# EFS CSI driver controller: classic EFS permissions plus the Amazon S3 Files
module "aws_efs_csi_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  create = var.create_addon_pod_identity_roles && var.enable_efs_csi_driver

  name                    = "aws-efs-csi-controller-pod-identity-${local.id}"
  aws_efs_csi_policy_name = "aws-efs-csi-controller-pod-identity-${local.id}"
  use_name_prefix         = false

  attach_aws_efs_csi_policy = true

  additional_policy_arns = {
    AmazonS3FilesCSIDriverPolicy  = "arn:aws:iam::aws:policy/service-role/AmazonS3FilesCSIDriverPolicy"
    AmazonS3FilesClientFullAccess = "arn:aws:iam::aws:policy/AmazonS3FilesClientFullAccess"
  }

  associations = {
    controller = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "efs-csi-controller-sa"
    }
  }

  tags = local.tags
}

# EFS CSI driver node: account-level S3 Files client/mount permissions plus
# account-wide S3 read so applications only need to create a bucket and
# reference it.
module "aws_efs_csi_node_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

  create = var.create_addon_pod_identity_roles && var.enable_efs_csi_driver

  name            = "aws-efs-csi-node-pod-identity-${local.id}"
  use_name_prefix = false

  additional_policy_arns = {
    AmazonS3FilesClientFullAccess = "arn:aws:iam::aws:policy/AmazonS3FilesClientFullAccess"
    AmazonElasticFileSystemsUtils = "arn:aws:iam::aws:policy/AmazonElasticFileSystemsUtils"
    AmazonS3ReadOnlyAccess        = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
  }

  associations = {
    node = {
      cluster_name    = module.eks.cluster_name
      namespace       = "kube-system"
      service_account = "efs-csi-node-sa"
    }
  }

  tags = local.tags
}

module "aws_gateway_controller_pod_identity" {
  source  = "terraform-aws-modules/eks-pod-identity/aws"
  version = "2.10.0"

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
  version = "2.10.0"

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
  version = "2.10.0"

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
  version = "2.10.0"

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
