output "namespace" {
  description = "Kubernetes namespace where Langflow is deployed"
  value       = kubernetes_namespace.langflow.metadata[0].name
}

output "database_connection" {
  description = "PostgreSQL connection details"
  value = {
    host     = module.database.host
    port     = module.database.port
    database = module.database.database_name
  }
  sensitive = false
}

output "broker_connection" {
  description = "Message broker connection details"
  value = {
    type = var.broker_type
    url  = module.message_broker.connection_string
    host = module.message_broker.host
    port = module.message_broker.port
  }
  sensitive = true
}

output "vector_db_connection" {
  description = "Vector database connection details"
  value = {
    type = var.vector_db_type
    url  = module.vector_db.connection_string
    host = module.vector_db.host
    port = module.vector_db.port
  }
  sensitive = false
}

output "langflow_ide_url" {
  description = "Langflow IDE URL"
  value       = var.ingress_enabled ? "https://${var.ide_ingress_host}" : "kubectl port-forward -n ${kubernetes_namespace.langflow.metadata[0].name} svc/langflow-ide 7860:7860"
}

output "langflow_runtime_url" {
  description = "Langflow Runtime API URL"
  value       = var.ingress_enabled ? "https://${var.runtime_ingress_host}" : "kubectl port-forward -n ${kubernetes_namespace.langflow.metadata[0].name} svc/langflow-runtime 8000:8000"
}

output "grafana_url" {
  description = "Grafana dashboard URL"
  value       = var.enable_observability && var.grafana_enabled ? (var.ingress_enabled ? "https://${var.grafana_ingress_host}" : "kubectl port-forward -n ${kubernetes_namespace.langflow.metadata[0].name} svc/grafana 3000:3000") : null
}

output "keda_scaler_status" {
  description = "KEDA scaler configuration"
  value = {
    min_replicas         = var.runtime_min_replicas
    max_replicas         = var.runtime_max_replicas
    queue_threshold      = var.keda_queue_threshold
    cpu_threshold        = var.keda_cpu_threshold
    memory_threshold     = var.keda_memory_threshold
  }
}

output "deployment_summary" {
  description = "Summary of deployment configuration"
  value = {
    environment      = var.environment
    namespace        = kubernetes_namespace.langflow.metadata[0].name
    broker           = var.broker_type
    database         = "postgresql"
    vector_db        = var.vector_db_type
    ide_replicas     = var.ide_replicas
    runtime_replicas = "${var.runtime_min_replicas}-${var.runtime_max_replicas} (auto-scaled)"
    observability    = var.enable_observability
  }
}
