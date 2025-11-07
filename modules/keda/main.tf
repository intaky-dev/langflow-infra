# KEDA Autoscaling Module

locals {
  labels = {
    app         = "keda"
    component   = "autoscaler"
    environment = var.environment
  }
}

# Install KEDA using Helm
resource "helm_release" "keda" {
  name       = "keda"
  repository = "https://kedacore.github.io/charts"
  chart      = "keda"
  version    = "~> 2.13"
  namespace  = "keda-system"

  create_namespace = true

  values = [
    yamlencode({
      resources = {
        operator = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
        metricServer = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }

      prometheus = {
        metricServer = {
          enabled = true
          serviceMonitor = {
            enabled = false
          }
        }
        operator = {
          enabled = true
          serviceMonitor = {
            enabled = false
          }
        }
      }
    })
  ]

  timeout = 600
}

# ScaledObject for RabbitMQ
resource "kubectl_manifest" "scaled_object_rabbitmq" {
  count = var.broker_type == "rabbitmq" ? 1 : 0

  depends_on = [helm_release.keda]

  yaml_body = yamlencode({
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "langflow-runtime-scaler"
      namespace = var.namespace
      labels    = local.labels
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind       = "StatefulSet"
        name       = var.target_deployment
      }

      # Polling and scaling intervals
      pollingInterval = 10 # Check metrics every 10 seconds
      cooldownPeriod  = 60 # Wait 60s after scale down before checking again

      # Replica bounds
      minReplicaCount = var.min_replicas
      maxReplicaCount = var.max_replicas

      # Advanced HPA configuration
      advanced = {
        restoreToOriginalReplicaCount = false # Don't restore to original count
        horizontalPodAutoscalerConfig = {
          behavior = {
            # Scale down conservatively to avoid disruptions
            scaleDown = {
              stabilizationWindowSeconds = 300 # Wait 5 min before scaling down
              selectPolicy               = "Min"
              policies = [
                {
                  type          = "Percent"
                  value         = 50 # Max 50% reduction per cycle
                  periodSeconds = 60
                },
                {
                  type          = "Pods"
                  value         = 1 # Or 1 pod at a time
                  periodSeconds = 60
                }
              ]
            }

            # Scale up aggressively to handle load spikes
            scaleUp = {
              stabilizationWindowSeconds = 0 # No delay on scale up
              selectPolicy               = "Max"
              policies = [
                {
                  type          = "Percent"
                  value         = 100 # Double pods if needed
                  periodSeconds = 30
                },
                {
                  type          = "Pods"
                  value         = 2 # Or add 2 pods
                  periodSeconds = 30
                },
                {
                  type          = "Pods"
                  value         = 4 # Or add 4 pods for extreme load
                  periodSeconds = 60
                }
              ]
            }
          }
        }
      }

      triggers = [
        # RabbitMQ queue length trigger
        {
          type = "rabbitmq"
          metadata = {
            protocol        = "auto"
            host            = var.broker_connection_url
            mode            = "QueueLength"
            value           = tostring(var.queue_length_threshold)
            queueName       = var.queue_name
            activationValue = "0"
          }
        },
        # CPU utilization trigger
        {
          type       = "cpu"
          metricType = "Utilization"
          metadata = {
            value = tostring(var.cpu_threshold)
          }
        },
        # Memory utilization trigger
        {
          type       = "memory"
          metricType = "Utilization"
          metadata = {
            value = tostring(var.memory_threshold)
          }
        }
      ]
    }
  })
}

# ScaledObject for Redis
resource "kubectl_manifest" "scaled_object_redis" {
  count = var.broker_type == "redis" ? 1 : 0

  depends_on = [helm_release.keda]

  yaml_body = yamlencode({
    apiVersion = "keda.sh/v1alpha1"
    kind       = "ScaledObject"
    metadata = {
      name      = "langflow-runtime-scaler"
      namespace = var.namespace
      labels    = local.labels
    }
    spec = {
      scaleTargetRef = {
        apiVersion = "apps/v1"
        kind       = "StatefulSet"
        name       = var.target_deployment
      }

      # Polling and scaling intervals
      pollingInterval = 10 # Check metrics every 10 seconds
      cooldownPeriod  = 60 # Wait 60s after scale down before checking again

      # Replica bounds
      minReplicaCount = var.min_replicas
      maxReplicaCount = var.max_replicas

      # Advanced HPA configuration
      advanced = {
        restoreToOriginalReplicaCount = false # Don't restore to original count
        horizontalPodAutoscalerConfig = {
          behavior = {
            # Scale down conservatively to avoid disruptions
            scaleDown = {
              stabilizationWindowSeconds = 300 # Wait 5 min before scaling down
              selectPolicy               = "Min"
              policies = [
                {
                  type          = "Percent"
                  value         = 50 # Max 50% reduction per cycle
                  periodSeconds = 60
                },
                {
                  type          = "Pods"
                  value         = 1 # Or 1 pod at a time
                  periodSeconds = 60
                }
              ]
            }

            # Scale up aggressively to handle load spikes
            scaleUp = {
              stabilizationWindowSeconds = 0 # No delay on scale up
              selectPolicy               = "Max"
              policies = [
                {
                  type          = "Percent"
                  value         = 100 # Double pods if needed
                  periodSeconds = 30
                },
                {
                  type          = "Pods"
                  value         = 2 # Or add 2 pods
                  periodSeconds = 30
                },
                {
                  type          = "Pods"
                  value         = 4 # Or add 4 pods for extreme load
                  periodSeconds = 60
                }
              ]
            }
          }
        }
      }

      triggers = [
        # Redis list length trigger
        {
          type = "redis"
          metadata = {
            address              = var.broker_connection_url
            listName             = var.queue_name
            listLength           = tostring(var.queue_length_threshold)
            activationListLength = "0"
          }
        },
        # CPU utilization trigger
        {
          type       = "cpu"
          metricType = "Utilization"
          metadata = {
            value = tostring(var.cpu_threshold)
          }
        },
        # Memory utilization trigger
        {
          type       = "memory"
          metricType = "Utilization"
          metadata = {
            value = tostring(var.memory_threshold)
          }
        }
      ]
    }
  })
}

# TriggerAuthentication for secure broker credentials (if needed)
resource "kubectl_manifest" "trigger_authentication" {
  count = var.broker_type == "rabbitmq" ? 1 : 0

  depends_on = [helm_release.keda]

  yaml_body = yamlencode({
    apiVersion = "keda.sh/v1alpha1"
    kind       = "TriggerAuthentication"
    metadata = {
      name      = "rabbitmq-trigger-auth"
      namespace = var.namespace
      labels    = local.labels
    }
    spec = {
      secretTargetRef = [{
        parameter = "host"
        name      = "rabbitmq-credentials"
        key       = "connection-url"
      }]
    }
  })
}

# ServiceMonitor for KEDA metrics
resource "kubectl_manifest" "keda_service_monitor" {
  count = var.enable_monitoring ? 1 : 0

  depends_on = [helm_release.keda]

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "keda"
      namespace = "keda-system"
      labels    = local.labels
    }
    spec = {
      selector = {
        matchLabels = {
          app = "keda-operator"
        }
      }
      endpoints = [{
        port     = "metrics"
        path     = "/metrics"
        interval = "30s"
      }]
    }
  })
}

# ConfigMap for KEDA configuration
resource "kubernetes_config_map" "keda_config" {
  metadata {
    name      = "keda-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    broker_type            = var.broker_type
    queue_name             = var.queue_name
    min_replicas           = tostring(var.min_replicas)
    max_replicas           = tostring(var.max_replicas)
    queue_length_threshold = tostring(var.queue_length_threshold)
    cpu_threshold          = tostring(var.cpu_threshold)
    memory_threshold       = tostring(var.memory_threshold)
  }
}
