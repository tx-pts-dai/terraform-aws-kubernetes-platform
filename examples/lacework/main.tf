terraform {
  required_version = ">= 1.3.2"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "examples/lacework.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    dynamodb_table       = "terraform-lock"
    region               = "eu-central-1"
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
    lacework = {
      source  = "lacework/lacework"
      version = "~> 1.8"
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

data "aws_secretsmanager_secret" "lacework" {
  name = "dai-lacework/tamedia/apiKey"
}

data "aws_secretsmanager_secret_version" "lacework" {
  secret_id = data.aws_secretsmanager_secret.lacework.id
}

provider "lacework" {
  account    = jsondecode(data.aws_secretsmanager_secret_version.lacework.secret_string)["account"]
  subaccount = jsondecode(data.aws_secretsmanager_secret_version.lacework.secret_string)["subAccount"]
  api_key    = jsondecode(data.aws_secretsmanager_secret_version.lacework.secret_string)["keyId"]
  api_secret = jsondecode(data.aws_secretsmanager_secret_version.lacework.secret_string)["secret"]
}

module "k8s_platform" {
  source = "../../"

  name = "lacework"

  cluster_admins = var.cluster_admins

  tags = {
    Environment = "sandbox"
    GithubRepo  = "terraform-aws-kubernetes-platform"
    GithubOrg   = "tx-pts-dai"
  }

  vpc = {
    create = true
    cidr   = "10.0.0.0/16"
  }

  karpenter = {
    subnet_cidrs = ["10.0.64.0/22", "10.0.68.0/22", "10.0.72.0/22"]
  }
}

module "lacework" {
  source = "../../modules/lacework"

  cluster_name = module.k8s_platform.eks.cluster_name
}