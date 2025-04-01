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

module "k8s_platform" {
  source = "../../"

  create_addons = true

  name = "tests-main"

  cluster_admins = {
    cicd = {
      role_name = "cicd-iac"
    }
  }

  metadata = {
    environment = "sandbox"
    team        = "dai"
  }

  tags = {
    Environment = "sandbox"
    GithubRepo  = "terraform-aws-kubernetes-platform"
    GithubOrg   = "tx-pts-dai"
  }

  vpc = {
    enabled = true
    cidr    = "10.240.0.0/16"
    max_az  = 3
    subnet_configs = [
      { public = 24 },
      { private = 24 },
      { intra = 26 },
      { karpenter = 22 }
    ]
  }

  karpenter = {
    set = [
      {
        name  = "replicas"
        value = 1
      }
    ]
  }

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
      {
        name  = "enableServiceMonitor"
        value = true
      },
      {
        name  = "clusterSecretsPermissions.allowAllSecrets"
        value = true # enables Okta integration by reading client id and secret from K8s secrets
      }
    ]
  }

  enable_downscaler = true

  enable_pagerduty = false
  pagerduty = {
    secrets_manager_secret_name = "dai/platform/pagerduty"
  }

  enable_okta = true
  okta = {
    base_url                    = "https://login.tx.group"
    secrets_manager_secret_name = "dai/platform/okta"
  }

  enable_slack = false
  slack = {
    secrets_manager_secret_name = "dai/platform/slack"
  }

  base_domain = "dai-sandbox.tamedia.tech"

  enable_acm_certificate = true
  acm_certificate = {
    subject_alternative_names = [
      "prometheus",
      "alertmanager",
      "grafana",
    ]
    prepend_stack_id      = false # Cannot be true for the initial deployment since the stack id is not known yet
    wildcard_certificates = false # Don't create wildcards for test deployments since other stacks might use them and cause cleanup failures
  }

  fluent_log_annotation = {
    name  = ""
    value = ""
  }

  enable_amp = false

  enable_argocd = true

  argocd = {
    enable_hub   = true
    enable_spoke = true

    cluster_secret_suffix = "example"
    cluster_secret_labels = {
      team        = "example"
      environment = "example"
    }
  }
}
