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
    time = {
      source  = "hashicorp/time"
      version = "0.11.2"
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

  karpenter = {
    pod_annotations = {
      "ad.datadoghq.com/controller.checks" = jsonencode(
        {
          "karpenter" : {
            "init_config" : {},
            "instances" : [{ "openmetrics_endpoint" : "http://%%host%%:8000/metrics" }]
          }
        }
      )
    }
    memory_request = "768Mi"
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
      { karpenter = 22 }
    ]
  }
}

module "datadog" {
  source = "../../modules/datadog"

  cluster_name   = module.k8s_platform.eks.cluster_name
  datadog_secret = "dai/datadog/tamedia/keys"
  environment    = "sandbox"
  product_name   = "dai"

  # Example: how to override specs in the Datadog Custom Resource
  datadog_agent_helm_values = [
    { name = "spec.features.apm.enabled", value = false },
    { name = "spec.features.logCollection.enabled", value = false },
    { name = "spec.override.clusterAgent.replicas", value = 3 }
  ]

  depends_on = [module.k8s_platform]
}
