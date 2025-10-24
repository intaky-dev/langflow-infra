# Langflow IDE Module - UI for flow editing

locals {
  labels = {
    app         = "langflow-ide"
    component   = "ide"
    environment = var.environment
  }
}

# Deployment for Langflow IDE
resource "kubernetes_deployment" "langflow_ide" {
  metadata {
    name      = "langflow-ide"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app       = "langflow-ide"
        component = "ide"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          version = var.image_tag
        })
      }

      spec {
        # Anti-affinity to spread pods across nodes
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["langflow-ide"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        container {
          name  = "langflow-ide"
          image = "langflowai/langflow:${var.image_tag}"

          env {
            name  = "LANGFLOW_DATABASE_URL"
            value = var.database_url
          }

          env {
            name  = "LANGFLOW_CONFIG_DIR"
            value = "/app/config"
          }

          env {
            name  = "LANGFLOW_SAVE_DB_IN_CONFIG_DIR"
            value = "false"
          }

          # IDE mode - primarily for editing
          env {
            name  = "LANGFLOW_WORKER_MODE"
            value = "false"
          }

          env {
            name  = "LANGFLOW_FRONTEND_PATH"
            value = "/app/frontend"
          }

          env {
            name  = "LANGFLOW_BACKEND_ONLY"
            value = "true"
          }

          # Performance settings
          env {
            name  = "LANGFLOW_CACHE_TYPE"
            value = "memory"
          }

          port {
            name           = "http"
            container_port = 7860
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = var.resources.requests.cpu
              memory = var.resources.requests.memory
            }
            limits = {
              cpu    = var.resources.limits.cpu
              memory = var.resources.limits.memory
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 7860
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 7860
            }
            initial_delay_seconds = 30
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          volume_mount {
            name       = "config"
            mount_path = "/app/config"
          }
        }

        # Use emptyDir for writable config storage
        volume {
          name = "config"
          empty_dir {}
        }
      }
    }

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }
  }
}

# Service for Langflow IDE
resource "kubernetes_service" "langflow_ide" {
  metadata {
    name      = "langflow-ide"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = {
      app       = "langflow-ide"
      component = "ide"
    }

    port {
      name        = "http"
      port        = 7860
      target_port = 7860
      protocol    = "TCP"
    }

    type             = "ClusterIP"
    session_affinity = "ClientIP"
  }
}

# ConfigMap for IDE configuration
resource "kubernetes_config_map" "langflow_ide_config" {
  metadata {
    name      = "langflow-ide-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    "config.yaml" = yamlencode({
      database = {
        url = var.database_url
      }
      cache = {
        type = "memory"
      }
      frontend = {
        enabled = true
      }
    })
  }
}

# HorizontalPodAutoscaler for IDE
resource "kubernetes_horizontal_pod_autoscaler_v2" "langflow_ide" {
  metadata {
    name      = "langflow-ide"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    scale_target_ref {
      api_version = "apps/v1"
      kind        = "Deployment"
      name        = kubernetes_deployment.langflow_ide.metadata[0].name
    }

    min_replicas = var.replicas
    max_replicas = var.replicas * 3

    metric {
      type = "Resource"
      resource {
        name = "cpu"
        target {
          type                = "Utilization"
          average_utilization = 70
        }
      }
    }

    metric {
      type = "Resource"
      resource {
        name = "memory"
        target {
          type                = "Utilization"
          average_utilization = 80
        }
      }
    }
  }
}

# ServiceMonitor for Prometheus (if monitoring is enabled)
resource "kubectl_manifest" "langflow_ide_service_monitor" {
  count = var.enable_monitoring ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "langflow-ide"
      namespace = var.namespace
      labels    = local.labels
    }
    spec = {
      selector = {
        matchLabels = {
          app       = "langflow-ide"
          component = "ide"
        }
      }
      endpoints = [{
        port     = "http"
        path     = "/metrics"
        interval = "30s"
      }]
    }
  })
}
