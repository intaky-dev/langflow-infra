variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vector_db" {
  description = "Vector database type (qdrant, weaviate, or milvus)"
  type        = string

  validation {
    condition     = contains(["qdrant", "weaviate", "milvus"], var.vector_db)
    error_message = "Vector DB must be qdrant, weaviate, or milvus."
  }
}

variable "replicas" {
  description = "Number of vector database replicas"
  type        = number
  default     = 2
}

variable "storage_size" {
  description = "Storage size for vector database"
  type        = string
  default     = "20Gi"
}

variable "storage_class" {
  description = "Storage class for persistent volumes"
  type        = string
  default     = "standard"
}

variable "enable_network_policy" {
  description = "Enable network policies for vector database security"
  type        = bool
  default     = true
}
