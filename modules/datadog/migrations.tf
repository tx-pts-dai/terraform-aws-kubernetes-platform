moved {
  from = module.datadog_operator.helm_release.this[0]
  to   = helm_release.datadog_operator
}
