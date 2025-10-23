output "ingress_class" {
  description = "Ingress class name"
  value       = var.ingress_class
}

output "ide_ingress_url" {
  description = "URL for Langflow IDE"
  value       = var.ide_host != "" ? "${var.tls_enabled ? "https" : "http"}://${var.ide_host}" : null
}

output "runtime_ingress_url" {
  description = "URL for Langflow Runtime API"
  value       = var.runtime_host != "" ? "${var.tls_enabled ? "https" : "http"}://${var.runtime_host}" : null
}

output "grafana_ingress_url" {
  description = "URL for Grafana"
  value       = var.grafana_host != "" ? "${var.tls_enabled ? "https" : "http"}://${var.grafana_host}" : null
}

output "cert_manager_enabled" {
  description = "Whether cert-manager is enabled"
  value       = var.cert_manager
}
