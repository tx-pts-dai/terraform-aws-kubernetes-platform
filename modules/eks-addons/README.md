# EKS Addons Management

This module manages AWS EKS native addons through Terraform. It handles the lifecycle of EKS-managed addons such as CoreDNS, kube-proxy, VPC CNI, and EBS CSI Driver.

## Overview

The module creates and manages EKS addons using the AWS EKS Addon API. These are AWS-managed Kubernetes components that are essential for cluster operation. This module is typically called after cluster creation and Karpenter setup to avoid dependency issues.

## Usage

```hcl
module "eks_addons" {
  source = "./modules/eks-addons"

  cluster_name       = module.eks.cluster_id
  kubernetes_version = var.kubernetes_version

  cluster_addons = {
    coredns = {
      addon_version            = "v1.11.1-eksbuild.4"
      service_account_role_arn = module.eks.eks_managed_node_groups["core"].iam_role_arn
    }
    kube-proxy = {
      addon_version = "v1.29.0-eksbuild.1"
    }
    vpc-cni = {
      addon_version            = "v1.16.0-eksbuild.1"
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      addon_version            = "v1.28.0-eksbuild.1"
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
  }

  tags = var.tags
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `cluster_name` | The name of the EKS cluster | `string` | n/a | yes |
| `kubernetes_version` | Kubernetes version to use for the EKS cluster | `string` | n/a | yes |
| `cluster_addons` | Map of cluster addon configurations | `map(object)` | `{}` | no |
| `cluster_addons_timeouts` | Default timeout values for addon resources | `object` | `{}` | no |
| `tags` | A map of tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| `addons` | Map of installed EKS addon attributes |

## Addon Configuration

Each addon in the `cluster_addons` map supports the following configuration:

- `create` - Whether to create the addon (default: `true`)
- `name` - Addon name (defaults to map key)
- `addon_version` - Version of the addon to install
- `configuration_values` - JSON encoded configuration values
- `most_recent` - Use the most recent version (default: `true`)
- `preserve` - Preserve addon on delete (default: `false`)
- `resolve_conflicts_on_create` - How to resolve conflicts on create (default: `"OVERWRITE"`)
- `resolve_conflicts_on_update` - How to resolve conflicts on update (default: `"OVERWRITE"`)
- `service_account_role_arn` - IAM role ARN for the addon's service account
- `pod_identity_association` - Pod identity associations for the addon
- `timeouts` - Timeout configuration for create/update/delete operations
- `tags` - Additional tags for the addon
