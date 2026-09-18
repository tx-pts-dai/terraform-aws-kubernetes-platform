terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # >= 6.40 for the aws_s3files_* resources
      version = ">= 6.40"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 3.0.2"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11"
    }
  }
}
