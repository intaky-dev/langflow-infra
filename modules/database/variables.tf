variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "postgres_replicas" {
  description = "Number of PostgreSQL replicas"
  type        = number
  default     = 3
}

variable "storage_size" {
  description = "Storage size for PostgreSQL"
  type        = string
  default     = "20Gi"
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "standard"
}
