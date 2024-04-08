# Tamedia Kubernetes as a Service (KaaS) Module

Batteries included module to deploy a Kubernetes cluster on AWS.

## Usage

< describe the module minimal code required for a deployment >

```hcl
module "my_module_example" {
}
```

## Explanation and description of interesting use-cases

< create a h2 chapter for each section explaining special module concepts >

## Examples

< if the folder `examples/` exists, put here the link to the examples subfolders with their descriptions >

## Contributing

< issues and contribution guidelines for public modules >

### Pre-Commit

Installation: [install pre-commit](https://pre-commit.com/) and execute `pre-commit install`. This will generate pre-commit hooks according to the config in `.pre-commit-config.yaml`

Before submitting a PR be sure to have used the pre-commit hooks or run: `pre-commit run -a`

The `pre-commit` command will run:

- Terraform fmt
- Terraform validate
- Terraform docs
- Terraform validate with tflint
- check for merge conflicts
- fix end of files

as described in the `.pre-commit-config.yaml` file

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.42.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.12 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.42.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.12 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0.2 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.11 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_addons"></a> [addons](#module\_addons) | aws-ia/eks-blueprints-addons/aws | 1.16.1 |
| <a name="module_ebs_csi_driver_irsa"></a> [ebs\_csi\_driver\_irsa](#module\_ebs\_csi\_driver\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.37.2 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 20.8.3 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_route53_zone.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route_table_association.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_subnet.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.karpenter_node_class](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.karpenter_node_pool](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.secretsmanager_auth](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [random_id.random_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [time_sleep.wait_on_destroy](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route_tables.private_route_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addons"></a> [addons](#input\_addons) | Map of addon configurations | `any` | <pre>{<br>  "aws_load_balancer_controller": {<br>    "enabled": true<br>  },<br>  "cert_manager": {<br>    "enabled": false<br>  },<br>  "external_dns": {<br>    "enabled": true<br>  },<br>  "external_secrets": {<br>    "enabled": true<br>  },<br>  "fargate_fluentbit": {<br>    "enabled": true<br>  },<br>  "ingress_nginx": {<br>    "enabled": false<br>  },<br>  "kube_prometheus_stack": {<br>    "enabled": false<br>  },<br>  "metrics_server": {<br>    "enabled": true<br>  }<br>}</pre> | no |
| <a name="input_base_domain"></a> [base\_domain](#input\_base\_domain) | The base domain for the platform | `string` | `"tamedia.net"` | no |
| <a name="input_cluster_admins"></a> [cluster\_admins](#input\_cluster\_admins) | Map of IAM roles to add as cluster admins | <pre>map(object({<br>    role_name         = string<br>    kubernetes_groups = optional(list(string))<br>  }))</pre> | <pre>{<br>  "cicd": {<br>    "role_name": "cicd-iac"<br>  },<br>  "sso": {<br>    "role_name": "aws-reserved/sso.amazonaws.com/eu-west-1/AWSReservedSSO_AWSAdministratorAccess_3cb2c900c0e65cd2"<br>  }<br>}</pre> | no |
| <a name="input_eks"></a> [eks](#input\_eks) | Map of EKS configurations | `any` | `{}` | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Map of Karpenter configurations | `any` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the platform | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Map of VPC configurations | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eks"></a> [eks](#output\_eks) | Map of attributes for the EKS cluster |
| <a name="output_network"></a> [network](#output\_network) | Map of attributes for the EKS cluster |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

## Authors

Module is maintained by [Alfredo Gottardo](https://github.com/AlfGot), [David Beauvererd](https://github.com/Davidoutz), [Davide Cammarata](https://github.com/DCamma), [Demetrio Carrara](https://github.com/sgametrio) and [Roland Bapst](https://github.com/rbapst-tamedia)

## License

Apache 2 Licensed. See [LICENSE](< link to license file >) for full details.
