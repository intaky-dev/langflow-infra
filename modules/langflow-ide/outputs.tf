output "service_name" {
  description = "Name of the IDE service"
  value       = kubernetes_service.langflow_ide.metadata[0].name
}

output "deployment_name" {
  description = "Name of the IDE deployment"
  value       = kubernetes_deployment.langflow_ide.metadata[0].name
}

output "port" {
  description = "Service port"
  value       = kubernetes_service.langflow_ide.spec[0].port[0].port
}
