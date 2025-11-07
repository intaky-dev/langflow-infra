# Observability Stack Module - Prometheus, Grafana, Loki

locals {
  labels = {
    app         = "observability"
    component   = "monitoring"
    environment = var.environment
  }
}

# Prometheus Operator (kube-prometheus-stack)
resource "helm_release" "prometheus_stack" {
  count = var.prometheus_enabled ? 1 : 0

  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "~> 56.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "30d"

          storageSpec = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = var.prometheus_storage_size
                  }
                }
              }
            }
          }

          resources = {
            requests = {
              cpu    = "500m"
              memory = "2Gi"
            }
            limits = {
              cpu    = "2000m"
              memory = "4Gi"
            }
          }

          # Service monitors
          serviceMonitorSelector = {}
          podMonitorSelector     = {}

          # Additional scrape configs for Langflow components
          additionalScrapeConfigs = [{
            job_name = "langflow-runtime"
            kubernetes_sd_configs = [{
              role = "pod"
              namespaces = {
                names = [var.namespace]
              }
            }]
            relabel_configs = [
              {
                source_labels = ["__meta_kubernetes_pod_label_app"]
                action        = "keep"
                regex         = "langflow-runtime"
              },
              {
                source_labels = ["__meta_kubernetes_pod_container_port_name"]
                action        = "keep"
                regex         = "metrics"
              }
            ]
          }]
        }
      }

      grafana = {
        enabled = var.grafana_enabled

        adminPassword = random_password.grafana_password[0].result

        persistence = {
          enabled          = true
          storageClassName = var.storage_class
          size             = "10Gi"
        }

        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }

        # Grafana dashboards
        dashboardProviders = {
          "dashboardproviders.yaml" = {
            apiVersion = 1
            providers = [{
              name            = "default"
              orgId           = 1
              folder          = ""
              type            = "file"
              disableDeletion = false
              editable        = true
              options = {
                path = "/var/lib/grafana/dashboards/default"
              }
            }]
          }
        }

        dashboards = {
          default = {
            langflow-overview = {
              gnetId     = 15759 # Generic application dashboard
              revision   = 1
              datasource = "Prometheus"
            }
            kubernetes-cluster = {
              gnetId     = 7249
              revision   = 1
              datasource = "Prometheus"
            }
            postgresql = {
              gnetId     = 9628
              revision   = 7
              datasource = "Prometheus"
            }
          }
        }

        # Data sources
        datasources = {
          "datasources.yaml" = {
            apiVersion = 1
            datasources = concat(
              [{
                name      = "Prometheus"
                type      = "prometheus"
                url       = "http://prometheus-kube-prometheus-prometheus:9090"
                access    = "proxy"
                isDefault = true
              }],
              var.loki_enabled ? [{
                name   = "Loki"
                type   = "loki"
                url    = "http://loki:3100"
                access = "proxy"
              }] : []
            )
          }
        }

        sidecar = {
          dashboards = {
            enabled = true
          }
          datasources = {
            enabled = true
          }
        }
      }

      alertmanager = {
        alertmanagerSpec = {
          storage = {
            volumeClaimTemplate = {
              spec = {
                storageClassName = var.storage_class
                accessModes      = ["ReadWriteOnce"]
                resources = {
                  requests = {
                    storage = "10Gi"
                  }
                }
              }
            }
          }

          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }

        config = {
          global = {
            resolve_timeout = "5m"
          }
          route = {
            group_by        = ["alertname", "cluster", "service"]
            group_wait      = "10s"
            group_interval  = "10s"
            repeat_interval = "12h"
            receiver        = "default"
          }
          receivers = [{
            name = "default"
            # Configure your notification channels here
            # slack_configs, email_configs, etc.
          }]
        }
      }

      commonLabels = local.labels
    })
  ]

  timeout = 900
}

# Loki for log aggregation
resource "helm_release" "loki" {
  count = var.loki_enabled ? 1 : 0

  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "~> 5.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      loki = {
        auth_enabled = false

        commonConfig = {
          replication_factor = 1
        }

        storage = {
          type = "filesystem"
        }

        schemaConfig = {
          configs = [{
            from         = "2024-01-01"
            store        = "boltdb-shipper"
            object_store = "filesystem"
            schema       = "v11"
            index = {
              prefix = "index_"
              period = "24h"
            }
          }]
        }
      }

      singleBinary = {
        replicas = 1

        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.loki_storage_size
        }

        resources = {
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
        }
      }

      monitoring = {
        serviceMonitor = {
          enabled = true
        }
      }

      gateway = {
        enabled = true
      }

      labels = local.labels
    })
  ]

  timeout = 600
}

# Promtail for log collection
resource "helm_release" "promtail" {
  count = var.loki_enabled ? 1 : 0

  depends_on = [helm_release.loki]

  name       = "promtail"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "promtail"
  version    = "~> 6.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      config = {
        lokiAddress = "http://loki:3100/loki/api/v1/push"

        snippets = {
          extraScrapeConfigs = <<-EOF
            - job_name: langflow
              kubernetes_sd_configs:
                - role: pod
                  namespaces:
                    names:
                      - ${var.namespace}
              relabel_configs:
                - source_labels: [__meta_kubernetes_pod_label_app]
                  regex: langflow-.*
                  action: keep
                - source_labels: [__meta_kubernetes_pod_name]
                  target_label: pod
                - source_labels: [__meta_kubernetes_namespace]
                  target_label: namespace
          EOF
        }
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }

      labels = local.labels
    })
  ]

  timeout = 600
}

# Generate random password for Grafana
resource "random_password" "grafana_password" {
  count = var.grafana_enabled ? 1 : 0

  length  = 16
  special = true
}

# Secret for Grafana credentials
resource "kubernetes_secret" "grafana_credentials" {
  count = var.grafana_enabled ? 1 : 0

  metadata {
    name      = "grafana-credentials"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    admin-user     = "admin"
    admin-password = random_password.grafana_password[0].result
  }

  type = "Opaque"
}

# PrometheusRule for Langflow alerts
resource "kubectl_manifest" "langflow_alerts" {
  count = var.prometheus_enabled ? 1 : 0

  depends_on = [helm_release.prometheus_stack]

  yaml_body = yamlencode({
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "PrometheusRule"
    metadata = {
      name      = "langflow-alerts"
      namespace = var.namespace
      labels    = merge(local.labels, { prometheus = "kube-prometheus" })
    }
    spec = {
      groups = [{
        name     = "langflow"
        interval = "30s"
        rules = [
          {
            alert = "LangflowRuntimeHighMemory"
            expr  = "container_memory_usage_bytes{pod=~\"langflow-runtime-.*\"} / container_spec_memory_limit_bytes{pod=~\"langflow-runtime-.*\"} > 0.9"
            for   = "5m"
            labels = {
              severity = "warning"
            }
            annotations = {
              summary     = "Langflow Runtime high memory usage"
              description = "Pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of its memory limit"
            }
          },
          {
            alert = "LangflowRuntimeHighCPU"
            expr  = "rate(container_cpu_usage_seconds_total{pod=~\"langflow-runtime-.*\"}[5m]) / container_spec_cpu_quota{pod=~\"langflow-runtime-.*\"} > 0.9"
            for   = "5m"
            labels = {
              severity = "warning"
            }
            annotations = {
              summary     = "Langflow Runtime high CPU usage"
              description = "Pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of its CPU limit"
            }
          },
          {
            alert = "LangflowQueueBacklog"
            expr  = "keda_scaler_metrics_value{scaledObject=\"langflow-runtime-scaler\"} > 50"
            for   = "5m"
            labels = {
              severity = "warning"
            }
            annotations = {
              summary     = "High message queue backlog"
              description = "Queue has {{ $value }} messages pending"
            }
          },
          {
            alert = "LangflowDatabaseDown"
            expr  = "up{job=\"postgresql\"} == 0"
            for   = "2m"
            labels = {
              severity = "critical"
            }
            annotations = {
              summary     = "PostgreSQL database is down"
              description = "PostgreSQL instance is not responding"
            }
          }
        ]
      }]
    }
  })
}
