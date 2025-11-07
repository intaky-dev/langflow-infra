variable "kubeconfig_path" {
  description = "Path to kubeconfig file (leave empty to use default kubectl configuration)"
  type        = string
  default     = ""
}

variable "kube_context" {
  description = "Kubernetes context to use"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace for Langflow"
  type        = string
  default     = "langflow"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "cloud_provider" {
  description = "Cloud provider (aws, gcp, azure, onprem) - used for storage class detection"
  type        = string
  default     = "onprem"

  validation {
    condition     = contains(["aws", "gcp", "azure", "onprem"], var.cloud_provider)
    error_message = "Cloud provider must be aws, gcp, azure, or onprem."
  }
}

variable "langflow_version" {
  description = "Langflow version/image tag"
  type        = string
  default     = "1.0.18"
}

# Message Broker Configuration
variable "broker_type" {
  description = "Message broker type (rabbitmq or redis)"
  type        = string
  default     = "rabbitmq"

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

variable "queue_name" {
  description = "Queue name for task processing"
  type        = string
  default     = "langflow-tasks"
}

# Database Configuration
variable "postgres_replicas" {
  description = "Number of PostgreSQL replicas"
  type        = number
  default     = 3
}

variable "postgres_storage_size" {
  description = "Storage size for PostgreSQL"
  type        = string
  default     = "20Gi"
}

# Vector Database Configuration
variable "vector_db_type" {
  description = "Vector database type (qdrant, weaviate, or milvus)"
  type        = string
  default     = "qdrant"

  validation {
    condition     = contains(["qdrant", "weaviate", "milvus"], var.vector_db_type)
    error_message = "Vector DB must be qdrant, weaviate, or milvus."
  }
}

variable "vector_db_replicas" {
  description = "Number of vector database replicas"
  type        = number
  default     = 2
}

variable "vector_db_storage_size" {
  description = "Storage size for vector database"
  type        = string
  default     = "20Gi"
}

# Langflow IDE Configuration
variable "ide_replicas" {
  description = "Number of Langflow IDE replicas"
  type        = number
  default     = 2
}

variable "ide_resources" {
  description = "Resource requests and limits for IDE. For production, consider using environment-specific values."
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
      cpu    = "250m"  # Reduced from 500m - IDE is mostly I/O bound
      memory = "512Mi" # Reduced from 1Gi - serves static assets and UI
    }
    limits = {
      cpu    = "1000m" # Reduced from 2000m - more reasonable 4x multiplier
      memory = "2Gi"   # Reduced from 4Gi - prevents resource waste
    }
  }
}

# Langflow Runtime Configuration
variable "runtime_min_replicas" {
  description = "Minimum number of runtime worker replicas"
  type        = number
  default     = 2
}

variable "runtime_max_replicas" {
  description = "Maximum number of runtime worker replicas"
  type        = number
  default     = 10
}

variable "runtime_resources" {
  description = "Resource requests and limits for Runtime workers. Workers execute flows and may need more resources for AI/ML workloads."
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
      cpu    = "500m" # Reduced from 1000m - scales up via KEDA when needed
      memory = "1Gi"  # Reduced from 2Gi - sufficient for most flows
    }
    limits = {
      cpu    = "2000m" # Reduced from 4000m - still 4x multiplier for bursts
      memory = "4Gi"   # Reduced from 8Gi - prevents single pod from consuming too much
    }
  }
}

variable "runtime_worker_storage_size" {
  description = "Storage size for each runtime worker's persistent volume"
  type        = string
  default     = "10Gi"
}

# KEDA Configuration
variable "keda_queue_threshold" {
  description = "Queue length threshold for KEDA scaling"
  type        = number
  default     = 5
}

variable "keda_cpu_threshold" {
  description = "CPU utilization threshold for KEDA scaling (%)"
  type        = number
  default     = 70
}

variable "keda_memory_threshold" {
  description = "Memory utilization threshold for KEDA scaling (%)"
  type        = number
  default     = 80
}

# Storage Configuration
variable "storage_class" {
  description = "Storage class for persistent volumes. Leave empty for automatic detection based on cloud_provider."
  type        = string
  default     = ""
}

# Ingress Configuration
variable "ingress_enabled" {
  description = "Enable ingress resources"
  type        = bool
  default     = true
}

variable "ingress_class" {
  description = "Ingress class name (nginx, traefik, etc.)"
  type        = string
  default     = "nginx"
}

variable "ide_ingress_host" {
  description = "Hostname for Langflow IDE"
  type        = string
  default     = "langflow.example.com"
}

variable "runtime_ingress_host" {
  description = "Hostname for Langflow Runtime API"
  type        = string
  default     = "langflow-api.example.com"
}

variable "tls_enabled" {
  description = "Enable TLS for ingress"
  type        = bool
  default     = true
}

variable "cert_manager_enabled" {
  description = "Use cert-manager for TLS certificates"
  type        = bool
  default     = true
}

variable "tls_secret_name" {
  description = "Name of TLS secret (if not using cert-manager)"
  type        = string
  default     = "langflow-tls"
}

variable "letsencrypt_email" {
  description = "Email for Let's Encrypt certificate notifications"
  type        = string
  default     = "admin@example.com"
}

# Observability Configuration
variable "enable_observability" {
  description = "Enable observability stack"
  type        = bool
  default     = true
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

variable "grafana_ingress_host" {
  description = "Hostname for Grafana"
  type        = string
  default     = "grafana.example.com"
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

# Network Policy Configuration
variable "enable_network_policies" {
  description = "Enable network policies for enhanced security and network segmentation"
  type        = bool
  default     = true
}
