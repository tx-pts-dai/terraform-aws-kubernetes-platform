
v2.0.0+1.32.0

Breaking Changes:

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
