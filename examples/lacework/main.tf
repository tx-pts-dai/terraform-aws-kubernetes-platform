terraform {
  required_version = ">= 1.7.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "examples/lacework.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    use_lockfile         = true
    region               = "eu-central-1"
    encrypt              = true
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
      version = "~> 2.0"
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

data "aws_secretsmanager_secret" "lacework" {
  name = "dai/lacework/tamedia/apiKey"
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

locals {
  region = "eu-central-1"
}

module "network" {
  source = "../../modules/network"

  stack_name = "ex-complete"

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

  name = "ex-lacework"

  cluster_admins = {
    cicd = {
      role_name = "cicd-iac"
    }
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

  tags = {
    Environment = "sandbox"
    GithubRepo  = "terraform-aws-kubernetes-platform"
    GithubOrg   = "tx-pts-dai"
  }

}

module "lacework" {
  source = "../../modules/lacework"

  cluster_name = module.k8s_platform.eks.cluster_name

  agent_tags = {
    KubernetesCluster = module.k8s_platform.eks.cluster_name
  }
}
