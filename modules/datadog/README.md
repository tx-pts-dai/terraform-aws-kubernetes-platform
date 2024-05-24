# Datadog

Deploy the Datadog Operator and the Datadog Agent

```hcl
module "datadog" {
  source = "../../modules/datadog"

  cluster_name = module.k8s_platform.eks.cluster_name

  depends_on = [module.k8s_platform]
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

| Name | Source | Version |
|------|--------|---------|
| <a name="module_datadog_operator"></a> [datadog\_operator](#module\_datadog\_operator) | aws-ia/eks-blueprints-addon/aws | ~> 1.0 |

## Resources

| Name | Type |
|------|------|
| [datadog_api_key.datadog_agent](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/api_key) | resource |
| [datadog_application_key.datadog_agent](https://registry.terraform.io/providers/DataDog/datadog/latest/docs/resources/application_key) | resource |
| [helm_release.datadog_agent](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_secret.datadog_keys](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster | `string` | n/a | yes |
| <a name="input_datadog"></a> [datadog](#input\_datadog) | Object of Datadog configurations | <pre>object({<br>    agent_api_key_name            = optional(string)<br>    agent_app_key_name            = optional(string)<br>    operator_chart_version        = optional(string)<br>    custom_resource_chart_version = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_datadog_agent_helm_values"></a> [datadog\_agent\_helm\_values](#input\_datadog\_agent\_helm\_values) | List of Datadog Agent custom resource values. https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | <pre>[<br>  {<br>    "name": "features.logs.enabled",<br>    "value": "true"<br>  }<br>]</pre> | no |
| <a name="input_datadog_operator_helm_values"></a> [datadog\_operator\_helm\_values](#input\_datadog\_operator\_helm\_values) | List of Datadog Operator values | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | <pre>[<br>  {<br>    "name": "resources.requests.cpu",<br>    "value": "10m"<br>  },<br>  {<br>    "name": "resources.requests.memory",<br>    "value": "50Mi"<br>  }<br>]</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Datadog resources | `string` | `"monitoring"` | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
