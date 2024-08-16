###############################################################################
# Kubernetes Platform Monitoring Stack

# Base infra logging
# Deploy fluentbit with the fluent-operator and configure it so that pods with the ${var.fluent_operator.log_annotation} annotation have
# they logs pushed to CloudWatch.
# By default (hardcoded), fluent-operator and fluent-bit will have this annotation set
locals {
  # Namespace for all monitoring resources
  monitoring_namespace                     = "monitoring"
  fluentbit_cloudwatch_log_group           = "/${local.stack_name}/fluentbit-logs"
  fluentbit_cloudwatch_log_stream_prefix   = "."
  fluentbit_cloudwatch_log_stream_template = "$kubernetes['namespace_name'].$kubernetes['pod_name'].$kubernetes['container_name'].$kubernetes['docker_id']"
  fluentbit_tag                            = "kaas"
  log_annotation                           = var.fluent_operator.enabled ? format("%s: \"%s\"", var.fluent_operator.log_annotation.name, var.fluent_operator.log_annotation.value) : ""

  okta_oidc_config = jsonencode({
    issuer                = var.okta_integration.base_url,
    authorizationEndpoint = "${var.okta_integration.base_url}/oauth2/v1/authorize",
    tokenEndpoint         = "${var.okta_integration.base_url}/oauth2/v1/token",
    userInfoEndpoint      = "${var.okta_integration.base_url}/oauth2/v1/userinfo",
    secretName            = var.okta_integration.kubernetes_secret_name,
  })
}

###############################################################################
# fluent operator (https://github.com/fluent/fluent-operator operator)

resource "helm_release" "fluent_operator" {
  count = var.fluent_operator.enabled ? 1 : 0

  chart       = "fluent-operator"
  name        = "fluent-operator"
  repository  = "https://fluent.github.io/helm-charts"
  version     = "v3.0.0" # Note: using "v3.0" will issue in resource update on each terraform plan/apply
  max_history = 3

  create_namespace = true
  namespace        = local.monitoring_namespace

  values = [
    <<-YAML
    containerRuntime: containerd
    operator:
      priorityClassName: system-cluster-critical
      annotations:
        ${local.log_annotation}
    fluentbit:
      priorityClassName: system-node-critical
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                  - key: kubernetes.io/os
                    operator: In
                    values:
                      - linux
                  - key: kubernetes.io/arch
                    operator: In
                    values:
                      - amd64
                      - arm64
                  - key: eks.amazonaws.com/compute-type
                    operator: NotIn
                    values:
                      - fargate
      annotations:
        ${local.log_annotation}
      # Because we deploy our own pipeline, disable the default one
      filter:
        kubernetes:
          enable: false # true = default
        containerd:
          enable: true # If disabled, fluent-operator has reconciler error
      input:
        tail:
          enable: false # true = default
      serviceAccountAnnotations:
        eks.amazonaws.com/role-arn: ${module.fluentbit_irsa[0].iam_role_arn}
    YAML
  ]

  depends_on = [
    helm_release.karpenter
  ]
}

# KaaS pipeline
# Idea is to have an INPUT-FILTERS-OUTPUT pipeline
# To differenciate with other pipelines we tag the log entries with local.fluentbit_tag
resource "kubectl_manifest" "fluentbit_cluster_input_pipeline" {
  yaml_body = <<-YAML
    apiVersion: fluentbit.fluent.io/v1alpha2
    kind: ClusterInput
    metadata:
      name: kaas-pipeline
      labels:
        fluentbit.fluent.io/enabled: "true"
    spec:
      tail:
        db: /fluent-bit/tail/pos-${local.fluentbit_tag}.db # Not sure it's required to have a different db for different input
        dbSync: Normal
        memBufLimit: 100MB
        parser: cri
        path: /var/log/containers/*.log
        readFromHead: false
        refreshIntervalSeconds: 10
        skipLongLines: true
        storageType: memory
        tag: ${local.fluentbit_tag}.*
  YAML

  depends_on = [
    helm_release.fluent_operator
  ]
}

# Fluentbit filters to log KaaS pods to cloudwatch
resource "kubectl_manifest" "fluentbit_cluster_filter_pipeline" {
  count = var.fluent_operator.enabled ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: fluentbit.fluent.io/v1alpha2
    kind: ClusterFilter
    metadata:
      name: kaas-pipeline
      labels:
        fluentbit.fluent.io/enabled: "true"
    spec:
      match: ${local.fluentbit_tag}.*
      filters:
      - lua:
          script:
            key: containerd.lua
            name: fluent-bit-containerd-config
          call: containerd
          timeAsTable: true
      - kubernetes:
          kubeURL: https://kubernetes.default.svc:443
          kubeCAFile: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          kubeTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
          kubeTagPrefix: ${local.fluentbit_tag}.var.log.containers
          labels: true
          annotations: true
      - nest:
          operation: lift
          nestedUnder: kubernetes
          addPrefix: kubernetes_
      - modify:
          rules:
          - remove: stream
          - remove: kubernetes_pod_id
          - remove: kubernetes_host
          - remove: kubernetes_container_hash
      - nest:
          operation: nest
          wildcard:
          - kubernetes_*
          nestUnder: kubernetes
          removePrefix: kubernetes_
      - grep:
          regex: $kubernetes['annotations']['${var.fluent_operator.log_annotation.name}'] ^${var.fluent_operator.log_annotation.value}$
  YAML

  depends_on = [
    helm_release.fluent_operator
  ]
}

resource "kubectl_manifest" "fluentbit_cluster_output_pipeline" {
  count = var.fluent_operator.enabled ? 1 : 0

  yaml_body = <<-YAML
    apiVersion: fluentbit.fluent.io/v1alpha2
    kind: ClusterOutput
    metadata:
      name: kaas-pipeline
      labels:
        fluentbit.fluent.io/enabled: "true"
    spec:
      customPlugin:
        config: |
          Name cloudwatch_logs
          Match ${local.fluentbit_tag}.*
          region ${data.aws_region.current.name}
          log_group_name ${local.fluentbit_cloudwatch_log_group}
          log_stream_prefix ${local.fluentbit_cloudwatch_log_stream_prefix}
          log_stream_template ${local.fluentbit_cloudwatch_log_stream_template}
          auto_create_group On # Fixed in 3.1.6 - Has to be set to On: https://github.com/fluent/fluent-bit/issues/8949
    YAML

  depends_on = [
    helm_release.fluent_operator
  ]
}

# CloudWatch log group and permission to allow fluent-bit to write log stream
resource "aws_cloudwatch_log_group" "fluentbit" {
  count = var.fluent_operator.enabled ? 1 : 0

  name              = local.fluentbit_cloudwatch_log_group
  retention_in_days = var.fluent_operator.cloudwatch_retention_in_days
}

data "aws_iam_policy_document" "fluentbit" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["${aws_cloudwatch_log_group.fluentbit[0].arn}:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_policy" "fluentbit" {
  count = var.fluent_operator.enabled ? 1 : 0

  name   = "${local.stack_name}-fluentbit"
  policy = data.aws_iam_policy_document.fluentbit.json
  tags   = local.tags
}

# k8s Service account AWS iam role to allow fluent-bit writing log streams
module "fluentbit_irsa" {
  count = var.fluent_operator.enabled ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  role_name = "fluentbit-${local.id}"

  role_policy_arns = {
    policy = aws_iam_policy.fluentbit[0].arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.monitoring_namespace}:fluent-bit"]
    }
  }

  tags = local.tags
}


###############################################################################
# Prometheus Operator

resource "helm_release" "prometheus_operator_crds" {
  count = var.prometheus_stack.enabled ? 1 : 0

  name             = "prometheus-operator-crds"
  namespace        = local.monitoring_namespace
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "prometheus-operator-crds"
  version          = "13.0.2"
  max_history      = 3

  depends_on = [
    module.eks
  ]
}

resource "helm_release" "prometheus_stack" {
  count = var.prometheus_stack.enabled ? 1 : 0

  name             = "prometheus-stack"
  namespace        = local.monitoring_namespace
  create_namespace = true
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "61.8.0"
  skip_crds        = true
  wait             = true
  max_history      = 3

  values = [
    <<-EOT
    cleanPrometheusOperatorObjectNames: true
    prometheus:
      priorityClassName: system-cluster-critical
      ingress:
        enabled: true
        ingressClassName: alb
        hosts:
        - ${local.id}.prometheus.${local.primary_acm_domain}
        paths:
          - /*
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: ip
          alb.ingress.kubernetes.io/group.name: ${local.stack_name}
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80,"HTTPS":443}]'
          alb.ingress.kubernetes.io/ssl-redirect: '443'
          alb.ingress.kubernetes.io/healthcheck-path: /-/healthy
          alb.ingress.kubernetes.io/auth-type: oidc
          alb.ingress.kubernetes.io/auth-idp-oidc: '${local.okta_oidc_config}'
          alb.ingress.kubernetes.io/auth-scope: 'openid groups'
    alertmanager:
      priorityClassName: system-cluster-critical
      ingress:
        enabled: true
        ingressClassName: alb
        hosts:
        - ${local.id}.alertmanager.${local.primary_acm_domain}
        paths:
          - /*
        annotations:
          alb.ingress.kubernetes.io/scheme: internet-facing
          alb.ingress.kubernetes.io/target-type: ip
          alb.ingress.kubernetes.io/group.name: ${local.stack_name}
          alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80,"HTTPS":443}]'
          alb.ingress.kubernetes.io/ssl-redirect: '443'
          alb.ingress.kubernetes.io/healthcheck-path: /-/healthy
          alb.ingress.kubernetes.io/auth-type: oidc
          alb.ingress.kubernetes.io/auth-idp-oidc: '${local.okta_oidc_config}'
          alb.ingress.kubernetes.io/auth-scope: 'openid groups'
    prometheus-node-exporter:
      priorityClassName: system-node-critical
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
              nodeSelectorTerms:
                - matchExpressions:
                  - key: kubernetes.io/os
                    operator: In
                    values:
                      - linux
                  - key: kubernetes.io/arch
                    operator: In
                    values:
                      - amd64
                      - arm64
                  - key: eks.amazonaws.com/compute-type
                    operator: NotIn
                    values:
                      - fargate
      resources:
        requests:
          cpu: 10m
          memory: 32Mi
    grafana:
      enabled: false
    kubeControllerManager:
      enabled: false
    kubeScheduler:
      enabled: false
    EOT
  ]

  depends_on = [
    helm_release.prometheus_operator_crds,
    helm_release.karpenter
  ]
}

# resource "helm_release" "alertmanager_pagerduty_config" {
#   count = var.pagerduty_integration.enabled ? 1 : 0

#   name        = "alertmanager-pagerduty-secrets"
#   namespace   = local.monitoring_namespace
#   repository  = "https://dnd-it.github.io/helm-charts"
#   chart       = "custom-resources"
#   version     = "0.1.0"
#   max_history = 3

#   values = [
#     <<-YAML
#     apiVersion: monitoring.coreos.com/v1beta1
#     kind: AlertmanagerConfig
#     metadata:
#       name: config-example
#       namespace: monitoring
#     spec:
#       route:
#         receiver: 'pagerduty'
#       receivers:
#       - name: "pagerduty"
#         pagerdutyConfigs:
#         - sendResolved: true
#           routingKey: "R028S12Q23R9IAM44G8VTAF850M03VUE"
#           severity: '{{ .CommonLabels.severity | default "critical" }}'
#       inhibitRules:
#       - sourceMatch:
#           severity: 'critical'
#         targetMatch:
#           severity: 'warning'
#         equal: ['alertname', 'namespace']
#     YAML
#   ]

#   depends_on = [
#     helm_release.prometheus_operator_crds
#   ]
# }

resource "helm_release" "pagerduty_secrets" {
  count = var.pagerduty_integration.enabled ? 1 : 0

  name        = "pagerduty-secrets"
  namespace   = local.monitoring_namespace
  repository  = "https://dnd-it.github.io/helm-charts"
  chart       = "custom-resources"
  version     = "0.1.0"
  max_history = 3

  values = [
    <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: pagerduty-secrets
    spec:
      refreshInterval: 5m0s
      secretStoreRef:
        name: aws-secretsmanager
        kind: ClusterSecretStore
      target:
        name: ${var.pagerduty_integration.kubernetes_secret_name}
        creationPolicy: Owner
      dataFrom:
        - extract:
            key: ${var.pagerduty_integration.secrets_manager_secret_name}
    YAML
  ]

  depends_on = [
    module.addons.external_secrets
  ]
}

###############################################################################
# Grafana

resource "helm_release" "grafana" {
  count = var.grafana.enabled ? 1 : 0

  name             = "grafana"
  namespace        = local.monitoring_namespace
  create_namespace = true
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "grafana"
  version          = "8.4.4"
  max_history      = 3
  wait             = true

  values = [
    <<-EOT
    serviceAccount:
      annotations:
        eks.amazonaws.com/role-arn: ${module.grafana_irsa[0].iam_role_arn}
    resources:
      requests:
        cpu: 100m
        memory: 128Mi
    ingress:
      enabled: true
      ingressClassName: alb
      hosts:
        - ${local.id}.grafana.${local.primary_acm_domain}
      annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/group.name: ${local.stack_name}
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80,"HTTPS":443}]'
        alb.ingress.kubernetes.io/ssl-redirect: '443'
        # Not required when using Okta
        # alb.ingress.kubernetes.io/auth-type: oidc
        # alb.ingress.kubernetes.io/auth-idp-oidc: '${local.okta_oidc_config}'
        # alb.ingress.kubernetes.io/auth-scope: 'openid groups'
    envFromSecrets:
      - name: okta
    grafana.ini:
      server:
        root_url: https://${local.id}.grafana.${local.primary_acm_domain}
        domain: ${local.id}.grafana.${local.primary_acm_domain}
        serve_from_sub_path: true
        router_logging: true
        enforce_domain: true
      analytics:
        check_for_updates: false
        check_for_plugin_updates: false
        reporting_enabled: false
      users:
        auto_assign_org_role: Editor
        viewers_can_edit: true
      auth:
        disable_login_form: true
        disable_signout_menu: true
      # JWT not supported https://github.com/grafana/grafana/pull/45191
      # auth.jwt:
      # Decide if we should use proxy or okta
      # auth.proxy:
      #   enabled: false
      #   auto_login: true
      #   header_name: x-amzn-oidc-identity
      auth.okta:
        enabled: true
        auto_login: true
        auth_url: ${var.okta_integration.base_url}/oauth2/v1/authorize
        token_url: ${var.okta_integration.base_url}/oauth2/v1/token
        api_url: ${var.okta_integration.base_url}/oauth2/v1/userinfo
        role_attribute_path: groups
    dashboardProviders:
      dashboardproviders.yaml:
        apiVersion: 1
        providers:
          - name: default
            orgId: 1
            folder: ""
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/default
          - name: kubernetes
            orgId: 1
            folder: Kubernetes
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/kubernetes
          - name: nginx
            orgId: 1
            folder: Nginx
            type: file
            disableDeletion: false
            editable: true
            options:
              path: /var/lib/grafana/dashboards/nginx
    datasources:
      datasources.yaml:
        apiVersion: 1
        deleteDatasources:
          - { name: Alertmanager, orgId: 1 }
          - { name: Prometheus, orgId: 1 }
        datasources:
          - name: Prometheus
            type: prometheus
            uid: prometheus
            access: proxy
            url: http://${helm_release.prometheus_stack[0].name}-kube-prom-prometheus.${local.monitoring_namespace}.svc.cluster.local:9090
            jsonData:
              prometheusType: Prometheus
            isDefault: true
          - name: Alertmanager
            type: alertmanager
            uid: alertmanager
            access: proxy
            url: http://alertmanager-operated.${local.monitoring_namespace}.svc.cluster.local:9093
            jsonData:
              implementation: prometheus
          - name: CloudWatch
            type: cloudwatch
            access: proxy
            uid: cloudwatch
            editable: false
            jsonData:
              authType: default
              defaultRegion: ${data.aws_region.current.name}
    dashboards:
      default:
        cert-manager:
          url: https://raw.githubusercontent.com/monitoring-mixins/website/master/assets/cert-manager/dashboards/cert-manager.json
          datasource: Prometheus
        external-dns:
          gnetId: 15038 # https://grafana.com/grafana/dashboards/15038?tab=revisions
          revision: 1
          datasource: Prometheus
        external-secrets:
          url: https://raw.githubusercontent.com/external-secrets/external-secrets/main/docs/snippets/dashboard.json
          datasource: Prometheus
        node-exporter-full:
          gnetId: 1860 # https://grafana.com/grafana/dashboards/1860?tab=revisions
          revision: 31
          datasource: Prometheus
        prometheus:
          url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-addons-prometheus.json
          datasource: Prometheus
      kubernetes:
        kubernetes-api-server:
          url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-system-api-server.json
          datasource: Prometheus
        kubernetes-coredns:
          url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-system-coredns.json
          datasource: Prometheus
        kubernetes-global:
          url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-views-global.json
          datasource: Prometheus
        kubernetes-namespaces:
          url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-views-namespaces.json
          datasource: Prometheus
        kubernetes-nodes:
          url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-views-nodes.json
          datasource: Prometheus
        kubernetes-pods:
          url: https://raw.githubusercontent.com/dotdc/grafana-dashboards-kubernetes/master/dashboards/k8s-views-pods.json
          datasource: Prometheus
      nginx:
        nginx:
          url: https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/grafana/dashboards/nginx.json
          datasource: Prometheus
        nginx-request-handling-performance:
          url: https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/grafana/dashboards/request-handling-performance.json
          datasource: Prometheus
    sidecar:
      dashboards:
        enabled: true
        searchNamespace: ALL
        labelValue: ""
        label: grafana_dashboard
        folderAnnotation: grafana_folder
        provider:
          disableDelete: true
          foldersFromFilesStructure: true
      datasources:
        enabled: true
        searchNamespace: ALL
        labelValue: ""
    serviceMonitor:
      enabled: ${var.prometheus_stack.enabled}
    testFramework:
      enabled: false
    EOT
  ]

  depends_on = [
    helm_release.karpenter,
    helm_release.okta_secrets
  ]
}

module "grafana_irsa" {
  count = var.grafana.enabled ? 1 : 0

  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  role_name = "grafana-${local.id}"

  role_policy_arns = {
    CloudWatchReadOnlyAccess = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess",
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.monitoring_namespace}:grafana"]
    }
  }

  tags = local.tags
}

###############################################################################
# Okta Secret

resource "helm_release" "okta_secrets" {
  count = var.okta_integration.enabled ? 1 : 0

  name       = "okta-secrets"
  namespace  = local.monitoring_namespace
  repository = "https://dnd-it.github.io/helm-charts"
  chart      = "custom-resources"
  version    = "0.1.0"

  values = [
    <<-YAML
    apiVersion: external-secrets.io/v1beta1
    kind: ExternalSecret
    metadata:
      name: okta-secrets
    spec:
      refreshInterval: 1m0s
      secretStoreRef:
        name: aws-secretsmanager
        kind: ClusterSecretStore
      target:
        name: ${var.okta_integration.kubernetes_secret_name}
        creationPolicy: Owner
      data:
        - secretKey: clientID
          remoteRef:
            key: ${var.okta_integration.secrets_manager_secret_name}
            property: clientID
        - secretKey: clientSecret
          remoteRef:
            key: ${var.okta_integration.secrets_manager_secret_name}
            property: clientSecret
        - secretKey: GF_AUTH_OKTA_CLIENT_ID
          remoteRef:
            key: ${var.okta_integration.secrets_manager_secret_name}
            property: clientID
        - secretKey: GF_AUTH_OKTA_CLIENT_SECRET
          remoteRef:
            key: ${var.okta_integration.secrets_manager_secret_name}
            property: clientSecret
  YAML
  ]

  depends_on = [
    module.addons.external_secrets
  ]
}

###############################################################################
