# Network Policy for Langflow Runtime Workers
# Restricts access and egress for the runtime workers

resource "kubernetes_network_policy" "langflow_runtime" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "langflow-runtime-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "langflow-runtime"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO Langflow Runtime
    ingress {
      # Allow from Ingress controller (if API is exposed)
      from {
        namespace_selector {
          match_labels = {
            name = "ingress-nginx"
          }
        }
      }

      # Allow from Langflow IDE (for triggering flows)
      from {
        pod_selector {
          match_labels = {
            app = "langflow-ide"
          }
        }
      }

      # Allow from anywhere in the namespace (for internal communication)
      from {
        namespace_selector {
          match_labels = {
            name = var.namespace
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8000" # Langflow Runtime API port
      }
    }

    # Egress rules - where Langflow Runtime can connect TO
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
      # Allow connections to PostgreSQL (via PgPool)
      to {
        pod_selector {
          match_labels = {
            app = "postgresql-ha"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5432"
      }
    }

    egress {
      # Allow connections to PostgreSQL (direct, if not using PgPool)
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

    egress {
      # Allow connections to RabbitMQ
      to {
        pod_selector {
          match_labels = {
            app = "rabbitmq"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "5672"
      }
    }

    egress {
      # Allow connections to Redis
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
    }

    egress {
      # Allow connections to Qdrant
      to {
        pod_selector {
          match_labels = {
            app = "qdrant"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "6333"
      }

      ports {
        protocol = "TCP"
        port     = "6334"
      }
    }

    egress {
      # Allow connections to Weaviate
      to {
        pod_selector {
          match_labels = {
            app = "weaviate"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "8080"
      }
    }

    egress {
      # Allow connections to Milvus
      to {
        pod_selector {
          match_labels = {
            app = "milvus"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "19530"
      }
    }

    egress {
      # Allow external HTTPS connections (for AI model APIs, LLM providers, etc.)
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        protocol = "TCP"
        port     = "443"
      }
    }

    egress {
      # Allow external HTTP connections
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        protocol = "TCP"
        port     = "80"
      }
    }

    egress {
      # Allow custom ports for various AI/ML services
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        protocol = "TCP"
        port     = "8080"
      }
    }

    egress {
      # Allow gRPC connections (common for AI services)
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }

      ports {
        protocol = "TCP"
        port     = "50051"
      }
    }
  }
}
