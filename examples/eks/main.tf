terraform {
  required_version = "~> 1.0"

  backend "s3" {
    bucket = "tf-state-911453050078"
    key = "terraform-aws-kubernetes-platform/eks.tfstate"
    region = "eu-central-1"
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
      version = "~= 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Required for public ECR where Karpenter artifacts (helm chart) are hosted
provider "aws" {
  region = "us-east-1"
  alias  = "virginia"
}

provider "kubernetes" {
  host                   = module.platform.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.platform.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.platform.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.platform.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.platform.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = ["eks", "get-token", "--cluster-name", module.platform.eks.cluster_name]
    }
  }
}

provider "kubectl" {
  apply_retry_count      = 5
  host                   = module.platform.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.platform.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = ["eks", "get-token", "--cluster-name", module.platform.eks.cluster_name]
  }
}

module "platform" {
  source = "../.."

  environment = "sandbox"
  github_repo = "terrafrom-aws-kubernetes-platform"
  github_org  = "tx-pts-dai"

  stack_name = "example-platform"

  providers = {
    aws.virginia = aws.virginia
  }

}