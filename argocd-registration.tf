################################################################################
# ArgoCD Dynamic Cluster Registration
################################################################################

module "argocd_registration" {
  source = "./modules/argocd-registration"

  create                 = var.enable_argocd_registration
  github_repository      = try(var.argocd_registration.github_repository, "")
  github_branch          = try(var.argocd_registration.github_branch, "main")
  argocd_hub_environment = try(var.argocd_registration.argocd_hub_environment, "prod")

  cluster_name          = module.eks.cluster_name
  cluster_endpoint      = module.eks.cluster_endpoint
  cluster_ca_data       = module.eks.cluster_certificate_authority_data
  argocd_spoke_role_arn = module.argocd.spoke_iam_role_arn
  aws_account_id        = data.aws_caller_identity.current.account_id
  aws_region            = data.aws_region.current.name
  vpc_cidr              = var.vpc.vpc_cidr

  cluster_labels = try(var.argocd_registration.cluster_labels, null)

  depends_on = [
    module.argocd,
    module.eks,
  ]
}
