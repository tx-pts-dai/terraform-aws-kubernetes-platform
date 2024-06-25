# Datadog Operator

locals {
  datadog_site = "datadoghq.eu"
  datadog_operator_helm_values = concat(
    [{ name = "site", value = local.datadog_site }],
  var.datadog_operator_helm_values)
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
  chart_version    = try(var.datadog.operator_chart_version, "1.8.1")
  atomic           = true
  create_namespace = true

  set = local.datadog_operator_helm_values
}

################################################################################
# Datadog Secret - ExternalSecrets for both monitoring and kube-system NS

resource "helm_release" "datadog_secrets" {
  name       = "datadog-secrets"
  repository = "https://dnd-it.github.io/helm-charts"
  chart      = "custom-resources"
  version    = try(var.datadog.custom_resource_chart_version, null)

  values = [
    <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: datadog-keys
      namespace: ${var.namespace}
    spec:
      refreshInterval: 1m0s
      secretStoreRef:
        name: aws-secretsmanager
        kind: ClusterSecretStore
      target:
        name: datadog-keys
        creationPolicy: Owner
      data:
      - secretKey: api-key
        remoteRef:
          key: ${var.datadog_secret}
          property: api_key
      - secretKey: app-key
        remoteRef:
          key: ${var.datadog_secret}
          property: app_key
  YAML
  ]
  depends_on = [module.datadog_operator]
}

resource "helm_release" "datadog_secrets_fargate" {
  name       = "datadog-secrets-fargate"
  repository = "https://dnd-it.github.io/helm-charts"
  chart      = "custom-resources"
  version    = try(var.datadog.custom_resource_chart_version, null)

  values = [
    <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: datadog-keys
      namespace: kube-system
    spec:
      refreshInterval: 1m0s
      secretStoreRef:
        name: aws-secretsmanager
        kind: ClusterSecretStore
      target:
        name: datadog-keys
        creationPolicy: Owner
      data:
      - secretKey: api-key
        remoteRef:
          key: ${var.datadog_secret}
          property: api_key
      - secretKey: app-key
        remoteRef:
          key: ${var.datadog_secret}
          property: app_key
  YAML
  ]
  depends_on = [module.datadog_operator]
}

################################################################################
# Datadog Agent

resource "helm_release" "datadog_agent" {
  name       = "datadog-agent"
  repository = "https://dnd-it.github.io/helm-charts"
  chart      = "custom-resources"
  version    = try(var.datadog.custom_resource_chart_version, null)

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
        site: ${local.datadog_site}
        credentials:
          apiSecret:
            secretName: datadog-keys
            keyName: api-key
          appSecret:
            secretName: datadog-keys
            keyName: app-key
      agent:
        properties:
      features:
        apm:
          enabled: true
        logCollection:
          enabled: true
        admissionController:
            enabled: true
            mutateUnlabelled: true
            agentCommunicationMode: service
            agentSidecarInjection:
              enabled: true
              clusterAgentCommunicationEnabled: false
              registry: public.ecr.aws/datadog
              image:
                name: agent
                tag: ${var.datadog_agent_version_fargate}
              provider: fargate
              profiles:
                - env:
                  - name: DD_APM_ENABLED
                    value: "false"
                  - name: DD_API_KEY
                    valueFrom:
                      secretKeyRef:
                        name: datadog-keys
                        key: api-key
                  - name: DD_APP_KEY
                    valueFrom:
                      secretKeyRef:
                        name: datadog-keys
                        key: app-key
                  - name: DD_LOGS_ENABLED
                    value: "false"
                  - name: DD_ENV
                    value: "${var.environment}"
                  - name: DD_CLUSTER_NAME
                    value: "${var.cluster_name}"
              selectors:
              - objectSelector:
                  matchLabels:
                    "app.kubernetes.io/name": karpenter
      override:
        clusterAgent:
          containers:
            cluster-agent:
              resources:
                requests:
                  cpu: 40m
                  memory: 200Mi
                limits:
                  memory: 300Mi
        nodeAgent:
          priorityClassName: system-node-critical
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
    for_each = var.datadog_agent_helm_values
    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }
  # Dependency on the eternal secrets, otherwise it will fail
  depends_on = [module.datadog_operator, helm_release.datadog_secrets, helm_release.datadog_secrets_fargate]
}

resource "kubernetes_annotations" "this" {
  api_version = "apps/v1"
  kind        = "Deployment"
  metadata {
    name      = "karpenter"
    namespace = "kube-system"
  }
  # These annotations will be applied to the Deployment resource itself
  annotations = {
    "datadog-values-sha" = sha256(join("", helm_release.datadog_agent.values))
  }
  template_annotations = {
    # These annotations will be applied to the Pods created by the Deployment
    "datadog-values-sha" = sha256(join("", helm_release.datadog_agent.values))
  }
  depends_on = [helm_release.datadog_agent]
}

resource "kubectl_manifest" "fargate_cluster_role" {
  yaml_body = file("${path.module}/manifests/cluster_role.yaml")
}

resource "kubectl_manifest" "fargate_role_binding" {
  yaml_body = file("${path.module}/manifests/role_binding.yaml")
}
