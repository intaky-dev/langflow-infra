#!/bin/bash
# Script para agregar todos los repositorios de Helm necesarios para langflow-infra
# Ejecutar en el servidor donde está corriendo k3s

set -e

echo "🔧 Agregando repositorios de Helm para langflow-infra..."
echo ""

# 1. Bitnami - PostgreSQL HA, RabbitMQ, Redis
echo "📦 Agregando repositorio Bitnami (PostgreSQL, RabbitMQ, Redis)..."
helm repo add bitnami https://charts.bitnami.com/bitnami

# 2. Ingress Nginx
echo "📦 Agregando repositorio Ingress Nginx..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# 3. Jetstack - cert-manager (TLS certificates)
echo "📦 Agregando repositorio Jetstack (cert-manager)..."
helm repo add jetstack https://charts.jetstack.io

# 4. Qdrant - Vector Database
echo "📦 Agregando repositorio Qdrant..."
helm repo add qdrant https://qdrant.github.io/qdrant-helm

# 5. Weaviate - Vector Database
echo "📦 Agregando repositorio Weaviate..."
helm repo add weaviate https://weaviate.github.io/weaviate-helm

# 6. Milvus - Vector Database
echo "📦 Agregando repositorio Milvus..."
helm repo add milvus https://zilliztech.github.io/milvus-helm

# 7. Prometheus Community - Monitoring
echo "📦 Agregando repositorio Prometheus Community..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# 8. Grafana - Loki, Promtail (Logging)
echo "📦 Agregando repositorio Grafana..."
helm repo add grafana https://grafana.github.io/helm-charts

# 9. KEDA - Kubernetes Event Driven Autoscaling
echo "📦 Agregando repositorio KEDA..."
helm repo add keda https://kedacore.github.io/charts

echo ""
echo "🔄 Actualizando repositorios..."
helm repo update

echo ""
echo "✅ Todos los repositorios agregados correctamente!"
echo ""
echo "📋 Lista de repositorios configurados:"
helm repo list

echo ""
echo "🎯 Ahora puedes ejecutar Terraform en langflow-infra:"
echo "   cd /home/intaky/Desktop/Dev/langflow-infra"
echo "   terraform init"
echo "   terraform plan"
