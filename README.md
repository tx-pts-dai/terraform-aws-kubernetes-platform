# [Tamedia Kubernetes as a Service (KaaS) Terraform Module](https://tx-pts-dai.github.io/terraform-aws-kubernetes-platform/)

Opinionated Terraform module to deploy Kubernetes in AWS. Includes:

Managed Addons:

- EBS CSI
- VPC CNI
- CoreDNS
- KubeProxy

Components (installed by default):

- [Karpenter](https://karpenter.sh/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)

## Requirements

The module needs some resources to be deployed in order to operate correctly:

IAM service-linked roles

- AWSServiceRoleForEC2Spot
- [AWSServiceRoleForEC2SpotFleet](https://docs.aws.amazon.com/batch/latest/userguide/spot_fleet_IAM_role.html)

## Usage

```tf
module "k8s_platform" {
  source = "tx-pts-dai/kubernetes-platform/aws"
  # Pin this module to a specific version to avoid breaking changes
  # version = "0.0.0"

  name = "example-platform"

  vpc = {
    vpc_id          = "vpc-12345678"
    vpc_cidr        = "10.0.0.0/16"
    private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
    intra_subnets   = ["10.0.3.0/24"]
  }

  tags = {
    Environment = "sandbox"
    GithubRepo  = "terraform-aws-kubernetes-platform"
  }
}
```

See the [Examples below](#Examples) for more use cases

## Release new kubernetes version
**important**
Each new kubernetes version needs it's own release. This is due to the fact that we should not skip kubernetes versions during a cluster upgrade.

To release a new Kubernetes version, follow these steps:

1. **Update the version file**:
   - Open the `K8S_VERSION` file located in the root of the repository.
   - Update the version number to the next Kubernetes version.

2. **Commit the Changes**:
   - Commit the changes to the `K8S_VERSION` file with a meaningful commit message following the release proces. For example:
     ```sh
     git add K8S_VERSION
     git commit -m "feat! update Kubernetes version to 1.30"
     ```

3. **Push the Changes**:
   - Push the changes to the main branch, the release workflow will automatically run. This workflow will:
     - Read the updated Kubernetes version from the `K8S_VERSION` file.
     - Determine the new module version based on the commit message.
     - Create a new release with the updated module version and the kubernetes version as metadata. The format would be X.Y.Z+A.B where X.Y.Z is the module version and A.B is the kubenetes control plane version.

4. **Verify the Release**:
   - Check the [GitHub Actions](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/actions) page to ensure the release workflow completed successfully.
   - Verify that the new module version is available in the [Terraform Registry](https://registry.terraform.io/modules/tx-pts-dai/kubernetes-platform/aws).


## Explanation and description of interesting use-cases

Why this module?

- To provide an AWS account with a K8s cluster with batteries included so that you can start deploying your workloads on a well-built foundation
- To encourage standardization and common practices
- To ease maintenance

## Examples

- [Complete](./examples/complete/) - Includes creation of VPC, k8s cluster, addons and all the optional features.
- [Datadog](./examples/datadog/) - EKS deployment with Datadog Operator integration
- [Lacework](./examples/lacework/) - EKS deployment with Lacework integration
- [Network](./examples/network/) - VPC deployment with custom subnets for kubernetes

### Cleanup example deployments

[Destroy Workflow](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/actions/workflows/examples-cleanup.yaml) - This manual workflow destroys deployed example deployments by selection the branch and the example to destroy.

## Contributing

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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.9 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.2 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.27 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.9 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.2 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.27 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.11 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 6.1.0 |
| <a name="module_argocd"></a> [argocd](#module\_argocd) | ./modules/argocd | n/a |
| <a name="module_aws_ebs_csi_pod_identity"></a> [aws\_ebs\_csi\_pod\_identity](#module\_aws\_ebs\_csi\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.0.0 |
| <a name="module_aws_gateway_controller_pod_identity"></a> [aws\_gateway\_controller\_pod\_identity](#module\_aws\_gateway\_controller\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.0.0 |
| <a name="module_aws_lb_controller_pod_identity"></a> [aws\_lb\_controller\_pod\_identity](#module\_aws\_lb\_controller\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.0.0 |
| <a name="module_aws_vpc_cni_pod_identity"></a> [aws\_vpc\_cni\_pod\_identity](#module\_aws\_vpc\_cni\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.0.0 |
| <a name="module_ebs_csi_driver_irsa"></a> [ebs\_csi\_driver\_irsa](#module\_ebs\_csi\_driver\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts | 6.2.1 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.1.5 |
| <a name="module_eks_addons"></a> [eks\_addons](#module\_eks\_addons) | ./modules/eks-addons | n/a |
| <a name="module_external_dns_pod_identity"></a> [external\_dns\_pod\_identity](#module\_external\_dns\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.0.0 |
| <a name="module_external_secrets_pod_identity"></a> [external\_secrets\_pod\_identity](#module\_external\_secrets\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.0.0 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | 21.1.5 |
| <a name="module_karpenter_irsa"></a> [karpenter\_irsa](#module\_karpenter\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts | 6.2.1 |
| <a name="module_karpenter_security_group"></a> [karpenter\_security\_group](#module\_karpenter\_security\_group) | ./modules/security-group | n/a |
| <a name="module_ssm"></a> [ssm](#module\_ssm) | ./modules/ssm | n/a |
| <a name="module_vpc_cni_irsa"></a> [vpc\_cni\_irsa](#module\_vpc\_cni\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts | 6.2.1 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.fargate_fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.fargate_fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_route_table_association.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group_rule.eks_control_plane_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_subnet.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [helm_release.karpenter_crd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter_release](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter_resources](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [kubernetes_config_map_v1.aws_logging](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/config_map_v1) | resource |
| [kubernetes_namespace_v1.aws_observability](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace_v1) | resource |
| [time_sleep.wait_after_karpenter](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_sleep.wait_on_destroy](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_static.timestamp_id](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.fargate_fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_roles.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.base_domain_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_route_tables.private_route_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate"></a> [acm\_certificate](#input\_acm\_certificate) | ACM certificate configuration for the domain(s). Controls domain name, alternative domain names, wildcard configuration, and validation behavior.<br/>Options include:<br/>  - domain\_name: Primary domain name for the certificate. If not provided, uses base\_domain from other configuration.<br/>  - subject\_alternative\_names: List of additional domain names to include in the certificate.<br/>  - wildcard\_certificates: When true, adds a wildcard prefix (*.) to all domains in the certificate.<br/>  - prepend\_stack\_id: When true, prepends the stack identifier to each domain name. Only works after random\_string is created.<br/>  - wait\_for\_validation: When true, Terraform will wait for certificate validation to complete before proceeding. | <pre>object({<br/>    domain_name               = optional(string)<br/>    subject_alternative_names = optional(list(string), [])<br/>    wildcard_certificates     = optional(bool, false)<br/>    prepend_stack_id          = optional(bool, false)<br/>    wait_for_validation       = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_argocd"></a> [argocd](#input\_argocd) | Argo CD configurations | <pre>object({<br/>    # Hub specific<br/>    enable_hub        = optional(bool, false)<br/>    namespace         = optional(string, "argocd")<br/>    hub_iam_role_name = optional(string, "argocd-controller")<br/><br/>    # Spoke specific<br/>    enable_spoke = optional(bool, false)<br/><br/>    hub_iam_role_arn  = optional(string, null)<br/>    hub_iam_role_arns = optional(list(string), null)<br/><br/>    # Common<br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_base_domain"></a> [base\_domain](#input\_base\_domain) | Base domain for the platform, used for ingress and ACM certificates | `string` | `null` | no |
| <a name="input_cluster_admins"></a> [cluster\_admins](#input\_cluster\_admins) | Map of IAM roles to add as cluster admins<br/>  role\_arn: ARN of the IAM role to add as cluster admin<br/>  role\_name: Name of the IAM role to add as cluster admin<br/>  kubernetes\_groups: List of Kubernetes groups to add the role to (default: ["system:masters"])<br/><br/>role\_arn and role\_name are mutually exclusive, exactly one must be set. | <pre>map(object({<br/>    role_arn          = optional(string)<br/>    role_name         = optional(string)<br/>    kubernetes_groups = optional(list(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_create_addon_pod_identity_roles"></a> [create\_addon\_pod\_identity\_roles](#input\_create\_addon\_pod\_identity\_roles) | Create addon pod identities roles. If set to true, all roles will be created | `bool` | `true` | no |
| <a name="input_eks"></a> [eks](#input\_eks) | Map of EKS configurations | `any` | `{}` | no |
| <a name="input_enable_acm_certificate"></a> [enable\_acm\_certificate](#input\_enable\_acm\_certificate) | Enable ACM certificate | `bool` | `false` | no |
| <a name="input_enable_argocd"></a> [enable\_argocd](#input\_enable\_argocd) | Enable Argo CD | `bool` | `false` | no |
| <a name="input_enable_fargate_fluentbit"></a> [enable\_fargate\_fluentbit](#input\_enable\_fargate\_fluentbit) | Enable Fargate Fluentbit | `bool` | `true` | no |
| <a name="input_enable_sso_admin_auto_discovery"></a> [enable\_sso\_admin\_auto\_discovery](#input\_enable\_sso\_admin\_auto\_discovery) | Enable automatic discovery of SSO admin roles. When disabled, only explicitly defined cluster\_admins are used. | `bool` | `true` | no |
| <a name="input_enable_timestamp_id"></a> [enable\_timestamp\_id](#input\_enable\_timestamp\_id) | Disable the timestamp-based ID generation. When true, uses a static ID instead of timestamp. | `bool` | `true` | no |
| <a name="input_extra_cluster_addons"></a> [extra\_cluster\_addons](#input\_extra\_cluster\_addons) | Map of cluster addon configurations to enable for the cluster. Addon name can be the map keys or set with `name`. Addons are created after karpenter resources | `any` | `{}` | no |
| <a name="input_extra_cluster_addons_timeouts"></a> [extra\_cluster\_addons\_timeouts](#input\_extra\_cluster\_addons\_timeouts) | Create, update, and delete timeout configurations for the cluster addons | `map(string)` | `{}` | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Karpenter configurations | <pre>object({<br/>    subnet_cidrs = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_karpenter_helm_set"></a> [karpenter\_helm\_set](#input\_karpenter\_helm\_set) | List of Karpenter Helm set values | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_karpenter_helm_values"></a> [karpenter\_helm\_values](#input\_karpenter\_helm\_values) | List of Karpenter Helm values | `list(string)` | `[]` | no |
| <a name="input_karpenter_resources_helm_set"></a> [karpenter\_resources\_helm\_set](#input\_karpenter\_resources\_helm\_set) | List of Karpenter Resources Helm set values | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_karpenter_resources_helm_values"></a> [karpenter\_resources\_helm\_values](#input\_karpenter\_resources\_helm\_values) | List of Karpenter Resources Helm values | `list(string)` | `[]` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the platform, a timestamp will be appended to this name to make the stack\_name. If not provided, the name of the directory will be used. | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to use | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configurations | <pre>object({<br/>    vpc_id          = string<br/>    vpc_cidr        = string<br/>    private_subnets = list(string)<br/>    intra_subnets   = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_argocd"></a> [argocd](#output\_argocd) | Map of attributes for the ArgoCD module |
| <a name="output_eks"></a> [eks](#output\_eks) | Map of attributes for the EKS cluster |
| <a name="output_karpenter"></a> [karpenter](#output\_karpenter) | Map of attributes for the Karpenter module |
<!-- END_TF_DOCS -->

## Authors

Module is maintained by [Alfredo Gottardo](https://github.com/AlfGot), [David Beauvererd](https://github.com/Davidoutz), [Davide Cammarata](https://github.com/DCamma), [Francisco Ferreira](https://github.com/cferrera),  [Roland Bapst](https://github.com/rbapst-tamedia) and [Samuel Wibrow](https://github.com/swibrow)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
