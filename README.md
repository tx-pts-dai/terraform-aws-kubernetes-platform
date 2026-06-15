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

## Upgrading Kubernetes Version

The Kubernetes version is configured via the `kubernetes_version` variable. The default version is updated with each module release.

To upgrade your cluster to a new Kubernetes version:

```hcl
module "k8s_platform" {
  source = "tx-pts-dai/kubernetes-platform/aws"

  kubernetes_version = "1.34"

  # ... other configuration
}
```

**Important**: Do not skip Kubernetes minor versions during upgrades. For example, upgrade from 1.32 → 1.33 → 1.34, not directly from 1.32 → 1.34.


## Explanation and description of interesting use-cases

Why this module?

- To provide an AWS account with a K8s cluster with batteries included so that you can start deploying your workloads on a well-built foundation
- To encourage standardization and common practices
- To ease maintenance

## EKS Auto Mode

The module can provision the cluster in [EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
instead of (or alongside) the self-managed Karpenter / EBS CSI / AWS Load Balancer
Controller stack. Set `enable_auto_mode = true` and, optionally, pass your own
NodePool and NodeClass via `auto_mode_node_pools` / `auto_mode_node_classes` (the
module injects the Auto Mode node IAM role automatically). Auto Mode is **opt-in**
and defaults to `false`, so existing clusters are unaffected.

`enable_auto_mode` and `enable_karpenter` (default `true`) are **independent**: keep
both enabled to run the two compute stacks side-by-side for a gradual migration. At
least one must be enabled or the cluster has no compute.

See the [Auto Mode migration guide](./docs/auto-mode-migration.md) for details,
including how to migrate the ALB controller that is deployed via ArgoCD today.

## Argo CD

Three mutually-exclusive options are available:

1. **None** (default) — no Argo CD.
2. **Self-managed** (`enable_argocd = true`) — creates the hub/spoke IAM roles and
   pod-identity associations for an Argo CD that you deploy via GitOps.
3. **AWS-managed capability** (`enable_argocd_capability = true`) — provisions the
   [Argo CD EKS capability](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html).
   The managed server is **publicly accessible by default** (set
   `argocd_capability.vpce_ids` to restrict it to VPC endpoints) and requires IAM
   Identity Center for authentication. The Identity Center instance ARN is
   auto-discovered (needs `sso:ListInstances`) or can be set explicitly via
   `argocd_capability.idc_instance_arn`. The server URL is exposed as the
   `argocd_capability_server_url` output.

   ```hcl
   enable_argocd_capability = true
   argocd_capability = {
     rbac_role_mapping = [{
       role     = "ADMIN"
       identity = [{ id = "<idc-group-id>", type = "SSO_GROUP" }]
     }]
   }
   ```

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
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.28 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | >= 3.0.2 |
| <a name="requirement_kubectl"></a> [kubectl](#requirement\_kubectl) | >= 2.0.2 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | >= 2.27 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.11 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.28 |
| <a name="provider_helm"></a> [helm](#provider\_helm) | >= 3.0.2 |
| <a name="provider_kubernetes"></a> [kubernetes](#provider\_kubernetes) | >= 2.27 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.11 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_ack_capability"></a> [ack\_capability](#module\_ack\_capability) | terraform-aws-modules/eks/aws//modules/capability | 21.15.1 |
| <a name="module_acm"></a> [acm](#module\_acm) | terraform-aws-modules/acm/aws | 6.3.0 |
| <a name="module_argocd"></a> [argocd](#module\_argocd) | ./modules/argocd | n/a |
| <a name="module_argocd_capability"></a> [argocd\_capability](#module\_argocd\_capability) | terraform-aws-modules/eks/aws//modules/capability | 21.15.1 |
| <a name="module_aws_ebs_csi_pod_identity"></a> [aws\_ebs\_csi\_pod\_identity](#module\_aws\_ebs\_csi\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.1 |
| <a name="module_aws_gateway_controller_pod_identity"></a> [aws\_gateway\_controller\_pod\_identity](#module\_aws\_gateway\_controller\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.1 |
| <a name="module_aws_lb_controller_pod_identity"></a> [aws\_lb\_controller\_pod\_identity](#module\_aws\_lb\_controller\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.1 |
| <a name="module_aws_vpc_cni_pod_identity"></a> [aws\_vpc\_cni\_pod\_identity](#module\_aws\_vpc\_cni\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.1 |
| <a name="module_ebs_csi_driver_irsa"></a> [ebs\_csi\_driver\_irsa](#module\_ebs\_csi\_driver\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts | 6.6.1 |
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | 21.15.1 |
| <a name="module_eks_addons"></a> [eks\_addons](#module\_eks\_addons) | ./modules/eks-addons | n/a |
| <a name="module_external_dns_pod_identity"></a> [external\_dns\_pod\_identity](#module\_external\_dns\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.1 |
| <a name="module_external_secrets_pod_identity"></a> [external\_secrets\_pod\_identity](#module\_external\_secrets\_pod\_identity) | terraform-aws-modules/eks-pod-identity/aws | 2.8.1 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | 21.15.1 |
| <a name="module_karpenter_irsa"></a> [karpenter\_irsa](#module\_karpenter\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts | 6.6.1 |
| <a name="module_karpenter_security_group"></a> [karpenter\_security\_group](#module\_karpenter\_security\_group) | ./modules/security-group | n/a |
| <a name="module_ssm"></a> [ssm](#module\_ssm) | ./modules/ssm | n/a |
| <a name="module_vpc_cni_irsa"></a> [vpc\_cni\_irsa](#module\_vpc\_cni\_irsa) | terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts | 6.6.1 |

## Resources

| Name | Type |
| ---- | ---- |
| [aws_cloudwatch_log_group.fargate_fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_eks_access_entry.auto_mode_node](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_entry.k8s_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_entry) | resource |
| [aws_eks_access_policy_association.k8s_access_custom](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_eks_access_policy_association.k8s_access_predefined](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_access_policy_association) | resource |
| [aws_iam_policy.ecr_passthrough](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.fargate_fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_policy.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.k8s_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.k8s_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_route_table_association.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_security_group_rule.eks_control_plane_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group_rule) | resource |
| [aws_subnet.karpenter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [helm_release.auto_mode_node_class](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
| [helm_release.auto_mode_node_pool](https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release) | resource |
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
| [aws_iam_policy_document.ecr_passthrough](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.fargate_fluentbit](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.k8s_access_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.k8s_access_permissions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.karpenter_controller](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_roles.sso](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_roles) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_route53_zone.base_domain_zone](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route53_zone) | data source |
| [aws_route_tables.private_route_tables](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/route_tables) | data source |
| [aws_ssoadmin_instances.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssoadmin_instances) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_entries"></a> [access\_entries](#input\_access\_entries) | Additional EKS access entries, passed through to the underlying EKS module and<br/>merged with the admin entries derived from cluster\_admins / SSO discovery.<br/><br/>Use this for non-admin principals — e.g. roles mapped to custom Kubernetes<br/>groups (read-only, operator) — which cluster\_admins cannot express because it<br/>always attaches the AmazonEKSClusterAdminPolicy. Keys must not collide with<br/>cluster\_admins keys or the reserved "sso\_admin" key; on any collision the<br/>admin entry wins.<br/><br/>Typed as `any` to accept the full EKS module access\_entries schema (nested<br/>policy\_associations etc.), but it must be a map. Each entry, e.g.:<br/>  access\_entries = {<br/>    readonly = {<br/>      principal\_arn     = "arn:aws:iam::123456789012:role/AWSReservedSSO\_ReadOnly\_abc"<br/>      kubernetes\_groups = ["readonly"]<br/>    }<br/>  } | `any` | `{}` | no |
| <a name="input_ack_iam_policy_arn"></a> [ack\_iam\_policy\_arn](#input\_ack\_iam\_policy\_arn) | IAM policy ARN to attach to the ACK capability role. Defaults to AdministratorAccess if not specified. | `string` | `null` | no |
| <a name="input_acm_certificate"></a> [acm\_certificate](#input\_acm\_certificate) | ACM certificate configuration for the domain(s). Controls domain name, alternative domain names, wildcard configuration, and validation behavior.<br/>Options include:<br/>  - domain\_name: Primary domain name for the certificate. If not provided, uses base\_domain from other configuration.<br/>  - subject\_alternative\_names: List of additional domain names to include in the certificate.<br/>  - wildcard\_certificates: When true, adds a wildcard prefix (*.) to all domains in the certificate.<br/>  - prepend\_stack\_id: When true, prepends the stack identifier to each domain name. Only works after random\_string is created.<br/>  - wait\_for\_validation: When true, Terraform will wait for certificate validation to complete before proceeding. | <pre>object({<br/>    domain_name               = optional(string)<br/>    subject_alternative_names = optional(list(string), [])<br/>    wildcard_certificates     = optional(bool, false)<br/>    prepend_stack_id          = optional(bool, false)<br/>    wait_for_validation       = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_argocd"></a> [argocd](#input\_argocd) | Argo CD configurations | <pre>object({<br/>    # Hub specific<br/>    enable_hub        = optional(bool, false)<br/>    namespace         = optional(string, "argocd")<br/>    hub_iam_role_name = optional(string, "argocd-controller")<br/><br/>    # Spoke specific<br/>    enable_spoke = optional(bool, false)<br/><br/>    hub_iam_role_arn  = optional(string, null)<br/>    hub_iam_role_arns = optional(list(string), null)<br/><br/>    # Common<br/>    tags = optional(map(string), {})<br/>  })</pre> | `{}` | no |
| <a name="input_argocd_capability"></a> [argocd\_capability](#input\_argocd\_capability) | Configuration for the AWS-managed Argo CD EKS capability. Only used when `enable_argocd_capability = true`.<br/>  - idc\_instance\_arn: IAM Identity Center instance ARN. Leave null to auto-discover the account/org instance via the aws\_ssoadmin\_instances data source (requires sso:ListInstances).<br/>  - idc\_region: Region of the Identity Center instance (defaults to the provider region).<br/>  - namespace: Kubernetes namespace for Argo CD (default "argocd").<br/>  - rbac\_role\_mapping: Maps Identity Center users/groups to Argo CD roles (ADMIN, EDITOR, VIEWER).<br/>  - vpce\_ids: VPC endpoint IDs for private access. When set, the public endpoint is BLOCKED and Argo CD is reachable only through these VPC endpoints. Leave empty for a public endpoint.<br/>  - iam\_policy\_statements: Extra IAM policy statements to attach to the capability role (e.g. ECR read for image reflection). | <pre>object({<br/>    idc_instance_arn = optional(string)<br/>    idc_region       = optional(string)<br/>    namespace        = optional(string, "argocd")<br/>    rbac_role_mapping = optional(list(object({<br/>      role = string<br/>      identity = list(object({<br/>        id   = string<br/>        type = string<br/>      }))<br/>    })), [])<br/>    vpce_ids = optional(list(string), [])<br/>    iam_policy_statements = optional(map(object({<br/>      sid       = optional(string)<br/>      actions   = optional(list(string))<br/>      resources = optional(list(string))<br/>      effect    = optional(string)<br/>    })), {})<br/>  })</pre> | `{}` | no |
| <a name="input_auto_mode"></a> [auto\_mode](#input\_auto\_mode) | EKS Auto Mode configuration. Only used when `enable_auto_mode = true`.<br/>  - builtin\_node\_pools: List of AWS-managed node pools to enable (e.g. ["general-purpose", "system"]). Leave empty ([]) to only use your own NodePools/NodeClasses.<br/>  - node\_iam\_role\_additional\_policies: Additional IAM policy ARNs to attach to the Auto Mode node role, keyed by an arbitrary name.<br/>  - default\_node\_pool\_taints: Taints applied to the auto-generated `default` NodePool (ignored when you pass your own auto\_mode\_node\_pools). Use this during a migration so existing workloads do not schedule onto Auto Mode nodes until they tolerate the taint.<br/>  - discover\_karpenter\_subnets: Controls how the auto-generated `default` NodeClass finds subnets. When true, it discovers them by tag (see subnet\_discovery\_tags) — by default the SAME dedicated subnets as the self-managed Karpenter stack (the "same network, different NodePools/taints" migration path). When false, it selects var.vpc.private\_subnets by ID. Defaults to null, which resolves to enable\_karpenter: shared subnets while the Karpenter stack runs, private subnets in pure Auto Mode. Ignored when you pass your own auto\_mode\_node\_classes.<br/>  - subnet\_discovery\_tags: Tags the `default` NodeClass matches when discover\_karpenter\_subnets is true. Defaults to { "karpenter.sh/discovery" = <cluster-name> } (the tag the module puts on its own dedicated Karpenter subnets). Override it to match a customized Karpenter discovery tag — e.g. { "karpenter.sh/discovery" = "shared" } when Karpenter is pointed at pre-existing subnets via karpenter\_resources\_helm\_set. | <pre>object({<br/>    builtin_node_pools                = optional(list(string), [])<br/>    node_iam_role_additional_policies = optional(map(string), {})<br/>    default_node_pool_taints = optional(list(object({<br/>      key    = string<br/>      value  = optional(string)<br/>      effect = string<br/>    })), [])<br/>    discover_karpenter_subnets = optional(bool, null)<br/>    subnet_discovery_tags      = optional(map(string), null)<br/>  })</pre> | `{}` | no |
| <a name="input_auto_mode_node_classes"></a> [auto\_mode\_node\_classes](#input\_auto\_mode\_node\_classes) | Map of EKS Auto Mode NodeClass resources to apply (apiVersion `eks.amazonaws.com/v1`). The map key is the NodeClass name and the value is its `spec`.<br/>Only used when `enable_auto_mode = true`. When left empty, a `default` NodeClass is created that targets the cluster private subnets and primary security group and uses the Auto Mode node IAM role. | `any` | `{}` | no |
| <a name="input_auto_mode_node_pools"></a> [auto\_mode\_node\_pools](#input\_auto\_mode\_node\_pools) | Map of Karpenter NodePool resources to apply (apiVersion `karpenter.sh/v1`). The map key is the NodePool name and the value is its `spec`.<br/>Only used when `enable_auto_mode = true`. When left empty, a `default` NodePool referencing the `default` NodeClass is created. | `any` | `{}` | no |
| <a name="input_base_domain"></a> [base\_domain](#input\_base\_domain) | Base domain for the platform, used for ingress and ACM certificates | `string` | `null` | no |
| <a name="input_cluster_admins"></a> [cluster\_admins](#input\_cluster\_admins) | Map of IAM roles to add as cluster admins<br/>  role\_arn: ARN of the IAM role to add as cluster admin<br/>  role\_name: Name of the IAM role to add as cluster admin<br/>  kubernetes\_groups: List of Kubernetes groups to add the role to (default: ["system:masters"])<br/><br/>role\_arn and role\_name are mutually exclusive, exactly one must be set. | <pre>map(object({<br/>    role_arn          = optional(string)<br/>    role_name         = optional(string)<br/>    kubernetes_groups = optional(list(string))<br/>  }))</pre> | `{}` | no |
| <a name="input_create_addon_pod_identity_roles"></a> [create\_addon\_pod\_identity\_roles](#input\_create\_addon\_pod\_identity\_roles) | Create addon pod identities roles. If set to true, all roles will be created | `bool` | `true` | no |
| <a name="input_eks"></a> [eks](#input\_eks) | Map of EKS configurations including cluster settings and core addon customization.<br/><br/>Cluster settings:<br/>  - cluster\_endpoint\_public\_access: Enable public access to cluster endpoint (default: true)<br/>  - cluster\_endpoint\_private\_access: Enable private access to cluster endpoint (default: true)<br/>  - enable\_cluster\_creator\_admin\_permissions: Grant admin permissions to cluster creator (default: false)<br/>  - create\_iam\_role: Whether the module creates the cluster IAM role (default: true). Set to false to reuse an existing role, e.g. when adopting an existing cluster.<br/>  - iam\_role\_arn: ARN of an existing cluster IAM role to use when create\_iam\_role is false.<br/><br/>Core addon settings (vpc\_cni, kube\_proxy, eks\_pod\_identity\_agent):<br/>  - configuration\_values: JSON string of addon configuration (merged with defaults for vpc-cni)<br/><br/>Example:<br/>  eks = {<br/>    cluster\_endpoint\_public\_access = false<br/>    vpc\_cni = {<br/>      configuration\_values = jsonencode({<br/>        env = {<br/>          ENABLE\_PREFIX\_DELEGATION = "true"<br/>          WARM\_PREFIX\_TARGET       = "1"<br/>        }<br/>      })<br/>    }<br/>  } | `any` | `{}` | no |
| <a name="input_enable_ack"></a> [enable\_ack](#input\_enable\_ack) | Enable ACK (AWS Controllers for Kubernetes) EKS capability. Note: AdministratorAccess is attached by default. Use ack\_iam\_policy\_arn to override with a least-privilege policy. | `bool` | `true` | no |
| <a name="input_enable_acm_certificate"></a> [enable\_acm\_certificate](#input\_enable\_acm\_certificate) | Enable ACM certificate | `bool` | `false` | no |
| <a name="input_enable_argocd"></a> [enable\_argocd](#input\_enable\_argocd) | Enable Argo CD | `bool` | `false` | no |
| <a name="input_enable_argocd_capability"></a> [enable\_argocd\_capability](#input\_enable\_argocd\_capability) | Enable the AWS-managed Argo CD EKS capability. Mutually exclusive with enable\_argocd (self-managed Argo CD). Requires IAM Identity Center (auto-discovered, or set argocd\_capability.idc\_instance\_arn). | `bool` | `false` | no |
| <a name="input_enable_auto_mode"></a> [enable\_auto\_mode](#input\_enable\_auto\_mode) | Enable EKS Auto Mode. AWS manages compute (built-in Karpenter), block storage, load balancing and core networking. Can be combined with enable\_karpenter to run both compute stacks side-by-side during a migration. | `bool` | `false` | no |
| <a name="input_enable_ecr_passthrough_policy"></a> [enable\_ecr\_passthrough\_policy](#input\_enable\_ecr\_passthrough\_policy) | Enable the ECR pull-through cache policy for cluster nodes. This policy may grant additional ECR permissions, including automatic repository creation for pull-through cache repositories, and is not required for standard ECR image pulls. | `bool` | `false` | no |
| <a name="input_enable_fargate_fluentbit"></a> [enable\_fargate\_fluentbit](#input\_enable\_fargate\_fluentbit) | Enable Fargate Fluentbit | `bool` | `true` | no |
| <a name="input_enable_karpenter"></a> [enable\_karpenter](#input\_enable\_karpenter) | Enable the self-managed Karpenter stack (controller, Helm releases, IRSA, subnets, security group, Fargate profile). Independent of enable\_auto\_mode: keep both enabled to run them side-by-side during a migration. At least one of enable\_karpenter / enable\_auto\_mode must be true or the cluster has no compute. | `bool` | `true` | no |
| <a name="input_enable_self_managed_ebs_csi"></a> [enable\_self\_managed\_ebs\_csi](#input\_enable\_self\_managed\_ebs\_csi) | Create the self-managed EBS CSI driver (addon, IRSA and pod-identity role). Defaults to enabled unless Auto Mode is on. Set to true to keep it running alongside Auto Mode's managed EBS CSI during a storage migration, or false to drop it. | `bool` | `null` | no |
| <a name="input_enable_self_managed_lb_controller"></a> [enable\_self\_managed\_lb\_controller](#input\_enable\_self\_managed\_lb\_controller) | Create the IAM pod-identity role for the self-managed AWS Load Balancer Controller. Defaults to enabled unless Auto Mode is on. Set to true to keep it alongside Auto Mode's built-in load balancing during a migration, or false to drop it. | `bool` | `null` | no |
| <a name="input_enable_sso_admin_auto_discovery"></a> [enable\_sso\_admin\_auto\_discovery](#input\_enable\_sso\_admin\_auto\_discovery) | Enable automatic discovery of SSO admin roles. When disabled, only explicitly defined cluster\_admins are used. | `bool` | `true` | no |
| <a name="input_enable_timestamp_id"></a> [enable\_timestamp\_id](#input\_enable\_timestamp\_id) | Disable the timestamp-based ID generation. When true, uses a static ID instead of timestamp. | `bool` | `true` | no |
| <a name="input_extra_cluster_addons"></a> [extra\_cluster\_addons](#input\_extra\_cluster\_addons) | Map of cluster addon configurations to enable for the cluster. Addon name can be the map keys or set with `name`. Addons are created after karpenter resources | `any` | `{}` | no |
| <a name="input_extra_cluster_addons_timeouts"></a> [extra\_cluster\_addons\_timeouts](#input\_extra\_cluster\_addons\_timeouts) | Create, update, and delete timeout configurations for the cluster addons | `map(string)` | `{}` | no |
| <a name="input_karpenter"></a> [karpenter](#input\_karpenter) | Karpenter configurations | <pre>object({<br/>    subnet_cidrs = optional(list(string), [])<br/>  })</pre> | `{}` | no |
| <a name="input_karpenter_helm_set"></a> [karpenter\_helm\_set](#input\_karpenter\_helm\_set) | List of Karpenter Helm set values | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_karpenter_helm_values"></a> [karpenter\_helm\_values](#input\_karpenter\_helm\_values) | List of Karpenter Helm values | `list(string)` | `[]` | no |
| <a name="input_karpenter_resources_helm_set"></a> [karpenter\_resources\_helm\_set](#input\_karpenter\_resources\_helm\_set) | List of Karpenter Resources Helm set values | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_karpenter_resources_helm_values"></a> [karpenter\_resources\_helm\_values](#input\_karpenter\_resources\_helm\_values) | List of Karpenter Resources Helm values | `list(string)` | `[]` | no |
| <a name="input_kubernetes_access_roles"></a> [kubernetes\_access\_roles](#input\_kubernetes\_access\_roles) | Map of reusable IAM roles that can be assumed by multiple principals.<br/>Creates standard roles that grant different levels of Kubernetes access.<br/><br/>Supported predefined access\_level values:<br/>- "view"         -> AmazonEKSViewPolicy (read-only)<br/>- "edit"         -> AmazonEKSEditPolicy (create/update resources)<br/>- "admin"        -> AmazonEKSClusterAdminPolicy (full admin)<br/>- "custom"       -> Use custom\_policy\_arns (list of policy ARNs)<br/><br/>Example:<br/>{<br/>  "readonly" = {<br/>    controller\_iam\_role\_arns = [<br/>      "arn:aws:iam::123456789012:role/backstage-prod",<br/>      "arn:aws:iam::123456789012:role/ai-agent"<br/>    ]<br/>    access\_level = "view"           # Predefined: view, edit, admin, or custom<br/>    scope        = "cluster"        # "cluster" or "namespace"<br/>    namespaces   = []               # required if scope = "namespace"<br/>  }<br/>  "developer" = {<br/>    controller\_iam\_role\_arns = ["arn:aws:iam::123456789012:role/dev-team"]<br/>    access\_level = "edit"<br/>    scope        = "namespace"<br/>    namespaces   = ["development", "staging"]<br/>  }<br/>  "ops-admin" = {<br/>    controller\_iam\_role\_arns = ["arn:aws:iam::123456789012:role/ops-team"]<br/>    access\_level = "admin"<br/>    scope        = "cluster"<br/>  }<br/>  "custom-access" = {<br/>    controller\_iam\_role\_arns = ["arn:aws:iam::123456789012:role/special-service"]<br/>    access\_level = "custom"<br/>    custom\_policy\_arns = [<br/>      "arn:aws:eks::aws:cluster-access-policy/MyCustomPolicy"<br/>    ]<br/>    scope = "cluster"<br/>  }<br/>}<br/><br/>This creates:<br/>- {cluster}-k8s-readonly (view access)<br/>- {cluster}-k8s-developer (edit access on dev/staging namespaces)<br/>- {cluster}-k8s-ops-admin (full admin access)<br/>- {cluster}-k8s-custom-access (custom policies) | <pre>map(object({<br/>    controller_iam_role_arns = list(string)<br/>    access_level             = string # "view", "edit", "admin", or "custom"<br/>    scope                    = string # "cluster" or "namespace"<br/>    namespaces               = optional(list(string), [])<br/>    custom_policy_arns       = optional(list(string), [])<br/>    external_id              = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Kubernetes version for the EKS cluster (e.g., "1.34") | `string` | `"1.34"` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the platform, a timestamp will be appended to this name to make the stack\_name. If not provided, the name of the directory will be used. | `string` | `""` | no |
| <a name="input_region"></a> [region](#input\_region) | AWS region to use | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Default tags to apply to all resources | `map(string)` | `{}` | no |
| <a name="input_vpc"></a> [vpc](#input\_vpc) | VPC configurations | <pre>object({<br/>    vpc_id          = string<br/>    vpc_cidr        = string<br/>    private_subnets = list(string)<br/>    intra_subnets   = list(string)<br/>  })</pre> | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_ack"></a> [ack](#output\_ack) | Map of attributes for the ACK EKS capability |
| <a name="output_argocd"></a> [argocd](#output\_argocd) | Map of attributes for the self-managed ArgoCD module |
| <a name="output_argocd_capability"></a> [argocd\_capability](#output\_argocd\_capability) | Map of attributes for the AWS-managed ArgoCD EKS capability (empty when disabled) |
| <a name="output_argocd_capability_server_url"></a> [argocd\_capability\_server\_url](#output\_argocd\_capability\_server\_url) | URL of the AWS-managed ArgoCD server (null when the capability is disabled) |
| <a name="output_auto_mode_node_iam_role_arn"></a> [auto\_mode\_node\_iam\_role\_arn](#output\_auto\_mode\_node\_iam\_role\_arn) | ARN of the EKS Auto Mode node IAM role (null when Auto Mode is disabled). Reference this from custom NodeClasses. |
| <a name="output_auto_mode_node_iam_role_name"></a> [auto\_mode\_node\_iam\_role\_name](#output\_auto\_mode\_node\_iam\_role\_name) | Name of the EKS Auto Mode node IAM role (null when Auto Mode is disabled). |
| <a name="output_eks"></a> [eks](#output\_eks) | Map of attributes for the EKS cluster |
| <a name="output_karpenter"></a> [karpenter](#output\_karpenter) | Map of attributes for the self-managed Karpenter module (empty when enable\_karpenter is false) |
| <a name="output_kubernetes_access_role_arns"></a> [kubernetes\_access\_role\_arns](#output\_kubernetes\_access\_role\_arns) | Map of reusable Kubernetes access role names to their IAM role ARNs |
| <a name="output_kubernetes_access_roles"></a> [kubernetes\_access\_roles](#output\_kubernetes\_access\_roles) | Detailed information about reusable Kubernetes access IAM roles |
<!-- END_TF_DOCS -->

## Authors

Module is maintained by [Alfredo Gottardo](https://github.com/AlfGot), [David Beauvererd](https://github.com/Davidoutz), [Davide Cammarata](https://github.com/DCamma), [Francisco Ferreira](https://github.com/cferrera),  [Roland Bapst](https://github.com/rbapst-tamedia) and [Samuel Wibrow](https://github.com/swibrow)

## License

Apache 2 Licensed. See [LICENSE](LICENSE) for full details.
