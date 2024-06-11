locals {
  # TODO: add validation
  ssm_hierarchy = "${var.base_prefix}/${var.stack_type}/${var.stack_name}"
}

resource "aws_ssm_parameter" "cluster_name" {
  for_each = var.parameters

  name           = "${local.ssm_hierarchy}/${each.value.name}"
  type           = each.value.type
  value          = each.value.value
  insecure_value = each.value.insecure_value

  tags = var.tags
}

resource "aws_ssm_parameter" "cluster_name_latest" {
  for_each = var.latest ? var.parameters : {}

  name           = "${var.base_prefix}/${var.stack_type}/latest/${each.value.name}"
  type           = each.value.type
  value          = each.value.value
  insecure_value = each.value.insecure_value

  tags = var.tags
}
