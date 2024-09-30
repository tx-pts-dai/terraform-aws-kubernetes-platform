locals {
  ssm_hierarchy = join("/", compact([var.base_prefix, var.stack_type, var.stack_name]))
}

resource "aws_ssm_parameter" "cluster_name" {
  for_each = var.create ? var.parameters : {}

  name           = join("/", ["", local.ssm_hierarchy, coalesce(each.value.name, each.key)])
  type           = each.value.type
  value          = each.value.value
  insecure_value = each.value.insecure_value

  tags = var.tags
}
