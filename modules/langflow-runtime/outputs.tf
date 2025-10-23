output "service_name" {
  description = "Name of the runtime headless service"
  value       = kubernetes_service.langflow_runtime.metadata[0].name
}

output "lb_service_name" {
  description = "Name of the runtime load balancer service"
  value       = kubernetes_service.langflow_runtime_lb.metadata[0].name
}

output "deployment_name" {
  description = "Name of the runtime StatefulSet"
  value       = kubernetes_stateful_set.langflow_runtime.metadata[0].name
}

output "port" {
  description = "Service port"
  value       = 8000
}
