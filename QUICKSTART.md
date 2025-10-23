# Quick Start Guide

This guide will help you deploy Langflow infrastructure quickly.

## Prerequisites Check

Before starting, verify you have the required tools:

```bash
# Check Terraform
terraform version  # Should be >= 1.5.0

# Check kubectl
kubectl version --client

# Check if you have a Kubernetes cluster
kubectl cluster-info
```

## Option 1: Use Existing Kubernetes Cluster

If you already have a Kubernetes cluster configured:

```bash
# Verify cluster access
kubectl get nodes

# Create terraform.tfvars
cp terraform.tfvars.example terraform.tfvars

# Edit configuration (minimal required)
vim terraform.tfvars
```

Minimal `terraform.tfvars` for existing cluster:

```hcl
# Leave empty to use default kubectl configuration
kubeconfig_path = ""
kube_context    = ""  # Or specify your context name

namespace    = "langflow"
environment  = "dev"

# Use simple configuration for testing
broker_type    = "redis"
vector_db_type = "qdrant"

# Minimal replicas for testing
postgres_replicas    = 1
redis_replicas       = 1
vector_db_replicas   = 1
ide_replicas         = 1
runtime_min_replicas = 1
runtime_max_replicas = 3

# Disable ingress for local testing
ingress_enabled = false

# Optional: Disable observability to save resources
enable_observability = false
```

Then deploy:

```bash
terraform init
terraform plan
terraform apply
```

## Option 2: Create Local Kubernetes Cluster (Minikube)

If you don't have a Kubernetes cluster, create one locally:

### Install Minikube

```bash
# Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# macOS
brew install minikube

# Verify installation
minikube version
```

### Start Minikube Cluster

```bash
# Start with sufficient resources
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --driver=docker

# Verify cluster is running
kubectl get nodes

# Enable metrics server (for HPA)
minikube addons enable metrics-server

# Enable storage
minikube addons enable default-storageclass
minikube addons enable storage-provisioner
```

### Deploy Langflow

```bash
cd langflow-infra

# Create minimal configuration
cat > terraform.tfvars <<EOF
# Minikube configuration
kubeconfig_path = ""
kube_context    = "minikube"

namespace    = "langflow"
environment  = "dev"

# Minimal setup for Minikube
langflow_version = "latest"

broker_type    = "redis"
vector_db_type = "qdrant"

# Single replicas for local testing
postgres_replicas    = 1
redis_replicas       = 1
vector_db_replicas   = 1
ide_replicas         = 1
runtime_min_replicas = 1
runtime_max_replicas = 2

# Reduced storage for local
postgres_storage_size    = "5Gi"
vector_db_storage_size   = "5Gi"
prometheus_storage_size  = "5Gi"
loki_storage_size        = "5Gi"

# Storage class for Minikube
storage_class = "standard"

# Disable ingress (use port-forward instead)
ingress_enabled = false

# Disable observability to save resources (optional)
enable_observability = false

# Minimal resources
ide_resources = {
  requests = { cpu = "250m", memory = "512Mi" }
  limits   = { cpu = "1000m", memory = "2Gi" }
}

runtime_resources = {
  requests = { cpu = "500m", memory = "1Gi" }
  limits   = { cpu = "2000m", memory = "4Gi" }
}
EOF

# Initialize and deploy
terraform init
terraform plan
terraform apply -auto-approve
```

## Option 3: Create Local Kubernetes Cluster (Kind)

Alternative to Minikube using Kind:

### Install Kind

```bash
# Linux / macOS
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# Verify installation
kind version
```

### Create Kind Cluster

```bash
# Create cluster configuration
cat > kind-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
- role: worker
- role: worker
- role: worker
EOF

# Create cluster
kind create cluster --config kind-config.yaml --name langflow

# Verify
kubectl cluster-info --context kind-langflow
```

### Deploy Langflow

Use the same `terraform.tfvars` as Minikube option, but with:

```hcl
kube_context = "kind-langflow"
```

## Accessing Services After Deployment

### Without Ingress (Local Development)

```bash
# Access Langflow IDE
kubectl port-forward -n langflow svc/langflow-ide 7860:7860
# Open http://localhost:7860

# Access Langflow Runtime API
kubectl port-forward -n langflow svc/langflow-runtime-lb 8000:8000
# API available at http://localhost:8000

# Access Grafana (if enabled)
kubectl port-forward -n langflow svc/prometheus-grafana 3000:80
# Open http://localhost:3000
# Get password: make get-grafana-password
```

### Using Minikube Tunnel (with Ingress)

If you enabled ingress on Minikube:

```bash
# In a separate terminal, run:
minikube tunnel

# Update /etc/hosts to map domains
echo "127.0.0.1 langflow.local" | sudo tee -a /etc/hosts
echo "127.0.0.1 grafana.local" | sudo tee -a /etc/hosts

# Access services
# http://langflow.local
# http://grafana.local
```

## Useful Commands

```bash
# Check deployment status
kubectl get pods -n langflow
kubectl get svc -n langflow

# View logs
kubectl logs -n langflow -l app=langflow-ide
kubectl logs -n langflow -l app=langflow-runtime

# Check KEDA scaling
kubectl get scaledobject -n langflow
kubectl describe scaledobject -n langflow langflow-runtime-scaler

# Scale workers manually
kubectl scale statefulset -n langflow langflow-runtime --replicas=3

# Get all resources
kubectl get all -n langflow
```

## Troubleshooting

### Pods stuck in Pending

Check if storage is available:

```bash
kubectl get pv
kubectl get pvc -n langflow

# For Minikube, ensure storage addon is enabled
minikube addons enable storage-provisioner
```

### Insufficient resources

Reduce resource requirements in `terraform.tfvars`:

```hcl
ide_resources = {
  requests = { cpu = "100m", memory = "256Mi" }
  limits   = { cpu = "500m", memory = "1Gi" }
}

runtime_resources = {
  requests = { cpu = "250m", memory = "512Mi" }
  limits   = { cpu = "1000m", memory = "2Gi" }
}
```

### KEDA not working

Install metrics-server:

```bash
# Minikube
minikube addons enable metrics-server

# Kind
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Database connection issues

Check PostgreSQL logs:

```bash
kubectl logs -n langflow postgresql-0
kubectl exec -it -n langflow postgresql-0 -- psql -U langflow -c "SELECT 1"
```

## Clean Up

### Destroy Infrastructure

```bash
# Remove all Terraform resources
terraform destroy -auto-approve
```

### Delete Cluster

```bash
# Minikube
minikube delete

# Kind
kind delete cluster --name langflow
```

## Next Steps

1. Read [DEPLOYMENT.md](DEPLOYMENT.md) for production deployment
2. Review [ARCHITECTURE.md](ARCHITECTURE.md) to understand the system
3. Check [README.md](README.md) for complete documentation

## Minimal Production Configuration

For a production deployment with HA:

```hcl
environment = "prod"

# High availability
postgres_replicas    = 3
rabbitmq_replicas    = 3
vector_db_replicas   = 2
ide_replicas         = 2
runtime_min_replicas = 3
runtime_max_replicas = 10

# Enable full stack
ingress_enabled      = true
enable_observability = true

# Configure your domain
ide_ingress_host     = "langflow.yourdomain.com"
runtime_ingress_host = "api.langflow.yourdomain.com"
grafana_ingress_host = "grafana.yourdomain.com"
letsencrypt_email    = "admin@yourdomain.com"

# Use RabbitMQ for better reliability
broker_type = "rabbitmq"
```

## Support

- Issues: Report in GitHub issues
- Documentation: See README.md and DEPLOYMENT.md
- Logs: Use `kubectl logs` to debug issues
