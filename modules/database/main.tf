# PostgreSQL Database Module
# Uses PostgreSQL-HA chart with PgPool for load balancing and failover
# Supports replication streaming and automatic failover

locals {
  labels = {
    app         = "postgresql"
    component   = "database"
    environment = var.environment
  }

  # PgPool service name for connection routing
  pgpool_host = "postgresql-postgresql-ha-pgpool.${var.namespace}.svc.cluster.local"
  pgpool_port = "5432"
}

# PostgreSQL-HA using Bitnami chart
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql-ha"
  version    = "16.3.2"
  namespace  = var.namespace

  values = [
    yamlencode({
      # Global settings
      global = {
        postgresql = {
          username       = "langflow"
          password       = random_password.postgres_password.result
          database       = "langflow"
          repmgrUsername = "repmgr"
          repmgrPassword = random_password.repmgr_password.result
        }
      }

      # PostgreSQL configuration
      postgresql = {
        # Explicit image tag required by Terraform Helm provider
        image = {
          registry   = "docker.io"
          repository = "bitnami/postgresql-repmgr"
          tag        = "17.2.0"
        }

        replicaCount = var.postgres_replicas

        # Persistence configuration
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }

        # Resource allocation
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

        # Enable health probes for better reliability
        startupProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 10
          successThreshold    = 1
        }

        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 6
          successThreshold    = 1
        }

        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 5
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 6
          successThreshold    = 1
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
          max_wal_size = 1GB
          min_wal_size = 80MB
        EOF

        # Replication settings
        repmgrConfiguration = <<-EOF
          event_notification_command='/opt/bitnami/scripts/postgresql-repmgr/entrypoint.sh'
          ssh_options='-o "StrictHostKeyChecking no" -v'
          use_replication_slots=yes
          reconnect_attempts=3
          reconnect_interval=5
          log_level=INFO
          log_facility=STDERR
          log_status_interval=300
        EOF
      }

      # PgPool Configuration - Load Balancer and Connection Pooler
      pgpool = {
        # Explicit image tag required by Terraform Helm provider
        image = {
          registry   = "docker.io"
          repository = "bitnami/pgpool"
          tag        = "4.6.1"
        }

        replicaCount = var.postgres_replicas >= 3 ? 2 : 1

        # Resource allocation for PgPool
        resources = {
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }

        # PgPool health probes
        startupProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 10
          successThreshold    = 1
        }

        livenessProbe = {
          enabled             = true
          initialDelaySeconds = 30
          periodSeconds       = 10
          timeoutSeconds      = 5
          failureThreshold    = 6
          successThreshold    = 1
        }

        readinessProbe = {
          enabled             = true
          initialDelaySeconds = 5
          periodSeconds       = 5
          timeoutSeconds      = 5
          failureThreshold    = 5
          successThreshold    = 1
        }

        # PgPool configuration
        adminUsername = "admin"
        adminPassword = random_password.pgpool_admin_password.result

        # Load balancing and connection pooling settings
        configuration = <<-EOF
          num_init_children = 32
          max_pool = 4
          child_life_time = 300
          child_max_connections = 0
          connection_life_time = 0
          client_idle_limit = 0
          connection_cache = on
          load_balance_mode = on
          statement_level_load_balance = off
          sr_check_period = 10
          health_check_period = 10
          health_check_timeout = 20
          health_check_user = 'langflow'
          health_check_max_retries = 3
          failover_on_backend_error = off
          log_per_node_statement = off
        EOF
      }

      # Witness node for quorum (only if replicas >= 3)
      witness = {
        enabled = var.postgres_replicas >= 3 ? true : false
      }

      # Disable volume permissions to avoid compatibility issues
      volumePermissions = {
        enabled = false
      }

      # Metrics disabled for now (can be enabled later)
      metrics = {
        enabled = false
      }

      commonLabels = local.labels
    })
  ]

  timeout = 900
}

# Generate password for PostgreSQL
resource "random_password" "postgres_password" {
  length  = 32
  special = true
}

# Generate password for repmgr (replication manager)
resource "random_password" "repmgr_password" {
  length  = 32
  special = true
}

# Generate password for PgPool admin
resource "random_password" "pgpool_admin_password" {
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
  # Service name for PostgreSQL - Use PgPool for load balancing
  # Applications should connect through PgPool, not directly to PostgreSQL nodes
  db_host = local.pgpool_host
  db_port = local.pgpool_port

  # Connection string uses PgPool for automatic load balancing and failover
  connection_string = "postgresql://langflow:${urlencode(random_password.postgres_password.result)}@${local.db_host}:${local.db_port}/langflow"
}

# Network Policy for PostgreSQL
# Restricts access to only Langflow IDE and Runtime workers
resource "kubernetes_network_policy" "postgresql" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "postgresql-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "postgresql"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO PostgreSQL
    ingress {
      # Allow from Langflow IDE
      from {
        pod_selector {
          match_labels = {
            app = "langflow-ide"
          }
        }
      }

      # Allow from Langflow Runtime workers
      from {
        pod_selector {
          match_labels = {
            app = "langflow-runtime"
          }
        }
      }

      # Allow internal PostgreSQL cluster communication (replication)
      from {
        pod_selector {
          match_labels = {
            app = "postgresql"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }

      ports {
        protocol = "TCP"
        port     = "5433" # Repmgr port
      }
    }

    # Egress rules - where PostgreSQL can connect TO
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
      # Allow internal PostgreSQL cluster communication
      to {
        pod_selector {
          match_labels = {
            app = "postgresql"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }

      ports {
        protocol = "TCP"
        port     = "5433" # Repmgr port
      }
    }

    egress {
      # Allow external connections (for initial setup and replication)
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }
  }
}

# Network Policy for PgPool
# Restricts access to PgPool load balancer
resource "kubernetes_network_policy" "pgpool" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "pgpool-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "postgresql-ha"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO PgPool
    ingress {
      # Allow from Langflow IDE
      from {
        pod_selector {
          match_labels = {
            app = "langflow-ide"
          }
        }
      }

      # Allow from Langflow Runtime workers
      from {
        pod_selector {
          match_labels = {
            app = "langflow-runtime"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }

    # Egress rules - where PgPool can connect TO
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
      # Allow connections to PostgreSQL backends
      to {
        pod_selector {
          match_labels = {
            app = "postgresql"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }
  }
}
