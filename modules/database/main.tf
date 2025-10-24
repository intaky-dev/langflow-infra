# PostgreSQL Database Module
# Uses simple PostgreSQL chart for development/Minikube
# For production HA, consider using cloud-managed PostgreSQL

locals {
  labels = {
    app         = "postgresql"
    component   = "database"
    environment = var.environment
  }
}

# PostgreSQL using Bitnami chart
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "~> 13.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      auth = {
        username = "langflow"
        password = random_password.postgres_password.result
        database = "langflow"
      }

      # Use latest tag - only tag guaranteed to exist after Bitnami migration
      image = {
        registry   = "docker.io"
        repository = "bitnami/postgresql"
        tag        = "latest"
      }

      # Disable volumePermissions init container to avoid os-shell image issues
      volumePermissions = {
        enabled = false
      }

      primary = {
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
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

        # Disable health probes for official postgres image compatibility
        startupProbe = {
          enabled = false
        }
        livenessProbe = {
          enabled = false
        }
        readinessProbe = {
          enabled = false
        }

        # PostgreSQL configuration for better performance
        extendedConfiguration = <<-EOF
          max_connections = 100
          shared_buffers = 256MB
          effective_cache_size = 1GB
          maintenance_work_mem = 64MB
          checkpoint_completion_target = 0.9
          wal_buffers = 8MB
          default_statistics_target = 100
          random_page_cost = 1.1
          effective_io_concurrency = 200
          work_mem = 2621kB
        EOF
      }

      # Disable metrics to avoid postgres-exporter image issues
      metrics = {
        enabled = false
      }

      commonLabels = local.labels
    })
  ]

  timeout = 600
}

# Generate password
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

# Secret to store database credentials
resource "kubernetes_secret" "postgres_credentials" {
  metadata {
    name      = "postgresql-credentials"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    username = "langflow"
    password = random_password.postgres_password.result
    database = "langflow"
    host     = local.db_host
    port     = local.db_port
  }

  type = "Opaque"
}

# ConfigMap for database connection details
resource "kubernetes_config_map" "postgres_config" {
  metadata {
    name      = "postgresql-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    host            = local.db_host
    port            = local.db_port
    database        = "langflow"
    connection_pool = "true"
    max_connections = "20"
  }
}

locals {
  # Service name for PostgreSQL
  db_host = "postgresql.${var.namespace}.svc.cluster.local"
  db_port = "5432"

  connection_string = "postgresql://langflow:${random_password.postgres_password.result}@${local.db_host}:${local.db_port}/langflow"
}
