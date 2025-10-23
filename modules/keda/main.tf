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
            enabled = true
          }
        }
        operator = {
          enabled = true
          serviceMonitor = {
            enabled = true
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

      pollingInterval  = 10
      cooldownPeriod   = 60
      minReplicaCount  = var.min_replicas
      maxReplicaCount  = var.max_replicas

      advanced = {
        horizontalPodAutoscalerConfig = {
          behavior = {
            scaleDown = {
              stabilizationWindowSeconds = 300
              policies = [{
                type          = "Percent"
                value         = 50
                periodSeconds = 60
              }]
            }
            scaleUp = {
              stabilizationWindowSeconds = 0
              policies = [{
                type          = "Percent"
                value         = 100
                periodSeconds = 30
              }, {
                type          = "Pods"
                value         = 2
                periodSeconds = 30
              }]
              selectPolicy = "Max"
            }
          }
        }
      }

      triggers = [
        # RabbitMQ queue length trigger
        {
          type = "rabbitmq"
          metadata = {
            protocol          = "auto"
            host              = var.broker_connection_url
            mode              = "QueueLength"
            value             = tostring(var.queue_length_threshold)
            queueName         = var.queue_name
            activationValue   = "0"
          }
        },
        # CPU utilization trigger
        {
          type = "cpu"
          metricType = "Utilization"
          metadata = {
            value = tostring(var.cpu_threshold)
          }
        },
        # Memory utilization trigger
        {
          type = "memory"
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

      pollingInterval  = 10
      cooldownPeriod   = 60
      minReplicaCount  = var.min_replicas
      maxReplicaCount  = var.max_replicas

      advanced = {
        horizontalPodAutoscalerConfig = {
          behavior = {
            scaleDown = {
              stabilizationWindowSeconds = 300
              policies = [{
                type          = "Percent"
                value         = 50
                periodSeconds = 60
              }]
            }
            scaleUp = {
              stabilizationWindowSeconds = 0
              policies = [{
                type          = "Percent"
                value         = 100
                periodSeconds = 30
              }, {
                type          = "Pods"
                value         = 2
                periodSeconds = 30
              }]
              selectPolicy = "Max"
            }
          }
        }
      }

      triggers = [
        # Redis list length trigger
        {
          type = "redis"
          metadata = {
            address             = var.broker_connection_url
            listName            = var.queue_name
            listLength          = tostring(var.queue_length_threshold)
            activationListLength = "0"
          }
        },
        # CPU utilization trigger
        {
          type = "cpu"
          metricType = "Utilization"
          metadata = {
            value = tostring(var.cpu_threshold)
          }
        },
        # Memory utilization trigger
        {
          type = "memory"
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
