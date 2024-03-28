terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.42.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}
