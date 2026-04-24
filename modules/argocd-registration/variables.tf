variable "create" {
  description = "Controls whether resources are created"
  type        = bool
  default     = true
}

variable "github_repository" {
  description = "GitHub repository in owner/repo format (e.g. dnd-it/fission-argocd)"
  type        = string
  default     = ""
}

variable "github_branch" {
  description = "Git branch to commit the cluster Secret file to"
  type        = string
  default     = "main"
}

variable "argocd_hub_environment" {
  description = "Environment directory name under configs/argocd/hub/ — must match the subdirectory where this cluster should be registered (e.g. prod, dev)"
  type        = string
  default     = "prod"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster API server endpoint URL"
  type        = string
}

variable "cluster_ca_data" {
  description = "Base64-encoded CA certificate data for the EKS cluster"
  type        = string
}

variable "argocd_spoke_role_arn" {
  description = "IAM role ARN that the ArgoCD hub assumes to access this cluster"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID hosting the cluster"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the cluster is deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block, stored as the config/vpc-cidr annotation on the cluster Secret"
  type        = string
}

variable "cluster_labels" {
  description = "ArgoCD cluster metadata and feature flags. All enable_* flags default to false."
  type = object({
    cluster_group  = string
    environment    = string
    team           = string
    promotion_tier = string

    enable_ack                          = optional(bool, false)
    enable_adapter                      = optional(bool, false)
    enable_aws_load_balancer_controller = optional(bool, false)
    enable_cert_manager                 = optional(bool, false)
    enable_datadog_operator             = optional(bool, false)
    enable_downscaler                   = optional(bool, false)
    enable_exporters                    = optional(bool, false)
    enable_external_dns                 = optional(bool, false)
    enable_external_dns_crossaccount    = optional(bool, false)
    enable_external_secrets             = optional(bool, false)
    enable_grafana                      = optional(bool, false)
    enable_kargo                        = optional(bool, false)
    enable_kube_prometheus_stack        = optional(bool, false)
    enable_metrics_server               = optional(bool, false)
    enable_reloader                     = optional(bool, false)
    enable_tailscale_operator           = optional(bool, false)
  })
}
