# Message Broker Module - RabbitMQ or Redis

locals {
  broker_name = var.broker_type == "rabbitmq" ? "rabbitmq" : "redis"
  labels = {
    app         = local.broker_name
    component   = "message-broker"
    environment = var.environment
  }
}

# RabbitMQ Deployment
resource "helm_release" "rabbitmq" {
  count = var.broker_type == "rabbitmq" ? 1 : 0

  name       = "rabbitmq"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "rabbitmq"
  version    = "~> 13.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      replicaCount = var.rabbitmq_replicas

      auth = {
        username = "langflow"
        password = random_password.broker_password.result
        erlangCookie = random_password.erlang_cookie[0].result
      }

      persistence = {
        enabled = true
        size    = var.rabbitmq_storage_size
      }

      resources = {
        requests = {
          cpu    = "500m"
          memory = "1Gi"
        }
        limits = {
          cpu    = "2000m"
          memory = "2Gi"
        }
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }

      clustering = {
        enabled = true
      }

      extraConfiguration = <<-EOF
        queue_master_locator = min-masters
        vm_memory_high_watermark.relative = 0.6
        disk_free_limit.absolute = 2GB
      EOF

      extraPlugins = "rabbitmq_stream rabbitmq_prometheus"

      podLabels = local.labels
    })
  ]

  timeout = 600
}

# Redis Deployment (Sentinel mode for HA)
resource "helm_release" "redis" {
  count = var.broker_type == "redis" ? 1 : 0

  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = "~> 18.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      architecture = "replication"

      auth = {
        enabled  = true
        password = random_password.broker_password.result
      }

      master = {
        persistence = {
          enabled = true
          size    = var.redis_storage_size
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
      }

      replica = {
        replicaCount = var.redis_replicas - 1
        persistence = {
          enabled = true
          size    = var.redis_storage_size
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
      }

      sentinel = {
        enabled = true
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }

      commonLabels = local.labels
    })
  ]

  timeout = 600
}

# Generate random password for broker
resource "random_password" "broker_password" {
  length  = 32
  special = true
}

# Generate Erlang cookie for RabbitMQ clustering
resource "random_password" "erlang_cookie" {
  count = var.broker_type == "rabbitmq" ? 1 : 0

  length  = 32
  special = false
}

# Secret to store broker credentials
resource "kubernetes_secret" "broker_credentials" {
  metadata {
    name      = "${local.broker_name}-credentials"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    password = random_password.broker_password.result
    username = var.broker_type == "rabbitmq" ? "langflow" : ""
  }

  type = "Opaque"
}

# ConfigMap for broker connection details
resource "kubernetes_config_map" "broker_config" {
  metadata {
    name      = "${local.broker_name}-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    broker_type = var.broker_type
    host        = local.broker_host
    port        = local.broker_port
    url         = local.connection_string
  }
}

locals {
  broker_host = var.broker_type == "rabbitmq" ? "rabbitmq.${var.namespace}.svc.cluster.local" : "redis-master.${var.namespace}.svc.cluster.local"
  broker_port = var.broker_type == "rabbitmq" ? "5672" : "6379"

  connection_string = var.broker_type == "rabbitmq" ? "amqp://langflow:${random_password.broker_password.result}@${local.broker_host}:${local.broker_port}/" : "redis://:${random_password.broker_password.result}@${local.broker_host}:${local.broker_port}/0"
}
