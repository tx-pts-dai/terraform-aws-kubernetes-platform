# [Tamedia Kubernetes as a Service (KaaS) Terraform Module](https://tx-pts-dai.github.io/terraform-aws-kubernetes-platform/)

Opinionated batteries included Terraform module to deploy Kubernetes in AWS. Includes:

Managed Addons:

- EBS CSI
- VPC CNI
- CoreDNS
- KubeProxy

Core components (installed by default):

- [Karpenter](https://karpenter.sh/)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/latest/)
- [External DNS](https://github.com/kubernetes-sigs/external-dns)
- [External Secrets Operator](https://external-secrets.io/latest/)
- [Prometheus Operator](https://prometheus-operator.dev/docs/getting-started/introduction/)
- [Grafana](https://grafana.com/)
- [Fluent Operator](https://github.com/fluent/fluent-operator)
- [Fluentbit for Fargate]()
- [Reloader](https://docs.stakater.com/reloader/)

Additional components (optional):

- [Cert Manager](https://cert-manager.io/docs/)
- [Ingress Nginx](https://kubernetes.github.io/ingress-nginx/)
- [Downscaler]()
- [ArgoCD](https://argoproj.github.io/argo-cd/)

Integrations (optional):

- Okta
- PagerDuty
- Slack

## Requirements

The module needs some resources to be deployed in order to operate correctly:

IAM service-linked roles

- AWSServiceRoleForEC2Spot
- [AWSServiceRoleForEC2SpotFleet](https://docs.aws.amazon.com/batch/latest/userguide/spot_fleet_IAM_role.html)

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


## Usage

```tf
module "k8s_platform" {
  source = "tx-pts-dai/kubernetes-platform/aws"
  # Pin this module to a specific version to avoid breaking changes
  # version = "0.0.0"

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

## Reloader
The [Stakater Reloader](https://github.com/stakater/Reloader) is a Kubernetes controller that automatically watches for changes in ConfigMaps and Secrets and triggers rolling restarts of the associated deployments, statefulsets, or daemonsets when these configurations are updated. This functionality ensures that applications deployed within a Kubernetes cluster always reflect the latest configuration without manual intervention.

When an application relies on configuration data or sensitive information stored in ConfigMaps or Secrets, and these resources are modified, Reloader automates the process of applying these changes by updating the relevant pods. Without Reloader, such changes would require a manual pod restart or redeployment to take effect.

Reloader is deployed by default on the cluster but is used as on demand via annotations.

Considering this kubernetes deployment and the required annotation:
```yaml
kind: Deployment
metadata:
  name: foo
  annotations:
    reloader.stakater.com/auto: "true"
spec:
  template:
    metadata:
```

Reloader will now watch for updates and manage rolling restart of pods for this specific deployment.

## Examples

- [Complete](./examples/complete/) - Includes creation of VPC, k8s cluster, addons and all the optional features.
- [Datadog](./examples/datadog/) - EKS deployment with Datadog Operator integration
- [Disable-Addons](./examples/disable-addons/) - EKS + Karpenter deployment with all addons disabled
- [Lacework](./examples/lacework/) - EKS deployment with Lacework integration
- [Network](./examples/network/) - VPC deployment with custom subnets for kubernetes
- [Simple](./examples/simple/) - Simplest EKS deployment with default VPC, addons, ... creation


### Cleanup example deployments

[Destroy Workflow](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/actions/workflows/examples-cleanup.yaml) - This manual workflow destroys deployed example deployments by selection the branch and the example to destroy.

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

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.7.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.12, < 3.0.0 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.27 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 2.12, < 3.0.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.11 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 6.1.0 |
| <a name="module_addons"></a> [addons](#module\_addons) | aws-ia/eks-blueprints-addons/aws | 1.22.0 |
| <a name="module_argocd"></a> [argocd](#module\_argocd) | ./modules/argocd | n/a |
| <a name="module_aws_ebs_csi_pod_identity"></a> [aws\_ebs\_csi\_pod\_identity](#module\_aws\_ebs\_csi\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.0.0 |
| <a name="module_downscaler"></a> [downscaler](#module\_downscaler) | tx-pts-dai/downscaler/kubernetes | 0.3.1 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.1.5 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | 21.1.5 |
| <a name="module_karpenter_irsa"></a> [karpenter\_irsa](#module\_karpenter\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts | 6.2.1 |
| <a name="module_karpenter_security_group"></a> [karpenter\_security\_group](#module\_karpenter\_security\_group) | ./modules/security-group | n/a |
| <a name="module_ssm"></a> [ssm](#module\_ssm) | ./modules/ssm | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_route_table_association.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group_rule.eks_control_plane_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_subnet.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [helm_release.cluster_secret_store](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter_crd](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter_release](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.karpenter_resources](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.reloader](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [time_sleep.wait_on_destroy](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_static.timestamp_id](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_roles.iam_cluster_admins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_iam_roles.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.base_domain_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_route_tables.private_route_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate"></a> [acm\_certificate](#input\_acm\_certificate) | ACM certificate configuration for the domain(s). Controls domain name, alternative domain names, wildcard configuration, and validation behavior.<br/>Options include:<br/>  - domain\_name: Primary domain name for the certificate. If not provided, uses base\_domain from other configuration.<br/>  - subject\_alternative\_names: List of additional domain names to include in the certificate.<br/>  - wildcard\_certificates: When true, adds a wildcard prefix (*.) to all domains in the certificate.<br/>  - prepend\_stack\_id: When true, prepends the stack identifier to each domain name. Only works after random\_string is created.<br/>  - wait\_for\_validation: When true, Terraform will wait for certificate validation to complete before proceeding. | <pre>object({<br/>    domain_name               = optional(string)<br/>    subject_alternative_names = optional(list(string), [])<br/>    wildcard_certificates     = optional(bool, false)<br/>    prepend_stack_id          = optional(bool, false)<br/>    wait_for_validation       = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_argocd"></a> [argocd](#input\_argocd) | Argo CD configurations | <pre>object({<br/>    # Hub specific<br/>    enable_hub        = optional(bool, false)<br/>    namespace         = optional(string, "argocd")<br/>    hub_iam_role_name = optional(string, "argocd-controller")<br/><br/>    helm_values = optional(list(string), [])<br/>    helm_set = optional(list(object({<br/>      name  = string<br/>      value = string<br/>    })), [])<br/><br/>    # Spoke specific<br/>    enable_spoke = optional(bool, false)<br/><br/>    hub_iam_role_arn  = optional(string, null)<br/>    hub_iam_role_arns = optional(list(string), null)<br/><br/>    # Common<br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_aws_load_balancer_controller"></a> [aws\_load\_balancer\_controller](#input\_aws\_load\_balancer\_controller) | AWS Load Balancer Controller configurations | `any` | `{}` | no |
| <a name="input_base_domain"></a> [base\_domain](#input\_base\_domain) | Base domain for the platform, used for ingress and ACM certificates | `string` | `null` | no |
| <a name="input_cert_manager"></a> [cert\_manager](#input\_cert\_manager) | Cert Manager configurations | `any` | `{}` | no |
| <a name="input_cluster_admins"></a> [cluster\_admins](#input\_cluster\_admins) | Map of IAM roles to add as cluster admins. Only exact matching role names are returned | <pre>map(object({<br/>    role_name         = string<br/>    kubernetes_groups = optional(list(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_create_addons"></a> [create\_addons](#input\_create\_addons) | Create the platform addons. if set to false, no addons will be created | `bool` | `true` | no |
| <a name="input_downscaler"></a> [downscaler](#input\_downscaler) | Downscaler configurations | `any` | `{}` | no |
| <a name="input_eks"></a> [eks](#input\_eks) | Map of EKS configurations | `any` | `{}` | no |
| <a name="input_enable_acm_certificate"></a> [enable\_acm\_certificate](#input\_enable\_acm\_certificate) | Enable ACM certificate | `bool` | `false` | no |
| <a name="input_enable_argocd"></a> [enable\_argocd](#input\_enable\_argocd) | Enable Argo CD | `bool` | `false` | no |
| <a name="input_enable_aws_load_balancer_controller"></a> [enable\_aws\_load\_balancer\_controller](#input\_enable\_aws\_load\_balancer\_controller) | Enable AWS Load Balancer Controller | `bool` | `true` | no |
| <a name="input_enable_cert_manager"></a> [enable\_cert\_manager](#input\_enable\_cert\_manager) | Enable Cert Manager | `bool` | `false` | no |
| <a name="input_enable_downscaler"></a> [enable\_downscaler](#input\_enable\_downscaler) | Enable Downscaler | `bool` | `false` | no |
| <a name="input_enable_external_dns"></a> [enable\_external\_dns](#input\_enable\_external\_dns) | Enable External DNS | `bool` | `true` | no |
| <a name="input_enable_external_secrets"></a> [enable\_external\_secrets](#input\_enable\_external\_secrets) | Enable External Secrets | `bool` | `true` | no |
| <a name="input_enable_fargate_fluentbit"></a> [enable\_fargate\_fluentbit](#input\_enable\_fargate\_fluentbit) | Enable Fargate Fluentbit | `bool` | `true` | no |
| <a name="input_enable_ingress_nginx"></a> [enable\_ingress\_nginx](#input\_enable\_ingress\_nginx) | Enable Ingress Nginx | `bool` | `false` | no |
| <a name="input_enable_metrics_server"></a> [enable\_metrics\_server](#input\_enable\_metrics\_server) | Enable Metrics Server | `bool` | `true` | no |
| <a name="input_enable_reloader"></a> [enable\_reloader](#input\_enable\_reloader) | Enable Reloader | `bool` | `true` | no |
| <a name="input_enable_sso_admin_auto_discovery"></a> [enable\_sso\_admin\_auto\_discovery](#input\_enable\_sso\_admin\_auto\_discovery) | Enable automatic discovery of SSO admin roles. When disabled, only explicitly defined cluster\_admins are used. | `bool` | `true` | no |
| <a name="input_enable_timestamp_id"></a> [enable\_timestamp\_id](#input\_enable\_timestamp\_id) | Disable the timestamp-based ID generation. When true, uses a static ID instead of timestamp. | `bool` | `true` | no |
| <a name="input_external_dns"></a> [external\_dns](#input\_external\_dns) | External DNS configurations | `any` | `{}` | no |
| <a name="input_external_secrets"></a> [external\_secrets](#input\_external\_secrets) | External Secrets configurations | `any` | `{}` | no |
| <a name="input_fargate_fluentbit"></a> [fargate\_fluentbit](#input\_fargate\_fluentbit) | Fargate Fluentbit configurations | `any` | `{}` | no |
| <a name="input_ingress_nginx"></a> [ingress\_nginx](#input\_ingress\_nginx) | Ingress Nginx configurations | `any` | `{}` | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Karpenter configurations | <pre>object({<br/>    subnet_cidrs = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_karpenter_helm_set"></a> [karpenter\_helm\_set](#input\_karpenter\_helm\_set) | List of Karpenter Helm set values | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_karpenter_helm_values"></a> [karpenter\_helm\_values](#input\_karpenter\_helm\_values) | List of Karpenter Helm values | `list(string)` | `[]` | no |
| <a name="input_karpenter_resources_helm_set"></a> [karpenter\_resources\_helm\_set](#input\_karpenter\_resources\_helm\_set) | List of Karpenter Resources Helm set values | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_karpenter_resources_helm_values"></a> [karpenter\_resources\_helm\_values](#input\_karpenter\_resources\_helm\_values) | List of Karpenter Resources Helm values | `list(string)` | `[]` | no |
| <a name="input_metrics_server"></a> [metrics\_server](#input\_metrics\_server) | Metrics Server configurations | `any` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the platform, a timestamp will be appended to this name to make the stack\_name. If not provided, the name of the directory will be used. | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to use | `string` | `null` | no |
| <a name="input_reloader"></a> [reloader](#input\_reloader) | Reloader configurations | `any` | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configurations | <pre>object({<br/>    vpc_id          = optional(string)<br/>    vpc_cidr        = optional(string)<br/>    private_subnets = optional(list(string))<br/>    intra_subnets   = optional(list(string))<br/>  })</pre> | `{}` | no |

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
