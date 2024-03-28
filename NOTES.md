# Notes while working on the base setup

The idea of the Kubernetes platform is to provide a batteries included base infrastructure setup. This means
not only do you get a kubernetes cluster, but you also get route53 zones, acm certs, iam roles, vpcs, etc in a
developer friendly interface (terraform input files).

Core kubernetes components are in the main module. This would include any resources that is required to have
a functional kubernetes cluster.

One addon per module!?(had issues with plans taking a long time). This allows for version tracking and easier management of the addons. EKS is special in that
it will create a cluster with a fargate profile for karpenter. It might be worth to manage core addons in the eks
module as well. (coredns, kube-proxy, vpc-cni)

- EKS Control Plane
- Karpenter
- CoreDNS
- AWS Load Balancer Controller
- External DNS
- Fluent Bit (Operator?) Even if datadog is used, it would make sense to ship non app logs to a separate location.
- Metrics Server
- External Secrets

Nested modules will include additional addons/resources that we as the dai team support.

- Datadog
- Lacework
- Prometheus
- LGTM Stack

# Multi cluster / region

When multi region or multi cluster is required, should a new module definition be created or should we support
multiple regions/clusters in the same module? Providers would need to be defined in a dynamic way.

# Managed addons

Should we self manage or use managed addons? For our simple case, the core 3 addons (coredns, kube-proxy, vpc-cni)
would be best suited for managed addons and the reset would be self managed.

# GitOps Tool

Should we look into a real gitops tool to manage application rollouts?

# Destroying Clusters

When destroying a cluster, everything deployed inside of the cluster should be cleaned up in a orderly fashion so that any
resources that are created by the cluster are also deleted. eg, Load balancers, Nodes, etc.

# Other

Daily deploys with latest version of modules

DAI Production Cluster

DAI Production AWS account
