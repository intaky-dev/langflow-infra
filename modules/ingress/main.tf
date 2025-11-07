# Ingress Module - Nginx Ingress Controller with TLS

locals {
  labels = {
    app         = "ingress"
    component   = "networking"
    environment = var.environment
  }
}

# Install Nginx Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "~> 4.9"
  namespace  = "ingress-nginx"

  create_namespace = true

  values = [
    yamlencode({
      controller = {
        replicaCount = 2

        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }

        autoscaling = {
          enabled                        = true
          minReplicas                    = 2
          maxReplicas                    = 10
          targetCPUUtilizationPercentage = 80
        }

        service = {
          type = "LoadBalancer"
          # Uncomment for cloud provider annotations
          # annotations = {
          #   "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
          # }
        }

        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = true
          }
        }

        # Security configurations
        config = {
          use-forwarded-headers      = "true"
          compute-full-forwarded-for = "true"
          use-proxy-protocol         = "false"
          enable-real-ip             = "true"
          proxy-body-size            = "100m"
          proxy-connect-timeout      = "60"
          proxy-send-timeout         = "60"
          proxy-read-timeout         = "60"
          ssl-protocols              = "TLSv1.2 TLSv1.3"
          ssl-ciphers                = "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384"
        }

        podLabels = local.labels
      }

      defaultBackend = {
        enabled = true
      }
    })
  ]

  timeout = 600
}

# Install cert-manager if enabled
resource "helm_release" "cert_manager" {
  count = var.cert_manager ? 1 : 0

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "~> 1.14"
  namespace  = "cert-manager"

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = "10m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      prometheus = {
        enabled = true
        servicemonitor = {
          enabled = true
        }
      }

      podLabels = local.labels
    })
  ]

  timeout = 600
}

# ClusterIssuer for Let's Encrypt (production)
resource "kubectl_manifest" "letsencrypt_prod" {
  count = var.cert_manager ? 1 : 0

  depends_on = [helm_release.cert_manager]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = "letsencrypt-prod"
      labels = local.labels
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = var.ingress_class
            }
          }
        }]
      }
    }
  })
}

# ClusterIssuer for Let's Encrypt (staging)
resource "kubectl_manifest" "letsencrypt_staging" {
  count = var.cert_manager ? 1 : 0

  depends_on = [helm_release.cert_manager]

  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name   = "letsencrypt-staging"
      labels = local.labels
    }
    spec = {
      acme = {
        server = "https://acme-staging-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-staging"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = var.ingress_class
            }
          }
        }]
      }
    }
  })
}

# Ingress for Langflow IDE
resource "kubernetes_ingress_v1" "langflow_ide" {
  count = var.ide_host != "" ? 1 : 0

  metadata {
    name      = "langflow-ide"
    namespace = var.namespace
    labels    = local.labels
    annotations = merge(
      {
        "nginx.ingress.kubernetes.io/proxy-body-size"     = "100m"
        "nginx.ingress.kubernetes.io/proxy-read-timeout"  = "3600"
        "nginx.ingress.kubernetes.io/proxy-send-timeout"  = "3600"
        "nginx.ingress.kubernetes.io/websocket-services"  = "langflow-ide"
        "nginx.ingress.kubernetes.io/affinity"            = "cookie"
        "nginx.ingress.kubernetes.io/session-cookie-name" = "langflow-ide"
      },
      var.tls_enabled && var.cert_manager ? {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      } : {}
    )
  }

  spec {
    ingress_class_name = var.ingress_class

    dynamic "tls" {
      for_each = var.tls_enabled ? [1] : []
      content {
        hosts       = [var.ide_host]
        secret_name = var.cert_manager ? "${var.ide_host}-tls" : var.tls_secret_name
      }
    }

    rule {
      host = var.ide_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "langflow-ide"
              port {
                number = 7860
              }
            }
          }
        }
      }
    }
  }
}

# Ingress for Langflow Runtime API
resource "kubernetes_ingress_v1" "langflow_runtime" {
  count = var.runtime_host != "" ? 1 : 0

  metadata {
    name      = "langflow-runtime"
    namespace = var.namespace
    labels    = local.labels
    annotations = merge(
      {
        "nginx.ingress.kubernetes.io/proxy-body-size"    = "50m"
        "nginx.ingress.kubernetes.io/proxy-read-timeout" = "300"
        "nginx.ingress.kubernetes.io/proxy-send-timeout" = "300"
        "nginx.ingress.kubernetes.io/rate-limit"         = "100"
      },
      var.tls_enabled && var.cert_manager ? {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      } : {}
    )
  }

  spec {
    ingress_class_name = var.ingress_class

    dynamic "tls" {
      for_each = var.tls_enabled ? [1] : []
      content {
        hosts       = [var.runtime_host]
        secret_name = var.cert_manager ? "${var.runtime_host}-tls" : var.tls_secret_name
      }
    }

    rule {
      host = var.runtime_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "langflow-runtime-lb"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }
}

# Ingress for Grafana
resource "kubernetes_ingress_v1" "grafana" {
  count = var.grafana_host != "" ? 1 : 0

  metadata {
    name      = "grafana"
    namespace = var.namespace
    labels    = local.labels
    annotations = merge(
      {
        "nginx.ingress.kubernetes.io/auth-type"   = "basic"
        "nginx.ingress.kubernetes.io/auth-secret" = "grafana-basic-auth"
        "nginx.ingress.kubernetes.io/auth-realm"  = "Authentication Required"
      },
      var.tls_enabled && var.cert_manager ? {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      } : {}
    )
  }

  spec {
    ingress_class_name = var.ingress_class

    dynamic "tls" {
      for_each = var.tls_enabled ? [1] : []
      content {
        hosts       = [var.grafana_host]
        secret_name = var.cert_manager ? "${var.grafana_host}-tls" : var.tls_secret_name
      }
    }

    rule {
      host = var.grafana_host

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "prometheus-grafana"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}
