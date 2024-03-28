
################################################################################
# EKS Addons
#
# Notes
#

module "addons" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.1"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  eks_addons = {
    coredns = {
      most_recent = true

      timeouts = {
        create = "10m"
        delete = "10m"
      }
    }
    vpc-cni = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent              = true
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

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    role_name        = "aws-load-balancer-controller-${local.id}"
    role_name_prefix = false
    # race condition if this is not disabled. Serivce type LB will use intree controller.
    # This just means annotations are needed for the service to use the aws load balancer controller
    set = [{
      name  = "enableServiceMutatorWebhook"
      value = "false"
      },
      {
        name  = "replicaCount"
        value = 1
    }]
  }

  enable_external_dns = true
  external_dns_route53_zone_arns = [
    "arn:aws:route53:::hostedzone/*",
  ]
  external_dns = {
    role_name        = "external-dns-${local.id}"
    role_name_prefix = false
    set = [{
      name  = "policy"
      value = "sync" # allows deletion of dns records
    }]
  }

  enable_external_secrets = true
  external_secrets = {
    role_name        = "external-secrets-${local.id}"
    role_name_prefix = false
  }

  enable_fargate_fluentbit = true
  fargate_fluentbit = {
    role_name        = "fargate-fluentbit-${local.id}"
    role_name_prefix = false
  }

  enable_metrics_server = true

  # Monitoring
  enable_kube_prometheus_stack = false # disable if using datadog

  # Alternative Ingress
  enable_cert_manager  = false
  enable_ingress_nginx = false

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