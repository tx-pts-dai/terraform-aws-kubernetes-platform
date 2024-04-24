# Datadog Operator
resource "datadog_api_key" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0
  name  = var.datadog.agent_api_key_name
}

resource "datadog_application_key" "datadog_agent" {
  count = var.enable_datadog ? 1 : 0
  name  = var.datadog.agent_app_key_name
}

module "datadog" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0"

  max_history      = 10
  create           = var.enable_datadog
  chart            = "datadog/datadog-operator"
  repository       = "https://helm.datadoghq.com"
  chart_version    = try(var.datadog.operator_chart_version, "1.6.0")
  description      = "Open source Kubernetes Operator that enables you to deploy and configure the Datadog Agent in a Kubernetes environment"
  namespace        = "monitoring"
  create_namespace = true

  values = try(var.datadog.values, [])

  set = {
    name  = "site"
    value = var.datadog.site
  }

  set_sensitive = [
    {
      name  = "apiKey"
      value = datadog_api_key.datadog_agent[0].key
    },
    {
      name  = "appKey"
      value = datadog_application_key.datadog_agent[0].key
    },
  ]

  tags = local.tags
}

resource "kubernetes_secret" "datadog_keys" { # TODO: do we need this also in AWS secretsmanager?
  count = var.enable_datadog ? 1 : 0
  metadata {
    name      = "datadog-keys"
    namespace = "datadog"
  }

  data = {
    api-key = datadog_api_key.datadog_agent[0].key
    app-key = datadog_application_key.datadog_agent[0].key
  }
}

################################################################################
# Datadog Agent

resource "kubectl_manifest" "datadog_agent" {
  depends_on = [module.datadog]
  yaml_body  = <<-YAML
    apiVersion: datadoghq.com/v2alpha1
    kind: DatadogAgent
    metadata:
      name: datadog
    spec:
      global:
        credentials:
          apiSecret:
            secretName: datadog-secret
            keyName: api-key
          appSecret:
            secretName: datadog-secret
            keyName: app-key
      features:
        apm:
          enabled: true
        logCollection:
          enabled: true
  YAML 
}