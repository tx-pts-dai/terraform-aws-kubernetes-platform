
locals {
  karpenter_namespace = "karpenter"
}

resource "aws_iam_service_linked_role" "spot" {
  aws_service_name = "spot.amazonaws.com"
}

module "karpenter" {
  source = "terraform-aws-modules/eks/aws//modules/karpenter"

  cluster_name           = module.eks.cluster_name
  enable_irsa            = true
  irsa_oidc_provider_arn = module.eks.oidc_provider_arn

  # Attach additional IAM policies to the Karpenter node IAM role
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }
}

resource "helm_release" "karpenter" {
  namespace           = "karpenter"
  create_namespace    = true
  name                = "karpenter"
  repository          = "oci://public.ecr.aws/karpenter"
  repository_username = var.aws_ecrpublic_authorization_token.user_name
  repository_password = var.aws_ecrpublic_authorization_token.password
  chart               = "karpenter"
  version             = "0.35.1"
  wait                = false

  values = [
    <<-EOT
    settings:
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter.iam_role_arn}
    tolerations:
      - key: 'eks.amazonaws.com/compute-type'
        operator: Equal
        value: fargate
        effect: "NoSchedule"
    EOT
  ]
}


resource "kubectl_manifest" "karpenter_node_class" {
  yaml_body = <<-YAML
    apiVersion: karpenter.k8s.aws/v1beta1
    kind: EC2NodeClass
    metadata:
      name: default
    spec:
      amiFamily: AL2
      role: ${module.karpenter.node_iam_role_name}
      subnetSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      securityGroupSelectorTerms:
        - tags:
            karpenter.sh/discovery: ${module.eks.cluster_name}
      tags:
        karpenter.sh/discovery: ${module.eks.cluster_name}
  YAML

  depends_on = [
    helm_release.karpenter
  ]
}

# TODO: how to best manage manifests?
resource "kubectl_manifest" "karpenter_node_pool" {
  yaml_body = <<-YAML
    apiVersion: karpenter.sh/v1beta1
    kind: NodePool
    metadata:
      name: default
    spec:
      template:
        spec:
          nodeClassRef:
            name: default
          requirements:
            - key: "karpenter.k8s.aws/instance-category"
              operator: In
              values: ["c", "m", "r", "t"]
            - key: "karpenter.k8s.aws/instance-cpu"
              operator: In
              values: ["2", "4", "8"]
            - key: "karpenter.k8s.aws/instance-hypervisor"
              operator: In
              values: ["nitro"]
            - key: "karpenter.k8s.aws/instance-generation"
              operator: Gt
              values: ["1"]
            - key: "kubernetes.io/arch"
              operator: In
              values: ["amd64"]
            - key: "karpenter.sh/capacity-type"
              operator: In
              values: ["spot", "on-demand"]
      limits:
        cpu: 1000
      disruption:
        consolidationPolicy: WhenEmpty
        consolidateAfter: 30s
  YAML

  depends_on = [
    kubectl_manifest.karpenter_node_class
  ]
}

# TODO: remove if no need for supporting eks asg nodes
# Karpenter nodes will use the "node_security_group" created by aws eks module
# ASG nodes use the "module.eks.node_security_group_id" security group created by AWS EKS
# During migration, we must allow those 2 SGs to communicate
# So thoses 2 resources:
#    - aws_vpc_security_group_ingress_rule.eks_to_karpenter_nodes
#    - aws_vpc_security_group_ingress_rule.karpenter_nodes_to_eks
resource "aws_vpc_security_group_ingress_rule" "eks_to_karpenter_nodes" {
  security_group_id            = module.eks.node_security_group_id
  description                  = "All traffic from EKS control plane/ASG nodes to karpenter provisioned nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = module.eks.cluster_primary_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "karpenter_nodes_to_eks" {
  security_group_id            = module.eks.cluster_primary_security_group_id
  description                  = "All traffic from karpenter provisioned nodes to EKS control plane/ASG nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = module.eks.node_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "node_to_node" {
  security_group_id            = module.eks.node_security_group_id
  description                  = "All traffic between EKS nodes"
  ip_protocol                  = "-1"
  referenced_security_group_id = module.eks.node_security_group_id
}

# Allow karpenter deployed nodes to talk to ASG deployed nodes
# Once all workloads are migrated to karpenter and no nodes, appart karpenter deployed one, this can be removed
resource "aws_vpc_security_group_ingress_rule" "node_from_controlplane" {
  security_group_id            = module.eks.node_security_group_id
  description                  = "Traffic from EKS control plane"
  ip_protocol                  = "tcp"
  from_port                    = 1025
  to_port                      = 65535
  referenced_security_group_id = module.eks.cluster_security_group_id
}
