# Datadog Operator
resource "helm_release" "datadog_operator" {
  name             = "datadog-operator"
  repository       = "https://helm.datadoghq.com"
  description      = "Open source Kubernetes Operator that enables you to deploy and configure the Datadog Agent in a Kubernetes environment"
  chart            = "datadog-operator"
  namespace        = var.namespace
  max_history      = 3
  version          = var.datadog_operator_helm_version
  atomic           = true
  cleanup_on_fail  = true
  create_namespace = true

  values = concat([
    <<-YAML
    clusterName: ${var.cluster_name}
    site: datadoghq.eu

    apiKeyExistingSecret: datadog-keys
    appKeyExistingSecret: datadog-keys

    datadogAgent:
      enabled: true
    datadogDashboard:
      enabled: true
    datadogGenericResource:
      enabled: true
    datadogMonitor:
      enabled: true
    remoteConfiguration:
      enabled: true

    datadogCRDs:
      crds:
        datadogAgents: true
        datadogMetrics: true
        datadogPodAutoscalers: true
        datadogMonitors: true
        datadogSLOs: false
        datadogDashboards: true
        datadogGenericResources: true

    resources:
      requests:
        cpu: 50m
        memory: 128Mi

    watchNamespaces:
      - ""

    clusterRole:
      allowReadAllResources: true

    YAML
  ], var.datadog_operator_helm_values)

  dynamic "set" {
    for_each = var.datadog_operator_helm_set

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  depends_on = [
    helm_release.datadog_secrets,
  ]

}

################################################################################
# Datadog Secret - ExternalSecrets for both monitoring and kube-system NS

resource "helm_release" "datadog_secrets" {
  name             = "datadog-secrets"
  repository       = "https://dnd-it.github.io/helm-charts"
  chart            = "custom-resources"
  version          = "0.1.2"
  namespace        = var.namespace
  max_history      = 3
  create_namespace = true

  values = [
    <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: datadog-keys
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
          property: DD_API_KEY
      - secretKey: app-key
        remoteRef:
          key: ${var.datadog_secret}
          property: DD_APP_KEY
    YAML
  ]
}

resource "helm_release" "datadog_secrets_fargate" {
  name        = "datadog-secrets-fargate"
  repository  = "https://dnd-it.github.io/helm-charts"
  chart       = "custom-resources"
  version     = "0.1.2"
  namespace   = "kube-system"
  max_history = 3

  values = [
    <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: datadog-keys
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
          property: DD_API_KEY
      - secretKey: app-key
        remoteRef:
          key: ${var.datadog_secret}
          property: DD_APP_KEY
    YAML
  ]
}

################################################################################
# Datadog Agent - available specs options https://github.com/DataDog/datadog-operator/blob/main/docs/configuration.v2alpha1.md

resource "helm_release" "datadog_agent" {
  name        = "datadog-agent"
  repository  = "https://dnd-it.github.io/helm-charts"
  chart       = "custom-resources"
  version     = "0.1.2"
  namespace   = var.namespace
  max_history = 3

  values = concat([
    <<-YAML
    apiVersion: datadoghq.com/v2alpha1
    kind: DatadogAgent
    metadata:
      name: datadog-agent
    spec:
      global:
        clusterName: ${var.cluster_name}
        site: datadoghq.eu
        tags:
          - "cluster:${var.cluster_name}"
          - "env:${var.environment}-${var.product_name}"
          - "product:${var.product_name}"
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
          containerCollectAll: true
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
              tag: 7
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
                  - name: DD_TAGS
                    value: "env:${var.environment}-${var.product_name}"
            selectors:
              - objectSelector:
                  matchLabels:
                    app.kubernetes.io/name: karpenter
      override:
        clusterAgent:
          priorityClassName: system-cluster-critical
          replicas: 2
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
  ], var.datadog_agent_helm_values)

  dynamic "set" {
    for_each = var.datadog_agent_helm_set

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  # Dependency on the external secrets, otherwise it will fail
  depends_on = [
    helm_release.datadog_operator,
    helm_release.datadog_secrets,
    helm_release.datadog_secrets_fargate,
  ]
}

# Delays the annotations until the Datadog Agent is ready
resource "time_sleep" "this" {
  create_duration = "60s"
  triggers = {
    helm_values = sha256(join("", helm_release.datadog_agent.values))
  }
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
  depends_on = [time_sleep.this]
}

resource "kubectl_manifest" "fargate_cluster_role" {
  yaml_body = file("${path.module}/manifests/cluster_role.yaml")
}

resource "kubectl_manifest" "fargate_role_binding" {
  yaml_body = file("${path.module}/manifests/role_binding.yaml")
}
