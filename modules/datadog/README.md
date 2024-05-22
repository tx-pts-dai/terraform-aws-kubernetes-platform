# Lacework

Deploy Lacework Agents

```hcl
module "lacework" {
  source = "./modules/lacework"

  cluster_name = module.eks.cluster_name
}
```
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |
| <a name="requirement_datadog"></a> [datadog](#requirement\_datadog) | ~> 3.39 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.6 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_datadog"></a> [datadog](#provider\_datadog) | ~> 3.39 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | ~> 2.6 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [datadog_api_key.datadog_agent](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/api_key) | resource |
| [datadog_application_key.datadog_agent](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/application_key) | resource |
| [helm_release.datadog_agent](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.datadog_operator](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_secret.datadog_keys](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster | `string` | n/a | yes |
| <a name="input_datadog"></a> [datadog](#input\_datadog) | Map of Datadog configurations | `any` | `{}` | no |
| <a name="input_datadog_agent_values"></a> [datadog\_agent\_values](#input\_datadog\_agent\_values) | Map of Datadog Agent values | `map(string)` | `{}` | no |
| <a name="input_datadog_operator_sensitive_values"></a> [datadog\_operator\_sensitive\_values](#input\_datadog\_operator\_sensitive\_values) | Map of Datadog Operator sensitive values | `map(string)` | `{}` | no |
| <a name="input_datadog_operator_values"></a> [datadog\_operator\_values](#input\_datadog\_operator\_values) | Map of Datadog Operator values | `map(string)` | `{}` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Datadog resources | `string` | `"monitoring"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
