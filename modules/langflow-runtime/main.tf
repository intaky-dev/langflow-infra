# Langflow Runtime Module - Workers for flow execution

locals {
  labels = {
    app         = "langflow-runtime"
    component   = "runtime-worker"
    environment = var.environment
  }
}

# StatefulSet for Langflow Runtime Workers
resource "kubernetes_stateful_set" "langflow_runtime" {
  metadata {
    name      = "langflow-runtime"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    replicas     = var.min_replicas
    service_name = "langflow-runtime"

    selector {
      match_labels = {
        app       = "langflow-runtime"
        component = "runtime-worker"
      }
    }

    template {
      metadata {
        labels = merge(local.labels, {
          version = var.image_tag
        })
        annotations = {
          "prometheus.io/scrape" = "true"
          "prometheus.io/port"   = "8000"
          "prometheus.io/path"   = "/metrics"
        }
      }

      spec {
        # Anti-affinity to spread workers across nodes
        affinity {
          pod_anti_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              pod_affinity_term {
                label_selector {
                  match_expressions {
                    key      = "app"
                    operator = "In"
                    values   = ["langflow-runtime"]
                  }
                }
                topology_key = "kubernetes.io/hostname"
              }
            }
          }
        }

        # Init container to wait for dependencies
        init_container {
          name  = "wait-for-db"
          image = "busybox:1.36"
          command = [
            "sh",
            "-c",
            "until nc -z postgresql.${var.namespace}.svc.cluster.local 5432; do echo waiting for database; sleep 2; done;"
          ]
        }

        container {
          name  = "langflow-runtime"
          image = "langflowai/langflow:${var.image_tag}"

          # Worker mode configuration
          env {
            name  = "LANGFLOW_WORKER_MODE"
            value = "true"
          }

          env {
            name  = "LANGFLOW_PORT"
            value = "8000"
          }

          env {
            name  = "LANGFLOW_HOST"
            value = "0.0.0.0"
          }

          env {
            name  = "LANGFLOW_DATABASE_URL"
            value = var.database_url
          }

          env {
            name  = "LANGFLOW_BROKER_URL"
            value = var.broker_url
          }

          env {
            name  = "LANGFLOW_VECTOR_STORE_URL"
            value = var.vector_db_url
          }

          # Worker configuration
          env {
            name  = "LANGFLOW_WORKER_TIMEOUT"
            value = "300"
          }

          env {
            name  = "LANGFLOW_MAX_WORKERS"
            value = "4"
          }

          env {
            name  = "LANGFLOW_WORKER_CONCURRENCY"
            value = "2"
          }

          # Cache configuration
          env {
            name  = "LANGFLOW_CACHE_TYPE"
            value = "redis"
          }

          env {
            name  = "LANGFLOW_REDIS_URL"
            value = var.broker_url
          }

          # Performance settings
          env {
            name  = "LANGFLOW_POOL_SIZE"
            value = "10"
          }

          env {
            name  = "LANGFLOW_MAX_OVERFLOW"
            value = "20"
          }

          # Observability
          env {
            name  = "LANGFLOW_LOG_LEVEL"
            value = "INFO"
          }

          env {
            name  = "LANGFLOW_METRICS_ENABLED"
            value = "true"
          }

          port {
            name           = "http"
            container_port = 8000
            protocol       = "TCP"
          }

          port {
            name           = "metrics"
            container_port = 9090
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
              port = 8000
            }
            initial_delay_seconds = 180
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            http_get {
              path = "/ready"
              port = 8000
            }
            initial_delay_seconds = 120
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
          }

          volume_mount {
            name       = "worker-data"
            mount_path = "/app/data"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }
        }

        volume {
          name = "tmp"
          empty_dir {}
        }

        # Security context
        security_context {
          run_as_non_root = true
          run_as_user     = 1000
          fs_group        = 1000
        }
      }
    }

    # Persistent volume for worker data
    volume_claim_template {
      metadata {
        name = "worker-data"
        labels = local.labels
      }

      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = var.storage_class

        resources {
          requests = {
            storage = var.worker_storage_size
          }
        }
      }
    }

    pod_management_policy = "Parallel"

    update_strategy {
      type = "RollingUpdate"
      rolling_update {
        partition = 0
      }
    }
  }
}

# Headless service for StatefulSet
resource "kubernetes_service" "langflow_runtime" {
  metadata {
    name      = "langflow-runtime"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    selector = {
      app       = "langflow-runtime"
      component = "runtime-worker"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }

    port {
      name        = "metrics"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }

    cluster_ip = "None"  # Headless service
  }
}

# Regular service for load balancing
resource "kubernetes_service" "langflow_runtime_lb" {
  metadata {
    name      = "langflow-runtime-lb"
    namespace = var.namespace
    labels    = merge(local.labels, { "service-type" = "load-balancer" })
  }

  spec {
    selector = {
      app       = "langflow-runtime"
      component = "runtime-worker"
    }

    port {
      name        = "http"
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }

    type             = "ClusterIP"
    session_affinity = "None"
  }
}

# PodDisruptionBudget for high availability
resource "kubernetes_pod_disruption_budget_v1" "langflow_runtime" {
  metadata {
    name      = "langflow-runtime"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    min_available = max(1, floor(var.min_replicas / 2))

    selector {
      match_labels = {
        app       = "langflow-runtime"
        component = "runtime-worker"
      }
    }
  }
}

# ServiceMonitor for Prometheus
resource "kubectl_manifest" "langflow_runtime_service_monitor" {
  count = var.enable_monitoring ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "langflow-runtime"
      namespace = var.namespace
      labels    = local.labels
    }
    spec = {
      selector = {
        matchLabels = {
          app       = "langflow-runtime"
          component = "runtime-worker"
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
