################################################################################
# Karpenter
#

locals {
  karpenter = {
    namespace = "kube-system"
  }

  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

# https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/modules/karpenter/policy.tf
data "aws_iam_policy_document" "karpenter_controller" {
  statement {
    sid = "AllowScopedEC2InstanceAccessActions"
    resources = [
      "arn:aws:ec2:${local.region}::image/*",
      "arn:aws:ec2:${local.region}::snapshot/*",
      "arn:aws:ec2:${local.region}:*:security-group/*",
      "arn:aws:ec2:${local.region}:*:subnet/*",
      "arn:aws:ec2:${local.region}:*:capacity-reservation/*",
    ]

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]
  }

  statement {
    sid = "AllowScopedEC2LaunchTemplateAccessActions"
    resources = [
      "arn:aws:ec2:${local.region}:*:launch-template/*"
    ]

    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowScopedEC2InstanceActionsWithTags"
    resources = [
      "arn:aws:ec2:${local.region}:*:fleet/*",
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:volume/*",
      "arn:aws:ec2:${local.region}:*:network-interface/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*",
      "arn:aws:ec2:${local.region}:*:spot-instances-request/*",
    ]
    actions = [
      "ec2:RunInstances",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [module.eks.cluster_name]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid = "AllowScopedResourceCreationTagging"
    resources = [
      "arn:aws:ec2:${local.region}:*:fleet/*",
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:volume/*",
      "arn:aws:ec2:${local.region}:*:network-interface/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*",
      "arn:aws:ec2:${local.region}:*:spot-instances-request/*",
    ]
    actions = ["ec2:CreateTags"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [module.eks.cluster_name]
    }

    condition {
      test     = "StringEquals"
      variable = "ec2:CreateAction"
      values = [
        "RunInstances",
        "CreateFleet",
        "CreateLaunchTemplate",
      ]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowScopedResourceTagging"
    resources = ["arn:aws:ec2:${local.region}:*:instance/*"]
    actions   = ["ec2:CreateTags"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }

    condition {
      test     = "StringEqualsIfExists"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [module.eks.cluster_name]
    }

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:TagKeys"
      values = [
        "eks:eks-cluster-name",
        "karpenter.sh/nodeclaim",
        "Name",
      ]
    }
  }

  statement {
    sid = "AllowScopedDeletion"
    resources = [
      "arn:aws:ec2:${local.region}:*:instance/*",
      "arn:aws:ec2:${local.region}:*:launch-template/*"
    ]

    actions = [
      "ec2:TerminateInstances",
      "ec2:DeleteLaunchTemplate"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.sh/nodepool"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowRegionalReadActions"
    resources = ["*"]
    actions = [
      "ec2:DescribeCapacityReservations",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeImages",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [local.region]
    }
  }

  statement {
    sid       = "AllowSSMReadActions"
    resources = ["arn:aws:ssm:${local.region}::parameter/aws/service/*"]
    actions   = ["ssm:GetParameter"]
  }

  statement {
    sid       = "AllowPricingReadActions"
    resources = ["*"]
    actions   = ["pricing:GetProducts"]
  }

  statement {
    sid = "AllowInterruptionQueueActions"
    actions = [
      "sqs:DeleteMessage",
      "sqs:GetQueueUrl",
      "sqs:ReceiveMessage"
    ]
    resources = [module.karpenter.queue_arn]
  }

  statement {
    sid       = "AllowPassingInstanceRole"
    actions   = ["iam:PassRole"]
    resources = [module.karpenter.node_iam_role_arn]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  statement {
    sid       = "AllowScopedInstanceProfileCreationActions"
    resources = ["arn:aws:iam::${local.account_id}:instance-profile/*"]
    actions   = ["iam:CreateInstanceProfile"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [module.eks.cluster_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = [local.region]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowScopedInstanceProfileTagActions"
    resources = ["arn:aws:iam::${local.account_id}:instance-profile/*"]
    actions   = ["iam:TagInstanceProfile"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = [local.region]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/eks:eks-cluster-name"
      values   = [module.eks.cluster_name]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/topology.kubernetes.io/region"
      values   = [local.region]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowScopedInstanceProfileActions"
    resources = ["arn:aws:iam::${local.account_id}:instance-profile/*"]
    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:DeleteInstanceProfile"
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/kubernetes.io/cluster/${module.eks.cluster_name}"
      values   = ["owned"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/topology.kubernetes.io/region"
      values   = [local.region]
    }

    condition {
      test     = "StringLike"
      variable = "aws:ResourceTag/karpenter.k8s.aws/ec2nodeclass"
      values   = ["*"]
    }
  }

  statement {
    sid       = "AllowInstanceProfileReadActions"
    resources = ["arn:aws:iam::${local.account_id}:instance-profile/*"]
    actions   = ["iam:GetInstanceProfile"]
  }

  statement {
    sid       = "AllowAPIServerEndpointDiscovery"
    resources = ["arn:aws:eks:${local.region}:${local.account_id}:cluster/${module.eks.cluster_name}"]
    actions   = ["eks:DescribeCluster"]
  }
}

resource "aws_iam_policy" "karpenter_controller" {
  name   = "karpenter-controller-${local.id}"
  policy = data.aws_iam_policy_document.karpenter_controller.json
}

# Custom IAM role for Karpenter running in Fargate
module "karpenter_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts"
  version = "6.2.1"

  name            = "karpenter-controller-${local.id}"
  use_name_prefix = false

  create_policy = false
  policies = {
    controller = aws_iam_policy.karpenter_controller.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.karpenter.namespace}:karpenter"]
    }
  }

  tags = local.tags
}

# Karpenter module - only for node IAM role and other resources
# IRSA is disabled as we're using a custom role for Fargate
module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.3.2"

  cluster_name = module.eks.cluster_name

  create_iam_role = false

  create_node_iam_role = true
  # Node IAM role configuration
  node_iam_role_name              = "karpenter-node-${local.id}"
  node_iam_role_use_name_prefix   = false
  node_iam_role_attach_cni_policy = true
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  tags = local.tags
}

resource "helm_release" "karpenter_crd" {
  name             = "karpenter-crd"
  chart            = "karpenter-crd"
  version          = "1.7.1"
  repository       = "oci://public.ecr.aws/karpenter"
  description      = "Karpenter CRDs"
  namespace        = local.karpenter.namespace
  create_namespace = true
}

resource "helm_release" "karpenter_release" {
  name             = "karpenter"
  chart            = "karpenter"
  version          = "1.7.1"
  repository       = "oci://public.ecr.aws/karpenter"
  namespace        = local.karpenter.namespace
  create_namespace = true
  skip_crds        = true
  wait             = true

  values = concat([
    <<-EOT
    logLevel: info
    dnsPolicy: Default
    replicas: 2
    controller:
      resources:
        requests:
          cpu: 0.5
          memory: "512Mi"
    settings:
      eksControlPlane: true
      clusterName: ${module.eks.cluster_name}
      clusterEndpoint: ${module.eks.cluster_endpoint}
      interruptionQueue: ${module.karpenter.queue_name}
      featureGates:
        spotToSpotConsolidation: true
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.karpenter_irsa.arn}
    EOT
  ], var.karpenter_helm_values)

  set = var.karpenter_helm_set

  depends_on = [
    module.karpenter_irsa,
    module.karpenter,
    module.karpenter_security_group,
    helm_release.karpenter_crd,
    aws_subnet.karpenter,
    aws_route_table_association.karpenter
  ]
}

resource "helm_release" "karpenter_resources" {
  name       = "karpenter-resources"
  chart      = "karpenter-resources"
  version    = "1.0.1"
  repository = "https://dnd-it.github.io/helm-charts"
  namespace  = local.karpenter.namespace

  values = concat([
    <<-EOT
    global:
      role: ${module.karpenter.node_iam_role_name}
      eksDiscovery:
        enabled: true
        clusterName: ${module.eks.cluster_name}
    nodePools:
      default:
        enabled: true

    ec2NodeClasses:
      default:
        enabled: true
    EOT
  ], var.karpenter_resources_helm_values)

  set = var.karpenter_resources_helm_set

  depends_on = [
    helm_release.karpenter_crd,
    helm_release.karpenter_release
  ]
}

###############################################################################
# Karpenter Networking

resource "aws_subnet" "karpenter" {
  count = length(var.karpenter.subnet_cidrs)

  vpc_id            = var.vpc.vpc_id
  cidr_block        = var.karpenter.subnet_cidrs[count.index]
  availability_zone = element(local.azs, count.index)

  tags = merge(local.tags, {
    Name                     = "${module.eks.cluster_name}-karpenter-${element(local.azs, count.index)}"
    "karpenter.sh/discovery" = module.eks.cluster_name
  })
}

data "aws_route_tables" "private_route_tables" {
  vpc_id = var.vpc.vpc_id

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

resource "aws_route_table_association" "karpenter" {
  count = length(var.karpenter.subnet_cidrs)

  subnet_id      = aws_subnet.karpenter[count.index].id
  route_table_id = try(data.aws_route_tables.private_route_tables.ids[count.index], data.aws_route_tables.private_route_tables.ids[0], "") # Depends on the number of Nat Gateways
}

module "karpenter_security_group" {
  source = "./modules/security-group"

  name        = "karpenter-default-${local.stack_name}"
  description = "Karpenter default security group"

  vpc_id = var.vpc.vpc_id

  ingress_rules = {
    self_all = {
      type      = "ingress"
      protocol  = "-1"
      from_port = 0
      to_port   = 65535
      self      = true
    }
    control_plane_other = {
      type                     = "ingress"
      protocol                 = "TCP"
      from_port                = 1025
      to_port                  = 65535
      source_security_group_id = module.eks.cluster_primary_security_group_id
    }
    vpc_all = {
      type        = "ingress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 65535
      cidr_blocks = [var.vpc.vpc_cidr]
    }
  }
  egress_rules = {
    all = {
      type        = "egress"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${local.stack_name}" = "owned"
    "karpenter.sh/discovery"                    = local.stack_name
  })
}
