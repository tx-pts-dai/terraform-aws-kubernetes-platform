locals {
  github_repo  = "test"
  cluster_name = "test"
}

provider "aws" {
  default_tags {
    tags = {
      Github-Repo = local.github_repo
    }
  }
}

provider "aws" {
  region = "us-east-1"
  alias  = "us"

  default_tags {
    tags = {
      Github-Repo = local.github_repo
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = module.k8s_platform.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.k8s_platform.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", local.cluster_name]
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
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}

provider "kubernetes" {
  host                   = module.k8s_platform.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.k8s_platform.eks.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", local.cluster_name]
  }
}

data "aws_ecrpublic_authorization_token" "this" {
  provider = aws.us
}

module "k8s_platform" {
  source       = "../../"
  environment  = "test"
  cluster_name = local.cluster_name
  aws_ecrpublic_authorization_token = {
    user_name = data.aws_ecrpublic_authorization_token.this.user_name
    password  = data.aws_ecrpublic_authorization_token.this.password
  }
  github_repo = local.github_repo
  sso_role_id = "test"
}
