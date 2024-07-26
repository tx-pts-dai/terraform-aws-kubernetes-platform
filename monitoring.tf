# Base infra logging
locals {
  fluent_operator_namespace              = "monitoring"
  fluent_operator_cloudwatch_log_group   = "/${local.stack_name}-fluent-operator"
  fluentbit_cloudwatch_log_stream_prefix = "fluentbit-"
}

# Fluent-operator (https://github.com/fluent/fluent-operator operator)
resource "helm_release" "fluent_operator" {
  chart      = "fluent-operator"
  name       = "fluent-operator"
  repository = "https://fluent.github.io/helm-charts"
  version    = "v3.0.0" # Note: using "v3.0" will issue in resource update on each terraform plan/apply

  create_namespace = true
  namespace        = local.fluent_operator_namespace

  values = [
    <<-YAML
    containerRuntime: containerd
    operator:
      fluentd:
        crdsEnable: false
        enable: false
    fluentbit:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-role.kubernetes.io/edge
                    operator: DoesNotExist
                  - key: eks.amazonaws.com/compute-type
                    operator: NotIn
                    values:
                      - fargate

    YAML
  ]
}

resource "aws_cloudwatch_log_group" "fluent_operator" {
  name              = local.fluent_operator_cloudwatch_log_group
  retention_in_days = 7
}

resource "kubectl_manifest" "fluentbit_output_cloudwatch_logs" {
  yaml_body = <<-YAML
    apiVersion: fluentbit.fluent.io/v1alpha2
    kind: ClusterOutput
    metadata:
      name: cloudwatch-logs
      namespace: ${local.fluent_operator_namespace}
      labels:
        fluentbit.fluent.io/enabled: "true"
        fluentbit.fluent.io/mode: "fluentbit-only"
    spec:
      customPlugin:
        config: |
          Name cloudwatch_logs
          Match_Regexp namespace_name[":]*(kube-system|rba-test)
          region eu-central-1
          log_group_name ${local.fluent_operator_cloudwatch_log_group}
          log_stream_prefix ${local.fluentbit_cloudwatch_log_stream_prefix}
          auto_create_group On # Has to be set to On: https://github.com/fluent/fluent-bit/issues/8949
    YAML

  depends_on = [helm_release.fluent_operator]
}

data "aws_iam_policy_document" "fluentbit" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["${aws_cloudwatch_log_group.fluent_operator.arn}:*"]

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
