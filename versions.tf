terraform {
  required_version = ">= 1.3.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.42.0"
      configuration_aliases = [ aws.virginia ]
    }
    # aws.virginia = {
    #   source  = "hashicorp/aws"
    #   version = ">= 5.42.0"
    # }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0"
    }
  }
}
