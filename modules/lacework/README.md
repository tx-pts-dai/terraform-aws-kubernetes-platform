# Lacework

Deploy Lacework Agents

```hcl
module "lacework" {
  source  = "tx-pts-dai/kubernetes-platform/aws//modules/datadog"
  version = ...

  cluster_name = module.eks.cluster_name
}
```
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0.0 |
| <a name="requirement_lacework"></a> [lacework](#requirement\_lacework) | >= 2.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.0.0 |
| <a name="provider_lacework"></a> [lacework](#provider\_lacework) | >= 2.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_lacework_k8s_datacollector"></a> [lacework\_k8s\_datacollector](#module\_lacework\_k8s\_datacollector) | lacework/agent/kubernetes | 2.5.2 |

## Resources

| Name | Type |
|------|------|
| [kubernetes_namespace_v1.lacework](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [lacework_agent_access_token.kubernetes](https://registry.terraform.io/providers/lacework/lacework/latest/docs/resources/agent_access_token) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_tags"></a> [agent\_tags](#input\_agent\_tags) | A map/dictionary of Tags to be assigned to the Lacework datacollector | `map(string)` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster | `string` | n/a | yes |
| <a name="input_enable_cluster_agent"></a> [enable\_cluster\_agent](#input\_enable\_cluster\_agent) | A boolean representing whether the Lacework cluster agent should be deployed | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Lacework resources | `string` | `"lacework"` | no |
| <a name="input_node_affinity"></a> [node\_affinity](#input\_node\_affinity) | Node affinity settings | <pre>list(object({<br/>    key      = string<br/>    operator = string<br/>    values   = list(string)<br/>  }))</pre> | <pre>[<br/>  {<br/>    "key": "eks.amazonaws.com/compute-type",<br/>    "operator": "NotIn",<br/>    "values": [<br/>      "fargate"<br/>    ]<br/>  }<br/>]</pre> | no |
| <a name="input_pod_priority_class_name"></a> [pod\_priority\_class\_name](#input\_pod\_priority\_class\_name) | Name of the pod priority class | `string` | `"system-node-critical"` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Resources for the Lacework agent | <pre>object({<br/>    cpu_request = string<br/>    mem_request = string<br/>    cpu_limit   = string<br/>    mem_limit   = string<br/>  })</pre> | <pre>{<br/>  "cpu_limit": "1000m",<br/>  "cpu_request": "100m",<br/>  "mem_limit": "1024Mi",<br/>  "mem_request": "256Mi"<br/>}</pre> | no |
| <a name="input_server_url"></a> [server\_url](#input\_server\_url) | Lacework server URL | `string` | `"https://api.fra.lacework.net"` | no |
| <a name="input_tolerations"></a> [tolerations](#input\_tolerations) | Tolerations for the Lacework agent | `list(map(string))` | <pre>[<br/>  {<br/>    "effect": "NoSchedule",<br/>    "operator": "Exists"<br/>  }<br/>]</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.2 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0.0 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.0.0 |
| <a name="requirement_lacework"></a> [lacework](#requirement\_lacework) | >= 1.18.2 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.0.0 |
| <a name="provider_lacework"></a> [lacework](#provider\_lacework) | >= 1.18.2 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_lacework_k8s_datacollector"></a> [lacework\_k8s\_datacollector](#module\_lacework\_k8s\_datacollector) | lacework/agent/kubernetes | 2.5.1 |

## Resources

| Name | Type |
|------|------|
| [kubernetes_namespace_v1.lacework](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [lacework_agent_access_token.kubernetes](https://registry.terraform.io/providers/lacework/lacework/latest/docs/resources/agent_access_token) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_tags"></a> [agent\_tags](#input\_agent\_tags) | A map/dictionary of Tags to be assigned to the Lacework datacollector | `map(string)` | `{}` | no |
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster | `string` | n/a | yes |
| <a name="input_enable_cluster_agent"></a> [enable\_cluster\_agent](#input\_enable\_cluster\_agent) | A boolean representing whether the Lacework cluster agent should be deployed | `bool` | `true` | no |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Lacework resources | `string` | `"lacework"` | no |
| <a name="input_node_affinity"></a> [node\_affinity](#input\_node\_affinity) | Node affinity settings | <pre>list(object({<br>    key      = string<br>    operator = string<br>    values   = list(string)<br>  }))</pre> | <pre>[<br>  {<br>    "key": "eks.amazonaws.com/compute-type",<br>    "operator": "NotIn",<br>    "values": [<br>      "fargate"<br>    ]<br>  }<br>]</pre> | no |
| <a name="input_pod_priority_class_name"></a> [pod\_priority\_class\_name](#input\_pod\_priority\_class\_name) | Name of the pod priority class | `string` | `"system-node-critical"` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Resources for the Lacework agent | <pre>object({<br>    cpu_request = string<br>    mem_request = string<br>    cpu_limit   = string<br>    mem_limit   = string<br>  })</pre> | <pre>{<br>  "cpu_limit": "1000m",<br>  "cpu_request": "100m",<br>  "mem_limit": "1024Mi",<br>  "mem_request": "256Mi"<br>}</pre> | no |
| <a name="input_server_url"></a> [server\_url](#input\_server\_url) | Lacework server URL | `string` | `"https://api.fra.lacework.net"` | no |
| <a name="input_tolerations"></a> [tolerations](#input\_tolerations) | Tolerations for the Lacework agent | `list(map(string))` | <pre>[<br>  {<br>    "effect": "NoSchedule",<br>    "operator": "Exists"<br>  }<br>]</pre> | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
