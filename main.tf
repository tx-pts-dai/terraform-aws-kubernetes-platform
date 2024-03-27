################################################################################
# TAMEDIA KUBERNETES AS A SERVICE (TKASS)
#
# This module creates batteries included Kubernetes clusters.
#
#
#
################################################################################

# provider "aws" {
#   region = local.region
# }

# # Required for public ECR where Karpenter artifacts (helm chart) are hosted
# provider "aws" {
#   region = "us-east-1"
#   alias  = "virginia"
# }

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

data "aws_availability_zones" "available" {}

# Create unique ids for resources
resource "random_id" "random_id" {
  byte_length = 4
}

################################################################################
# Common locals
locals {
  # There should be some randomization here, so we can deploy multiple clusters
  stack_name         = coalesce(var.stack_name, replace(basename(path.cwd), "_", "-"))
  name               = "${local.stack_name}-${random_id.random_id.hex}"
  environment        = coalesce(var.environment, "test")
  kubernetes_version = coalesce(var.kubernetes_version, "1.29")
  region             = coalesce(var.region, "eu-central-1")
  github_repo        = var.github_repo
  github_org         = var.github_org

  tags = {
    Environment = local.environment
    GithubRepo  = local.github_repo
    GithubOrg   = local.github_org
    StackName   = local.stack_name
  }
}

################################################################################
# VPC
#
# Notes
# The module should support passing in a vpc or creating one.
# If passing in a vpc, the module should support creating subnets.

# VPC  Resources
locals {
  vpc = {
    id              = try(var.vpc.id, module.network.vpc.vpc_id)
    private_subnets = try(var.vpc.private_subnets, module.network.vpc.private_subnets)
    intra_subnets   = try(var.vpc.intra_subnets, module.network.vpc.intra_subnets)
  }
}

module "network" {
  source  = "./modules/networking"

  create_vpc = try(var.vpc.create, false)

  cidr = var.vpc.cidr
  name = local.name
  cluster_name = local.name

  tags = local.tags
}

################################################################################
# EKS Cluster

# TODO: try catch in locals or the module definition itself?
locals {
  eks = {
    # cluster_name    = try(var.eks.cluster_name, local.name)
    # cluster_version = try(var.eks.kubernetes_version, local.kubernetes_version)
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0" # hard pin version

  # A loop for creating multiple clusters. Makes it more complex
  # for_each = { for k, v in var.clusters : k => v if v.create }

  # cluster_name                   = try(each.value.name, local.name)
  # cluster_version                = try(each.value.version, local.cluster_version)
  cluster_name                   = local.name
  cluster_version                = local.kubernetes_version
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  # Install addons here or with blueprint? I think here is better
  # Had the first dependency issue karpenter module depends on eks module
  # and coredns is stuck in pending state since theres no node to run on yet.

  # cluster_addons = {
  #   coredns = {
  #     configuration_values = jsonencode({
  #       replicaCount = 2
  #     })
  #   }
  #   kube-proxy = {}
  #   vpc-cni    = {}
  # }

  vpc_id                   = local.vpc.id
  subnet_ids               = local.vpc.private_subnets # Used for fargate profiles
  control_plane_subnet_ids = local.vpc.intra_subnets   # No internet access subnets

  # Keep this module minimal - karpenter will handle the security groups
  create_cluster_security_group = false
  create_node_security_group    = false

  fargate_profiles = {
    karpenter = {
      selectors = [
        { namespace = "karpenter" }
      ]
    }
  }

  tags = merge(local.tags, {
    # NOTE - if creating multiple security groups with this module, only tag the
    # security group that Karpenter should utilize with the following tag
    # (i.e. - at most, only one security group should have this tag in your account)
    "karpenter.sh/discovery" = local.name
  })
}

################################################################################
# Karpenter
#
# Track notes here for future reference e.g. reasons for certain decisions

locals {
  karpenter = {
    chart_version = try(var.addons.karpenter.chart_version, "0.35.2")
    namespace     = "karpenter"
    replicas      = try(var.addons.karpenter.replicas, 2)
  }
}

module "karpenter" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.1"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_karpenter = true

  karpenter = merge({
    # ECR Public Login
    repository_username = data.aws_ecrpublic_authorization_token.token.user_name
    repository_password = data.aws_ecrpublic_authorization_token.token.password

    chart_version      = local.karpenter.chart_version
    namespace          = local.karpenter.namespace
    create_namespace   = true
    atomic             = true
    cleanup_on_failure = true
    wait               = true

    # Can either set inline or use a file.
    values = [
      # - removes tabs and spaces
      <<-EOT
        dnsPolicy: Default
        replicas: "${local.karpenter.replicas}"
        resources:
          requests:
            cpu: "0.5"
            memory: 512Mi
        serviceMonitor:
          enabled: false # Requires prometheus-operator to be installed (at least the crds)
      EOT
    ]
    # values = [
    #   templatefile("${path.module}/values/karpenter.yaml", {
    #     cluster_name            = module.eks.cluster_name
    #     replicas                = var.karpenter.replicas
    #   })
    # ]
    # set = [{
    #   name  = "dnsPolicy"
    #   value = "Default"
    #   },
      # {
      #   name  = "valuesChecksum"
      #   value = filemd5("${path.module}/values/karpenter.yaml")
      # }
    # ]
  }, var.addons.karpenter) # Merge with user provided values
}

resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.karpenter.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    module.karpenter
  ]
}

resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["4", "8", "16", "32"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["2"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

################################################################################
# Core EKS Managed Adddons
#
# Notes
# Installing here since the karpenter module depends on the eks module

# module "core_addons" {
#   source  = "aws-ia/eks-blueprints-addons/aws"
#   version = "1.16.1"

#   cluster_name      = module.eks.cluster_name
#   cluster_endpoint  = module.eks.cluster_endpoint
#   cluster_version   = module.eks.cluster_version
#   oidc_provider_arn = module.eks.oidc_provider_arn

#   eks_addons = {
#     coredns = {
#       most_recent = true

#       timeouts = {
#         create = "25m"
#         delete = "10m"
#       }
#     }
#     vpc-cni = {
#       most_recent = true
#     }
#     kube-proxy = {
#       most_recent = true
#     }
#     # This is a core component of Kubernetes and the intree ebs driver will be removed soon,
#     # should we install it as default?
#     aws-ebs-csi-driver = {
#       most_recent              = true
#       service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
#     }
#   }

#   depends_on = [module.karpenter]
# }

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.20"

  role_name_prefix = substr("${local.name}-ebs-csi-driver-", 0, 38)

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = local.tags
}
