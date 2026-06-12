# Compute modes: what gets deployed (Karpenter vs Auto Mode vs hybrid)

A quick reference for what this module deploys in each combination of the two
independent compute toggles, and **where each thing is visible** (Kubernetes API
via `kubectl` vs the AWS control plane via `aws` CLI).

Two toggles drive everything:

| Toggle             | Default | Controls                                                                    |
| ------------------ | ------- | --------------------------------------------------------------------------- |
| `enable_karpenter` | `true`  | Self-managed Karpenter stack (controller, CRDs, IRSA, subnets, SG, Fargate) |
| `enable_auto_mode` | `false` | EKS Auto Mode (`compute_config` on the cluster + AWS-managed data plane)    |

> At least one must be `true` (enforced by validation) or the cluster has no compute.

The storage/LB capabilities have their own per-capability toggles that default to
"on unless Auto Mode is on" but can be flipped to coexist during a migration:

| Capability     | Toggle                              | Default (when unset) |
| -------------- | ----------------------------------- | -------------------- |
| Block storage  | `enable_self_managed_ebs_csi`       | `!enable_auto_mode`  |
| Load balancing | `enable_self_managed_lb_controller` | `!enable_auto_mode`  |

---

## Scenario 1 — Karpenter only (`enable_karpenter = true`, `enable_auto_mode = false`)

The classic self-managed stack. Everything runs as workloads/CRDs **you can see and
manage with `kubectl`**.

**Deployed:**

| Component               | What                                                                                                    | Visible via                                                |
| ----------------------- | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Karpenter controller    | Helm `karpenter`, pods run on a **Fargate** profile                                                     | `kubectl` (pods)                                           |
| Karpenter CRDs          | `karpenter-crd` Helm — owns `nodepools`/`nodeclaims.karpenter.sh`                                       | `kubectl get crd`                                          |
| NodePool / EC2NodeClass | `karpenter-resources` Helm → `default` NodePool + `default` EC2NodeClass                                | `kubectl get nodepool,ec2nodeclass`                        |
| Karpenter networking    | Dedicated subnets (if `karpenter.subnet_cidrs`) + security group, tagged `karpenter.sh/discovery`       | `aws` CLI (EC2)                                            |
| IAM                     | Karpenter controller IRSA + node IAM role                                                               | `aws` CLI (IAM)                                            |
| Nodes                   | Regular EC2 instances Karpenter launches                                                                | `kubectl get nodes` + `aws` CLI (EC2 console)              |
| Core addons             | `vpc-cni`, `kube-proxy`, `coredns`, `eks-pod-identity-agent`, `aws-ebs-csi-driver` (managed EKS addons) | `kubectl` (DaemonSets/Deployments) + `aws eks list-addons` |
| Load balancing          | Self-managed AWS LB Controller (deployed via ArgoCD; module creates its pod-identity IAM)               | `kubectl` (pods)                                           |

---

## Scenario 2 — Auto Mode only (`enable_auto_mode = true`, `enable_karpenter = false`)

"Pure" Auto Mode. AWS runs the data plane as **managed core components**, not as
add-ons. The big mental shift: most of what used to be `kubectl`-visible pods is
now **invisible** — it runs inside AWS-managed infrastructure. Yes, Auto Mode
includes the full feature set (compute, pod networking, kube-proxy, local DNS,
block storage, load balancing, pod identity).

**Deployed:**

| Component                | What                                                                                        | Visible via                                                                        |
| ------------------------ | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Auto Mode enablement     | `compute_config { enabled = true }` on the EKS cluster                                      | **`aws eks describe-cluster`** (not kubectl)                                       |
| Built-in Karpenter       | Runs in the **AWS-managed control plane** — there is **no** karpenter pod                   | not visible (no pod)                                                               |
| NodePool                 | Module's `auto-mode` NodePool (`karpenter.sh/v1`)                                           | `kubectl get nodepool`                                                             |
| NodeClass                | Module's `auto-mode` NodeClass (`eks.amazonaws.com/v1`)                                     | `kubectl get nodeclasses.eks.amazonaws.com`                                        |
| Built-in node pools      | `general-purpose` / `system` — only if `auto_mode.builtin_node_pools` set                   | `kubectl get nodepool`                                                             |
| Node IAM role            | Created by the EKS module; authorized via an `EC2`-type **access entry**                    | `aws` CLI (IAM / `aws eks list-access-entries`)                                    |
| Nodes                    | Auto Mode "managed instances" (Bottlerocket), labeled `eks.amazonaws.com/compute-type=auto` | `kubectl get nodes`; underlying EC2 **hidden by default** from the EC2 console/API |
| Pod networking (VPC CNI) | Built into the node — **no** `aws-node` DaemonSet                                           | not visible (no pod)                                                               |
| kube-proxy               | Built into the node — **no** `kube-proxy` DaemonSet                                         | not visible (no pod)                                                               |
| Cluster DNS              | Local DNS on Auto Mode nodes — **no** `coredns` Deployment / addon                          | not visible (no pod)                                                               |
| Pod identity             | Built in — **no** `eks-pod-identity-agent` DaemonSet                                        | not visible (no pod)                                                               |
| Block storage            | Managed `ebs.csi.eks.amazonaws.com` — **no** `ebs-csi-*` pods                               | StorageClass via `kubectl`; driver itself not a pod                                |
| Load balancing           | Built-in controller, IngressClass `eks.amazonaws.com/alb`                                   | IngressClass via `kubectl`; controller not a pod                                   |

> **Rule of thumb:** in pure Auto Mode, `kubectl get pods -n kube-system` is nearly
> empty — no aws-node, kube-proxy, coredns, ebs-csi, or karpenter pods. They still
> exist as functionality, just not as Kubernetes objects you manage. You configure
> them through NodePools/NodeClasses and cluster settings, and inspect cluster-level
> facts with the `aws` CLI.

---

## Scenario 3 — Hybrid / migration (both `enable_karpenter = true` and `enable_auto_mode = true`)

The supported path for a gradual, in-place migration. **Both controllers run
side-by-side.** This is what `examples/complete` and `tests/main` exercise.

> ⚠️ Only safe as a **staged** migration: enable self-managed Karpenter first (it
> owns the `karpenter.sh` CRDs), then flip on Auto Mode so it adopts them. Never
> both at once on a fresh cluster. See [auto-mode-migration.md](./auto-mode-migration.md).

**Deployed (union of both, with coexistence rules):**

| Component                           | State in hybrid                                                                                                                                                                         | Visible via                                                              |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| Karpenter controller                | Running (on Fargate)                                                                                                                                                                    | `kubectl` (pods)                                                         |
| Auto Mode built-in Karpenter        | Running (control plane)                                                                                                                                                                 | not visible (no pod)                                                     |
| NodePools                           | **Two**, sharing one CRD: `default` (self-managed) + `auto-mode` (Auto Mode)                                                                                                            | `kubectl get nodepool` (both listed)                                     |
| Node configs                        | `default` **EC2NodeClass** (`karpenter.k8s.aws`) **and** `auto-mode` **NodeClass** (`eks.amazonaws.com`) — different CRDs                                                               | `kubectl get ec2nodeclass` / `kubectl get nodeclasses.eks.amazonaws.com` |
| Subnet discovery                    | Both discover the **same** subnets by tag (default), separated by NodePool + taints, OR different subnets — see migration doc                                                           | `aws` CLI (EC2 tags)                                                     |
| Nodes                               | Self-managed EC2 nodes **and** Auto Mode nodes (compute-type `auto`)                                                                                                                    | `kubectl get nodes -L eks.amazonaws.com/compute-type`                    |
| Compute separation                  | Auto Mode `auto-mode` NodePool is **tainted** (`auto-mode=true:NoSchedule`); workloads migrate by adding the matching toleration                                                        | `kubectl`                                                                |
| CoreDNS                             | **Retained** (managed addon) — Auto Mode's DNS doesn't serve the self-managed nodes; pods run on the self-managed nodes                                                                 | `kubectl` (Deployment) + `aws eks list-addons`                           |
| VPC CNI / kube-proxy / pod-identity | Addons **deregistered** but `preserve = true` leaves the DaemonSets running on the self-managed nodes (gone once those nodes drain)                                                     | `kubectl` (DaemonSets on self-managed nodes only)                        |
| Block storage                       | Self-managed `ebs.csi.aws.com` **and** Auto Mode `ebs.csi.eks.amazonaws.com` coexist (set `enable_self_managed_ebs_csi = true`); migrate per `StorageClass`                             | `kubectl` (self-managed pods)                                            |
| Load balancing                      | Self-managed LB controller (`ingress.k8s.aws/alb`) **and** Auto Mode (`eks.amazonaws.com/alb`) coexist (set `enable_self_managed_lb_controller = true`); migrate per `ingressClassName` | `kubectl` (self-managed pods)                                            |

---

## Visibility cheat-sheet

| You want to check…                        | Command                                                                                                                                                           |
| ----------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Is Auto Mode on?                          | `aws eks describe-cluster --name <c> --query 'cluster.computeConfig'`                                                                                             |
| Which Auto Mode capabilities are enabled  | `describe-cluster` → `computeConfig.enabled`, `storageConfig.blockStorage.enabled`, `kubernetesNetworkConfig.elasticLoadBalancing.enabled` (all 3 wired together) |
| Auto Mode node IAM authorization          | `aws eks list-access-entries --cluster-name <c>` (look for the `EC2` entry)                                                                                       |
| All NodePools (both controllers)          | `kubectl get nodepools`                                                                                                                                           |
| Self-managed node config                  | `kubectl get ec2nodeclasses`                                                                                                                                      |
| Auto Mode node config + readiness         | `kubectl get nodeclasses.eks.amazonaws.com`; `… -o yaml` → `.status.conditions`                                                                                   |
| Which nodes are Auto Mode vs self-managed | `kubectl get nodes -L eks.amazonaws.com/compute-type` (`auto` = Auto Mode)                                                                                        |
| Managed EKS addons present                | `aws eks list-addons --cluster-name <c>`                                                                                                                          |
| Is cluster DNS actually up                | `kubectl get deploy,pods -n kube-system -l k8s-app=kube-dns`                                                                                                      |
