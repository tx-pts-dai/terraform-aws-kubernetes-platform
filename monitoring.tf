# Base infra logging
# Deploy fluentbit with the fluent-operator and configure it so that pods with the `dai/logging: enable` annotation have
# they logs pushed to CloudWatch.
# By default (hardcoded), fluent-operator and fluent-bit will have this annotation set
locals {
  # Namespace for the resources deployed by the fluent-operator (fluent-bit will be here too)
  fluent_namespace                       = "monitoring"
  fluentbit_cloudwatch_log_group         = "/${local.stack_name}-fluentbit-operator"
  fluentbit_cloudwatch_log_stream_prefix = "fluentbit-"
  fluentbit_dai_tag                      = "dai"
}

# Fluent-operator (https://github.com/fluent/fluent-operator operator)
resource "helm_release" "fluent_operator" {
  chart      = "fluent-operator"
  name       = "fluent-operator"
  repository = "https://fluent.github.io/helm-charts"
  version    = "v3.0.0" # Note: using "v3.0" will issue in resource update on each terraform plan/apply

  create_namespace = true
  namespace        = local.fluent_namespace

  values = [
    <<-YAML
    containerRuntime: containerd
    operator:
      annotations:
        dai/logging: enable
    fluentbit:
      affinity:
        nodeAffinity:
          # Need to be modified because by default fluent-bit will try to start on faregate nodes and it's not working
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/edge # This expression is here by default
                    operator: DoesNotExist
                  - key: eks.amazonaws.com/compute-type
                    operator: NotIn
                    values:
                      - fargate
      annotations:
        dai/logging: enable
      # Because we deploy our own pipeline, disable the default one
      filter:
        kubernetes:
          enable: false # true = default
          annotations: true
        containerd:
          enable: true # If disabled, fluent-operator has reconilier error
      input:
        tail:
          enable: false # true = default
    YAML
  ]
}

resource "aws_cloudwatch_log_group" "fluentbit" {
  name              = local.fluentbit_cloudwatch_log_group
  retention_in_days = 7
}

# DAI pipeline
# Idea is to have a INPUT-FILTERS-OUTPUT pipeline
# To differenciate with other pipelines we tag the log entries with local.fluentbit_dai_tag
resource "kubectl_manifest" "fluentbit_cluster_input_dai_pipeline" {
  yaml_body = <<-YAML
    apiVersion: fluentbit.fluent.io/v1alpha2
    kind: ClusterInput
    metadata:
      name: dai-pipeline
      labels:
        fluentbit.fluent.io/enabled: "true"
    spec:
      tail:
        db: /fluent-bit/tail/pos-${local.fluentbit_dai_tag}.db # Not sure it's required to have a different db for different input
        dbSync: Normal
        memBufLimit: 100MB
        parser: cri
        path: /var/log/containers/*.log
        readFromHead: false
        refreshIntervalSeconds: 10
        skipLongLines: true
        storageType: memory
        tag: ${local.fluentbit_dai_tag}.*
  YAML
}

# Fluentbit filters to log DAI pods to cloudwatch
#
resource "kubectl_manifest" "fluentbit_cluster_filter_dai_pipeline" {
  yaml_body = <<-YAML
    apiVersion: fluentbit.fluent.io/v1alpha2
    kind: ClusterFilter
    metadata:
      name: dai-pipeline
      labels:
        fluentbit.fluent.io/enabled: "true"
    spec:
      match: ${local.fluentbit_dai_tag}.*
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
          kubeTagPrefix:  ${local.fluentbit_dai_tag}.var.log.containers
          labels: false
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
          regex: $kubernetes['annotations']['dai/logging'] ^enable$
  YAML
}

resource "kubectl_manifest" "fluentbit_cluster_output_dai_pipeline" {
  yaml_body = <<-YAML
    apiVersion: fluentbit.fluent.io/v1alpha2
    kind: ClusterOutput
    metadata:
      name: dai-pipeline
      labels:
        fluentbit.fluent.io/enabled: "true"
    spec:
      customPlugin:
        config: |
          Name cloudwatch_logs
          Match ${local.fluentbit_dai_tag}.*
          region ${data.aws_region.current.name}
          log_group_name ${local.fluentbit_cloudwatch_log_group}
          log_stream_prefix ${local.fluentbit_cloudwatch_log_stream_prefix}
          auto_create_group On # Has to be set to On: https://github.com/fluent/fluent-bit/issues/8949
    YAML

  depends_on = [helm_release.fluent_operator]
}

data "aws_iam_policy_document" "fluentbit" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["${aws_cloudwatch_log_group.fluentbit.arn}:*"]

    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
  }
}

resource "aws_iam_policy" "fluentbit" {
  name   = "${local.stack_name}-fluentbit"
  policy = data.aws_iam_policy_document.fluentbit.json
}
