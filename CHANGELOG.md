# v3.0.0+1.32.0

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
