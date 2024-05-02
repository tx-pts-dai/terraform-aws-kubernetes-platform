locals {
  datadog_site = try(var.datadog.site, "datadoghq.eu")
}

# Datadog Operator
resource "datadog_api_key" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0
  name  = try(var.datadog.agent_api_key_name, local.stack_name)
}

resource "datadog_application_key" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0
  name  = try(var.datadog.agent_app_key_name, local.stack_name)
}

module "datadog" {
  count   = var.enable_datadog ? 1 : 0 # required to avoid error on datadog_api_key.datadog_agent[0].key reference
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0"

  max_history      = 10
  create           = var.enable_datadog # this is not enough to avoid error on datadog_api_key.datadog_agent[0].key reference
  chart            = "datadog-operator"
  repository       = "https://helm.datadoghq.com"
  chart_version    = try(var.datadog.operator_chart_version, "1.6.0")
  description      = "Open source Kubernetes Operator that enables you to deploy and configure the Datadog Agent in a Kubernetes environment"
  namespace        = "monitoring"
  create_namespace = true

  values = try(var.datadog.values, [])

  set = [{
    name  = "site"
    value = local.datadog_site
  }]

  # set_sensitive = [
  #   {
  #     name  = "apiKey"
  #     value = var.datadog.api_key
  #   },
  #   {
  #     name  = "appKey"
  #     value = var.datadog.app_key
  #   },
  # ]

  tags = local.tags
}

resource "kubernetes_secret" "datadog_keys" { # TODO: do we need this also in AWS secretsmanager?
  count      = var.enable_datadog ? 1 : 0
  depends_on = [module.datadog]
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
  depends_on = [module.datadog]
  yaml_body  = <<-YAML
    apiVersion: datadoghq.com/v2alpha1
    kind: DatadogAgent
    metadata:
      name: datadog-agent
      namespace: monitoring
    spec:
      global:
        clusterName: ${local.stack_name}
        site: ${local.datadog_site}
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
}
