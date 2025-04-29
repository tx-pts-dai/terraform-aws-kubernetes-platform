# ArgoCD

This module deploys ArgoCD as either the hub or spoke controller. This will deploy the default ArgoCD Helm chart and all the necessary IAM roles and policies.

## Examples

### Hub

The hub is the controller that manages the spoke clusters. This is where the applications are defined and synced to the spoke clusters.

```hcl
module "hub" {
  source = "./.."

  enable_hub = true

  cluster_name = "example-cluster"
}
```

### Spoke

The spoke is the controller that manages the applications on the cluster. This is where the applications are deployed and synced from the hub.

```hcl
module "spoke" {
  source = "./.."

  enable_spoke = true

  cluster_name = "example-cluster"

  cluster_secret_suffix = "sandbox"

  hub_iam_role_arn = "arn:aws:iam::123456789012:role/argocd-example-cluster-hub"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.9 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.9 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_eks_access_entry.argocd_spoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.argocd_spoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_pod_identity_association.argocd_application_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_eks_pod_identity_association.argocd_applicationset_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_eks_pod_identity_association.argocd_server](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_pod_identity_association) | resource |
| [aws_iam_policy.argocd_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.argocd_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.argocd_spoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.argocd_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [helm_release.argocd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [aws_eks_cluster.cluster](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_iam_policy_document.argocd_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.argocd_controller_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.argocd_spoke](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the EKS cluster | `string` | n/a | yes |
| <a name="input_cluster_secret_labels"></a> [cluster\_secret\_labels](#input\_cluster\_secret\_labels) | Labels to add to the ArgoCD Cluster Secret | `map(string)` | `{}` | no |
| <a name="input_cluster_secret_suffix"></a> [cluster\_secret\_suffix](#input\_cluster\_secret\_suffix) | Suffix to add to the ArgoCD Cluster Secret. This will show in the ArgoCD UI | `string` | `""` | no |
| <a name="input_create"></a> [create](#input\_create) | Create the ArgoCD resources | `bool` | `true` | no |
| <a name="input_enable_hub"></a> [enable\_hub](#input\_enable\_hub) | Enable ArgoCD Hub | `bool` | `false` | no |
| <a name="input_enable_spoke"></a> [enable\_spoke](#input\_enable\_spoke) | Enable ArgoCD Spoke | `bool` | `false` | no |
| <a name="input_helm_set"></a> [helm\_set](#input\_helm\_set) | Set values to pass to the Helm chart | `list(string)` | `[]` | no |
| <a name="input_helm_values"></a> [helm\_values](#input\_helm\_values) | Values to pass to the Helm chart | `list(string)` | `[]` | no |
| <a name="input_hub_iam_role_arn"></a> [hub\_iam\_role\_arn](#input\_hub\_iam\_role\_arn) | (Deprecated, use hub\_iam\_role\_arns) IAM Role ARN for ArgoCD Hub. This is required for spoke clusters | `string` | `null` | no |
| <a name="input_hub_iam_role_arns"></a> [hub\_iam\_role\_arns](#input\_hub\_iam\_role\_arns) | A list of ArgoCD Hub IAM Role ARNs, enabling hubs to access spoke clusters. This is required for spoke clusters. | `list(string)` | `null` | no |
| <a name="input_hub_iam_role_name"></a> [hub\_iam\_role\_name](#input\_hub\_iam\_role\_name) | IAM Role Name for ArgoCD Hub. This is referenced by the Spoke clusters | `string` | `"argocd-controller"` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace to deploy ArgoCD | `string` | `"argocd"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_name"></a> [cluster\_name](#output\_cluster\_name) | Name of the EKS cluster |
| <a name="output_cluster_secret_yaml"></a> [cluster\_secret\_yaml](#output\_cluster\_secret\_yaml) | ArgoCD cluster secret YAML configuration |
| <a name="output_hub_iam_role_arn"></a> [hub\_iam\_role\_arn](#output\_hub\_iam\_role\_arn) | IAM Role ARN for ArgoCD |
| <a name="output_spoke_iam_role_arn"></a> [spoke\_iam\_role\_arn](#output\_spoke\_iam\_role\_arn) | IAM Role ARN for ArgoCD Spoke |
<!-- END_TF_DOCS -->
