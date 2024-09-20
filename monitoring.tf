###############################################################################
# Kubernetes Platform Monitoring Stack

# Base infra logging
# Deploy fluentbit with the fluent-operator and configure it so that pods with the ${var.fluent_operator.log_annotation} annotation have
# they logs pushed to CloudWatch.
# By default (hardcoded), fluent-operator and fluent-bit will have this annotation set
locals {
  # Namespace for all monitoring resources
  monitoring_namespace                     = "monitoring"
  fluentbit_cloudwatch_log_group           = "/platform/${local.stack_name}/logs"
  fluentbit_cloudwatch_log_stream_prefix   = "."
  fluentbit_cloudwatch_log_stream_template = "$kubernetes['namespace_name'].$kubernetes['pod_name'].$kubernetes['container_name'].$kubernetes['docker_id']"
  log_annotation                           = var.enable_fluent_operator && var.fluent_log_annotation.name != "" ? "${var.fluent_log_annotation.name}: \"${var.fluent_log_annotation.value}\"" : "{}"

  okta_oidc_config = jsonencode({
    issuer                = var.okta.base_url,
    authorizationEndpoint = "${var.okta.base_url}/oauth2/v1/authorize",
    tokenEndpoint         = "${var.okta.base_url}/oauth2/v1/token",
    userInfoEndpoint      = "${var.okta.base_url}/oauth2/v1/userinfo",
    secretName            = var.okta.kubernetes_secret_name,
  })
}

# Enable pod readiness gate injection for the monitoring namespace.
# This allows for the AWS Load Balancer Controller add / remove pods
# from the load balancer when available
resource "kubernetes_annotations" "monitoring" {
  count = var.enable_aws_load_balancer_controller ? 1 : 0

  api_version = "v1"
  kind        = "Namespace"
  metadata {
    name = local.monitoring_namespace
  }
  annotations = {
    "elbv2.k8s.aws/pod-readiness-gate-inject" = "enabled"
  }

  depends_on = [
    module.prometheus_operator_crds
  ]
}

module "amp" {
  source  = "terraform-aws-modules/managed-service-prometheus/aws"
  version = "3.0.0"

  create = var.create_addons && var.enable_amp

  workspace_alias = local.stack_name
}

###############################################################################
# fluent operator (https://github.com/fluent/fluent-operator)

# ISSUE: helm uninstall deletes the operator before the custom resource are removed
# TODO: Split Custom Resources / Operator https://github.com/fluent/fluent-operator/pull/1348
module "fluent_operator" {
  source = "./modules/addon"

  create = var.create_addons && var.enable_fluent_operator

  chart         = "fluent-operator"
  chart_version = "3.1.0"
  repository    = "https://fluent.github.io/helm-charts"
  description   = "Fluent Operator"
  namespace     = local.monitoring_namespace

  create_namespace = true

  # https://github.com/fluent/fluent-operator/blob/master/charts/fluent-operator/values.yaml
  values = [
    file("${path.module}/files/helm/fluent-operator/common.yaml"),
    <<-EOT
    operator:
      annotations:
        ${local.log_annotation}
    fluentbit:
      image:
        tag: 3.1.7 # FIXES: Configuring log_group_class requires `auto_create_group On` - Remove when chart is updated
    EOT
  ]

  set = try(var.fluent_operator.set, [])

  create_role = var.create_addons && var.enable_fluent_operator

  set_irsa_names = ["fluentbit.serviceAccountAnnotations.eks\\.amazonaws\\.com/role-arn"]
  role_name      = "fluent-bit-${local.id}"
  role_policies = {
    fluentbit = try(aws_iam_policy.fluentbit[0].arn, "")
  }

  oidc_providers = {
    this = {
      provider_arn    = module.eks.oidc_provider_arn
      service_account = "fluent-bit"
    }
  }

  additional_delay_create_duration  = "10s" # TODO: Remove when CRDs are split out
  additional_delay_destroy_duration = "10s"

  additional_helm_releases = {
    fluentbit_cluster_filter_grep = {
      create = var.fluent_log_annotation.name != "" && var.fluent_log_annotation.value != ""

      description   = "Fluentbit Cluster Filter Grep"
      chart         = "custom-resources"
      chart_version = "0.1.0"
      repository    = "https://dnd-it.github.io/helm-charts"

      values = [
        <<-EOT
        apiVersion: fluentbit.fluent.io/v1alpha2
        kind: ClusterFilter
        metadata:
          name: z-grep
          labels:
            fluentbit.fluent.io/enabled: "true"
            fluentbit.fluent.io/component: logging
        spec:
          match: kube.*
          filters:
            - grep:
                regex: kubernetes['annotations']['${var.fluent_log_annotation.name}'] ^${var.fluent_log_annotation.value}$
        EOT
      ]
    }

    fluentbit_cluster_output_cloudwatch = {
      description   = "Fluentbit Cluster Output Cloudwatch"
      chart         = "custom-resources"
      chart_version = "0.1.0"
      repository    = "https://dnd-it.github.io/helm-charts"

      values = [
        <<-EOT
        apiVersion: fluentbit.fluent.io/v1alpha2
        kind: ClusterOutput
        metadata:
          name: cloudwatch
          labels:
            fluentbit.fluent.io/enabled: "true"
        spec:
          customPlugin:
            config: |
              Name cloudwatch_logs
              Match kube.*
              region ${data.aws_region.current.name}
              log_group_name ${local.fluentbit_cloudwatch_log_group}
              log_stream_prefix ${local.fluentbit_cloudwatch_log_stream_prefix}
              log_stream_template ${local.fluentbit_cloudwatch_log_stream_template}
        EOT
      ]
    }
  }

  depends_on = [
    module.addons
  ]
}

data "aws_iam_policy_document" "fluentbit" {
  count = var.create_addons && var.enable_fluent_operator ? 1 : 0

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
  count = var.create_addons && var.enable_fluent_operator ? 1 : 0

  name   = "fluent-bit-${local.id}"
  policy = data.aws_iam_policy_document.fluentbit[0].json
  tags   = local.tags
}

# CloudWatch log group and permission to allow fluent-bit to write log stream
resource "aws_cloudwatch_log_group" "fluentbit" {
  count = var.create_addons && var.enable_fluent_operator ? 1 : 0

  name              = local.fluentbit_cloudwatch_log_group
  retention_in_days = var.fluent_cloudwatch_retention_in_days
}

###############################################################################
# Prometheus Operator
locals {
  prometheus_service_url = try("https://${module.prometheus_stack.name}-prometheus.${local.monitoring_namespace}.svc.cluster.local:9090", "")
}

module "prometheus_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.0"

  create_role = var.create_addons && var.enable_prometheus_stack

  role_name = "prometheus-${local.id}"

  attach_amazon_managed_service_prometheus_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.monitoring_namespace}:kube-prometheus-stack-prometheus"]
    }
  }

  tags = local.tags
}

module "prometheus_operator_crds" {
  source = "./modules/addon"

  create = var.create_addons && var.enable_prometheus_stack

  chart         = "prometheus-operator-crds"
  chart_version = "13.0.2"
  repository    = "https://prometheus-community.github.io/helm-charts"
  description   = "Prometheus Operator CRDs"
  namespace     = local.monitoring_namespace

  create_namespace = true

  depends_on = [
    module.eks
  ]
}

module "prometheus_stack" {
  source = "./modules/addon"

  create = var.create_addons && var.enable_prometheus_stack

  chart         = "kube-prometheus-stack"
  chart_version = "61.8.0"
  repository    = "https://prometheus-community.github.io/helm-charts"
  description   = "Prometheus Stack"
  namespace     = local.monitoring_namespace

  skip_crds = true

  # https://github.com/prometheus-community/helm-charts/blob/main/charts/kube-prometheus-stack/values.yaml
  values = [
    file("${path.module}/files/helm/prometheus/common.yaml"),
    <<-EOT
    prometheus:
      serviceAccount:
        annotations:
          eks.amazonaws.com/role-arn: ${module.prometheus_irsa.iam_role_arn}
      ingress:
        enabled: ${var.enable_okta}
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
      prometheusSpec:
        # allow prometheus rules to be created in any namespace
        ruleSelectorNilUsesHelmValues: false
        %{if var.enable_amp}
        remoteWrite:
          - url: ${module.amp.workspace_prometheus_endpoint}api/v1/remote_write
            sigv4:
              region: ${local.region}
            queue_config:
              max_samples_per_send: 1000
              max_shards: 200
              capacity: 2500
        %{endif}
    alertmanager:
      ingress:
        enabled: ${var.enable_okta}
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
      alertmanagerSpec:
      %{if var.enable_pagerduty}
        secrets:
          - ${var.pagerduty.kubernetes_secret_name}
      config:
        route:
          receiver: "null"
          group_by: [...]
          continue: false
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 12h
          routes:
            - receiver: "null"
              matchers:
                - alertname="Watchdog"
              continue: false
            - receiver: pagerduty-critical
              match:
                severity: critical
              continue: false
            - receiver: pagerduty-warning
              match:
                severity: warning
              continue: false
            - receiver: pagerduty-info
              match:
                severity: info
              continue: false

        receivers:
          - name: "null"
          - name: pagerduty-critical
            pagerduty_configs:
            - send_resolved: true
              http_config:
                follow_redirects: true
                enable_http2: true
              routing_key_file: /etc/alertmanager/secrets/${var.pagerduty.kubernetes_secret_name}/pagerduty_dai_critical_support_hours_key
              url: https://events.pagerduty.com/v2/enqueue
              client: '{{ template "pagerduty.default.client" . }}'
              client_url: '{{ template "pagerduty.default.clientURL" . }}'
              description: '{{ template "pagerduty.default.description" .}}'
              details:
                alertname: '{{ .CommonLabels.alertname }}'
                description: '{{ .CommonAnnotations.description }}'
                firing: '{{ template "pagerduty.default.instances" .Alerts.Firing }}'
                instance: '{{ .CommonLabels.instance }}'
                num_firing: '{{ .Alerts.Firing | len }}'
                num_resolved: '{{ .Alerts.Resolved | len }}'
                resolved: '{{ template "pagerduty.default.instances" .Alerts.Resolved }}'
                severity: '{{ .CommonLabels.severity }}'
              source: '{{ template "pagerduty.default.client" . }}'
              severity: critical
          - name: pagerduty-warning
            pagerduty_configs:
            - send_resolved: true
              http_config:
                follow_redirects: true
                enable_http2: true
              routing_key_file: /etc/alertmanager/secrets/${var.pagerduty.kubernetes_secret_name}/pagerduty_dai_warning_key
              url: https://events.pagerduty.com/v2/enqueue
              client: '{{ template "pagerduty.default.client" . }}'
              client_url: '{{ template "pagerduty.default.clientURL" . }}'
              description: '{{ template "pagerduty.default.description" .}}'
              details:
                alertname: '{{ .CommonLabels.alertname }}'
                description: '{{ .CommonAnnotations.description }}'
                firing: '{{ template "pagerduty.default.instances" .Alerts.Firing }}'
                instance: '{{ .CommonLabels.instance }}'
                num_firing: '{{ .Alerts.Firing | len }}'
                num_resolved: '{{ .Alerts.Resolved | len }}'
                resolved: '{{ template "pagerduty.default.instances" .Alerts.Resolved }}'
                severity: '{{ .CommonLabels.severity }}'
              source: '{{ template "pagerduty.default.client" . }}'
              severity: warning
          - name: pagerduty-info
            pagerduty_configs:
            - send_resolved: true
              http_config:
                follow_redirects: true
                enable_http2: true
              routing_key_file: /etc/alertmanager/secrets/${var.pagerduty.kubernetes_secret_name}/pagerduty_dai_info_key
              url: https://events.pagerduty.com/v2/enqueue
              client: '{{ template "pagerduty.default.client" . }}'
              client_url: '{{ template "pagerduty.default.clientURL" . }}'
              description: '{{ template "pagerduty.default.description" .}}'
              details:
                alertname: '{{ .CommonLabels.alertname }}'
                description: '{{ .CommonAnnotations.description }}'
                firing: '{{ template "pagerduty.default.instances" .Alerts.Firing }}'
                instance: '{{ .CommonLabels.instance }}'
                num_firing: '{{ .Alerts.Firing | len }}'
                num_resolved: '{{ .Alerts.Resolved | len }}'
                resolved: '{{ template "pagerduty.default.instances" .Alerts.Resolved }}'
                severity: '{{ .CommonLabels.severity }}'
              source: '{{ template "pagerduty.default.client" . }}'
              severity: info
      %{endif}
    EOT
  ]

  set = try(var.prometheus_stack.set, [])

  # TODO: Placeholder for future use
  # additional_helm_releases = {
  #   pagerduty_config = {
  #     create = var.enable_pagerduty

  #     description   = "PagerDuty Alert Manager Config"
  #     chart         = "custom-resources"
  #     chart_version = "0.1.0"
  #     repository    = "https://dnd-it.github.io/helm-charts"

  #     values = [
  #       file("${path.module}/files/helm/prometheus/alertmanagerconfig-pagerduty.yaml")
  #     ]
  #   }
  # }

  depends_on = [
    module.prometheus_operator_crds,
    module.addons,
    module.okta_secrets,
    module.pagerduty_secrets
  ]
}

###############################################################################
# Grafana

locals {
  grafana_secret_name = "grafana-secrets"
}

module "grafana" {
  source = "./modules/addon"

  create = var.create_addons && var.enable_grafana

  chart         = "grafana"
  chart_version = "8.4.4"
  repository    = "https://grafana.github.io/helm-charts"
  description   = "Grafana"
  namespace     = local.monitoring_namespace

  # https://github.com/grafana/helm-charts/blob/main/charts/grafana/values.yaml
  values = [
    file("${path.module}/files/helm/grafana/common.yaml"),
    file("${path.module}/files/helm/grafana/dashboards.yaml"),
    <<-EOT
    ingress:
      enabled: ${var.enable_okta}
      ingressClassName: alb
      hosts:
        - ${local.id}.grafana.${local.primary_acm_domain}
      annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/group.name: ${local.stack_name}
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP":80,"HTTPS":443}]'
        alb.ingress.kubernetes.io/ssl-redirect: '443'
        alb.ingress.kubernetes.io/healthcheck-path: /healthz
    envFromSecret: ${local.grafana_secret_name}
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
        sigv4_auth_enabled: ${var.enable_amp}
      auth.proxy:
        enabled: false
        auto_login: true
        header_name: x-amzn-oidc-identity
      auth.okta:
        enabled: ${var.enable_okta}
        auto_login: true
        auth_url: ${var.okta.base_url}/oauth2/v1/authorize
        token_url: ${var.okta.base_url}/oauth2/v1/token
        api_url: ${var.okta.base_url}/oauth2/v1/userinfo
        role_attribute_path: groups
    datasources:
      datasources.yaml:
        apiVersion: 1
        deleteDatasources:
          - { name: Alertmanager, orgId: 1 }
          - { name: Prometheus, orgId: 1 }
        datasources:
          - name: ${var.enable_amp ? "Prometheus-Local" : "Prometheus"}
            type: prometheus
            uid: ${var.enable_amp ? "prometheus-local" : "prometheus"}
            access: proxy
            url: ${local.prometheus_service_url}
            jsonData:
              prometheusType: Prometheus
            isDefault: ${var.enable_amp ? false : true}
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
              defaultRegion: ${local.region}
          %{if var.enable_amp}
          - name: Prometheus
            type: prometheus
            uid: prometheus
            access: proxy
            url: ${module.amp.workspace_prometheus_endpoint}
            jsonData:
              prometheusType: Prometheus
            isDefault: true
            basicAuth: false
            jsonData:
              sigV4Auth: true
              sigV4AuthType: default
              sigV4Region: ${local.region}
          %{endif}
    serviceMonitor:
      enabled: ${var.enable_prometheus_stack}
    EOT
  ]

  set = concat(
    [
      { # Load Okta secrets
        name  = "envFromSecret"
        value = var.enable_okta ? local.grafana_secret_name : ""
      }
  ], try(var.grafana.set, []))

  create_role = true

  set_irsa_names = ["serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"]
  role_name      = "grafana-${local.id}"
  role_policies = {
    CloudWatchReadOnlyAccess    = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
    AmazonPrometheusQueryAccess = "arn:aws:iam::aws:policy/AmazonPrometheusQueryAccess"
  }

  oidc_providers = {
    this = {
      provider_arn    = module.eks.oidc_provider_arn
      service_account = "grafana"
    }
  }

  release_delay_create_duration = "10s"

  additional_helm_releases = {
    grafana_secrets = {
      create = var.enable_okta

      description   = "Grafana Secrets"
      chart         = "custom-resources"
      chart_version = "0.1.0"
      repository    = "https://dnd-it.github.io/helm-charts"

      values = [
        <<-EOT
        apiVersion: external-secrets.io/v1beta1
        kind: ExternalSecret
        metadata:
          name: grafana-secrets
        spec:
          refreshInterval: 1m0s
          secretStoreRef:
            name: aws-secretsmanager
            kind: ClusterSecretStore
          target:
            name: ${local.grafana_secret_name}
            creationPolicy: Owner
          data:
            - secretKey: GF_AUTH_OKTA_CLIENT_ID
              remoteRef:
                key: ${var.okta.secrets_manager_secret_name}
                property: clientID
            - secretKey: GF_AUTH_OKTA_CLIENT_SECRET
              remoteRef:
                key: ${var.okta.secrets_manager_secret_name}
                property: clientSecret
        EOT
      ]
    }
  }

  depends_on = [
    module.addons
  ]
}

###############################################################################
# Load Secrets

module "okta_secrets" {
  source = "./modules/addon"

  create = var.create_addons && var.enable_okta

  name          = "okta-secrets"
  chart         = "custom-resources"
  chart_version = "0.1.0"
  repository    = "https://dnd-it.github.io/helm-charts"
  description   = "Okta Secrets"
  namespace     = local.monitoring_namespace

  values = [
    <<-EOT
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
        name: ${var.okta.kubernetes_secret_name}
        creationPolicy: Owner
      data:
        - secretKey: clientID
          remoteRef:
            key: ${var.okta.secrets_manager_secret_name}
            property: clientID
        - secretKey: clientSecret
          remoteRef:
            key: ${var.okta.secrets_manager_secret_name}
            property: clientSecret
    EOT
  ]

  release_delay_destroy_duration = "1m"

  depends_on = [
    module.addons
  ]
}

module "pagerduty_secrets" {
  source = "./modules/addon"

  create = var.create_addons && var.enable_pagerduty

  name          = "pagerduty-secrets"
  chart         = "custom-resources"
  chart_version = "0.1.0"
  repository    = "https://dnd-it.github.io/helm-charts"
  description   = "PagerDuty Secrets"
  namespace     = local.monitoring_namespace

  values = [
    <<-EOT
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
        name: ${var.pagerduty.kubernetes_secret_name}
        creationPolicy: Owner
      dataFrom:
        - extract:
            key: ${var.pagerduty.secrets_manager_secret_name}
    EOT
  ]

  release_delay_destroy_duration = "1m"

  depends_on = [
    module.addons
  ]
}

###############################################################################
