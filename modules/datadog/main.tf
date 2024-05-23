resource "kubernetes_secret" "datadog_keys" { # TODO: do we need this also in AWS secretsmanager?
  depends_on = [module.datadog_operator]
  metadata {
    name      = "datadog-keys"
    namespace = var.namespace
  }

  data = {
    api-key = datadog_api_key.datadog_agent.key
    app-key = datadog_application_key.datadog_agent.key
  }
}
# Datadog Operator
resource "datadog_api_key" "datadog_agent" {
  name = try(var.datadog.agent_api_key_name, var.cluster_name)
}

resource "datadog_application_key" "datadog_agent" {
  name = try(var.datadog.agent_app_key_name, var.cluster_name)
}

module "datadog_operator" {
  source  = "aws-ia/eks-blueprints-addon/aws"
  version = "~> 1.0"

  name             = "datadog-operator"
  repository       = "https://helm.datadoghq.com"
  description      = "Open source Kubernetes Operator that enables you to deploy and configure the Datadog Agent in a Kubernetes environment"
  chart            = "datadog-operator"
  namespace        = var.namespace
  max_history      = 10
  chart_version    = try(var.datadog.operator_chart_version, "1.6.0")
  atomic           = true
  create_namespace = true

  set = [
    for pair in var.datadog_operator_values :
    {
      name  = pair.key
      value = pair.value
    }
  ]

  set_sensitive = [
    for pair in var.datadog_operator_sensitive_values :
    {
      name  = pair.key
      value = pair.value
    }
  ]
}

################################################################################
# Datadog Agent

resource "helm_release" "datadog_agent" {
  name    = "datadog-agent"
  chart   = "https://dnd-it.github.io/helm-charts/custom-resources"
  version = try(var.datadog.custom_resource_chart_version, "0.1.2")

  values = [
    <<-YAML
    apiVersion: datadoghq.com/v2alpha1
    kind: DatadogAgent
    metadata:
      name: datadog-agent
      namespace: ${var.namespace}
    spec:
      global:
        clusterName: ${var.cluster_name}
        site: ${var.datadog_agent_values.site}
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
    override:
      clusterAgent:
        containers:
          cluster-agent:
            resources:
              requests:
                cpu: 30m
                memory: 200Mi
              limits:
                memory: 300Mi
      nodeAgent:
        containers:
          process-agent:
            resources:
              requests:
                cpu: 10m
                memory: 64Mi
              limits:
                memory: 128Mi
          trace-agent:
            resources:
              requests:
                cpu: 35m
                memory: 56Mi
              limits:
                memory: 100Mi
  YAML
  ]

  dynamic "set" {
    for_each = var.datadog_agent_values
    content {
      name  = set.key
      value = set.value
    }
  }

  depends_on = [module.datadog_operator, kubernetes_secret.datadog_keys]
}
