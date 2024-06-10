# Tamedia Kubernetes as a Service (KaaS) Module

Batteries included module to deploy a Kubernetes cluster on AWS. Includes:

- Metrics server
- AWS Load Balancer Controller
- Karpenter
- External DNS
- External secrets

## Requirements

The module needs some resources to be deployed in order to operate correctly:

- IAM Service-linked roles (`AWSServiceRoleForEC2Spot` and `AWSServiceRoleForEC2SpotFleet`) - [docs](https://docs.aws.amazon.com/batch/latest/userguide/spot_fleet_IAM_role.html)

## Usage

```tf
module "k8s_platform" {
  source  = "tx-pts-dai/kubernetes-platform/aws"
  version = "0.0.1"

  name = "example-platform"

  vpc = {
    enabled = true
  }

  tags = {
    Environment = "sandbox"
    GithubRepo  = "terraform-aws-kubernetes-platform"
  }
}
```

See the [Examples below](#Examples) for more use cases

## Explanation and description of interesting use-cases

Why this module?

- To provide an AWS account with a K8s cluster with batteries included so that you can start deploying your workloads on a well-built foundation
- To encourage standardization and common practices
- To ease maintenance

## Examples

- [Complete](./examples/complete/) - Includes creation of VPC, k8s cluster, addons and all the optional features.
- [Simple](./examples/simple/) - Simplest EKS deployment with default VPC, addons, ... creation
- [Lacework](./examples/lacework/) - EKS deployment with Lacework integration
- [Datadog](./examples/datadog/) - EKS deployment with Datadog Operator integration

### Cleanup example deployments

[Destroy Workflow](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/actions/workflows/cleanup.yaml) - This workflow will destroy the provided example deployments

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.42.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.12 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.27 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | >= 4.0 |

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
| <a name="module_downscaler"></a> [downscaler](#module\_downscaler) | tx-pts-dai/downscaler/kubernetes | 0.3.0 |
| <a name="module_ebs_csi_driver_irsa"></a> [ebs\_csi\_driver\_irsa](#module\_ebs\_csi\_driver\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.37.2 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 20.8.3 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_vpc_cni_irsa"></a> [vpc\_cni\_irsa](#module\_vpc\_cni\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.37.2 |

## Resources

| Name | Type |
|------|------|
| [aws_route53_zone.private](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_zone) | resource |
| [aws_route_table_association.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_ssm_parameter.cluster_name](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_subnet.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [helm_release.karpenter](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.karpenter_node_class](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.karpenter_node_pool](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.secretsmanager_auth](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [random_id.random_id](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [time_sleep.wait_on_destroy](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_roles.iam_cluster_admins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_iam_roles.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route_tables.private_route_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_addons"></a> [addons](#input\_addons) | Map of addon configurations | `any` | <pre>{<br>  "aws_load_balancer_controller": {<br>    "enabled": true<br>  },<br>  "cert_manager": {<br>    "enabled": false<br>  },<br>  "downscaler": {<br>    "enabled": false<br>  },<br>  "external_dns": {<br>    "enabled": true<br>  },<br>  "external_secrets": {<br>    "enabled": true<br>  },<br>  "fargate_fluentbit": {<br>    "enabled": true<br>  },<br>  "ingress_nginx": {<br>    "enabled": false<br>  },<br>  "kube_prometheus_stack": {<br>    "enabled": false<br>  },<br>  "metrics_server": {<br>    "enabled": true<br>  }<br>}</pre> | no |
| <a name="input_base_domain"></a> [base\_domain](#input\_base\_domain) | The base domain for the platform | `string` | `""` | no |
| <a name="input_cluster_admins"></a> [cluster\_admins](#input\_cluster\_admins) | Map of IAM roles to add as cluster admins. Only exact matching role names are returned | <pre>map(object({<br>    role_name         = string<br>    kubernetes_groups = optional(list(string))<br>  }))</pre> | `{}` | no |
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

Module is maintained by [Alfredo Gottardo](https://github.com/AlfGot), [David Beauvererd](https://github.com/Davidoutz), [Davide Cammarata](https://github.com/DCamma), [Demetrio Carrara](https://github.com/sgametrio), [Roland Bapst](https://github.com/rbapst-tamedia) and [Samuel Wibrow](https://github.com/swibrow)

## License

Apache 2 Licensed. See [LICENSE](< link to license file >) for full details.
