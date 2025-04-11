# Karpenter

By default the Kubernetes as a Service (KaaS) module will deploy a Karpenter controller and the custom resources for creating nodes. These resources are [NodePool](https://karpenter.sh/docs/concepts/nodepools/) and [Ec2NodeClass](https://karpenter.sh/docs/concepts/nodeclasses/). You can think of these as NodeClass defines the ec2 launch template and NodePool defines the node group. The Karpenter controller will then create the nodes based on the node class and node pool.

## Configuration

To customise the Karpenter configuration, you need to define the necessary variables in the `kaas` module. The following example shows how to do this:

```hcl
module "k8s_platform" {
  source = "../../"

  name = "ex-complete"

  ...redacted for brevity...

  # Karpenter general configuration variable
  karpenter = {
    values = [
      # Add your custom values here
      # These will be treated like how helm treat values inputs. eg. helm install -f values.yaml -f values2.yaml
      replicas: 2
    ]
    # Karpenter Helm chart sets
    set = [
      {
        name  = "replicas"
        value = 1
      }
    ]


## Karpenter Custom Resources

The Karpenter custom resources are defined in the `karpenter_resources` variable. This variable is a map of values that will be passed to the [Karpenter resources Helm chart](https://github.com/DND-IT/helm-charts/tree/main/charts/karpenter-resources#karpenter-resources). The following example shows how to define the Karpenter custom resources:

```hcl
module "k8s_platform" {
  source = "../../"

  name = "ex-complete"

  ...redacted for brevity...

  # Karpenter general configuration variable
  karpenter = {
    # Karpenter custom resources overrides
    # Direct inline overrides to the Karpenter custom resources
    karpenter_resources = {
      values = [
        file("${path.module}/karpenter-values.yaml"), # Set the values file
        <<-EOT # Inline YAML
        nodePools:
          default:
            requirements:
              - key: karpenter.k8s.aws/instance-category
                operator: In
                values: ["t"]
        EOT
      ]
      set = [ # Set the values directly
        {
          name  = "nodePools.default.requirements[0].key"
          value = "karpenter.k8s.aws/instance-category"
        },
        {
          name  = "nodePools.default.requirements[0].operator"
          value = "In"
        },
        {
          name  = "nodePools.default.requirements[0].values"
          value = "[\"t\"]"
        }
      ]
    }
  }
}
```

```hcl
data "helm_template" "karpenter_custom_resources" {
  name       = "karpenter-resources"
  chart      = "karpenter-resources"
  version    = "0.3.1"
  repository = "https://dnd-it.github.io/helm-charts"
  namespace  = local.karpenter.namespace

  values = [
    <<-EOT
    global:
      role: ${module.k8s_platform.karpenter.node_iam_role_name}
      eksDiscovery:
        enabled: true
        clusterName: ${module.k8s_platform.eks.cluster_name}

    nodePools:
      custom:
        requirements:
          - key: karpenter.k8s.aws/instance-category
            operator: In
            values: ["t"]
        labels:
          my-custom-nodepool: "true"
        taints:
          - key: "karpenter.sh/capacity-type"
            value: "spot"
            effect: "NoSchedule"
        limits:
          resources:
            cpu: 100
            memory: 10Gi
        providerRef:
          name: custom

    ec2NodeClasses:
      custom:
        amiFamily: al2023
        amiSelectorTerms:
          - alias: al2023@v20240807
        tags:
          Name: "custom-node-class"
        kubelet:
          maxPods: 10
    EOT
  ]
}
```
