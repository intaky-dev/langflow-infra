# PostgreSQL Database Module - SIMPLE VERSION (No HA)
# Uses standard PostgreSQL chart - much simpler and more reliable

locals {
  labels = {
    app         = "postgresql"
    component   = "database"
    environment = var.environment
  }

  db_host = "postgresql.${var.namespace}.svc.cluster.local"
  db_port = "5432"
}

# PostgreSQL using Bitnami chart (simple, not HA)
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "~> 15.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      auth = {
        username = "langflow"
        password = random_password.postgres_password.result
        database = "langflow"
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
      }

      metrics = {
        enabled = false
      }
    })
  ]

  timeout = 600
}

# Generate password for PostgreSQL
resource "random_password" "postgres_password" {
  length  = 32
  special = false
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
  connection_string = "postgresql://langflow:${urlencode(random_password.postgres_password.result)}@${local.db_host}:${local.db_port}/langflow"
}
