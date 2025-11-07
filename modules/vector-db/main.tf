# Vector Database Module - Qdrant, Weaviate, or Milvus

locals {
  labels = {
    app         = var.vector_db
    component   = "vector-database"
    environment = var.environment
  }
}

# Qdrant Deployment
resource "helm_release" "qdrant" {
  count = var.vector_db == "qdrant" ? 1 : 0

  name       = "qdrant"
  repository = "https://qdrant.github.io/qdrant-helm"
  chart      = "qdrant"
  version    = "~> 0.7"
  namespace  = var.namespace

  values = [
    yamlencode({
      replicaCount = var.replicas

      image = {
        tag = "v1.7.4"
      }

      persistence = {
        enabled      = true
        storageClass = var.storage_class
        size         = var.storage_size
      }

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

      config = {
        cluster = {
          enabled = true
        }
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = false
        }
      }

      podLabels = local.labels
    })
  ]

  timeout = 600
}

# Weaviate Deployment
resource "helm_release" "weaviate" {
  count = var.vector_db == "weaviate" ? 1 : 0

  name       = "weaviate"
  repository = "https://weaviate.github.io/weaviate-helm"
  chart      = "weaviate"
  version    = "~> 17.0"
  namespace  = var.namespace

  values = [
    yamlencode({
      replicas = var.replicas

      storage = {
        size         = var.storage_size
        storageClass = var.storage_class
      }

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

      modules = {
        "text2vec-transformers" = {
          enabled = true
        }
        "text2vec-openai" = {
          enabled = true
        }
        "generative-openai" = {
          enabled = true
        }
      }

      env = {
        CLUSTER_HOSTNAME = "weaviate-headless"
      }

      monitoring = {
        enabled = true
      }

      labels = local.labels
    })
  ]

  timeout = 600
}

# Milvus Deployment
resource "helm_release" "milvus" {
  count = var.vector_db == "milvus" ? 1 : 0

  name       = "milvus"
  repository = "https://zilliztech.github.io/milvus-helm"
  chart      = "milvus"
  version    = "~> 4.1"
  namespace  = var.namespace

  values = [
    yamlencode({
      cluster = {
        enabled = true
      }

      pulsar = {
        enabled = false # Use external message broker
      }

      kafka = {
        enabled = false # Use external message broker
      }

      etcd = {
        replicaCount = 3
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = "10Gi"
        }
      }

      minio = {
        mode     = "distributed"
        replicas = 4
        persistence = {
          enabled      = true
          storageClass = var.storage_class
          size         = var.storage_size
        }
      }

      queryNode = {
        replicas = var.replicas
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
      }

      dataNode = {
        replicas = var.replicas
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
      }

      indexNode = {
        replicas = var.replicas
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
      }

      metrics = {
        enabled = true
        serviceMonitor = {
          enabled = true
        }
      }

      labels = local.labels
    })
  ]

  timeout = 900
}

# ConfigMap for vector DB connection details
resource "kubernetes_config_map" "vector_db_config" {
  metadata {
    name      = "${var.vector_db}-config"
    namespace = var.namespace
    labels    = local.labels
  }

  data = {
    vector_db = var.vector_db
    host      = local.host
    port      = local.port
    url       = local.connection_string
  }
}

locals {
  host = var.vector_db == "qdrant" ? "qdrant.${var.namespace}.svc.cluster.local" : var.vector_db == "weaviate" ? "weaviate.${var.namespace}.svc.cluster.local" : "milvus.${var.namespace}.svc.cluster.local"

  port = var.vector_db == "qdrant" ? "6333" : var.vector_db == "weaviate" ? "8080" : "19530"

  connection_string = var.vector_db == "qdrant" ? "http://${local.host}:${local.port}" : var.vector_db == "weaviate" ? "http://${local.host}:${local.port}" : "${local.host}:${local.port}"
}

# Network Policy for Qdrant
# Restricts access to only Langflow Runtime workers
resource "kubernetes_network_policy" "qdrant" {
  count = var.enable_network_policy && var.vector_db == "qdrant" ? 1 : 0

  metadata {
    name      = "qdrant-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "qdrant"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO Qdrant
    ingress {
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
        port     = "6333" # HTTP API
      }

      ports {
        protocol = "TCP"
        port     = "6334" # gRPC API
      }
    }

    # Egress rules - where Qdrant can connect TO
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
      # Allow external connections if needed
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }
  }
}

# Network Policy for Weaviate
# Restricts access to only Langflow Runtime workers
resource "kubernetes_network_policy" "weaviate" {
  count = var.enable_network_policy && var.vector_db == "weaviate" ? 1 : 0

  metadata {
    name      = "weaviate-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "weaviate"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO Weaviate
    ingress {
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
        port     = "8080" # HTTP API
      }
    }

    # Egress rules - where Weaviate can connect TO
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
      # Allow external connections (for ML models, etc.)
      to {
        ip_block {
          cidr = "0.0.0.0/0"
        }
      }
    }
  }
}

# Network Policy for Milvus
# Restricts access to only Langflow Runtime workers
resource "kubernetes_network_policy" "milvus" {
  count = var.enable_network_policy && var.vector_db == "milvus" ? 1 : 0

  metadata {
    name      = "milvus-network-policy"
    namespace = var.namespace
    labels    = local.labels
  }

  spec {
    pod_selector {
      match_labels = {
        app = "milvus"
      }
    }

    policy_types = ["Ingress", "Egress"]

    # Ingress rules - who can connect TO Milvus
    ingress {
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
        port     = "19530" # gRPC API
      }

      ports {
        protocol = "TCP"
        port     = "9091" # Metrics
      }
    }

    # Egress rules - where Milvus can connect TO
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
      # Allow connections to etcd (Milvus dependency)
      to {
        pod_selector {
          match_labels = {
            app = "milvus-etcd"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "2379"
      }
    }

    egress {
      # Allow connections to MinIO (Milvus dependency)
      to {
        pod_selector {
          match_labels = {
            app = "milvus-minio"
          }
        }
      }

      ports {
        protocol = "TCP"
        port     = "9000"
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
