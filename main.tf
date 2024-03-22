################################################################################
# TAMEDIA KUBERNETES AS A SERVICE (TKASS)
#
# This module creates batteries included Kubernetes clusters.
#
#
#
################################################################################

provider "aws" {
  region = local.region
}

# Required for public ECR where Karpenter artifacts (helm chart) are hosted
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

data "aws_availability_zones" "available" {}

################################################################################
# Common locals

locals {
  name     = replace(basename(path.cwd), "_", "-") # TODO add random 4 characters for uniqueness
  region   = "eu-central-1"                        # get from vars
  vpc_cidr = "10.0.0.0/16"                         # get from vars
  azs      = slice(data.aws_availability_zones.available.names, 0, 3) # We only need 3 AZs

  cluster_version = "1.29"

  tags = {
    Environment = var.environment
    GithubRepo  = var.github_repo
  }
}

################################################################################
# VPC
#
# Notes
# The module should support passing in a vpc or creating one.
# If passing in a vpc, the module should support creating subnets.

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  create_vpc = true

  name = local.name
  cidr = local.vpc_cidr

  azs = local.azs
  # TODO: Fix these subnets
  # public rarely changes make them /24
  # intra subnets are used for enis that dont require egress to the internet eg. vpc lambda, prviate endpoints

  public_subnets   = [for k, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, k)]
  intra_subnets    = [for k, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 8)]
  database_subnets = [for k, _ in local.azs : cidrsubnet(local.vpc_cidr, 8, k + 16)]
  # ...
  # keep private at the end since they are the most likely to change/expand
  private_subnets = [for k, v in local.azs : cidrsubnet(local.vpc_cidr, 4, k + 4)]

  enable_nat_gateway = true
  single_nat_gateway = true # TODO: false in prod

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
    # "karpenter.sh/discovery" = local.name TODO: Karpenter should have its own subnets
  }

  tags = local.tags
}

################################################################################
# EKS Cluster

# TODO: try catch in locals or the module definition itself?
locals {
  eks = {
    cluster_name    = try(var.eks.cluster_name, local.name)
    cluster_version = try(var.eks.cluster_version, local.cluster_version)
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  # A loop for creating multiple clusters. Makes it more complex
  # for_each = { for k, v in var.clusters : k => v if v.create }

  # cluster_name                   = try(each.value.name, local.name)
  # cluster_version                = try(each.value.version, local.cluster_version)
  cluster_name                   = local.eks.cluster_name
  cluster_version                = local.eks.cluster_version
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

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets # Used for fargate profiles
  control_plane_subnet_ids = module.vpc.intra_subnets   # No internet access subnets

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

  tags = local.tags
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

  role_name_prefix = "${local.eks.cluster_name}-ebs-csi-driver-"

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
# Karpenter
#
# Track notes here for future reference e.g. reasons for certain decisions

locals {
  karpenter = {
    chart_version = try(var.karpenter.chart_version, "0.35.2")
    namespace     = "karpenter"
    replicas      = try(var.karpenter.replicas, 2)
  }
}

data "aws_ecrpublic_authorization_token" "token" {
  provider = aws.virginia
}

module "karpenter" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "1.16.1"

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_karpenter = true

  karpenter = merge(var.karpenter, {
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
    set = [{
        name  = "dnsPolicy"
        value = "Default"
      },
      # {
      #   name  = "valuesChecksum"
      #   value = filemd5("${path.module}/values/karpenter.yaml")
      # }
    ]
  })
}
