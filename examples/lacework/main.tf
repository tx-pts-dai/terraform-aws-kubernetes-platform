terraform {
  required_version = "~> 1.10"

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
      version = "~> 6.9"
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

data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = ["central"]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_subnets" "intra_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*intra*"]
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
    vpc_id          = data.aws_vpc.default.id
    vpc_cidr        = data.aws_vpc.default.cidr_block
    private_subnets = data.aws_subnets.private_subnets.ids
    intra_subnets   = data.aws_subnets.intra_subnets.ids
  }

  karpenter_resources_helm_set = [
    {
      name  = "global.eksDiscovery.tags.subnets.karpenter\\.sh/discovery"
      value = "shared"
    }
  ]

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
