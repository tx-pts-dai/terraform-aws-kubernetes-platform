# Datadog Operator

Deploy the Datadog Operator and the Datadog Agent

```hcl
module "datadog" {
  source = "../../modules/datadog"

  cluster_name   = "my-cluster"
  datadog_secret = "secretsmanager/secret/namespace"
  environment    = "example"
  product_name   = "dai"

  datadog_operator_helm_values = {
    values = [
      <<-YAML
      remoteConfiguration:
        enabled: true
      YAML
    ]
  }

  datadog_operator_helm_set = [
    {
      name  = "replicas"
      value = 2
    }
  ]

  datadog_agent_helm_values = [
    <<-YAML
    spec:
      override:
        clusterAgent:
          replicas: 1
    YAML
  ]

  datadog_agent_helm_set = [
    {
      name  = "spec.features.admissionController.agentSidecarInjection.image.tag",
      value = "7.57.2"
    }
  ]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.2 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.27 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.2 |
| <a name="provider_kubectl"></a> [kubectl](#provider\_kubectl) | >= 2.0.2 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.27 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.11.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [helm_release.datadog_agent](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.datadog_operator](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubectl_manifest.fargate_cluster_role](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubectl_manifest.fargate_role_binding](https://registry.terraform.io/providers/alekc/kubectl/latest/docs/resources/manifest) | resource |
| [kubernetes_annotations.this](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/annotations) | resource |
| [kubernetes_namespace_v1.datadog](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [kubernetes_secret.datadog_keys](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret) | resource |
| [time_sleep.this](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_secretsmanager_secret.datadog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret) | data source |
| [aws_secretsmanager_secret_version.datadog](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/secretsmanager_secret_version) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster | `string` | n/a | yes |
| <a name="input_datadog_agent_helm_set"></a> [datadog\_agent\_helm\_set](#input\_datadog\_agent\_helm\_set) | List of Datadog Agent custom resource set values | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_datadog_agent_helm_values"></a> [datadog\_agent\_helm\_values](#input\_datadog\_agent\_helm\_values) | List of Datadog Agent custom resource values | `list(string)` | `[]` | no |
| <a name="input_datadog_operator_helm_set"></a> [datadog\_operator\_helm\_set](#input\_datadog\_operator\_helm\_set) | List of Datadog Operator Helm set values | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_datadog_operator_helm_values"></a> [datadog\_operator\_helm\_values](#input\_datadog\_operator\_helm\_values) | List of Datadog Operator Helm values | `list(string)` | `[]` | no |
| <a name="input_datadog_operator_helm_version"></a> [datadog\_operator\_helm\_version](#input\_datadog\_operator\_helm\_version) | Version of the datadog operator chart | `string` | `"2.12.1"` | no |
| <a name="input_datadog_secret"></a> [datadog\_secret](#input\_datadog\_secret) | Name of the datadog secret in Secrets Manager | `string` | n/a | yes |
| <a name="input_environment"></a> [environment](#input\_environment) | Name of the environment | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Datadog resources | `string` | `"monitoring"` | no |
| <a name="input_product_name"></a> [product\_name](#input\_product\_name) | Value of the product tag added to all metrics and logs sent to datadog | `string` | n/a | yes |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

<!-- BEGIN_TF_DOCS -->
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
| <a name="input_datadog"></a> [datadog](#input\_datadog) | Object of Datadog configurations | <pre>object({<br>    agent_api_key_name            = optional(string) # by default it uses the cluster name<br>    agent_app_key_name            = optional(string) # by default it uses the cluster name<br>    operator_chart_version        = optional(string)<br>    custom_resource_chart_version = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_datadog_agent_helm_values"></a> [datadog\_agent\_helm\_values](#input\_datadog\_agent\_helm\_values) | List of Datadog Agent custom resource values. <https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md> | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_datadog_operator_helm_values"></a> [datadog\_operator\_helm\_values](#input\_datadog\_operator\_helm\_values) | List of Datadog Operator values | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | <pre>[<br>  {<br>    "name": "resources.requests.cpu",<br>    "value": "10m"<br>  },<br>  {<br>    "name": "resources.requests.memory",<br>    "value": "50Mi"<br>  }<br>]</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Datadog resources | `string` | `"monitoring"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

<!-- BEGIN_TF_DOCS -->
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
| <a name="input_datadog"></a> [datadog](#input\_datadog) | Object of Datadog configurations | <pre>object({<br>    agent_api_key_name            = optional(string) # by default it uses the cluster name<br>    agent_app_key_name            = optional(string) # by default it uses the cluster name<br>    operator_chart_version        = optional(string)<br>    custom_resource_chart_version = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_datadog_agent_helm_values"></a> [datadog\_agent\_helm\_values](#input\_datadog\_agent\_helm\_values) | List of Datadog Agent custom resource values. https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | `[]` | no |
| <a name="input_datadog_operator_helm_values"></a> [datadog\_operator\_helm\_values](#input\_datadog\_operator\_helm\_values) | List of Datadog Operator values | <pre>list(object({<br>    name  = string<br>    value = string<br>  }))</pre> | <pre>[<br>  {<br>    "name": "resources.requests.cpu",<br>    "value": "10m"<br>  },<br>  {<br>    "name": "resources.requests.memory",<br>    "value": "50Mi"<br>  }<br>]</pre> | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Datadog resources | `string` | `"monitoring"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
