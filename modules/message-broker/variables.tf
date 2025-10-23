variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "broker_type" {
  description = "Message broker type (rabbitmq or redis)"
  type        = string

  validation {
    condition     = contains(["rabbitmq", "redis"], var.broker_type)
    error_message = "Broker type must be rabbitmq or redis."
  }
}

variable "rabbitmq_replicas" {
  description = "Number of RabbitMQ replicas"
  type        = number
  default     = 3
}

variable "rabbitmq_storage_size" {
  description = "Storage size for RabbitMQ"
  type        = string
  default     = "10Gi"
}

variable "redis_replicas" {
  description = "Number of Redis replicas"
  type        = number
  default     = 3
}

variable "redis_storage_size" {
  description = "Storage size for Redis"
  type        = string
  default     = "5Gi"
}
