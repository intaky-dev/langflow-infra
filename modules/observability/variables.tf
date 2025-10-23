variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "prometheus_enabled" {
  description = "Enable Prometheus"
  type        = bool
  default     = true
}

variable "grafana_enabled" {
  description = "Enable Grafana"
  type        = bool
  default     = true
}

variable "loki_enabled" {
  description = "Enable Loki for log aggregation"
  type        = bool
  default     = true
}

variable "prometheus_storage_size" {
  description = "Storage size for Prometheus"
  type        = string
  default     = "50Gi"
}

variable "loki_storage_size" {
  description = "Storage size for Loki"
  type        = string
  default     = "50Gi"
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "standard"
}
