terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "< 7.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.9"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11"
    }
  }
}
