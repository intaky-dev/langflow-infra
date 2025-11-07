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
        username     = "langflow"
        password     = random_password.broker_password.result
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
          enabled = false
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
  version    = "20.3.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      architecture = "replication"

      auth = {
        enabled  = true
        password = random_password.broker_password.result
      }

      # Use specific version for reproducible deployments
      image = {
        registry   = "docker.io"
        repository = "bitnami/redis"
        tag        = "7.4.1"
      }

      sentinel = {
        enabled = true
        image = {
          registry   = "docker.io"
          repository = "bitnami/redis-sentinel"
          tag        = "7.4.1"
        }
      }

      metrics = {
        enabled = true
        image = {
          registry   = "docker.io"
          repository = "bitnami/redis-exporter"
          tag        = "1.66.0"
        }
        serviceMonitor = {
          enabled = false
        }
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
  broker_host = var.broker_type == "rabbitmq" ? "rabbitmq.${var.namespace}.svc.cluster.local" : "redis.${var.namespace}.svc.cluster.local"
  broker_port = var.broker_type == "rabbitmq" ? "5672" : "6379"

  connection_string = var.broker_type == "rabbitmq" ? "amqp://langflow:${urlencode(random_password.broker_password.result)}@${local.broker_host}:${local.broker_port}/" : "redis://:${urlencode(random_password.broker_password.result)}@${local.broker_host}:${local.broker_port}/0"
}

# Network Policy for RabbitMQ
# Restricts access to only Langflow Runtime workers and KEDA
resource "kubernetes_network_policy" "rabbitmq" {
  count = var.enable_network_policy && var.broker_type == "rabbitmq" ? 1 : 0

  metadata {
    name      = "rabbitmq-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "rabbitmq"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO RabbitMQ
    ingress {
      # Allow from Langflow Runtime workers
      from {
        pod_selector {
          match_labels = {
            app = "langflow-runtime"
          }
        }
      }

      # Allow from KEDA for metrics scraping
      from {
        namespace_selector {
          match_labels = {
            name = "keda-system"
          }
        }
      }

      # Allow internal RabbitMQ cluster communication
      from {
        pod_selector {
          match_labels = {
            app = "rabbitmq"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5672" # AMQP
      }

      ports {
        protocol = "TCP"
        port     = "15672" # Management UI
      }

      ports {
        protocol = "TCP"
        port     = "4369" # EPMD (Erlang Port Mapper Daemon)
      }

      ports {
        protocol = "TCP"
        port     = "25672" # Inter-node communication
      }
    }

    # Egress rules - where RabbitMQ can connect TO
    egress {
      # Allow DNS resolution
      to {
        namespace_selector {}
      }

      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    egress {
      # Allow internal RabbitMQ cluster communication
      to {
        pod_selector {
          match_labels = {
            app = "rabbitmq"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "4369"
      }

      ports {
        protocol = "TCP"
        port     = "25672"
      }
    }

    egress {
      # Allow external connections if needed
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }
  }
}

# Network Policy for Redis
# Restricts access to only Langflow Runtime workers and KEDA
resource "kubernetes_network_policy" "redis" {
  count = var.enable_network_policy && var.broker_type == "redis" ? 1 : 0

  metadata {
    name      = "redis-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "redis"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO Redis
    ingress {
      # Allow from Langflow Runtime workers
      from {
        pod_selector {
          match_labels = {
            app = "langflow-runtime"
          }
        }
      }

      # Allow from KEDA for metrics scraping
      from {
        namespace_selector {
          match_labels = {
            name = "keda-system"
          }
        }
      }

      # Allow internal Redis replication (master-replica communication)
      from {
        pod_selector {
          match_labels = {
            app = "redis"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "6379" # Redis port
      }

      ports {
        protocol = "TCP"
        port     = "26379" # Sentinel port
      }
    }

    # Egress rules - where Redis can connect TO
    egress {
      # Allow DNS resolution
      to {
        namespace_selector {}
      }

      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    egress {
      # Allow internal Redis replication
      to {
        pod_selector {
          match_labels = {
            app = "redis"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "6379"
      }

      ports {
        protocol = "TCP"
        port     = "26379"
      }
    }

    egress {
      # Allow external connections if needed
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }
  }
}
