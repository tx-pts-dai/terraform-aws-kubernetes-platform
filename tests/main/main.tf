terraform {
  required_version = "~> 1.13"

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
      version = "~> 6.9"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
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
  default_tags {
    tags = {
      Terraform   = "true"
      Environment = "examples"
      GithubRepo  = "terraform-aws-kubernetes-platform"
      GithubOrg   = "tx-pts-dai"
      Example     = "tests/main"
    }
  }
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
  kubernetes = {
    host                   = module.k8s_platform.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.k8s_platform.eks.cluster_certificate_authority_data)
    exec = {
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

data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = ["central"]
  }
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_subnets" "intra_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "tag:Name"
    values = ["*intra*"]
  }
}

module "k8s_platform" {
  source = "../../"

  name = "tests-main"

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
    vpc_id          = data.aws_vpc.default.id
    vpc_cidr        = data.aws_vpc.default.cidr_block
    private_subnets = data.aws_subnets.private_subnets.ids
    intra_subnets   = data.aws_subnets.intra_subnets.ids
  }

  karpenter_helm_set = [
    {
      name  = "replicas"
      value = 1
    }
  ]
  karpenter_resources_helm_values = [
    <<-EOT
    global:
      eksDiscovery:
        tags:
          subnets:
            karpenter.sh/discovery: "shared"
    nodePools:
      default:
        requirements:
          - key: karpenter.k8s.aws/instance-category
            operator: In
            values: ["t"]
          - key: "karpenter.k8s.aws/instance-memory"
            operator: Gt
            values: ["2048"]
          - key: "karpenter.sh/capacity-type"
            operator: In
            values: ["spot", "on-demand"]
    EOT
  ]

  # EKS Auto Mode is enabled alongside the self-managed Karpenter stack
  # (enable_karpenter defaults to true) to demonstrate a gradual migration.
  # See docs/auto-mode-migration.md.
  enable_auto_mode = true

  auto_mode = {
    # Self-managed Karpenter here discovers subnets tagged
    # karpenter.sh/discovery = shared (see karpenter_resources_helm_values above),
    # so point Auto Mode at the same tag to share the same network.
    subnet_discovery_tags = { "karpenter.sh/discovery" = "shared" }

    # Taint the Auto Mode default NodePool so existing workloads stay on the
    # self-managed Karpenter nodes until they explicitly tolerate Auto Mode.
    # Migrate compute by adding this toleration to workloads one at a time.
    default_node_pool_taints = [
      {
        key    = "auto-mode"
        value  = "true"
        effect = "NoSchedule"
      }
    ]
  }

  # Keep the self-managed EBS CSI driver and AWS Load Balancer Controller running
  # alongside Auto Mode's managed equivalents during the migration. Cut storage
  # over by StorageClass and ingresses over by ingressClassName, then set these to
  # false once nothing depends on the self-managed versions.
  enable_self_managed_ebs_csi       = true
  enable_self_managed_lb_controller = true

  base_domain = "dai-sandbox.tamedia.tech"

  enable_acm_certificate = false
  acm_certificate = {
    subject_alternative_names = [
      "argocd"
    ]
    prepend_stack_id      = false # Cannot be true for the initial deployment since the stack id is not known yet
    wildcard_certificates = false # Don't create wildcards for test deployments since other stacks might use them and cause cleanup failures
  }

  enable_argocd = false

  argocd = {
    enable_spoke = true
    hub_iam_role_arns = [
      "arn:aws:iam::123456789012:role/argocd-controller",
      "arn:aws:iam::851725213542:role/argocd-controller"
    ]
  }
}
