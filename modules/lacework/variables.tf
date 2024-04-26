variable "server_url" {
  description = "Lacework server URL"
  type        = string
  default     = "https://api.fra.lacework.net"
}

variable "namespace" {
  description = "Namespace for Lacework resources"
  type        = string
  default     = "lacework"
}

variable "cluster_name" {
  description = "Name of the cluster"
  type        = string
}

variable "pod_priority_class_name" {
  description = "Name of the pod priority class"
  type        = string
  default     = "system-node-critical"
}

variable "node_affinity" {
  description = "Node affinity settings"
  type = list(object({
    key      = string
    operator = string
    values   = list(string)
  }))
  default = [
    {
      key      = "eks.amazonaws.com/compute-type"
      operator = "NotIn"
      values = [
        "fargate"
      ]
    }
  ]
}

variable "tolerations" {
  description = "Tolerations for the Lacework agent"
  type        = list(map(string))
  default = [
    {
      operator = "Exists"
      effect   = "NoSchedule"
    }
  ]
}

variable "resources" {
  description = "Resources for the Lacework agent"
  type = object({
    cpu_request = string
    mem_request = string
    cpu_limit   = string
    mem_limit   = string
  })
  default = {
    cpu_request = "100m"
    mem_request = "256Mi"
    cpu_limit   = "1000m"
    mem_limit   = "1024Mi"
  }
}
