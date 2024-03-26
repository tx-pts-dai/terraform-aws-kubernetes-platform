terraform {

  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubectl = {
      source  = "alekc/kubectl" # see https://github.com/gavinbunney/terraform-provider-kubectl/issues/270 for the choice of this provider
      version = ">= 2.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

module "iam_eks_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-eks-role"
  version = "~> 5.32"

  role_name_prefix = "${var.github_repo}-"

  assume_role_condition_test = "StringLike"
  cluster_service_accounts = {
    (var.cluster_name) = ["default:*"]
  }
}

module "eks" {
  source                         = "terraform-aws-modules/eks/aws"
  version                        = "20.8.3"
  cluster_name                   = var.cluster_name
  cluster_version                = 1.29
  cluster_endpoint_public_access = true

  kms_key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/eu-west-1/AWSReservedSSO_AWSAdministratorAccess_${var.sso_role_id}",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cicd-iac"
  ]

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent    = true
      before_compute = true
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  node_security_group_tags = {
    "karpenter.sh/discovery" = var.cluster_name
  }

  fargate_profiles = {
    karpenter = {
      selectors = [
        {
          namespace = local.karpenter_namespace
        }
      ]
    }
  }

  access_entries = {
    sso = {
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-reserved/sso.amazonaws.com/eu-west-1/AWSReservedSSO_AWSAdministratorAccess_${var.sso_role_id}"
      policy_associations = {
        single = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
    cicd = {
      kubernetes_groups = ["masters"]
      principal_arn     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/cicd-iac"
      policy_associations = {
        single = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }
}
