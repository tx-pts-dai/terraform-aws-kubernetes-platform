# Pre v1

moved {
  from = aws_security_group_rule.eks_control_plan_ingress
  to   = aws_security_group_rule.eks_control_plane_ingress
}

# migrations: v2.0 > v2.1
moved {
  from = module.karpenter_crds.helm_release.this[0]
  to   = helm_release.karpenter_crd
}

moved {
  from = module.karpenter_release.helm_release.this[0]
  to   = helm_release.karpenter
}

# Remove the additional helm releases (ec2 node class and node pool) and the helm chart will take over
removed {
  from = module.karpenter_release.helm_release.additional

  lifecycle {
    destroy = false
  }
}

moved {
  from = module.cluster_secret_store.helm_release.this[0]
  to   = helm_release.cluster_secret_store[0]
}

moved {
  from = module.reloader.helm_release.this[0]
  to   = helm_release.reloader
}
