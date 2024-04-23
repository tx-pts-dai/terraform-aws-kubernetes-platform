data "aws_caller_identity" "this" {}

resource "lacework_agent_access_token" "kubernetes" {
  name        = "${var.cluster_name}-${data.aws_caller_identity.this.account_id}-kubernetes"
  description = "For the kubernetes agent"
}

resource "kubernetes_namespace_v1" "lacework" {
  metadata {
    name = var.namespace
  }
}

module "lacework_k8s_datacollector" {
  source  = "lacework/agent/kubernetes"
  version = "2.5.1"

  namespace = kubernetes_namespace_v1.lacework.metadata[0].name

  lacework_access_token = lacework_agent_access_token.kubernetes.token
  lacework_server_url   = var.server_url
  lacework_cluster_name = var.cluster_name

  pod_cpu_request         = var.resources.cpu_request
  pod_mem_request         = var.resources.mem_request
  pod_cpu_limit           = var.resources.cpu_limit
  pod_mem_limit           = var.resources.mem_limit
  pod_priority_class_name = var.pod_priority_class_name

  node_affinity = var.node_affinity
  tolerations   = var.tolerations
}
