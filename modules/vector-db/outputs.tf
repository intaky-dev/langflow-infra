output "connection_string" {
  description = "Vector database connection string"
  value       = local.connection_string
}

output "host" {
  description = "Vector database host"
  value       = local.host
}

output "port" {
  description = "Vector database port"
  value       = local.port
}

output "config_map_name" {
  description = "Name of the ConfigMap containing vector DB configuration"
  value       = kubernetes_config_map.vector_db_config.metadata[0].name
}
