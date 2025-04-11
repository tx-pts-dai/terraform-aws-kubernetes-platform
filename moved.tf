moved {
  from = aws_security_group_rule.eks_control_plan_ingress
  to   = aws_security_group_rule.eks_control_plane_ingress
}

removed {
  from = module.karpenter_release.helm_release.additional

  lifecycle {
    destroy = false
  }
}
