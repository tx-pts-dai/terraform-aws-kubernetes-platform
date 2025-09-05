################################################################################
# EKS Addons
################################################################################

data "aws_eks_addon_version" "this" {
  for_each = { for k, v in var.cluster_addons : k => v if v.create }

  addon_name         = try(each.value.name, each.key)
  kubernetes_version = var.kubernetes_version
  most_recent        = each.value.most_recent
}

resource "aws_eks_addon" "this" {
  for_each = { for k, v in var.cluster_addons : k => v if v.create }

  cluster_name = var.cluster_name
  addon_name   = try(each.value.name, each.key)

  addon_version        = coalesce(each.value.addon_version, data.aws_eks_addon_version.this[each.key].version)
  configuration_values = each.value.configuration_values

  dynamic "pod_identity_association" {
    for_each = each.value.pod_identity_association

    content {
      role_arn        = pod_identity_association.value.role_arn
      service_account = pod_identity_association.value.service_account
    }
  }

  preserve                    = each.value.preserve
  resolve_conflicts_on_create = each.value.resolve_conflicts_on_create
  resolve_conflicts_on_update = each.value.resolve_conflicts_on_update
  service_account_role_arn    = each.value.service_account_role_arn

  timeouts {
    create = try(each.value.timeouts.create, var.cluster_addons_timeouts.create, null)
    update = try(each.value.timeouts.update, var.cluster_addons_timeouts.update, null)
    delete = try(each.value.timeouts.delete, var.cluster_addons_timeouts.delete, null)
  }

  tags = merge(var.tags, try(each.value.tags, {}))
}
