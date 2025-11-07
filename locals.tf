# Local values for environment-specific configurations
# These are reference configurations that can be used in terraform.tfvars

locals {
  # Resource configurations by environment
  # Use these as reference when configuring your deployment

  # Development / Minikube configuration (minimal resources)
  dev_config = {
    ide_resources = {
      requests = {
        cpu    = "250m"
        memory = "512Mi"
      }
      limits = {
        cpu    = "1000m"
        memory = "2Gi"
      }
    }
    runtime_resources = {
      requests = {
        cpu    = "500m"
        memory = "1Gi"
      }
      limits = {
        cpu    = "2000m"
        memory = "4Gi"
      }
    }
    postgres_replicas      = 1
    redis_replicas         = 1
    vector_db_replicas     = 1
    ide_replicas           = 1
    runtime_min_replicas   = 1
    runtime_max_replicas   = 3
    postgres_storage_size  = "10Gi"
    redis_storage_size     = "5Gi"
    vector_db_storage_size = "10Gi"
  }

  # Staging configuration (moderate resources for testing)
  staging_config = {
    ide_resources = {
      requests = {
        cpu    = "500m"
        memory = "1Gi"
      }
      limits = {
        cpu    = "1500m"
        memory = "3Gi"
      }
    }
    runtime_resources = {
      requests = {
        cpu    = "1000m"
        memory = "2Gi"
      }
      limits = {
        cpu    = "3000m"
        memory = "6Gi"
      }
    }
    postgres_replicas      = 2
    redis_replicas         = 2
    vector_db_replicas     = 2
    ide_replicas           = 2
    runtime_min_replicas   = 2
    runtime_max_replicas   = 6
    postgres_storage_size  = "20Gi"
    redis_storage_size     = "10Gi"
    vector_db_storage_size = "20Gi"
  }

  # Production configuration (full HA and resources)
  prod_config = {
    ide_resources = {
      requests = {
        cpu    = "1000m"
        memory = "2Gi"
      }
      limits = {
        cpu    = "2000m"
        memory = "4Gi"
      }
    }
    runtime_resources = {
      requests = {
        cpu    = "2000m"
        memory = "4Gi"
      }
      limits = {
        cpu    = "4000m"
        memory = "8Gi"
      }
    }
    postgres_replicas      = 3
    redis_replicas         = 3
    vector_db_replicas     = 3
    ide_replicas           = 3
    runtime_min_replicas   = 3
    runtime_max_replicas   = 10
    postgres_storage_size  = "50Gi"
    redis_storage_size     = "20Gi"
    vector_db_storage_size = "50Gi"
  }

  # Select configuration based on environment variable
  # This allows dynamic configuration selection
  selected_config = var.environment == "dev" ? local.dev_config : var.environment == "staging" ? local.staging_config : local.prod_config

  # Storage class detection
  # Tries to use cloud-provider specific storage classes, falls back to generic ones
  detected_storage_class = (
    # AWS
    var.storage_class != "" ? var.storage_class :
    # GCP
    var.environment == "prod" && var.cloud_provider == "gcp" ? "standard-rwo" :
    # Azure
    var.environment == "prod" && var.cloud_provider == "azure" ? "managed-premium" :
    # AWS
    var.environment == "prod" && var.cloud_provider == "aws" ? "gp3" :
    # Default fallback
    "standard"
  )
}
