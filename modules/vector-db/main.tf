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
        enabled = false  # Use external message broker
      }

      kafka = {
        enabled = false  # Use external message broker
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
        mode = "distributed"
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
