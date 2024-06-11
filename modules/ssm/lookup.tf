data "aws_ssm_parameters_by_path" "this" {
  path            = "${var.base_prefix}/${var.stack_type}/"
  recursive       = true
  with_decryption = true
}

locals {
  parameters = zipmap(data.aws_ssm_parameters_by_path.this.names, nonsensitive(data.aws_ssm_parameters_by_path.this.values))
  # Returns second last item in the parameter name e.g. /foo/bar/baz -> bar
  stacks = toset([for key, _ in local.parameters : element(split("/", key), length(split("/", key)) - 2)])
  # Filter parameters by stack name prefix
  filtered_parameters = {
    for key, value in local.parameters : key => value if strcontains(key, var.stack_name_prefix)
  }
  # Returns all parameter values with cluster_name in the name
  clusters = [
    for key, value in local.parameters : value if contains(split("/", key), "cluster_name")
  ]
}
