# Changelog

All notable changes to this project will be documented in this file.

## [6.6.2](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/compare/v6.6.1...v6.6.2) (2025-12-09)

### Bug Fixes

* **argocd:** use static cluster name to prevent dependency issues ([#263](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/issues/263)) ([b356f5f](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/commit/b356f5fc0331c1432b0730f3e5fae320d5916629))

## [6.6.1](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/compare/v6.6.0+1.33...v6.6.1) (2025-12-03)

### Bug Fixes

* allow custom settings for default addons ([#260](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/issues/260)) ([315aa1d](https://github.com/tx-pts-dai/terraform-aws-kubernetes-platform/commit/315aa1df2f9fb70fb1e3f025ec6f28be30a318fa))

# v6.0.0

**Breaking Changes:**

- **Helm Provider Version**: The Helm provider version has been updated to `3.0.2`.
- **Addons Module Removed**: The entire addons module has been removed. All Kubernetes addons must now be installed and managed externally.
- **Simplified Examples**: Removed `simple` and `disable-addons` examples as they are no longer relevant with the addons module removal.

# v5.0.0

**Breaking Changes:**

- **Addons Module Disabled**: Kubernetes resources have been disabled and will be uninstalled. They're required to be installed externally. IRAS Roles will be removed in the next major version.
- **Reloader Module Removed**: The Reloader module has been removed. It's required to be installed externally.
- **Downscaler Module Removed**: The Downscaler module has been removed. It's required to be installed externally.
- **Metrics Server Removed**: The Metrics Server has been removed. It's required to be installed externally.

**Features:**

- Pod Identity Roles enabled by default
- EKS Addons submodule added to support managed addons after Karpenter Resources have been created

# v4.0.0

**Breaking Changes:**

- **AWS Provider Version**: The AWS provider version has been updated to `6.9.0`

# v3.0.0

**Breaking Changes:**

- **VPC Configuration Structure**: The `vpc` variable type has been changed from `any` to a typed object with specific fields:
  ```hcl
  vpc = {
    vpc_id          = optional(string)
    vpc_cidr        = optional(string)
    private_subnets = optional(list(string))
    intra_subnets   = optional(list(string))
  }
  ```

- **Network Module Integration**: The network module has been refactored with cleaner separation of concerns
  - VPC provisioning is now controlled by the `create_vpc` variable in the network module
  - When using an existing VPC, pass configuration through the `vpc` variable only
  - Removed complex VPC lookup logic from main.tf

- **Karpenter Configuration Simplified**: The `karpenter` variable now only contains `subnet_cidrs`
  ```hcl
  karpenter = {
    subnet_cidrs = optional(list(string), [])
  }
  ```

- **IAM Role Name Changes**: Shortened IAM role names to prevent AWS character limit issues
  - AWS Load Balancer Controller role prefix: `aws-load-balancer-controller-` → `lb-controller-`

**New Features:**

- **Timestamp ID Control**: Added `enable_timestamp_id` variable (default: `true`)
  - Set to `false` to disable timestamp-based ID generation for predictable resource naming
  - When disabled, `stack_name` equals `name` without timestamp suffix

- **SSO Admin Auto-Discovery Control**: Added `enable_sso_admin_auto_discovery` variable (default: `true`)
  - Controls automatic discovery of AWS SSO admin roles
  - When `false`, only explicitly defined `cluster_admins` are used
  - Ensures consistent behavior between CI and local environments

**Bug Fixes:**

- **SSM Module**: Fixed duplicate object key errors in parameter lookup
  - Added ellipsis operator to handle multiple parameters with same names
- **Karpenter Dependencies**: Fixed dependency chain for proper resource creation order
  - Added explicit dependency on `karpenter_crd` in karpenter release

**Migration Guide:**

Update VPC configuration:
```hcl
# Old
vpc = {
  enabled = true
  vpc_id = "vpc-123"
  # ... other complex fields
}

# New
vpc = {
  vpc_id          = "vpc-123"
  vpc_cidr        = "10.0.0.0/16"
  private_subnets = ["subnet-1", "subnet-2"]
  intra_subnets   = ["subnet-3", "subnet-4"]
}
```

Control timestamp generation:
```hcl
# Disable for predictable naming
enable_timestamp_id = false
```

Control SSO discovery:
```hcl
# Disable auto-discovery in CI
enable_sso_admin_auto_discovery = false
cluster_admins = {
  cicd = {
    role_name = "cicd-iac"
  }
}
```

# v2.2.0+1.32.0

**Breaking Changes:**

- Karpenter helm release and Karpenter Resources inputs have been moved to dedicated variables.

```yaml
karpenter_helm_values = [
  <<-EOT
  replicas: 1
  EOT
]

karpenter_helm_set = [
  {
    name = "replicas"
    value = 1
  }
]

karpenter_resources_helm_values = [
  <<-EOT
  ec2NodeClasses:
    blockDeviceMappings:
      - deviceName: /dev/xvda
        ebs:
          volumeSize: 80Gi
          volumeType: gp3
          encrypted: true
  EOT
]

karpenter_resources_helm_set = [
  {
    name = "ec2NodeClasses.blockDeviceMappings[0].deviceName"
    value = "/dev/xvda"
  },
  {
    name = "ec2NodeClasses.blockDeviceMappings[0].ebs.volumeSize"
    value = 80
  },
  {
    name = "ec2NodeClasses.blockDeviceMappings[0].ebs.volumeType"
    value = "gp3"
  },
  {
    name = "ec2NodeClasses.blockDeviceMappings[0].ebs.encrypted"
    value = true
  }
]
```

- ArgoCD variable type changed from any to object.

```hcl
variable "argocd" {
  description = "Argo CD configurations"
  type = object({
    # Hub specific
    enable_hub        = optional(bool, false)
    namespace         = optional(string, "argocd")
    hub_iam_role_name = optional(string, "argocd-controller")

    helm_values = optional(list(string), [])
    helm_set = optional(list(object({
      name  = string
      value = string
    })), [])

    # Spoke specific
    enable_spoke = optional(bool, false)

    hub_iam_role_arn  = optional(string, null)
    hub_iam_role_arns = optional(list(string), null)

    # Common
    tags = optional(map(string), {})
  })
  default = {}
}
```


# v2.0.0+1.32.0

**Breaking Changes:**

- Setting disk size via the karpenter variable is now deprecated. Use the karpenter_resources variable instead.

```
karpenter = {
  ...
  data_volume_size = 80Gi
  ...
}
```

Use the karpenter_resources variable instead.

```
karpenter = {
  ...
  karpenter_resources = {
    ...
    ec2NodeClasses:
      blockDeviceMappings:
        - deviceName: /dev/xvda
          ebs:
            volumeSize: 80Gi
            volumeType: gp3
            encrypted: true
      }
    }
  }
  ...
}
```

- Patching Helm Chart annotations - these need to be added to the root modules and then removed.
```
# These annotations allow the new helm chart to own the resources
resource "kubernetes_annotations" "karpenter_ec2_node_class" {
  api_version = "karpenter.k8s.aws/v1"
  kind        = "EC2NodeClass"
  metadata {
    name = "default"
  }
  annotations = {
    "meta.helm.sh/release-name" = "karpenter-resources"
  }

  force = true

  lifecycle {
    ignore_changes = all
  }
}

resource "kubernetes_annotations" "karpenter_node_pool" {
  api_version = "karpenter.sh/v1"
  kind        = "NodePool"
  metadata {
    name = "default"
  }
  annotations = {
    "meta.helm.sh/release-name" = "karpenter-resources"
  }

  force = true

  lifecycle {
    ignore_changes = all
  }
}
```
