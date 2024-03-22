terraform {
  backend "s3" {
    dynamodb_table = "terraform-lock"
  }
}

provider "kubernetes" {
  host                   = module.cluster1.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cluster1.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    # This requires the awscli to be installed locally where Terraform is executed
    args = ["eks", "get-token", "--cluster-name", module.cluster1.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.cluster1.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.cluster1.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      # This requires the awscli to be installed locally where Terraform is executed
      args = ["eks", "get-token", "--cluster-name", module.cluster1.eks.cluster_name]
    }
  }
}

module "cluster1" {
  source = "../.."

  environment = "sandbox"
  github_repo = "terrafrom-aws-kubernetes-platform"

  eks = {
    cluster_name    = "foo"
    cluster_version = "1.29"
  }

  # Testing multiple clusters per module
  # clusters = {
  #   foo = {
  #     name    = "foo"
  #     region  = "eu-central-1"
  #     version = "1.29"

  #     create = true
  #   }
  # }
}