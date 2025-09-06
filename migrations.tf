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

# Disabled since it needs to be removed and readded.
# removed {
#   from = helm_release.cluster_secret_store

#   lifecycle {
#     destroy = false
#   }
# }
