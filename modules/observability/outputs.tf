output "prometheus_url" {
  description = "Prometheus URL"
  value       = var.prometheus_enabled ? "http://prometheus-kube-prometheus-prometheus.${var.namespace}.svc.cluster.local:9090" : null
}

output "grafana_url" {
  description = "Grafana URL"
  value       = var.grafana_enabled ? "http://prometheus-grafana.${var.namespace}.svc.cluster.local:80" : null
}

output "grafana_admin_password" {
  description = "Grafana admin password"
  value       = var.grafana_enabled ? random_password.grafana_password[0].result : null
  sensitive   = true
}

output "loki_url" {
  description = "Loki URL"
  value       = var.loki_enabled ? "http://loki.${var.namespace}.svc.cluster.local:3100" : null
}

output "alertmanager_url" {
  description = "Alertmanager URL"
  value       = var.prometheus_enabled ? "http://prometheus-kube-prometheus-alertmanager.${var.namespace}.svc.cluster.local:9093" : null
}
