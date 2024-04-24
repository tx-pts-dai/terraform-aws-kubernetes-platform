
################################################################################
# EKS Addons
#
# Notes
#

module "addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.1"

  create_delay_dependencies = [
    helm_release.karpenter.status
  ]
  # Wait for karpenter node to start so when the managed addons are applied they already have running pods, otherwise they will fail to update.
  create_delay_duration = "2m"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    coredns = {
      most_recent = true
      preserve    = false

      timeouts = {
        create = "10m"
        delete = "10m"
      }
    }
    vpc-cni = {
      most_recent = true
      preserve    = true

      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn

      configurations = {
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
        }
      }
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
      preserve    = false

      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn

      configurations = {
        replicaCount = 1
      }

      timeouts = {
        create = "10m"
        delete = "10m"
      }
    }
  }

  enable_aws_load_balancer_controller = try(var.addons.aws_load_balancer_controller.enabled, true)
  aws_load_balancer_controller = {
    role_name        = "aws-load-balancer-controller-${local.id}"
    role_name_prefix = false
    # race condition if this is not disabled. Serivce type LB will use intree controller.
    # This just means annotations are needed for the service to use the aws load balancer controller
    set = [{
      name  = "enableServiceMutatorWebhook"
      value = "false"
      }, {
      name  = "replicaCount"
      value = 1
      }, {
      name  = "clusterSecretsPermissions.allowAllSecrets"
      value = "true" # enables Okta integration by reading client id and secret from K8s secrets
    }]
  }

  enable_external_dns = try(var.addons.external_dns.enabled, true)
  external_dns_route53_zone_arns = [
    "arn:aws:route53:::hostedzone/*",
  ]
  external_dns = {
    role_name        = "external-dns-${local.id}"
    role_name_prefix = false
    set = [{
      name  = "policy"
      value = "sync" # allows deletion of dns records
      }, {
      name  = "txtOwnerId"
      value = "external-dns-${local.id}" # avoid conflicts on the same hosted zone
    }]
  }

  enable_external_secrets = try(var.addons.external_secrets.enabled, true)
  external_secrets = {
    wait             = true
    role_name        = "external-secrets-${local.id}"
    role_name_prefix = false
  }

  enable_fargate_fluentbit = try(var.addons.fargate_fluentbit.enabled, true)
  fargate_fluentbit = {
    role_name        = "fargate-fluentbit-${local.id}"
    role_name_prefix = false
  }

  enable_metrics_server = try(var.addons.metrics_server.enabled, true)

  # Monitoring
  enable_kube_prometheus_stack = try(var.addons.kube_prometheus_stack.enabled, false)

  # Alternative Ingress
  enable_cert_manager  = try(var.addons.cert_manager.enabled, false)
  enable_ingress_nginx = try(var.addons.ingress_nginx.enabled, false)

  # Additional Helm Releases
  # helm_releases = {
  #   fluent_operator = {
  #     chart = "fluent-operator"
  #     repository = "https://fluentbit.github.io/helm-charts"
  #     version = "0.9.0"
  #     namespace = "kube-system"
  #     set = [
  #       {
  #         name  = "foo"
  #         value = "bar"
  #       }
  #     ]
  #   }
  # }

  depends_on = [
    module.karpenter,
    helm_release.karpenter,
    kubectl_manifest.karpenter_node_pool
  ]
}

################################################################################
# VPC CNI

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.37.2"

  role_name = "vpc-cni-${local.id}"

  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }

  tags = local.tags
}

################################################################################
# EBS CSI Controller

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.37.2"

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

################################################################################
# External Secrets

resource "kubectl_manifest" "secretsmanager_auth" {
  yaml_body  = <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ClusterSecretStore
    metadata:
      name: aws-secretsmanager
    spec:
      provider:
        aws:
          service: SecretsManager
          region: ${data.aws_region.current.name}
  YAML
  depends_on = [module.addons]
}

################################################################################
# Kube Downscaler (placeholder)

# module "downscaler" {
#   source  = "terraform-aws-modules/eks/aws//modules/downscaler"
#   version = "12.0.0"

#   cluster_name = module.eks.cluster_name
#   namespace    = "kube-system"

#   tags = local.tags
# }
