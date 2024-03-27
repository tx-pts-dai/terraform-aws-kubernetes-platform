variable "environment" {
  description = "The name of the environment"
  type        = string
}

variable "region" {
  description = "The AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "github_repo" {
  description = "The name of the GitHub repository"
  type        = string
}

variable "github_org" {
  description = "The name of the GitHub organization"
  type        = string
}

variable "stack_name" {
  description = "The stack name for the resources"
  type        = string
  default     = ""
}

variable "kubernetes_version" {
  description = "The Kubernetes version"
  type        = string
  default     = ""
}

variable "vpc" {
  description = "Map of VPC configurations"
  type        = any
  default     = {
    create = true
    cidr = "10.0.0.0/16"
  }
}

variable "eks" {
  description = "Map of EKS configurations"
  type        = any
  default     = {}
}

variable "addons" {
  description = "Map of addon configurations"
  type        = any
  default = {
    karpenter                    = { enabled = true }
    coredns                      = { enabled = true }
    vpc_cni                      = { enabled = true }
    kube_proxy                   = { enabled = true }
    metrics_server               = { enabled = true }
    aws_load_balancer_controller = { enabled = true }
    aws_ebs_csi_driver           = { enabled = true }
    external_dns                 = { enabled = true }
    external_secrets             = { enabled = true }
    datadog                      = { enabled = true }
    kube_prometheus_stack        = { enabled = true }
  }
}