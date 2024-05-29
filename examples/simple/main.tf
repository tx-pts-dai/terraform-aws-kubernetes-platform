terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    # Defined in "examples-simple-sandbox" github environment
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.6"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
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

module "k8s_platform" {
  source = "../../"

  name = var.cluster_name

  vpc = {
    enabled = true
  }

  cluster_admins = var.cluster_admins

  tags = var.cluster_tags
}
