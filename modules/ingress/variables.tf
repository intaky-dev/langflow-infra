variable "namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ingress_class" {
  description = "Ingress class name"
  type        = string
  default     = "nginx"
}

variable "tls_enabled" {
  description = "Enable TLS for ingress"
  type        = bool
  default     = true
}

variable "cert_manager" {
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

variable "ide_host" {
  description = "Hostname for Langflow IDE"
  type        = string
  default     = ""
}

variable "runtime_host" {
  description = "Hostname for Langflow Runtime API"
  type        = string
  default     = ""
}

variable "grafana_host" {
  description = "Hostname for Grafana"
  type        = string
  default     = ""
}
