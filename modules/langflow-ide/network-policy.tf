# Network Policy for Langflow IDE
# Restricts access and egress for the IDE frontend

resource "kubernetes_network_policy" "langflow_ide" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "langflow-ide-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "langflow-ide"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO Langflow IDE
    ingress {
      # Allow from Ingress controller (if enabled)
      from {
        namespace_selector {
          match_labels = {
            name = "ingress-nginx"
          }
        }
      }

      # Allow from anywhere in the namespace (for port-forward access)
      from {
        namespace_selector {
          match_labels = {
            name = var.namespace
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "7860" # Langflow IDE port
      }
    }

    # Egress rules - where Langflow IDE can connect TO
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
      # Allow external HTTPS connections (for AI model APIs, package downloads, etc.)
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
  }
}
