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
| <a name="input_cluster_name"></a> [cluster\_name](#input\_cluster\_name) | Name of the cluster | `string` | n/a | yes |
| <a name="input_namespace"></a> [namespace](#input\_namespace) | Namespace for Lacework resources | `string` | `"lacework"` | no |
| <a name="input_node_affinity"></a> [node\_affinity](#input\_node\_affinity) | Node affinity settings | <pre>list(object({<br>    key      = string<br>    operator = string<br>    values   = list(string)<br>  }))</pre> | <pre>[<br>  {<br>    "key": "kubernetes.io/arch",<br>    "operator": "In",<br>    "values": [<br>      "amd64",<br>      "arm64"<br>    ]<br>  },<br>  {<br>    "key": "kubernetes.io/os",<br>    "operator": "In",<br>    "values": [<br>      "linux"<br>    ]<br>  },<br>  {<br>    "key": "eks.amazonaws.com/compute-type",<br>    "operator": "NotIn",<br>    "values": [<br>      "fargate"<br>    ]<br>  }<br>]</pre> | no |
| <a name="input_pod_priority_class_name"></a> [pod\_priority\_class\_name](#input\_pod\_priority\_class\_name) | Name of the pod priority class | `string` | `"system-node-critical"` | no |
| <a name="input_resources"></a> [resources](#input\_resources) | Resources for the Lacework agent | <pre>object({<br>    cpu_request = string<br>    mem_request = string<br>    cpu_limit   = string<br>    mem_limit   = string<br>  })</pre> | <pre>{<br>  "cpu_limit": "1000m",<br>  "cpu_request": "100m",<br>  "mem_limit": "1024Mi",<br>  "mem_request": "256Mi"<br>}</pre> | no |
| <a name="input_server_url"></a> [server\_url](#input\_server\_url) | Lacework server URL | `string` | `"https://api.fra.lacework.net"` | no |
| <a name="input_tolerations"></a> [tolerations](#input\_tolerations) | Tolerations for the Lacework agent | `list(map(string))` | <pre>[<br>  {<br>    "effect": "NoSchedule",<br>    "operator": "Exists"<br>  }<br>]</pre> | no |

## Outputs

No outputs.
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
