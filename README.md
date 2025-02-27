# Tamedia Kubernetes as a Service (KaaS) Terraform Module (Alpha)

Opinionated batteries included Terraform module to deploy Kubernetes in AWS. Includes:

Managed Addons:

- EBS CSI
- VPC CNI
- CoreDNS
- KubeProxy

Core components (installed by default):

- Karpenter
- Metrics Server
- AWS Load Balancer Controller
- External DNS
- External Secrets
- Prometheus Operator
- Grafana
- Fluent Operator
- Fluentbit for Fargate
- Reloader

Additional components (optional):

- Cert Manager
- Ingress Nginx
- Downscaler

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

Reloader will now watch for updates and manage rolling restats of pods for this specific deployment.

## Examples

- [Complete](./examples/complete/) - Includes creation of VPC, k8s cluster, addons and all the optional features.
- [Simple](./examples/simple/) - Simplest EKS deployment with default VPC, addons, ... creation
- [Lacework](./examples/lacework/) - EKS deployment with Lacework integration
- [Datadog](./examples/datadog/) - EKS deployment with Datadog Operator integration

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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.42.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 2.12 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.27 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.42.0 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.27 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.11 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 5.1.1 |
| <a name="module_addons"></a> [addons](#module\_addons) | aws-ia/eks-blueprints-addons/aws | 1.19.0 |
| <a name="module_amp"></a> [amp](#module\_amp) | terraform-aws-modules/managed-service-prometheus/aws | 3.0.0 |
| <a name="module_cluster_secret_store"></a> [cluster\_secret\_store](#module\_cluster\_secret\_store) | ./modules/addon | n/a |
| <a name="module_downscaler"></a> [downscaler](#module\_downscaler) | tx-pts-dai/downscaler/kubernetes | 0.3.1 |
| <a name="module_ebs_csi_driver_irsa"></a> [ebs\_csi\_driver\_irsa](#module\_ebs\_csi\_driver\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.52.2 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 20.31.6 |
| <a name="module_fluent_operator"></a> [fluent\_operator](#module\_fluent\_operator) | ./modules/addon | n/a |
| <a name="module_grafana"></a> [grafana](#module\_grafana) | ./modules/addon | n/a |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | 20.31.6 |
| <a name="module_karpenter_crds"></a> [karpenter\_crds](#module\_karpenter\_crds) | ./modules/addon | n/a |
| <a name="module_karpenter_release"></a> [karpenter\_release](#module\_karpenter\_release) | ./modules/addon | n/a |
| <a name="module_karpenter_security_group"></a> [karpenter\_security\_group](#module\_karpenter\_security\_group) | ./modules/security-group | n/a |
| <a name="module_network"></a> [network](#module\_network) | ./modules/network | n/a |
| <a name="module_okta_secrets"></a> [okta\_secrets](#module\_okta\_secrets) | ./modules/addon | n/a |
| <a name="module_pagerduty_secrets"></a> [pagerduty\_secrets](#module\_pagerduty\_secrets) | ./modules/addon | n/a |
| <a name="module_prometheus_irsa"></a> [prometheus\_irsa](#module\_prometheus\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.52.2 |
| <a name="module_prometheus_operator_crds"></a> [prometheus\_operator\_crds](#module\_prometheus\_operator\_crds) | ./modules/addon | n/a |
| <a name="module_prometheus_stack"></a> [prometheus\_stack](#module\_prometheus\_stack) | ./modules/addon | n/a |
| <a name="module_reloader"></a> [reloader](#module\_reloader) | ./modules/addon | n/a |
| <a name="module_slack_secrets"></a> [slack\_secrets](#module\_slack\_secrets) | ./modules/addon | n/a |
| <a name="module_ssm"></a> [ssm](#module\_ssm) | ./modules/ssm | n/a |
| <a name="module_vpc_cni_irsa"></a> [vpc\_cni\_irsa](#module\_vpc\_cni\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks | 5.52.2 |

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_policy.fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_route_table_association.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group_rule.eks_control_plane_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_subnet.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [kubernetes_annotations.monitoring](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/annotations) | resource |
| [time_sleep.wait_on_destroy](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [time_static.timestamp_id](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/static) | resource |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_iam_policy_document.fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_roles.iam_cluster_admins](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_iam_roles.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.base_domain_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_route_tables.private_route_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate"></a> [acm\_certificate](#input\_acm\_certificate) | ACM certificate configuration. If wildcard\_certificates is true, all domains will include a wildcard prefix. | <pre>object({<br/>    domain_name               = optional(string) # Overrides base_domain<br/>    subject_alternative_names = optional(list(string), [])<br/>    wildcard_certificates     = optional(bool, false)<br/>    wait_for_validation       = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_aws_load_balancer_controller"></a> [aws\_load\_balancer\_controller](#input\_aws\_load\_balancer\_controller) | AWS Load Balancer Controller configurations | `any` | `{}` | no |
| <a name="input_base_domain"></a> [base\_domain](#input\_base\_domain) | Base domain for the platform, used for ingress and ACM certificates | `string` | `"test"` | no |
| <a name="input_cert_manager"></a> [cert\_manager](#input\_cert\_manager) | Cert Manager configurations | `any` | `{}` | no |
| <a name="input_cluster_admins"></a> [cluster\_admins](#input\_cluster\_admins) | Map of IAM roles to add as cluster admins. Only exact matching role names are returned | <pre>map(object({<br/>    role_name         = string<br/>    kubernetes_groups = optional(list(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_create_addons"></a> [create\_addons](#input\_create\_addons) | Create the platform addons. if set to false, no addons will be created | `bool` | `true` | no |
| <a name="input_downscaler"></a> [downscaler](#input\_downscaler) | Downscaler configurations | `any` | `{}` | no |
| <a name="input_eks"></a> [eks](#input\_eks) | Map of EKS configurations | `any` | `{}` | no |
| <a name="input_enable_acm_certificate"></a> [enable\_acm\_certificate](#input\_enable\_acm\_certificate) | Enable ACM certificate | `bool` | `false` | no |
| <a name="input_enable_amp"></a> [enable\_amp](#input\_enable\_amp) | Enable AWS Managed Prometheus | `bool` | `false` | no |
| <a name="input_enable_aws_load_balancer_controller"></a> [enable\_aws\_load\_balancer\_controller](#input\_enable\_aws\_load\_balancer\_controller) | Enable AWS Load Balancer Controller | `bool` | `true` | no |
| <a name="input_enable_cert_manager"></a> [enable\_cert\_manager](#input\_enable\_cert\_manager) | Enable Cert Manager | `bool` | `false` | no |
| <a name="input_enable_downscaler"></a> [enable\_downscaler](#input\_enable\_downscaler) | Enable Downscaler | `bool` | `false` | no |
| <a name="input_enable_external_dns"></a> [enable\_external\_dns](#input\_enable\_external\_dns) | Enable External DNS | `bool` | `true` | no |
| <a name="input_enable_external_secrets"></a> [enable\_external\_secrets](#input\_enable\_external\_secrets) | Enable External Secrets | `bool` | `true` | no |
| <a name="input_enable_fargate_fluentbit"></a> [enable\_fargate\_fluentbit](#input\_enable\_fargate\_fluentbit) | Enable Fargate Fluentbit | `bool` | `true` | no |
| <a name="input_enable_fluent_operator"></a> [enable\_fluent\_operator](#input\_enable\_fluent\_operator) | Enable fluent operator | `bool` | `true` | no |
| <a name="input_enable_grafana"></a> [enable\_grafana](#input\_enable\_grafana) | Enable Grafana | `bool` | `true` | no |
| <a name="input_enable_ingress_nginx"></a> [enable\_ingress\_nginx](#input\_enable\_ingress\_nginx) | Enable Ingress Nginx | `bool` | `false` | no |
| <a name="input_enable_metrics_server"></a> [enable\_metrics\_server](#input\_enable\_metrics\_server) | Enable Metrics Server | `bool` | `true` | no |
| <a name="input_enable_okta"></a> [enable\_okta](#input\_enable\_okta) | Enable Okta integration | `bool` | `false` | no |
| <a name="input_enable_pagerduty"></a> [enable\_pagerduty](#input\_enable\_pagerduty) | Enable PagerDuty integration | `bool` | `false` | no |
| <a name="input_enable_prometheus_stack"></a> [enable\_prometheus\_stack](#input\_enable\_prometheus\_stack) | Enable Prometheus stack | `bool` | `true` | no |
| <a name="input_enable_reloader"></a> [enable\_reloader](#input\_enable\_reloader) | Enable Reloader | `bool` | `true` | no |
| <a name="input_enable_slack"></a> [enable\_slack](#input\_enable\_slack) | Enable Slack integration | `bool` | `false` | no |
| <a name="input_external_dns"></a> [external\_dns](#input\_external\_dns) | External DNS configurations | `any` | `{}` | no |
| <a name="input_external_secrets"></a> [external\_secrets](#input\_external\_secrets) | External Secrets configurations | `any` | `{}` | no |
| <a name="input_fargate_fluentbit"></a> [fargate\_fluentbit](#input\_fargate\_fluentbit) | Fargate Fluentbit configurations | `any` | `{}` | no |
| <a name="input_fluent_cloudwatch_retention_in_days"></a> [fluent\_cloudwatch\_retention\_in\_days](#input\_fluent\_cloudwatch\_retention\_in\_days) | Number of days to keep logs in cloudwatch | `string` | `"7"` | no |
| <a name="input_fluent_log_annotation"></a> [fluent\_log\_annotation](#input\_fluent\_log\_annotation) | Pod Annotation required to enable fluent bit logging. Setting name to empty string will disable annotation requirement. | <pre>object({<br/>    name  = optional(string, "fluentbit.io/include")<br/>    value = optional(string, "true")<br/>  })</pre> | `{}` | no |
| <a name="input_fluent_operator"></a> [fluent\_operator](#input\_fluent\_operator) | Fluent configurations | `any` | `{}` | no |
| <a name="input_grafana"></a> [grafana](#input\_grafana) | Grafana configurations, used to override default configurations | `any` | `{}` | no |
| <a name="input_ingress_nginx"></a> [ingress\_nginx](#input\_ingress\_nginx) | Ingress Nginx configurations | `any` | `{}` | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Karpenter configurations | `any` | `{}` | no |
| <a name="input_metadata"></a> [metadata](#input\_metadata) | Metadata for the platform | <pre>object({<br/>    environment = optional(string, "")<br/>    team        = optional(string, "")<br/>  })</pre> | `{}` | no |
| <a name="input_metrics_server"></a> [metrics\_server](#input\_metrics\_server) | Metrics Server configurations | `any` | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the platform, a timestamp will be appended to this name to make the stack\_name. If not provided, the name of the directory will be used. | `string` | `""` | no |
| <a name="input_okta"></a> [okta](#input\_okta) | Okta configurations | <pre>object({<br/>    base_url                    = optional(string, "")<br/>    secrets_manager_secret_name = optional(string, "")<br/>    kubernetes_secret_name      = optional(string, "okta")<br/>  })</pre> | `{}` | no |
| <a name="input_pagerduty"></a> [pagerduty](#input\_pagerduty) | PagerDuty configurations | <pre>object({<br/>    secrets_manager_secret_name = optional(string, "")<br/>    kubernetes_secret_name      = optional(string, "pagerduty")<br/>  })</pre> | `{}` | no |
| <a name="input_prometheus_stack"></a> [prometheus\_stack](#input\_prometheus\_stack) | Prometheus stack configurations | `any` | `{}` | no |
| <a name="input_reloader"></a> [reloader](#input\_reloader) | Reloader configurations | `any` | `{}` | no |
| <a name="input_slack"></a> [slack](#input\_slack) | Slack configurations | <pre>object({<br/>    secrets_manager_secret_name = optional(string, "")<br/>    kubernetes_secret_name      = optional(string, "slack")<br/>  })</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | Map of VPC configurations | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_eks"></a> [eks](#output\_eks) | Map of attributes for the EKS cluster |
| <a name="output_karpenter"></a> [karpenter](#output\_karpenter) | Map of attributes for the Karpenter module |
| <a name="output_network"></a> [network](#output\_network) | Map of attributes for the VPC module |
<!-- END_TF_DOCS -->

## Authors

Module is maintained by [Alfredo Gottardo](https://github.com/AlfGot), [David Beauvererd](https://github.com/Davidoutz), [Davide Cammarata](https://github.com/DCamma), [Demetrio Carrara](https://github.com/sgametrio), [Roland Bapst](https://github.com/rbapst-tamedia) and [Samuel Wibrow](https://github.com/swibrow)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
