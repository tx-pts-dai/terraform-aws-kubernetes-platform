# Notes while working on the base setup

The idea of the Kubernetes platform is to provide a base infrastructure setup that is batteries included. This means
not only do you get a kubernetes cluster, but you also get route53 zones, acm certs, iam roles, vpcs, etc in a
developer friendly interface (terraform input files).

Core kubernetes components are in the main module. This would include any resources that is required to have
a functional kubernetes cluster.

One addon per module. This allows for version tracking and easier management of the addons. EKS is special in that
it will create a cluster with a fargate profile for karpenter. It might be worth to manage core addons in the eks
module as well. (coredns, kube-proxy, vpc-cni)

- EKS Control Plane
- Karpenter
- CoreDNS
- AWS Load Balancer Controller
- External DNS
- Fluent Bit (Operator?)
- Metrics Server

Nested modules will include additional addons/resources that we as the dai team support.

- Datadog
- Lacework
- Prometheus
- Grafana
- Loki
- Tempo
- External Secrets (core?)

# Multi cluster / region

When multi region or multi cluster is required, should a new module definition be created or should we support
multiple regions/clusters in the same module? The tricky part is providers are inherited from the root module. And
if providers are defined in the nested module, loops and counts are not supported.

# Managed addons

Should we self manage or use managed addons? For our simple case, the core 3 addons (coredns, kube-proxy, vpc-cni)
would be best suited for managed addons and the reset would be self managed.

# EKS Charts

prefer aws eks charts (aws lb controller)

https://github.com/aws/eks-charts

