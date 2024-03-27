resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server"
  chart      = "metrics-server"
  version    = "3.12.0"
  namespace  = "kube-system"
  values = [
    templatefile("${path.module}/values/metrics-server.yaml", {
    })
  ]
}
