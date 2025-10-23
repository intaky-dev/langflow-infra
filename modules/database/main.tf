# PostgreSQL HA Database Module

locals {
  labels = {
    app         = "postgresql"
    component   = "database"
    environment = var.environment
  }
}

# PostgreSQL HA using Bitnami chart with replication
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql-ha"
  version    = "14.2.32"
  namespace  = var.namespace

  values = [
    yamlencode({
      image = {
        registry = "docker.io"
        repository = "bitnami/postgresql-repmgr"
        tag = "16.4.0-debian-12-r7"
      }

      postgresql = {
        replicaCount = var.postgres_replicas

        username     = "langflow"
        password     = random_password.postgres_password.result
        database     = "langflow"

        repmgrUsername = "repmgr"
        repmgrPassword = random_password.repmgr_password.result

        resources = {
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
          limits = {
            cpu    = "2000m"
            memory = "4Gi"
          }
        }

        # PostgreSQL configuration for production
        extendedConfiguration = <<-EOF
          max_connections = 200
          shared_buffers = 512MB
          effective_cache_size = 2GB
          maintenance_work_mem = 128MB
          checkpoint_completion_target = 0.9
          wal_buffers = 16MB
          default_statistics_target = 100
          random_page_cost = 1.1
          effective_io_concurrency = 200
          work_mem = 2621kB
          min_wal_size = 1GB
          max_wal_size = 4GB
          max_worker_processes = 4
          max_parallel_workers_per_gather = 2
          max_parallel_workers = 4
          max_parallel_maintenance_workers = 2
        EOF
      }

      persistence = {
        enabled      = true
        storageClass = var.storage_class
        size         = var.storage_size
      }

      pgpool = {
        image = {
          registry = "docker.io"
          repository = "bitnami/pgpool"
          tag = "4.5.4-debian-12-r2"
        }

        replicaCount = 2

        adminUsername = "admin"
        adminPassword = random_password.pgpool_password.result

        resources = {
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }

        # Load balancing configuration
        numInitChildren = 32
        maxPool = 4
        childLifeTime = 300
        childMaxConnections = 50
        connectionLifeTime = 600
        clientIdleLimit = 0
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = false
        }
      }

      volumePermissions = {
        enabled = true
      }

      # Automatic backup configuration
      backup = {
        enabled = false  # Enable if you want automated backups
        cronjob = {
          schedule = "0 2 * * *"  # Daily at 2 AM
          storage = {
            size = "20Gi"
          }
        }
      }

      commonLabels = local.labels
    })
  ]

  timeout = 900
}

# Generate passwords
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

resource "random_password" "repmgr_password" {
  length  = 32
  special = true
}

resource "random_password" "pgpool_password" {
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
  # PgPool service for load balancing
  db_host = "postgresql-pgpool.${var.namespace}.svc.cluster.local"
  db_port = "5432"

  connection_string = "postgresql://langflow:${random_password.postgres_password.result}@${local.db_host}:${local.db_port}/langflow"
}
