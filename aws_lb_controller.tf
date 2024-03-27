module "eks_addons_aws_lb_controller" {
  source  = "aws-ia/eks-blueprints-addons/aws"
  version = "~> 1.0" #ensure to update this to the latest/desired version

  cluster_name      = module.eks.cluster_name
  cluster_endpoint  = module.eks.cluster_endpoint
  cluster_version   = module.eks.cluster_version
  oidc_provider_arn = module.eks.oidc_provider_arn

  enable_aws_load_balancer_controller = true
  aws_load_balancer_controller = {
    atomic             = true
    cleanup_on_failure = true
    wait               = true
  }

  enable_external_dns            = true
  external_dns_route53_zone_arns = [aws_route53_zone.private.arn]
  external_dns = {
    set = [{
      name  = "policy"
      value = "sync" # allows deletion of dns records
    }]
  }
}

data "kubernetes_service_account_v1" "aws_alb_ingress_controller" {
  metadata {
    name      = "aws-load-balancer-controller-sa"
    namespace = "kube-system"
  }

  depends_on = [
    module.eks_addons_aws_lb_controller
  ]
}

# Give access to read the okta-monitoring-oidc secret in order to create new load balancers correctly when using Okta integration through annotations
# requires kubernetes provider
resource "kubernetes_cluster_role_v1" "read_oidc_secret" {
  metadata {
    name = "read-oidc-secret"
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    resource_names = ["okta-monitoring-oidc"]
    verbs          = ["get", "watch", "list"]
  }
}

# requires kubernetes provider
resource "kubernetes_cluster_role_binding_v1" "ingress_can_read_oidc_secret" {
  metadata {
    name = "read-oidc-secret"
  }
  role_ref {
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.read_oidc_secret.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }
  subject {
    kind      = "ServiceAccount"
    name      = data.kubernetes_service_account_v1.aws_alb_ingress_controller.metadata[0].name
    namespace = data.kubernetes_service_account_v1.aws_alb_ingress_controller.metadata[0].namespace
  }
}
