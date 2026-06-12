# EKS Auto Mode Migration Guide

## Overview

This guide explains how to enable [EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)
on a cluster created with this module, and how to migrate an existing cluster
that currently runs the **self-managed** stack (Karpenter, EBS CSI driver and the
AWS Load Balancer Controller deployed via ArgoCD) over to the AWS-managed
equivalents.

> **Auto Mode is opt-in.** The `enable_auto_mode` variable defaults to `false`,
> so existing clusters are unaffected until you explicitly flip it.

## What changes

When `enable_auto_mode = true`, AWS manages compute, block storage, load
balancing and core networking. This module therefore **stops creating** the
self-managed components:

| Capability        | Self-managed (default)                                   | Auto Mode                                              |
| ----------------- | -------------------------------------------------------- | ------------------------------------------------------ |
| Compute / scaling | Karpenter Helm release + Fargate profile + IRSA + subnets | Built-in Karpenter (`compute_config`)                  |
| Node config       | `karpenter-resources` Helm chart (NodePool / EC2NodeClass) | `NodePool` (`karpenter.sh/v1`) + `NodeClass` (`eks.amazonaws.com/v1`) |
| Core networking   | `vpc-cni`, `kube-proxy` addons + VPC CNI IRSA            | Managed by Auto Mode                                   |
| Cluster DNS       | `coredns` addon                                          | Managed by Auto Mode                                   |
| Block storage     | `aws-ebs-csi-driver` addon + IRSA / pod identity         | Managed by Auto Mode (`ebs.csi.eks.amazonaws.com`)     |
| Load balancing    | AWS Load Balancer Controller (ArgoCD) + pod identity      | Built-in (`eks.amazonaws.com/alb`)                     |

**Migrate storage and load balancing independently.** Compute (`enable_karpenter`)
and the **storage** and **load balancing** capabilities each have their own toggle,
so you can decide per capability which side — self-managed or Auto Mode — runs at a
given moment:

| Capability    | Toggle                              | Default            |
| ------------- | ----------------------------------- | ------------------ |
| Compute       | `enable_karpenter`                  | `true`             |
| Block storage | `enable_self_managed_ebs_csi`       | `!enable_auto_mode` |
| Load balancing| `enable_self_managed_lb_controller` | `!enable_auto_mode` |

Each storage/LB toggle defaults to "off when Auto Mode is on", but you can set it to
`true` to keep the self-managed version running alongside Auto Mode's managed one
while you cut over, then flip it to `false` when done. Networking (VPC CNI,
kube-proxy) is **not** independently togglable — Auto Mode owns the data plane, so
those copies always follow `enable_auto_mode`.

**CoreDNS is the exception:** Auto Mode's managed DNS only serves Auto Mode nodes,
so while self-managed compute is still running (`enable_karpenter = true`) the
cluster `coredns` addon is **retained automatically** — its pods run on the
self-managed nodes and back the `kube-dns` Service for the whole cluster. CoreDNS
is handed over to Auto Mode (the addon dropped) only in **pure** Auto Mode
(`enable_auto_mode = true`, `enable_karpenter = false`). You don't toggle this; it
follows `enable_karpenter`. Removing it too early leaves every pod on the
self-managed nodes without DNS.

Resources that are **not** affected and keep working in both modes: ArgoCD, the
ACK capability, external-dns / external-secrets pod identities, the AWS Gateway
API (VPC Lattice) controller pod identity, ACM, and the Kubernetes access roles.

## Prerequisites

- Module version that includes Auto Mode support (this release or newer).
- Kubernetes `1.29`+ (Auto Mode requires a recent control plane).
- The `helm` provider configured in the root module (already a dependency). The
  NodePool/NodeClass are applied via the `custom-resources` Helm chart, which
  defers correctly on clusters created in the same `apply`.

## Bringing your own NodePool / NodeClass

Auto Mode capacity is declared with two CRDs:

- **`NodeClass`** (`eks.amazonaws.com/v1`) — the AWS-specific node configuration
  (IAM role, subnets, security groups, ephemeral storage, …).
- **`NodePool`** (`karpenter.sh/v1`) — scheduling requirements, limits and
  disruption settings, referencing a `NodeClass`.

Pass them while calling the module, the same way the `karpenter_resources` Helm
values were passed before. The map key is the resource name and the value is its
`spec`. The module injects the Auto Mode node IAM `role` into each NodeClass
automatically, so you only provide selectors and extra settings:

```hcl
module "k8s_platform" {
  source = "tx-pts-dai/kubernetes-platform/aws"

  # ...

  enable_auto_mode = true

  auto_mode_node_classes = {
    default = {
      subnetSelectorTerms        = [{ tags = { "kubernetes.io/role/internal-elb" = "1" } }]
      securityGroupSelectorTerms = [{ tags = { "kubernetes.io/cluster/<cluster-name>" = "owned" } }]
      ephemeralStorage           = { size = "80Gi", iops = 3000, throughput = 125 }
    }
  }

  auto_mode_node_pools = {
    default = {
      template = {
        spec = {
          nodeClassRef = { group = "eks.amazonaws.com", kind = "NodeClass", name = "default" }
          requirements = [
            { key = "eks.amazonaws.com/instance-category", operator = "In", values = ["c", "m", "r"] },
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["on-demand"] },
          ]
        }
      }
      limits     = { cpu = "1000" }
      disruption = { consolidationPolicy = "WhenEmptyOrUnderutilized", consolidateAfter = "30s" }
    }
  }
}
```

If you omit `auto_mode_node_classes` / `auto_mode_node_pools` entirely, the module
creates a sensible `default` NodeClass (targeting the cluster private subnets and
primary security group) and a `default` NodePool.

You can also enable the AWS-managed built-in node pools alongside your own:

```hcl
auto_mode = {
  builtin_node_pools = ["system"] # and/or "general-purpose"
}
```

---

## Migrating an existing cluster

`enable_auto_mode` and `enable_karpenter` are **independent** toggles. Auto Mode
and the self-managed Karpenter stack can run **side-by-side**, which is the
supported path for a gradual, low-risk in-place migration. Each capability cuts
over with its own mechanism:

| Capability     | Cutover mechanism                                                        |
| -------------- | ------------------------------------------------------------------------ |
| Compute        | Auto Mode NodePool **taint** + per-workload **toleration**               |
| Block storage  | **StorageClass** — provision new volumes against `ebs.csi.eks.amazonaws.com` |
| Load balancing | **`ingressClassName`** — repoint each Ingress to the Auto Mode class      |

### Migrating compute (taint + tolerations)

1. Enable Auto Mode **alongside** Karpenter (`enable_auto_mode = true`, keep
   `enable_karpenter = true`), with the Auto Mode `default` NodePool **tainted** so
   existing workloads do not move automatically. The `complete` example uses:

   ```hcl
   auto_mode = {
     subnet_discovery_tags = { "karpenter.sh/discovery" = "shared" }
     default_node_pool_taints = [
       { key = "auto-mode", value = "true", effect = "NoSchedule" },
     ]
   }
   ```

2. Move workloads onto Auto Mode one at a time by adding the matching toleration
   (and, if you want to force placement, a `nodeSelector` such as
   `eks.amazonaws.com/compute-type: auto`):

   ```yaml
   tolerations:
     - key: "auto-mode"
       value: "true"
       effect: "NoSchedule"
   ```

3. Once every workload runs on Auto Mode, disable the self-managed stack
   (`enable_karpenter = false`). Karpenter's nodes drain as their pods reschedule.

This mirrors AWS's
[Migrate from Karpenter to EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/auto-migrate-karpenter.html)
guide. The `karpenter.sh` NodePool/NodeClaim CRDs are **shared** between the two
controllers — keep the `karpenter-crd` Helm release in place and **do not change
its version** while both stacks run.

### Same network vs. different subnets

When both stacks run, you choose whether Auto Mode shares Karpenter's network or
sits on its own subnets via `auto_mode.discover_karpenter_subnets`. It defaults to
`null`, which **resolves to `enable_karpenter`** — so when the self-managed
Karpenter stack is enabled, Auto Mode shares its subnets **by default**:

- **Same network (different NodePools/taints) — default while Karpenter runs.**
  With `discover_karpenter_subnets` unset (or `true`), the auto-generated `default`
  NodeClass discovers subnets by tag — by default `karpenter.sh/discovery =
  <cluster-name>`, the tag the module puts on its own dedicated Karpenter subnets.
  Both controllers launch into the same subnets; you separate them with NodePools
  and taints, not with the network.

  If you point self-managed Karpenter at a **customized** discovery tag (e.g. via
  `karpenter_resources_helm_set` setting `karpenter.sh/discovery = shared` on
  pre-existing subnets), set `auto_mode.subnet_discovery_tags` to the same tag so
  Auto Mode matches those subnets:

  ```hcl
  enable_auto_mode = true
  auto_mode = {
    subnet_discovery_tags = { "karpenter.sh/discovery" = "shared" }
  }
  ```

  Setting `discover_karpenter_subnets = true` with the default tag requires
  `enable_karpenter = true` (those subnets only exist while the Karpenter stack is
  enabled); with custom `subnet_discovery_tags` it does not, since you own those
  subnets.
- **Different subnets.** Set `discover_karpenter_subnets = false`. The `default`
  NodeClass selects `var.vpc.private_subnets` by ID, while self-managed Karpenter
  stays on its dedicated `karpenter.subnet_cidrs` subnets — so the two stacks land
  on separate networks. To put Auto Mode on some other set of subnets, pass your
  own `auto_mode_node_classes` with the selectors you want and provision those
  subnets outside the module.

In **pure Auto Mode** (`enable_karpenter = false`), the `null` default resolves to
`false`, so the `default` NodeClass uses `var.vpc.private_subnets` — there are no
Karpenter subnets to discover.

### Migrating storage and load balancing

Keep the self-managed components running alongside the Auto Mode ones while you
cut over, by setting their toggles explicitly (they otherwise default to **off**
when Auto Mode is on):

```hcl
enable_self_managed_ebs_csi       = true
enable_self_managed_lb_controller = true
```

**Block storage.** The self-managed driver (`ebs.csi.aws.com`) and Auto Mode's
driver (`ebs.csi.eks.amazonaws.com`) coexist — they are different provisioners.
Existing PVs stay bound to whichever driver created them. To migrate, create a
StorageClass backed by `ebs.csi.eks.amazonaws.com` and point new PVCs at it via
`storageClassName`. **Avoid two default StorageClasses** — keep exactly one
marked `storageclass.kubernetes.io/is-default-class: "true"`.

**Load balancing.** The self-managed AWS Load Balancer Controller
(`ingress.k8s.aws/alb`) and Auto Mode's built-in controller (`eks.amazonaws.com/alb`)
are separate IngressClass controllers, so each Ingress is reconciled by **one**
of them based on its `ingressClassName`. Migrate **one Ingress at a time** by
repointing `ingressClassName` to the Auto Mode class. Do not leave an Ingress
matching both (ambiguous class/annotations) or you get two load balancers
fighting over it.

Once nothing depends on the self-managed versions, flip both toggles to `false`.

> **ℹ️ CRD ownership is handled for you.** EKS Auto Mode installs and owns the
> `nodepools.karpenter.sh` / `nodeclaims.karpenter.sh` CRDs, which would otherwise
> collide with the module's `karpenter-crd` Helm release (`invalid ownership
> metadata`). That release sets `take_ownership = true`, so it **adopts** the
> existing CRDs no matter which controller created them first. As a result a clean
> cluster with both `enable_karpenter` and `enable_auto_mode` enabled applies in a
> single pass, and disabling Auto Mode later (its CRDs linger on the cluster) does
> not break the self-managed stack. The staged approach — deploy Karpenter first,
> then enable Auto Mode in a second apply — still works and is the most conservative
> path. Note that with both stacks enabled the chart's CRD version and Auto Mode's
> are co-managed; this is low-risk since both are `karpenter.sh/v1`.

<!-- -->

> **Compute guard:** at least one of `enable_karpenter` / `enable_auto_mode` must
> be `true`, otherwise the cluster has no compute (enforced by a variable
> validation).
