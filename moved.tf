moved {
  from = aws_security_group_rule.eks_control_plan_ingress
  to   = aws_security_group_rule.eks_control_plane_ingress
}
