# Deployment Guide

Comprehensive guide for deploying Langflow infrastructure to Kubernetes.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Deployment Checklist](#pre-deployment-checklist)
3. [Deployment Steps](#deployment-steps)
4. [Post-Deployment Verification](#post-deployment-verification)
5. [Environment-Specific Configurations](#environment-specific-configurations)
6. [Cloud Provider Specifics](#cloud-provider-specifics)

## Prerequisites

### Required Tools

```bash
# Terraform
terraform --version  # >= 1.5.0

# kubectl
kubectl version --client  # >= 1.25

# Helm
helm version  # >= 3.0

# Optional: Make
make --version
```

### Kubernetes Cluster Requirements

- Kubernetes version: 1.25+
- Minimum nodes: 3 (for HA)
- Minimum resources per node:
  - CPU: 4 cores
  - Memory: 8GB
  - Storage: 50GB

### Storage Classes

Ensure your cluster has a default storage class or configure one:

```bash
kubectl get storageclass
```

For cloud providers:
- AWS EKS: `gp3` or `gp2`
- GKE: `standard` or `premium-rwo`
- AKS: `managed-premium` or `managed`

## Pre-Deployment Checklist

- [ ] Kubernetes cluster is running and accessible
- [ ] kubectl is configured with correct context
- [ ] Sufficient cluster resources available
- [ ] Storage class is configured
- [ ] DNS records created (for ingress)
- [ ] TLS certificates prepared (if not using cert-manager)
- [ ] Configuration file prepared (`terraform.tfvars`)

## Deployment Steps

### 1. Clone Repository

```bash
git clone <repository-url>
cd langflow-infra
```

### 2. Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

Minimum required configuration:

```hcl
kubeconfig_path = "~/.kube/config"
namespace       = "langflow"
environment     = "prod"

# Ingress hosts (update with your domain)
ide_ingress_host     = "langflow.yourdomain.com"
runtime_ingress_host = "api.langflow.yourdomain.com"
grafana_ingress_host = "grafana.langflow.yourdomain.com"

# Broker and Vector DB
broker_type    = "rabbitmq"
vector_db_type = "qdrant"

# Storage (adjust for your cloud provider)
storage_class = "standard"
```

### 3. Initialize Terraform

```bash
terraform init
```

This will:
- Download required providers
- Initialize backend
- Prepare modules

### 4. Review Plan

```bash
terraform plan -out=tfplan
```

Review the plan carefully:
- Check resource counts
- Verify configurations
- Ensure no unexpected changes

### 5. Apply Configuration

```bash
terraform apply tfplan
```

Or with auto-approval (use with caution):

```bash
terraform apply -auto-approve
```

Deployment typically takes 15-30 minutes.

### 6. Save Outputs

```bash
terraform output > deployment-info.txt
```

## Post-Deployment Verification

### 1. Check Pod Status

```bash
kubectl get pods -n langflow
```

All pods should be in `Running` state.

### 2. Check Services

```bash
kubectl get svc -n langflow
```

Verify all services have ClusterIP assigned.

### 3. Check Ingress

```bash
kubectl get ingress -n langflow
```

Verify ingress resources have addresses assigned.

### 4. Check KEDA

```bash
kubectl get scaledobject -n langflow
kubectl describe scaledobject -n langflow langflow-runtime-scaler
```

### 5. Test Database Connection

```bash
kubectl exec -it -n langflow postgresql-0 -- psql -U langflow -d langflow -c "SELECT version();"
```

### 6. Test Message Broker

For RabbitMQ:
```bash
kubectl exec -n langflow rabbitmq-0 -- rabbitmqctl cluster_status
```

For Redis:
```bash
kubectl exec -n langflow redis-master-0 -- redis-cli ping
```

### 7. Access Langflow IDE

If using ingress:
```bash
curl -I https://langflow.yourdomain.com
```

Or port-forward:
```bash
kubectl port-forward -n langflow svc/langflow-ide 7860:7860
# Open http://localhost:7860
```

### 8. Access Grafana

Get admin password:
```bash
kubectl get secret -n langflow grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d
echo
```

Access Grafana:
```bash
kubectl port-forward -n langflow svc/prometheus-grafana 3000:80
# Open http://localhost:3000
# Login: admin / <password from above>
```

## Environment-Specific Configurations

### Development Environment

`terraform.tfvars`:
```hcl
environment = "dev"

# Minimal resources
postgres_replicas    = 1
rabbitmq_replicas    = 1
vector_db_replicas   = 1
ide_replicas         = 1
runtime_min_replicas = 1
runtime_max_replicas = 3

# Reduced storage
postgres_storage_size = "10Gi"
prometheus_storage_size = "10Gi"

# Disable TLS for local testing
tls_enabled = false
ingress_enabled = false

# Disable observability to save resources
enable_observability = false
```

### Staging Environment

`terraform.tfvars`:
```hcl
environment = "staging"

# Moderate HA
postgres_replicas    = 2
rabbitmq_replicas    = 2
vector_db_replicas   = 2
ide_replicas         = 2
runtime_min_replicas = 2
runtime_max_replicas = 5

# Standard storage
postgres_storage_size = "20Gi"
prometheus_storage_size = "30Gi"

# Enable TLS with staging certs
tls_enabled = true
cert_manager_enabled = true
letsencrypt_email = "admin@yourdomain.com"

# Full observability
enable_observability = true
```

### Production Environment

`terraform.tfvars`:
```hcl
environment = "prod"

# Full HA
postgres_replicas    = 3
rabbitmq_replicas    = 3
vector_db_replicas   = 2
ide_replicas         = 3
runtime_min_replicas = 3
runtime_max_replicas = 15

# Production storage
postgres_storage_size = "50Gi"
prometheus_storage_size = "100Gi"
loki_storage_size = "100Gi"

# Production resources
ide_resources = {
  requests = { cpu = "1000m", memory = "2Gi" }
  limits   = { cpu = "4000m", memory = "8Gi" }
}

runtime_resources = {
  requests = { cpu = "2000m", memory = "4Gi" }
  limits   = { cpu = "8000m", memory = "16Gi" }
}

# Production TLS
tls_enabled = true
cert_manager_enabled = true
letsencrypt_email = "admin@yourdomain.com"

# Full observability
enable_observability = true
prometheus_enabled = true
grafana_enabled = true
loki_enabled = true

# Aggressive autoscaling
keda_queue_threshold = 3
keda_cpu_threshold = 60
```

## Cloud Provider Specifics

### AWS EKS

```hcl
# Storage class
storage_class = "gp3"

# Ingress annotations
# Add to modules/ingress/main.tf
service.beta.kubernetes.io/aws-load-balancer-type = "nlb"
service.beta.kubernetes.io/aws-load-balancer-ssl-cert = "arn:aws:acm:..."
```

Create EKS cluster:
```bash
eksctl create cluster \
  --name langflow-cluster \
  --region us-east-1 \
  --nodes 3 \
  --nodes-min 3 \
  --nodes-max 10 \
  --node-type m5.xlarge \
  --with-oidc \
  --managed
```

### Google GKE

```hcl
# Storage class
storage_class = "premium-rwo"  # or "standard"
```

Create GKE cluster:
```bash
gcloud container clusters create langflow-cluster \
  --region us-central1 \
  --num-nodes 3 \
  --machine-type n1-standard-4 \
  --enable-autoscaling \
  --min-nodes 3 \
  --max-nodes 10 \
  --enable-autorepair \
  --enable-autoupgrade
```

### Azure AKS

```hcl
# Storage class
storage_class = "managed-premium"  # or "managed"
```

Create AKS cluster:
```bash
az aks create \
  --resource-group langflow-rg \
  --name langflow-cluster \
  --node-count 3 \
  --node-vm-size Standard_D4s_v3 \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10 \
  --enable-addons monitoring
```

## Troubleshooting Deployment

### Pods Stuck in Pending

Check events:
```bash
kubectl describe pod -n langflow <pod-name>
```

Common causes:
- Insufficient cluster resources
- PVC not binding (storage class issue)
- Node affinity/anti-affinity conflicts

### Helm Release Fails

Check Helm release status:
```bash
helm list -n langflow
helm status -n langflow <release-name>
```

Rollback if needed:
```bash
helm rollback -n langflow <release-name>
```

### Ingress Not Working

Check ingress controller:
```bash
kubectl get pods -n ingress-nginx
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

Verify DNS:
```bash
nslookup langflow.yourdomain.com
```

### cert-manager Issues

Check certificate status:
```bash
kubectl get certificate -n langflow
kubectl describe certificate -n langflow
```

Check cert-manager logs:
```bash
kubectl logs -n cert-manager -l app=cert-manager
```

## Updating Deployment

### Update Langflow Version

```hcl
langflow_version = "1.1.0"
```

```bash
terraform apply
```

### Update Configuration

```bash
vim terraform.tfvars
terraform plan
terraform apply
```

### Scale Resources

```bash
# Quick scale (manual)
kubectl scale deployment -n langflow langflow-ide --replicas=5

# Permanent (via Terraform)
vim terraform.tfvars  # Update ide_replicas
terraform apply
```

## Rolling Back

### Terraform State Rollback

```bash
# List state versions (if using remote backend)
terraform state list

# Restore from backup
cp terraform.tfstate.backup terraform.tfstate
```

### Kubernetes Rollback

```bash
# Rollback deployment
kubectl rollout undo deployment -n langflow langflow-ide

# Rollback to specific revision
kubectl rollout undo deployment -n langflow langflow-ide --to-revision=2
```

## Clean Up

### Destroy Everything

```bash
terraform destroy
```

### Delete Specific Resources

```bash
# Delete namespace (will delete all resources in namespace)
kubectl delete namespace langflow

# Keep namespace, delete specific resources
terraform destroy -target=module.langflow_runtime
```

## Next Steps

After successful deployment:

1. Configure DNS records
2. Set up monitoring alerts
3. Configure backup schedules
4. Set up CI/CD pipelines
5. Document runbooks
6. Train team on operations

## Support

For deployment issues:
- Check logs: `kubectl logs -n langflow <pod-name>`
- Check events: `kubectl get events -n langflow --sort-by='.lastTimestamp'`
- Review Terraform output: `terraform show`
