terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.25"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  # Uncomment for remote state
  # backend "s3" {
  #   bucket = "langflow-terraform-state"
  #   key    = "langflow-infra/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

# Provider configuration
provider "kubernetes" {
  config_path    = var.kubeconfig_path != "" ? pathexpand(var.kubeconfig_path) : null
  config_context = var.kube_context != "" ? var.kube_context : null
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path != "" ? pathexpand(var.kubeconfig_path) : null
    config_context = var.kube_context != "" ? var.kube_context : null
  }
}

provider "kubectl" {
  config_path    = var.kubeconfig_path != "" ? pathexpand(var.kubeconfig_path) : null
  config_context = var.kube_context != "" ? var.kube_context : null
}

# Create namespace
resource "kubernetes_namespace" "langflow" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = var.environment
      managed-by  = "terraform"
    }
  }
}

# Modules
module "message_broker" {
  source = "./modules/message-broker"

  namespace   = kubernetes_namespace.langflow.metadata[0].name
  environment = var.environment
  broker_type = var.broker_type # "rabbitmq" or "redis"

  # RabbitMQ specific
  rabbitmq_replicas     = var.rabbitmq_replicas
  rabbitmq_storage_size = var.rabbitmq_storage_size

  # Redis specific
  redis_replicas     = var.redis_replicas
  redis_storage_size = var.redis_storage_size
}

module "database" {
  source = "./modules/database"

  namespace         = kubernetes_namespace.langflow.metadata[0].name
  environment       = var.environment
  postgres_replicas = var.postgres_replicas
  storage_size      = var.postgres_storage_size
  storage_class     = var.storage_class
}

module "vector_db" {
  source = "./modules/vector-db"

  namespace     = kubernetes_namespace.langflow.metadata[0].name
  environment   = var.environment
  vector_db     = var.vector_db_type # "qdrant", "weaviate", or "milvus"
  replicas      = var.vector_db_replicas
  storage_size  = var.vector_db_storage_size
  storage_class = var.storage_class
}

module "langflow_ide" {
  source = "./modules/langflow-ide"

  namespace   = kubernetes_namespace.langflow.metadata[0].name
  environment = var.environment

  image_tag        = var.langflow_version
  replicas         = var.ide_replicas
  database_url     = module.database.connection_string
  ingress_enabled  = var.ingress_enabled
  ingress_host     = var.ide_ingress_host
  ingress_class    = var.ingress_class

  resources        = var.ide_resources
  enable_monitoring = false
}

module "langflow_runtime" {
  source = "./modules/langflow-runtime"

  namespace   = kubernetes_namespace.langflow.metadata[0].name
  environment = var.environment

  image_tag         = var.langflow_version
  min_replicas      = var.runtime_min_replicas
  max_replicas      = var.runtime_max_replicas
  database_url      = module.database.connection_string
  broker_url        = module.message_broker.connection_string
  vector_db_url     = module.vector_db.connection_string

  resources         = var.runtime_resources
  enable_monitoring = false
}

module "keda" {
  source = "./modules/keda"

  namespace   = kubernetes_namespace.langflow.metadata[0].name
  environment = var.environment

  broker_type           = var.broker_type
  broker_connection_url = module.message_broker.connection_string
  queue_name            = var.queue_name

  min_replicas = var.runtime_min_replicas
  max_replicas = var.runtime_max_replicas

  # Scaling thresholds
  queue_length_threshold = var.keda_queue_threshold
  cpu_threshold          = var.keda_cpu_threshold
  memory_threshold       = var.keda_memory_threshold

  target_deployment = module.langflow_runtime.deployment_name
  enable_monitoring = false
}

module "observability" {
  source = "./modules/observability"

  count = var.enable_observability ? 1 : 0

  namespace   = kubernetes_namespace.langflow.metadata[0].name
  environment = var.environment

  prometheus_enabled      = var.prometheus_enabled
  grafana_enabled         = var.grafana_enabled
  loki_enabled            = var.loki_enabled

  prometheus_storage_size = var.prometheus_storage_size
  loki_storage_size       = var.loki_storage_size
  storage_class           = var.storage_class
}

module "ingress" {
  source = "./modules/ingress"

  count = var.ingress_enabled ? 1 : 0

  namespace     = kubernetes_namespace.langflow.metadata[0].name
  environment   = var.environment
  ingress_class = var.ingress_class

  # TLS configuration
  tls_enabled       = var.tls_enabled
  cert_manager      = var.cert_manager_enabled
  tls_secret_name   = var.tls_secret_name
  letsencrypt_email = var.letsencrypt_email

  # Hosts
  ide_host     = var.ide_ingress_host
  runtime_host = var.runtime_ingress_host
  grafana_host = var.grafana_ingress_host
}
