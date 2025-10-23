output "connection_string" {
  description = "Broker connection string"
  value       = local.connection_string
  sensitive   = true
}

output "host" {
  description = "Broker host"
  value       = local.broker_host
}

output "port" {
  description = "Broker port"
  value       = local.broker_port
}

output "secret_name" {
  description = "Name of the secret containing broker credentials"
  value       = kubernetes_secret.broker_credentials.metadata[0].name
}

output "config_map_name" {
  description = "Name of the ConfigMap containing broker configuration"
  value       = kubernetes_config_map.broker_config.metadata[0].name
}
