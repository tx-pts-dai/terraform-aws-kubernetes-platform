################################################################################
# (Generic) Helm Release
################################################################################

resource "helm_release" "additional" {
  for_each = var.create ? { for k, v in var.additional_helm_releases : k => v if try(v.create, true) } : {}

  name             = try(each.value.name, replace(each.key, "_", "-"))
  description      = try(each.value.description, null)
  namespace        = try(each.value.namespace, local.namespace, null)
  create_namespace = try(each.value.create_namespace, null)
  chart            = each.value.chart
  version          = try(each.value.chart_version, null)
  repository       = try(each.value.repository, null)
  values           = try(each.value.values, [])

  timeout                    = try(each.value.timeout, null)
  repository_key_file        = try(each.value.repository_key_file, null)
  repository_cert_file       = try(each.value.repository_cert_file, null)
  repository_ca_file         = try(each.value.repository_ca_file, null)
  repository_username        = try(each.value.repository_username, null)
  repository_password        = try(each.value.repository_password, null)
  devel                      = try(each.value.devel, null)
  verify                     = try(each.value.verify, null)
  keyring                    = try(each.value.keyring, null)
  disable_webhooks           = try(each.value.disable_webhooks, null)
  reuse_values               = try(each.value.reuse_values, null)
  reset_values               = try(each.value.reset_values, null)
  force_update               = try(each.value.force_update, null)
  recreate_pods              = try(each.value.recreate_pods, null)
  cleanup_on_fail            = try(each.value.cleanup_on_fail, null)
  max_history                = try(each.value.max_history, 3)
  atomic                     = try(each.value.atomic, null)
  skip_crds                  = try(each.value.skip_crds, null)
  render_subchart_notes      = try(each.value.render_subchart_notes, null)
  disable_openapi_validation = try(each.value.disable_openapi_validation, null)
  wait                       = try(each.value.wait, false)
  wait_for_jobs              = try(each.value.wait_for_jobs, null)
  dependency_update          = try(each.value.dependency_update, null)
  replace                    = try(each.value.replace, null)
  lint                       = try(each.value.lint, null)

  dynamic "postrender" {
    for_each = try([each.value.postrender], [])

    content {
      binary_path = postrender.value.binary_path
      args        = try(postrender.value.args, null)
    }
  }

  dynamic "set" {
    for_each = try(each.value.set, [])

    content {
      name  = set.value.name
      value = set.value.value
      type  = try(set.value.type, null)
    }
  }

  dynamic "set_sensitive" {
    for_each = try(each.value.set_sensitive, [])

    content {
      name  = set_sensitive.value.name
      value = set_sensitive.value.value
      type  = try(set_sensitive.value.type, null)
    }
  }

  depends_on = [time_sleep.additional]
}

resource "time_sleep" "additional" {
  count = var.additional_delay_create_duration != null || var.additional_delay_destroy_duration != null ? 1 : 0

  create_duration = var.additional_delay_create_duration

  destroy_duration = var.additional_delay_destroy_duration

  triggers = {
    main_release = var.additional_depend_on_helm_release ? try(helm_release.this[0].name, "") : ""
    custom       = join(",", var.additional_custom_delay_triggers)
  }
}
