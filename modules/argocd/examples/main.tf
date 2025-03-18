terraform {
  required_version = ">= 1.11"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "modules/argocd/examples/simple.tfstate"
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

locals {
  region = "eu-central-1"
}

module "k8s_platform" {
  source = ".././../.."

  name = "ex-argocd"

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
    enabled = true
    cidr    = "10.0.0.0/16"
    max_az  = 3
    subnet_configs = [
      { public = 24 },
      { private = 24 },
      { intra = 26 },
    ]
  }

  create_addons = false
}

module "hub" {
  source = "./.."

  enable_hub = true

  cluster_name = "example-cluster"
}

module "spoke" {
  source = "./.."

  enable_spoke = true

  cluster_name = "example-cluster"

  cluster_secret_suffix = "sandbox"

  hub_iam_role_arn = module.hub.iam_role_arn
}
