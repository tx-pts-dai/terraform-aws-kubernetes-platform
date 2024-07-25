# Base infra logging
locals {
  fluent_operator_namespace              = "fluent" # should we put it as a fluent_namespace variable ?
  fluent_operator_helm_chart_version     = "v3.0.0" # variable ? and if "v3.0", then every terraform apply will update, even if there is no change
  fluent_operator_cloudwatch_log_group   = "/${local.stack_name}-fluent-operator"
  fluentbit_cloudwatch_log_stream_prefix = "fluentbit-"
}

# Fluent-operator (https://github.com/fluent/fluent-operator operator)
resource "helm_release" "fluent_operator" {
  chart      = "fluent-operator"
  name       = "fluent-operator"
  repository = "https://fluent.github.io/helm-charts"
  version    = local.fluent_operator_helm_chart_version

  create_namespace = true
  namespace        = local.fluent_operator_namespace

  values = [
    <<-YAML
    containerRuntime: containerd
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
          Match *
          region eu-central-1
          log_group_name ${local.fluent_operator_cloudwatch_log_group}
          log_stream_prefix ${local.fluentbit_cloudwatch_log_stream_prefix}
          auto_create_group On
    YAML

  depends_on = [helm_release.fluent_operator]
}

resource "aws_iam_policy" "fluentbit" {
  name   = "${local.stack_name}-fluentbit"
  policy = <<-JSON
    {
      "Version": "2012-10-17",
      "Statement": [{
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": [
          "${aws_cloudwatch_log_group.fluent_operator.arn}:*"
        ]
      }]
    }
    JSON
}
