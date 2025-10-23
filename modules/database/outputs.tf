output "connection_string" {
  description = "PostgreSQL connection string"
  value       = local.connection_string
  sensitive   = true
}

output "host" {
  description = "PostgreSQL host (PgPool load balancer)"
  value       = local.db_host
}

output "port" {
  description = "PostgreSQL port"
  value       = local.db_port
}

output "database_name" {
  description = "Database name"
  value       = "langflow"
}

output "secret_name" {
  description = "Name of the secret containing database credentials"
  value       = kubernetes_secret.postgres_credentials.metadata[0].name
}

output "config_map_name" {
  description = "Name of the ConfigMap containing database configuration"
  value       = kubernetes_config_map.postgres_config.metadata[0].name
}
