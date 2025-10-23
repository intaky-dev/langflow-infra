variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "image_tag" {
  description = "Langflow image tag"
  type        = string
  default     = "latest"
}

variable "replicas" {
  description = "Number of IDE replicas"
  type        = number
  default     = 2
}

variable "database_url" {
  description = "PostgreSQL connection string"
  type        = string
  sensitive   = true
}

variable "ingress_enabled" {
  description = "Enable ingress for IDE"
  type        = bool
  default     = true
}

variable "ingress_host" {
  description = "Hostname for IDE ingress"
  type        = string
  default     = "langflow.example.com"
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "resources" {
  description = "Resource requests and limits"
  type = object({
    requests = object({
      cpu    = string
      memory = string
    })
    limits = object({
      cpu    = string
      memory = string
    })
  })
  default = {
    requests = {
      cpu    = "500m"
      memory = "1Gi"
    }
    limits = {
      cpu    = "2000m"
      memory = "4Gi"
    }
  }
}

variable "enable_monitoring" {
  description = "Enable Prometheus ServiceMonitor"
  type        = bool
  default     = true
}
