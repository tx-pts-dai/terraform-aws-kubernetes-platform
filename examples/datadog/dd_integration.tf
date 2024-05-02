###############################################################################
# Datadog AWS Integration

# AWS Integration in Datadog
# These resources must be created in each AWS Account that needs to be integrated with Datadog
# From https://docs.datadoghq.com/integrations/guide/aws-terraform-setup/
locals {
  datadog_aws_account_id = "464622532012"
}

data "aws_iam_policy_document" "datadog_aws_integration_assume_role" {
  count = var.enable_dd_integration ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.datadog_aws_account_id}:root"]
    }
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"

      values = [
        datadog_integration_aws.this[0].external_id
      ]
    }
  }
}

# Actions gotten from https://docs.datadoghq.com/integrations/amazon_web_services/?tab=manual#aws-iam-permissions
data "aws_iam_policy_document" "datadog_aws_integration" {
  statement {
    actions = [
      "apigateway:GET",
      "autoscaling:Describe*",
      "backup:List*",
      "budgets:ViewBudget",
      "cloudfront:GetDistributionConfig",
      "cloudfront:ListDistributions",
      "cloudtrail:DescribeTrails",
      "cloudtrail:GetTrailStatus",
      "cloudtrail:LookupEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "codedeploy:List*",
      "codedeploy:BatchGet*",
      "directconnect:Describe*",
      "dynamodb:List*",
      "dynamodb:Describe*",
      "ec2:Describe*",
      "ec2:GetTransitGatewayPrefixListReferences",
      "ec2:SearchTransitGatewayRoutes",
      "ecs:Describe*",
      "ecs:List*",
      "elasticache:Describe*",
      "elasticache:List*",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeTags",
      "elasticfilesystem:DescribeAccessPoints",
      "elasticloadbalancing:Describe*",
      "elasticmapreduce:List*",
      "elasticmapreduce:Describe*",
      "es:ListTags",
      "es:ListDomainNames",
      "es:DescribeElasticsearchDomains",
      "events:CreateEventBus",
      "fsx:DescribeFileSystems",
      "fsx:ListTagsForResource",
      "health:DescribeEvents",
      "health:DescribeEventDetails",
      "health:DescribeAffectedEntities",
      "kinesis:List*",
      "kinesis:Describe*",
      "lambda:GetPolicy",
      "lambda:List*",
      "logs:DeleteSubscriptionFilter",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      "logs:DescribeSubscriptionFilters",
      "logs:FilterLogEvents",
      "logs:PutSubscriptionFilter",
      "logs:TestMetricFilter",
      "organizations:Describe*",
      "organizations:List*",
      "rds:Describe*",
      "rds:List*",
      "redshift:DescribeClusters",
      "redshift:DescribeLoggingStatus",
      "route53:List*",
      "s3:GetBucketLogging",
      "s3:GetBucketLocation",
      "s3:GetBucketNotification",
      "s3:GetBucketTagging",
      "s3:ListAllMyBuckets",
      "s3:PutBucketNotification",
      "ses:Get*",
      "sns:List*",
      "sns:Publish",
      "sqs:ListQueues",
      "states:ListStateMachines",
      "states:DescribeStateMachine",
      "support:DescribeTrustedAdvisor*",
      "support:RefreshTrustedAdvisorCheck",
      "tag:GetResources",
      "tag:GetTagKeys",
      "tag:GetTagValues",
      "xray:BatchGetTraces",
      "xray:GetTraceSummaries"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "datadog_aws_integration" {
  count = var.enable_dd_integration ? 1 : 0

  name   = "DatadogTamediaAWSIntegrationPolicy"
  policy = data.aws_iam_policy_document.datadog_aws_integration.json
}

resource "aws_iam_role" "datadog_aws_integration" {
  count = var.enable_dd_integration ? 1 : 0

  name               = "DatadogTamediaAWSIntegrationRole"
  description        = "Role for Datadog AWS Integration"
  assume_role_policy = data.aws_iam_policy_document.datadog_aws_integration_assume_role[0].json
}

resource "aws_iam_role_policy_attachment" "datadog_aws_integration" {
  count = var.enable_dd_integration ? 1 : 0

  role       = aws_iam_role.datadog_aws_integration[0].name
  policy_arn = aws_iam_policy.datadog_aws_integration[0].arn
}

data "aws_regions" "all" {
  all_regions = true
}

data "aws_caller_identity" "current" {}

resource "datadog_integration_aws" "this" {
  count = var.enable_dd_integration ? 1 : 0

  account_id = data.aws_caller_identity.current.account_id
  role_name  = "DatadogTamediaAWSIntegrationRole"
  host_tags = [
    "env:sandbox-platform-dca-test",
    "product:platform-dca-test",
  ]
  excluded_regions = setsubtract(data.aws_regions.all.names, ["eu-central-1"])
  # Enable additional sub-integrations https://docs.datadoghq.com/api/latest/aws-integration/#list-namespace-rules
  account_specific_namespace_rules = {
    crawl_alarms = false # disable sending CloudWatch alarms
  }
}
