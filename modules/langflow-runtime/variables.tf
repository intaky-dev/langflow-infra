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

variable "min_replicas" {
  description = "Minimum number of runtime worker replicas"
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum number of runtime worker replicas"
  type        = number
  default     = 10
}

variable "database_url" {
  description = "PostgreSQL connection string"
  type        = string
  sensitive   = true
}

variable "broker_url" {
  description = "Message broker connection string"
  type        = string
  sensitive   = true
}

variable "vector_db_url" {
  description = "Vector database connection string"
  type        = string
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
      cpu    = "1000m"
      memory = "2Gi"
    }
    limits = {
      cpu    = "4000m"
      memory = "8Gi"
    }
  }
}

variable "worker_storage_size" {
  description = "Storage size for each worker"
  type        = string
  default     = "10Gi"
}

variable "storage_class" {
  description = "Storage class for worker persistent volumes"
  type        = string
  default     = "standard"
}

variable "enable_monitoring" {
  description = "Enable Prometheus ServiceMonitor"
  type        = bool
  default     = true
}
