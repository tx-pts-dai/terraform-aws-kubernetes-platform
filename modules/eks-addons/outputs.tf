################################################################################
# Outputs
################################################################################

output "addon_versions" {
  description = "Map of addon names to their resolved versions"
  value = {
    for k, v in aws_eks_addon.this : k => v.addon_version
  }
}

output "addon_arns" {
  description = "Map of addon names to their ARNs"
  value = {
    for k, v in aws_eks_addon.this : k => v.arn
  }
}

output "addon_ids" {
  description = "Map of addon names to their IDs"
  value = {
    for k, v in aws_eks_addon.this : k => v.id
  }
}
