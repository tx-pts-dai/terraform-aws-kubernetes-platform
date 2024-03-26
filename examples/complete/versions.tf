terraform {
  backend "s3" {
    region  = "eu-central-1"
    encrypt = "true"
  }

  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    kubectl = {
      source  = "alekc/kubectl" # see https://github.com/gavinbunney/terraform-provider-kubectl/issues/270 for the choice of this provider
      version = ">= 2.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
  }
}
