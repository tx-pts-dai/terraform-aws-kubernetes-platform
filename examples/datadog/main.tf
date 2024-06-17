terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "examples/datadog.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    region               = "eu-central-1"
    dynamodb_table       = "terraform-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    datadog = {
      source  = "DataDog/datadog"
      version = "~> 3.39"
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
  region = local.region
}

data "aws_secretsmanager_secret_version" "datadog" {
  secret_id = "dai-datadog/tamedia/keys"
}

provider "datadog" {
  api_url  = "https://api.${local.datadog_site}/"
  api_key  = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["api_key"]
  app_key  = jsondecode(data.aws_secretsmanager_secret_version.datadog.secret_string)["app_key"]
  validate = true
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
  region       = "eu-central-1"
  datadog_site = "datadoghq.eu"
}

module "k8s_platform" {
  source = "../../"

  name = "ex-datadog"

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
      { database = 26 },
      { redshift = 26 },
      { karpenter = 22 }
    ]
  }
}

module "datadog" {
  source = "../../modules/datadog"

  cluster_name = module.k8s_platform.eks.cluster_name

  datadog_secret = "dai-datadog/tamedia/keys"

  depends_on = [module.k8s_platform]
}
