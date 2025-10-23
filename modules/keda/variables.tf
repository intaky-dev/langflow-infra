variable "namespace" {
  description = "Kubernetes namespace for ScaledObject"
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

variable "broker_connection_url" {
  description = "Message broker connection URL"
  type        = string
  sensitive   = true
}

variable "queue_name" {
  description = "Queue name to monitor"
  type        = string
  default     = "langflow-tasks"
}

variable "target_deployment" {
  description = "Name of the deployment/statefulset to scale"
  type        = string
}

variable "min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 2
}

variable "max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 10
}

variable "queue_length_threshold" {
  description = "Queue length threshold to trigger scaling"
  type        = number
  default     = 5
}

variable "cpu_threshold" {
  description = "CPU utilization threshold for scaling (%)"
  type        = number
  default     = 70
}

variable "memory_threshold" {
  description = "Memory utilization threshold for scaling (%)"
  type        = number
  default     = 80
}

variable "enable_monitoring" {
  description = "Enable Prometheus ServiceMonitor for KEDA"
  type        = bool
  default     = true
}
