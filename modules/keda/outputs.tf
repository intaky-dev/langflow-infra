output "keda_namespace" {
  description = "Namespace where KEDA is installed"
  value       = "keda-system"
}

output "scaled_object_name" {
  description = "Name of the ScaledObject"
  value       = "langflow-runtime-scaler"
}

output "scaling_config" {
  description = "KEDA scaling configuration"
  value = {
    min_replicas     = var.min_replicas
    max_replicas     = var.max_replicas
    queue_threshold  = var.queue_length_threshold
    cpu_threshold    = var.cpu_threshold
    memory_threshold = var.memory_threshold
    polling_interval = 10
    cooldown_period  = 60
  }
}
