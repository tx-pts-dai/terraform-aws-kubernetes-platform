# Migration from blueprints module to eks-addons module
moved {
  from = module.addons.aws_eks_addon.this["coredns"]
  to   = module.eks_addons.aws_eks_addon.this["coredns"]
}

moved {
  from = module.addons.aws_eks_addon.this["aws-ebs-csi-driver"]
  to   = module.eks_addons.aws_eks_addon.this["aws-ebs-csi-driver"]
}

# Move to resources that don't depend on resources, fargate profiles in particular.
moved {
  from = module.eks.aws_eks_addon.this["kube-proxy"]
  to   = module.eks.aws_eks_addon.before_compute["kube-proxy"]
}

moved {
  from = module.eks.aws_eks_addon.this["vpc-cni"]
  to   = module.eks.aws_eks_addon.before_compute["vpc-cni"]
}

moved {
  from = module.addons.kubernetes_namespace_v1.aws_observability[0]
  to   = kubernetes_namespace_v1.aws_observability[0]
}

moved {
  from = module.addons.kubernetes_config_map_v1.aws_logging[0]
  to   = kubernetes_config_map_v1.aws_logging[0]
}

moved {
  from = module.addons.aws_cloudwatch_log_group.fargate_fluentbit[0]
  to   = aws_cloudwatch_log_group.fargate_fluentbit[0]
}

# Auto Mode support: the self-managed Karpenter raw resources became conditional
# (count). These moves keep existing (Auto Mode disabled) deployments stable.
# Note: aws_iam_policy.karpenter_controller itself has no moved block here — it
# was replaced by the inline aws_iam_role_policy.karpenter_controller[0] (a
# different resource type, which moved blocks cannot bridge), matching how main
# shipped that same transition (commit 4199874) with no moved block either.
moved {
  from = helm_release.karpenter_crd
  to   = helm_release.karpenter_crd[0]
}

moved {
  from = helm_release.karpenter_release
  to   = helm_release.karpenter_release[0]
}

moved {
  from = helm_release.karpenter_resources
  to   = helm_release.karpenter_resources[0]
}

moved {
  from = time_sleep.wait_after_karpenter
  to   = time_sleep.wait_after_karpenter[0]
}

# Disabled since it needs to be removed and readded.
# removed {
#   from = helm_release.cluster_secret_store

#   lifecycle {
#     destroy = false
#   }
# }
