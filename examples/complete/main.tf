terraform {
  required_version = "~> 1.10"

  backend "s3" {
    bucket               = "tf-state-911453050078"
    key                  = "examples/complete.tfstate"
    workspace_key_prefix = "terraform-aws-kubernetes-platform"
    use_lockfile         = true
    region               = "eu-central-1"
    encrypt              = true
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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
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
      Example     = "complete"
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

  name = "ex-complete"

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

  karpenter_resources_helm_set = [
    {
      name  = "global.eksDiscovery.tags.subnets.karpenter\\.sh/discovery"
      value = "shared"
    }

  ]

  # Custom NodePool using the Balanced consolidation policy.

  karpenter_resources_helm_values = [
    <<-EOT
    nodePools:
      balanced:
        enabled: true
        nodeClassRef:
          group: karpenter.k8s.aws
          kind: EC2NodeClass
          name: default
        requirements:
          - key: "karpenter.k8s.aws/instance-category"
            operator: In
            values: ["c", "m", "r", "t"]
          - key: "karpenter.k8s.aws/instance-hypervisor"
            operator: In
            values: ["nitro"]
          - key: "karpenter.k8s.aws/instance-generation"
            operator: Gt
            values: ["2"]
        disruption:
          consolidationPolicy: Balanced
          consolidateAfter: 1h
        limits:
          cpu: 1000
          memory: 4000Gi
    EOT
  ]

  # EKS Auto Mode is enabled alongside the self-managed Karpenter stack
  # (enable_karpenter defaults to true) to demonstrate a gradual migration.
  # See docs/auto-mode-migration.md.
  enable_auto_mode = false

  auto_mode = {
    # Self-managed Karpenter here discovers subnets tagged
    # karpenter.sh/discovery = shared (see karpenter_resources_helm_set above),
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

  enable_efs_csi_driver = true

  # Example (opt-in): Kubecost EKS add-on
  # Requires subscribing to the "IBM Kubecost - Amazon EKS cost monitoring"
  # listing in AWS Marketplace for this account first.
  # access dashboard: https://docs.aws.amazon.com/eks/latest/userguide/cost-monitoring-kubecost-dashboard.html
  #
  # The Kubecost Marketplace add-on requires the AWSMarketplaceMeteringRegisterUsage
  # permission on the IAM role associated with its awsstore-serviceaccount. The
  # module doesn't set up that role for you, so enabling the flag alone leaves
  # the add-on unable to register its Marketplace usage (the deployment may end
  # up unhealthy). Create the required role/policy and wire it to the
  # awsstore-serviceaccount (pod identity or IRSA) before enabling this.
  #
  # enable_kubecost = true

  # Kubecost (enable_kubecost above) needs a default StorageClass for its
  # Prometheus PVC. Most clusters already have one (e.g. gp2/gp3); this one is
  # created here only because the example cluster doesn't ship a default class.
  # Only needed if you opt in to enable_kubecost.
  #
  # locals {
  #   kubecost_hostname = "kubecost.dai-sandbox.tamedia.tech"
  # }
  # resource "kubernetes_storage_class_v1" "gp3" {
  #   metadata {
  #     name = "gp3"
  #     annotations = {
  #       "storageclass.kubernetes.io/is-default-class" = "true"
  #     }
  #   }
  #
  #   storage_provisioner    = "ebs.csi.aws.com"
  #   reclaim_policy         = "Delete"
  #   volume_binding_mode    = "WaitForFirstConsumer"
  #   allow_volume_expansion = true
  #
  #   parameters = {
  #     type = "gp3"
  #   }
  # }

  # Example (opt-in): expose the Kubecost dashboard via an internal ALB ingress.
  # Requires the AWS Load Balancer Controller (enable_self_managed_lb_controller
  # or Auto Mode) and external-dns (wired up via the module's
  # external_dns_pod_identity) to create the Route53 record.
  #
  # We wre using ALB controller from Auto_mode for testing, therefore we need to create an IngressClass and IngressClassParams.
  # Resource "kubernetes_ingress_v1" "kubecost" {
  #   metadata {
  #     name      = "kubecost-ingress"
  #     namespace = "kubecost"
  #     annotations = {
  #       "kubernetes.io/ingress.class"                = "alb"
  #       "alb.ingress.kubernetes.io/group.name"       = "kubecost"
  #       "alb.ingress.kubernetes.io/target-type"      = "ip"
  #       "alb.ingress.kubernetes.io/scheme"           = "internal"
  #       "alb.ingress.kubernetes.io/healthcheck-path" = "/"
  #       "external-dns.alpha.kubernetes.io/hostname"  = local.kubecost_hostname
  #     }
  #   }
  #
  #   spec {
  #     rule {
  #       http {
  #         path {
  #           path      = "/"
  #           path_type = "Prefix"

  #           backend {
  #             service {
  #               name = "kubecost-frontend"
  #               port {
  #                 number = 9090
  #               }
  #             }
  #           }
  #         }
  #       }
  #     }
  #   }
  # }

  # Example: Reusable Kubernetes access roles with different permission levels
  # Creates standard roles that can be assumed by multiple principals
  # kubernetes_access_roles = {
  #   # View-only access (read-only) - for Backstage, AI agents, monitoring
  #   readonly = {
  #     controller_iam_role_arns = [
  #       "arn:aws:iam::123456789012:role/backstage-prod",
  #       "arn:aws:iam::123456789012:role/ai-agent"
  #     ]
  #     access_level = "view"    # Options: view, edit, admin, custom
  #     scope        = "cluster"
  #   }
  #   # Edit access - for developers in specific namespaces
  #   developer = {
  #     controller_iam_role_arns = [
  #       "arn:aws:iam::123456789012:role/dev-team-prod",
  #       "arn:aws:iam::123456789012:role/dev-team-staging"
  #     ]
  #     access_level = "edit"
  #     scope        = "namespace"
  #     namespaces   = ["development", "staging"]
  #   }
  #   # Admin access - for ops team with full cluster permissions
  #   ops-admin = {
  #     controller_iam_role_arns = ["arn:aws:iam::123456789012:role/ops-team"]
  #     access_level             = "admin"
  #     scope                    = "cluster"
  #   }
  #   # Custom policies - for special use cases
  #   custom-access = {
  #     controller_iam_role_arns = ["arn:aws:iam::123456789012:role/special-service"]
  #     access_level             = "custom"
  #     custom_policy_arns = [
  #       "arn:aws:eks::aws:cluster-access-policy/MyCustomPolicy"
  #     ]
  #     scope = "cluster"
  #   }
  # }
}

# Example: Using Amazon S3 Files with the EFS CSI driver
#
# The driver's node role is granted account-wide S3 read (AmazonS3ReadOnlyAccess), so an
# application only needs to create a bucket and reference it - no per-bucket IAM.
#
# End-to-end steps for a consuming application (S3 Files has no Terraform
# resource yet; the file system is created via the `aws s3files` API/CLI):
#
#   1. Create an S3 bucket (e.g. aws_s3_bucket.app).
#
#   2. Create the S3 file system and capture its id
#
#   3. Create mount targets in the cluster's subnets
#
#   4. Mount it with a StorageClass / PersistentVolume / PVC referencing the
#      file system id. See the driver's S3 Files docs for the manifest schema:
#        https://docs.aws.amazon.com/eks/latest/userguide/s3files-csi.html
#


data "aws_secretsmanager_secret_version" "cloudflare" {
  secret_id = "dai/cloudflare/tamedia/apiToken"
}

provider "cloudflare" {
  api_token = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["apiToken"]
}

locals {
  zones = {
    "kaas-example.tamedia.tech" = {
      comment = "DAI KaaS example complete"
    }
  }
}

# Manage DNS sub-domains in cloudflare and attach them to they parent in route53
module "cloudflare" {
  source = "../../modules/cloudflare"

  for_each = local.zones

  zone_name    = module.route53_zones[each.key].route53_zone_name[each.key]
  comment      = "Managed by KAAS examples"
  name_servers = [for i in range(4) : module.route53_zones[each.key].route53_zone_name_servers[each.key][i]]
  account_id   = jsondecode(data.aws_secretsmanager_secret_version.cloudflare.secret_string)["accountId"]
}

module "route53_zones" {
  source  = "terraform-aws-modules/route53/aws//modules/zones"
  version = "5.0.0"

  for_each = local.zones

  zones = {
    (each.key) = {
      comment = each.value.comment
    }
  }
}
