terraform {
  required_version = ">= 1.11"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "tests/main.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    region               = "eu-central-1"
    use_lockfile         = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.6"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

provider "aws" {
  region = local.region
}

provider "kubernetes" {
  host                   = module.k8s_platform.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.k8s_platform.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.k8s_platform.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.k8s_platform.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.k8s_platform.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.k8s_platform.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.k8s_platform.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.k8s_platform.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.k8s_platform.eks.cluster_name]
  }
}

locals {
  region = "eu-central-1"
}

module "network" {
  source = "../../modules/network"

  stack_name = "tests-main"

  cidr     = "10.251.0.0/16"
  az_count = 3

  subnet_configs = [
    { public = 24 },
    { private = 24 },
    { intra = 24 },
    { kubernetes = 22 }
  ]

  tags = {
    Environment = "sandbox"
    GithubRepo  = "terraform-aws-kubernetes-platform"
    GithubOrg   = "tx-pts-dai"
  }
}

module "k8s_platform" {
  source = "../../"

  create_addons = true

  name = "tests-main"

  cluster_admins = {
    cicd = {
      role_name = "cicd-iac"
    }
  }

  tags = {
    Environment = "sandbox"
    GithubRepo  = "terraform-aws-kubernetes-platform"
    GithubOrg   = "tx-pts-dai"
  }

  vpc = {
    vpc_id          = module.network.vpc.vpc_id
    vpc_cidr        = module.network.vpc.vpc_cidr_block
    private_subnets = module.network.vpc.private_subnets
    intra_subnets   = module.network.vpc.intra_subnets
  }

  karpenter = {
    subnet_cidrs = module.network.grouped_networks.kubernetes
  }

  karpenter_helm_set = [
    {
      name  = "replicas"
      value = 1
    }
  ]
  karpenter_resources_helm_values = [
    <<-EOT
    nodePools:
      default:
        requirements:
          - key: karpenter.k8s.aws/instance-category
            operator: In
            values: ["t"]
    EOT
  ]

  metrics_server = {
    set = [
      {
        name  = "replicas"
        value = 1
      }
    ]
  }
  aws_load_balancer_controller = {
    set = [
      {
        name  = "replicaCount"
        value = 1
      },
      # {
      #   name  = "clusterSecretsPermissions.allowAllSecrets"
      #   value = true # enables Okta integration by reading client id and secret from K8s secrets
      # }
    ]
  }

  enable_downscaler = false

  base_domain = "dai-sandbox.tamedia.tech"

  enable_acm_certificate = false
  acm_certificate = {
    subject_alternative_names = [
      "argocd"
    ]
    prepend_stack_id      = false # Cannot be true for the initial deployment since the stack id is not known yet
    wildcard_certificates = false # Don't create wildcards for test deployments since other stacks might use them and cause cleanup failures
  }

  enable_argocd = true

  argocd = {
    # enable_hub        = true
    # hub_iam_role_name = "argocd-controller-tests-main"

    enable_spoke      = true
    hub_iam_role_arns = ["arn:aws:iam::911453050078:role/argocd-controller"]
  }
}
