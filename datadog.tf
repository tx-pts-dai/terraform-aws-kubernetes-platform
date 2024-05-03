# Datadog Operator
resource "datadog_api_key" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0
  name  = try(var.datadog.agent_api_key_name, local.stack_name)
}

resource "datadog_application_key" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0
  name  = try(var.datadog.agent_app_key_name, local.stack_name)
}

resource "helm_release" "datadog" {
  count      = var.enable_datadog ? 1 : 0
  depends_on = [kubectl_manifest.karpenter_node_pool]

  name             = "datadog-operator"
  repository       = "https://helm.datadoghq.com"
  description      = "Open source Kubernetes Operator that enables you to deploy and configure the Datadog Agent in a Kubernetes environment"
  chart            = "datadog-operator"
  namespace        = "monitoring"
  version          = try(var.datadog.operator_chart_version, "1.6.0")
  max_history      = 10
  create_namespace = true

  values = []

  set {
    name  = "site"
    value = var.datadog.site
  }
}

resource "kubernetes_secret" "datadog_keys" { # TODO: do we need this also in AWS secretsmanager?
  count      = var.enable_datadog ? 1 : 0
  depends_on = [helm_release.datadog]
  metadata {
    name      = "datadog-keys"
    namespace = "monitoring"
  }

  data = {
    api-key = datadog_api_key.datadog_agent[0].key
    app-key = datadog_application_key.datadog_agent[0].key
  }
}

################################################################################
# Datadog Agent

resource "kubectl_manifest" "datadog_agent" {
  count      = var.enable_datadog ? 1 : 0
  depends_on = [helm_release.datadog, kubernetes_secret.datadog_keys, kubectl_manifest.karpenter_node_pool]
  # full list of features available https://github.com/DataDog/datadog-operator/blob/main/examples/datadogagent/v2alpha1/datadog-agent-all.yaml
  # TODO: decide if we want to pass the whole yaml or single variables
  # TODO: if kept like this, double check default features and add anything that is missing for stronger defaults
  yaml_body = try(var.datadog.agent_manifest, <<-YAML
    apiVersion: datadoghq.com/v2alpha1
    kind: DatadogAgent
    metadata:
      name: datadog-agent
      namespace: monitoring
    spec:
      global:
        clusterName: ${local.stack_name}
        site: ${var.datadog.site}
        credentials:
          apiSecret:
            secretName: datadog-keys
            keyName: api-key
          appSecret:
            secretName: datadog-keys
            keyName: app-key
      features:
        apm:
          enabled: true
        logCollection:
          enabled: true
  YAML
  )
}
