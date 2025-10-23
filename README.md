# Langflow Infrastructure - Kubernetes Native with KEDA

Infrastructure as Code (IaC) for deploying Langflow on Kubernetes with high availability, autoscaling, and observability.

## Architecture Overview

This infrastructure implements **Option C** - Kubernetes native with KEDA for production-grade deployments:

### Components

1. **Langflow IDE** - Web UI for flow editing (read-only execution)
   - Deployed as Kubernetes Deployment
   - Multiple replicas with HPA
   - Session affinity for user experience

2. **Langflow Runtime** - Worker nodes for flow execution
   - Deployed as StatefulSet for persistent worker identity
   - KEDA autoscaling based on queue metrics
   - Scales from 2 to 10+ workers based on load

3. **Message Broker** - Task queue management
   - RabbitMQ (cluster mode with 3 replicas) OR
   - Redis (Sentinel mode with replication)

4. **PostgreSQL** - Primary database with HA
   - PostgreSQL-HA with PgPool for load balancing
   - 3 replicas with streaming replication
   - Automatic failover

5. **Vector Database** - Embeddings storage
   - Qdrant (default) OR
   - Weaviate OR
   - Milvus
   - All with HA configuration

6. **KEDA** - Event-driven autoscaling
   - Scales workers based on:
     - Queue length (RabbitMQ/Redis)
     - CPU utilization
     - Memory utilization

7. **Observability Stack**
   - Prometheus - Metrics collection
   - Grafana - Visualization dashboards
   - Loki - Log aggregation
   - Alertmanager - Alert routing

8. **Ingress & TLS**
   - Nginx Ingress Controller
   - cert-manager for automatic TLS certificates
   - Let's Encrypt integration

## Prerequisites

- Kubernetes cluster (1.25+)
- kubectl configured
- Terraform >= 1.5.0
- Helm >= 3.0

### Supported Kubernetes Platforms

- AWS EKS
- Google GKE
- Azure AKS
- On-premises Kubernetes
- Minikube/Kind (for testing)

## Quick Start

### 1. Clone and Configure

```bash
git clone <repository-url>
cd langflow-infra

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
vim terraform.tfvars
```

### 2. Configure Variables

Edit `terraform.tfvars` with your settings:

```hcl
# Kubernetes Configuration
kubeconfig_path = "~/.kube/config"
namespace       = "langflow"
environment     = "prod"

# Langflow
langflow_version = "1.0.0"

# Message Broker (choose one)
broker_type = "rabbitmq"  # or "redis"

# Vector Database (choose one)
vector_db_type = "qdrant"  # or "weaviate" or "milvus"

# Ingress Hosts
ide_ingress_host     = "langflow.yourdomain.com"
runtime_ingress_host = "api.langflow.yourdomain.com"
grafana_ingress_host = "grafana.langflow.yourdomain.com"

# Autoscaling
runtime_min_replicas = 2
runtime_max_replicas = 10
keda_queue_threshold = 5
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply configuration
terraform apply

# Get outputs
terraform output
```

### 4. Access Services

```bash
# Port-forward (if ingress not configured)
kubectl port-forward -n langflow svc/langflow-ide 7860:7860
kubectl port-forward -n langflow svc/langflow-runtime-lb 8000:8000

# Or access via ingress
echo "Langflow IDE: https://langflow.yourdomain.com"
echo "Langflow API: https://api.langflow.yourdomain.com"
```

## Configuration Options

### Message Broker

**RabbitMQ** (recommended for production)
- Better observability
- Native KEDA support
- Persistence and clustering

**Redis**
- Simpler setup
- Lower resource usage
- Good for development/staging

### Vector Database

**Qdrant** (default)
- Easy to deploy
- Good performance
- Native filtering

**Weaviate**
- GraphQL API
- Hybrid search
- Module system

**Milvus**
- High performance
- Distributed architecture
- Best for large-scale

### Resource Configuration

Adjust resources in `terraform.tfvars`:

```hcl
# IDE Resources
ide_resources = {
  requests = { cpu = "500m", memory = "1Gi" }
  limits   = { cpu = "2000m", memory = "4Gi" }
}

# Runtime Worker Resources
runtime_resources = {
  requests = { cpu = "1000m", memory = "2Gi" }
  limits   = { cpu = "4000m", memory = "8Gi" }
}
```

### Autoscaling Configuration

```hcl
# KEDA Thresholds
keda_queue_threshold  = 5   # Messages per worker
keda_cpu_threshold    = 70  # CPU percentage
keda_memory_threshold = 80  # Memory percentage

# Worker Scaling
runtime_min_replicas = 2
runtime_max_replicas = 10
```

## Observability

### Grafana Dashboards

Access Grafana at `https://grafana.yourdomain.com`

Default dashboards:
- Langflow Overview
- Kubernetes Cluster Monitoring
- PostgreSQL Metrics
- Message Broker Status
- KEDA Autoscaling Metrics

### Prometheus Queries

```promql
# Queue length
keda_scaler_metrics_value{scaledObject="langflow-runtime-scaler"}

# Worker CPU usage
rate(container_cpu_usage_seconds_total{pod=~"langflow-runtime-.*"}[5m])

# Worker memory usage
container_memory_usage_bytes{pod=~"langflow-runtime-.*"}

# Request rate
rate(http_requests_total{service="langflow-runtime"}[5m])
```

### Alerts

Pre-configured alerts:
- High memory/CPU usage on workers
- Queue backlog exceeding threshold
- Database connection issues
- Pod restart loops

## High Availability

### Database HA

PostgreSQL with:
- 3 replicas with streaming replication
- PgPool for connection pooling and load balancing
- Automatic failover with repmgr
- Persistent volumes

### Message Broker HA

RabbitMQ:
- 3-node cluster
- Quorum queues
- Persistent storage
- Automatic cluster recovery

Redis:
- Master-replica with Sentinel
- Automatic failover
- Persistent AOF

### Application HA

- Multiple IDE replicas with session affinity
- StatefulSet for runtime workers
- PodDisruptionBudget (minimum 50% available)
- Anti-affinity rules to spread pods across nodes

## Scaling Strategy

### Horizontal Pod Autoscaling (HPA)

IDE scales based on:
- CPU utilization (70%)
- Memory utilization (80%)

### KEDA Autoscaling

Runtime workers scale based on:
1. **Queue length** - Primary metric
   - Scales up when queue > threshold
   - Scales down when queue empty
2. **CPU utilization** - Secondary metric
3. **Memory utilization** - Safety metric

### Scale Behavior

```yaml
Scale Up:
  - 100% increase every 30s (aggressive)
  - OR add 2 pods every 30s
  - No stabilization window

Scale Down:
  - 50% decrease every 60s (conservative)
  - 5-minute stabilization window
  - Prevents flapping
```

## Backup & Recovery

### Database Backups

Automated backups (optional):

```hcl
# Enable in modules/database/main.tf
backup = {
  enabled = true
  cronjob = {
    schedule = "0 2 * * *"  # Daily at 2 AM
  }
}
```

Manual backup:

```bash
kubectl exec -n langflow postgresql-0 -- pg_dump -U langflow langflow > backup.sql
```

### Restore

```bash
kubectl exec -i -n langflow postgresql-0 -- psql -U langflow langflow < backup.sql
```

## Security

### Network Policies

Apply network policies to restrict traffic:

```bash
kubectl apply -f examples/network-policies.yaml
```

### Secrets Management

Credentials are generated automatically and stored as Kubernetes secrets:
- PostgreSQL password
- RabbitMQ credentials
- Grafana admin password

Retrieve secrets:

```bash
# PostgreSQL password
kubectl get secret -n langflow postgresql-credentials -o jsonpath='{.data.password}' | base64 -d

# Grafana password
kubectl get secret -n langflow grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d
```

### TLS Configuration

Enable TLS with cert-manager:

```hcl
tls_enabled          = true
cert_manager_enabled = true
letsencrypt_email    = "admin@yourdomain.com"
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n langflow
kubectl describe pod -n langflow <pod-name>
kubectl logs -n langflow <pod-name>
```

### Check KEDA Scaling

```bash
kubectl get scaledobject -n langflow
kubectl describe scaledobject -n langflow langflow-runtime-scaler
```

### Check Database Connection

```bash
kubectl exec -it -n langflow postgresql-0 -- psql -U langflow -d langflow -c "SELECT version();"
```

### Check Message Broker

RabbitMQ:
```bash
kubectl exec -n langflow rabbitmq-0 -- rabbitmqctl cluster_status
kubectl exec -n langflow rabbitmq-0 -- rabbitmqctl list_queues
```

Redis:
```bash
kubectl exec -n langflow redis-master-0 -- redis-cli info replication
```

### Common Issues

**Workers not scaling:**
- Check KEDA operator logs: `kubectl logs -n keda-system -l app=keda-operator`
- Verify ScaledObject: `kubectl get scaledobject -n langflow -o yaml`

**Database connection errors:**
- Check PostgreSQL logs: `kubectl logs -n langflow postgresql-0`
- Verify service: `kubectl get svc -n langflow postgresql-pgpool`

**Ingress not working:**
- Check ingress controller: `kubectl get pods -n ingress-nginx`
- Verify ingress: `kubectl describe ingress -n langflow`

## Cost Optimization

### Development Environment

```hcl
environment = "dev"

# Reduce replicas
postgres_replicas    = 1
rabbitmq_replicas    = 1
vector_db_replicas   = 1
ide_replicas         = 1
runtime_min_replicas = 1
runtime_max_replicas = 3

# Disable observability
enable_observability = false
```

### Production Environment

```hcl
environment = "prod"

# HA configuration
postgres_replicas    = 3
rabbitmq_replicas    = 3
vector_db_replicas   = 2
ide_replicas         = 2
runtime_min_replicas = 2
runtime_max_replicas = 10

# Full observability
enable_observability = true
```

## Maintenance

### Update Langflow Version

```hcl
langflow_version = "1.1.0"
```

```bash
terraform apply
```

### Scale Workers Manually

```bash
kubectl scale statefulset -n langflow langflow-runtime --replicas=5
```

### Update Configuration

```bash
# Edit ConfigMap
kubectl edit configmap -n langflow langflow-ide-config

# Restart pods to apply changes
kubectl rollout restart deployment -n langflow langflow-ide
kubectl rollout restart statefulset -n langflow langflow-runtime
```

## Module Structure

```
langflow-infra/
├── main.tf                    # Root module
├── variables.tf               # Input variables
├── outputs.tf                 # Output values
├── terraform.tfvars.example   # Example configuration
├── modules/
│   ├── message-broker/        # RabbitMQ/Redis
│   ├── database/              # PostgreSQL HA
│   ├── vector-db/             # Qdrant/Weaviate/Milvus
│   ├── langflow-ide/          # IDE deployment
│   ├── langflow-runtime/      # Runtime workers
│   ├── keda/                  # KEDA autoscaling
│   ├── observability/         # Prometheus/Grafana/Loki
│   └── ingress/               # Nginx Ingress + cert-manager
└── README.md                  # This file
```

## Contributing

Contributions are welcome! Please submit issues and pull requests.

## License

MIT License

## Support

For issues and questions:
- GitHub Issues: <repository-url>/issues
- Langflow Documentation: https://docs.langflow.org
- KEDA Documentation: https://keda.sh

## Acknowledgments

- [Langflow](https://github.com/logspace-ai/langflow)
- [KEDA](https://keda.sh)
- [Bitnami Helm Charts](https://github.com/bitnami/charts)
- [Prometheus Operator](https://github.com/prometheus-operator/kube-prometheus)
