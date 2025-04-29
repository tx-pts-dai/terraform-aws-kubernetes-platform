# Move from addon module to direct helm_release
moved {
  from = module.argocd.helm_release.this[0]
  to   = helm_release.argocd[0]
}
