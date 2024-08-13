# Base infra logging
# Deploy fluentbit with the fluent-operator and configure it so that pods with the ${var.logging_annontation} annotation have
# they logs pushed to CloudWatch.
# By default (hardcoded), fluent-operator and fluent-bit will have this annotation set
locals {
  # Namespace for the resources deployed by the fluent-operator (fluent-bit will be here too)
  fluent_namespace                       = "monitoring"
  fluentbit_cloudwatch_log_group         = "/${local.stack_name}/fluentbit-logs"
  fluentbit_cloudwatch_log_stream_prefix = "."
  fluentbit_tag                          = "kaas"
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
        ${var.logging_annotation.name}: "${var.logging_annotation.value}"
    fluentbit:
      affinity:
        nodeAffinity:
          # Do not start fluent-bit on Fargate node
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
        ${var.logging_annotation.name}: "${var.logging_annotation.value}"
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
        eks.amazonaws.com/role-arn: ${module.fluentbit_irsa.iam_role_arn}
    YAML
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
}

# Fluentbit filters to log KaaS pods to cloudwatch
resource "kubectl_manifest" "fluentbit_cluster_filter_pipeline" {
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
          regex: $kubernetes['annotations']['${var.logging_annotation.name}'] ^${var.logging_annotation.value}$
  YAML
}

resource "kubectl_manifest" "fluentbit_cluster_output_pipeline" {
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
          log_stream_template $kubernetes['namespace_name'].$kubernetes['pod_name'].$kubernetes['container_name'].$kubernetes['docker_id']
          auto_create_group On # Has to be set to On: https://github.com/fluent/fluent-bit/issues/8949
    YAML

  depends_on = [helm_release.fluent_operator]
}

# CloudWatch log group and permission to allow fluent-bit to write log stream
resource "aws_cloudwatch_log_group" "fluentbit" {
  name              = local.fluentbit_cloudwatch_log_group
  retention_in_days = var.logging_retention_in_days
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
  tags   = local.tags
}

# k8s Service account AWS iam role to allow fluent-bit writing log streams
module "fluentbit_irsa" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${local.stack_name}-fluentbit"

  role_policy_arns = {
    policy = aws_iam_policy.fluentbit.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.fluent_namespace}:fluent-bit"] # Don't know how to get the name...
    }
  }
  tags = local.tags
}
