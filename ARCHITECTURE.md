# Langflow Infrastructure Architecture

## Overview

This document describes the architecture of the Langflow Kubernetes infrastructure with KEDA autoscaling.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet / Users                                │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Ingress Layer (TLS)                                  │
│  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐ │
│  │ Nginx Ingress        │  │  cert-manager        │  │  Let's Encrypt   │ │
│  │ - Load Balancing     │  │  - TLS Automation    │  │  - Certificates  │ │
│  │ - Rate Limiting      │  │  - Certificate Mgmt  │  │                  │ │
│  └──────────────────────┘  └──────────────────────┘  └──────────────────┘ │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
                ┌──────────────┼──────────────┐
                ▼              ▼              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Application Layer                                    │
│                                                                              │
│  ┌────────────────────────────────┐    ┌────────────────────────────────┐  │
│  │  Langflow IDE (Deployment)     │    │  Langflow Runtime (StatefulSet)│  │
│  │  ┌──────┐  ┌──────┐  ┌──────┐ │    │  ┌──────┐  ┌──────┐  ┌──────┐ │  │
│  │  │ IDE  │  │ IDE  │  │ IDE  │ │    │  │Worker│  │Worker│  │Worker│ │  │
│  │  │  1   │  │  2   │  │  3   │ │    │  │  0   │  │  1   │  │  2   │ │  │
│  │  └──────┘  └──────┘  └──────┘ │    │  └──────┘  └──────┘  └──────┘ │  │
│  │  - Flow Editing UI             │    │  - Flow Execution              │  │
│  │  - Session Affinity            │    │  - Task Processing             │  │
│  │  - HPA Scaling (2-6)           │    │  - Persistent Storage          │  │
│  └────────────────────────────────┘    └────────────────────────────────┘  │
│                  │                                    │                      │
│                  │                                    │                      │
└──────────────────┼────────────────────────────────────┼──────────────────────┘
                   │                                    │
                   ▼                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Data Layer                                           │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐   │
│  │  PostgreSQL HA     │  │  Message Broker    │  │  Vector Database   │   │
│  │  ┌──────┐          │  │  ┌──────┐          │  │  ┌──────┐          │   │
│  │  │ PG-0 │◄────────┐│  │  │ RMQ-0│◄────────┐│  │  │Qdrant│          │   │
│  │  └──────┘         ││  │  └──────┘         ││  │  │  0   │          │   │
│  │  ┌──────┐         ││  │  ┌──────┐         ││  │  └──────┘          │   │
│  │  │ PG-1 │◄────────┤│  │  │ RMQ-1│◄────────┤│  │  ┌──────┐          │   │
│  │  └──────┘         ││  │  └──────┘         ││  │  │Qdrant│          │   │
│  │  ┌──────┐         ││  │  ┌──────┐         ││  │  │  1   │          │   │
│  │  │ PG-2 │◄────────┘│  │  │ RMQ-2│◄────────┘│  │  └──────┘          │   │
│  │  └──────┘          │  │  └──────┘          │  │                     │   │
│  │  ┌──────────────┐  │  │  - Queue Management│  │  - Embeddings       │   │
│  │  │   PgPool     │  │  │  - Task Distribution│  │  - Vector Search   │   │
│  │  │Load Balancer │  │  │  - Persistence     │  │  - Clustering       │   │
│  │  └──────────────┘  │  │                    │  │                     │   │
│  │  - Replication     │  │  OR                │  │  OR                 │   │
│  │  - Auto Failover   │  │  ┌──────────────┐ │  │  ┌──────────────┐  │   │
│  │  - Connection Pool │  │  │ Redis Sentinel│ │  │  │   Weaviate   │  │   │
│  └────────────────────┘  │  │ - Master/Slave│ │  │  │   Milvus     │  │   │
│                          │  │ - Auto Failover│ │  │                  │  │   │
│                          │  └──────────────────┘  └────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Autoscaling Layer (KEDA)                                │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────┐        │
│  │  KEDA Operator                                                  │        │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │        │
│  │  │Queue Scaler  │  │  CPU Scaler  │  │Memory Scaler │         │        │
│  │  │ Monitor queue│  │  Monitor CPU │  │Monitor Memory│         │        │
│  │  │ length       │  │  utilization │  │ utilization  │         │        │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘         │        │
│  │         │                 │                  │                 │        │
│  │         └─────────────────┴──────────────────┘                 │        │
│  │                           │                                    │        │
│  │                           ▼                                    │        │
│  │              ┌────────────────────────┐                        │        │
│  │              │ Scale Runtime Workers  │                        │        │
│  │              │  Min: 2, Max: 10       │                        │        │
│  │              └────────────────────────┘                        │        │
│  └────────────────────────────────────────────────────────────────┘        │
│                                                                              │
│  Scaling Triggers:                                                          │
│  - Queue Length > 5 messages/worker → Scale Up                             │
│  - CPU > 70% → Scale Up                                                     │
│  - Memory > 80% → Scale Up                                                  │
│  - Queue empty + CPU < 30% for 5min → Scale Down                           │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                      Observability Layer                                     │
│                                                                              │
│  ┌────────────────────┐  ┌────────────────────┐  ┌────────────────────┐   │
│  │   Prometheus       │  │      Grafana       │  │       Loki         │   │
│  │   - Metrics        │  │   - Dashboards     │  │   - Logs           │   │
│  │   - Alerts         │  │   - Visualization  │  │   - Aggregation    │   │
│  │   - Time Series    │  │   - Analytics      │  │   - Search         │   │
│  └────────────────────┘  └────────────────────┘  └────────────────────┘   │
│            │                       │                       │                │
│            └───────────────────────┴───────────────────────┘                │
│                                    │                                        │
│                                    ▼                                        │
│                          ┌──────────────────┐                               │
│                          │  Alertmanager    │                               │
│                          │  - Notifications │                               │
│                          │  - Routing       │                               │
│                          └──────────────────┘                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Component Details

### 1. Ingress Layer

**Nginx Ingress Controller**
- Handles external traffic routing
- TLS termination
- Load balancing across pods
- Rate limiting and DDoS protection
- WebSocket support for IDE

**cert-manager**
- Automatic certificate provisioning
- Let's Encrypt integration
- Certificate renewal
- Multi-domain support

### 2. Application Layer

**Langflow IDE**
- Purpose: Flow design and editing
- Deployment: Kubernetes Deployment
- Replicas: 2-6 (HPA controlled)
- Features:
  - Web UI for visual flow editing
  - Session affinity for user experience
  - Read-only flow execution
  - Configuration management

**Langflow Runtime**
- Purpose: Flow execution workers
- Deployment: StatefulSet
- Replicas: 2-10 (KEDA controlled)
- Features:
  - Persistent worker identity
  - Task queue processing
  - Concurrent flow execution
  - Resource isolation
  - Graceful shutdown

### 3. Data Layer

**PostgreSQL HA**
- Configuration: 3-node cluster
- Replication: Streaming replication
- Load Balancer: PgPool
- Features:
  - Automatic failover (repmgr)
  - Connection pooling
  - Load distribution (read/write split)
  - Persistent storage

**Message Broker**

*Option A: RabbitMQ (Recommended)*
- Configuration: 3-node cluster
- Features:
  - Quorum queues for HA
  - Persistent messages
  - Mirrored queues
  - Management UI
  - KEDA integration

*Option B: Redis*
- Configuration: Sentinel with replication
- Features:
  - Master-slave replication
  - Automatic failover
  - Pub/Sub support
  - Simpler than RabbitMQ

**Vector Database**

*Option A: Qdrant (Default)*
- Configuration: 2-node cluster
- Features:
  - Native filtering
  - Efficient storage
  - REST + gRPC API

*Option B: Weaviate*
- Configuration: Clustered
- Features:
  - GraphQL API
  - Hybrid search
  - Module system

*Option C: Milvus*
- Configuration: Distributed
- Features:
  - High performance
  - Large-scale support
  - Multiple indexes

### 4. Autoscaling Layer (KEDA)

**KEDA Operator**
- Monitors multiple metrics
- Scales StatefulSet replicas
- Event-driven autoscaling

**Scaling Triggers**

1. **Queue Length** (Primary)
   - Metric: Messages in queue / Active workers
   - Threshold: 5 messages per worker
   - Action: Scale up immediately
   - Rationale: Prevent queue backlog

2. **CPU Utilization** (Secondary)
   - Metric: Average CPU across workers
   - Threshold: 70%
   - Action: Scale up gradually
   - Rationale: Resource optimization

3. **Memory Utilization** (Safety)
   - Metric: Average memory across workers
   - Threshold: 80%
   - Action: Scale up immediately
   - Rationale: Prevent OOM kills

**Scaling Behavior**

- **Scale Up**
  - Policy: Aggressive
  - Rate: 100% increase or +2 pods per 30s
  - Stabilization: None (immediate)

- **Scale Down**
  - Policy: Conservative
  - Rate: 50% decrease per 60s
  - Stabilization: 5 minutes
  - Rationale: Prevent thrashing

### 5. Observability Layer

**Prometheus**
- Metrics collection from all components
- Custom recording rules
- Alert evaluation
- 30-day retention

**Grafana**
- Pre-configured dashboards:
  - Langflow Overview
  - Kubernetes Cluster
  - PostgreSQL Metrics
  - RabbitMQ Status
  - KEDA Autoscaling
- Alert visualization
- Custom queries

**Loki + Promtail**
- Log aggregation
- Label-based indexing
- Grafana integration
- Long-term storage

**Alertmanager**
- Alert routing
- Notification channels:
  - Slack
  - Email
  - PagerDuty
  - Webhooks
- Alert grouping and deduplication

## Data Flow

### 1. Flow Editing (IDE)

```
User → Ingress → IDE Pod → PostgreSQL
                         → Vector DB (for testing)
```

### 2. Flow Execution (Runtime)

```
User/IDE → API → Message Broker → Runtime Worker → PostgreSQL
                                                  → Vector DB
                                                  → External APIs
         ↓
      Response
```

### 3. Autoscaling Decision

```
KEDA → Query Broker (queue length)
    → Query Metrics (CPU/Memory)
    → Calculate desired replicas
    → Update StatefulSet
    → Kubernetes schedules new pods
```

### 4. Observability Pipeline

```
Components → Prometheus (scrape metrics)
          → Loki (push logs)
          → Grafana (query & visualize)
          → Alertmanager (alert routing)
          → Notification channels
```

## High Availability Strategy

### Application HA
- Multiple replicas with anti-affinity
- PodDisruptionBudget (minimum 50%)
- Rolling updates with zero downtime
- Health checks (liveness + readiness)

### Database HA
- Streaming replication (async)
- Automatic failover (repmgr)
- PgPool for load balancing
- Persistent volumes

### Message Broker HA
- Cluster mode (3 nodes)
- Quorum queues
- Persistent storage
- Automatic partition healing

### Infrastructure HA
- Multi-zone node distribution
- Load balancer with health checks
- DNS failover
- Backup and restore procedures

## Security Architecture

### Network Security
- Network policies for pod isolation
- Ingress-only external access
- Service mesh (optional: Istio)
- TLS encryption everywhere

### Authentication & Authorization
- Kubernetes RBAC
- Service accounts with minimal permissions
- Secret management (Sealed Secrets optional)
- Pod security policies

### Data Security
- Encrypted persistent volumes
- TLS for all database connections
- Secret rotation policies
- Audit logging

## Scaling Limits

### Component Limits

| Component | Min | Default | Max | Constraint |
|-----------|-----|---------|-----|------------|
| IDE | 1 | 2 | 6 | CPU/Memory |
| Runtime Workers | 2 | 2 | 10 | Queue + Resources |
| PostgreSQL | 1 | 3 | 5 | Replication lag |
| RabbitMQ | 1 | 3 | 5 | Network partition |
| Vector DB | 1 | 2 | 5 | Storage |

### Resource Requirements (Per Environment)

**Development**
- Nodes: 3
- CPU: 12 cores total
- Memory: 24GB total
- Storage: 100GB total

**Production**
- Nodes: 6-10
- CPU: 48+ cores total
- Memory: 96GB+ total
- Storage: 500GB+ total

## Disaster Recovery

### Backup Strategy
- PostgreSQL: Daily pg_dump to object storage
- Configuration: Git repository
- Secrets: Encrypted backup
- RPO: 24 hours
- RTO: 2 hours

### Recovery Procedures
1. Provision new cluster
2. Restore from Terraform state
3. Restore database from backup
4. Restore secrets
5. Deploy application
6. Verify functionality

## Performance Characteristics

### Throughput
- IDE: 1000 concurrent users
- Runtime: 100 flows/second (scales linearly)
- API: 10,000 requests/second

### Latency
- IDE: < 100ms (p95)
- Runtime: < 1s (p95)
- Database: < 10ms (p95)

### Scalability
- Horizontal: Up to 10 runtime workers
- Vertical: Up to 8 CPU / 16GB per worker
- Database: Up to 10,000 connections (PgPool)

## Cost Optimization

### Development
- Single replicas
- Smaller instance types
- Spot instances for workers
- Reduced storage

### Production
- Right-sized replicas
- Reserved instances for core
- Spot for burst capacity
- Tiered storage

## Future Enhancements

1. **Multi-tenancy**
   - Namespace per tenant
   - Resource quotas
   - Network isolation

2. **Advanced Autoscaling**
   - Predictive scaling (ML-based)
   - Multi-dimensional scaling
   - Cost-aware scaling

3. **Enhanced Observability**
   - Distributed tracing (Jaeger)
   - APM integration
   - Custom business metrics

4. **Security Hardening**
   - Service mesh (Istio/Linkerd)
   - mTLS everywhere
   - OPA policy enforcement

5. **Multi-region**
   - Active-active deployment
   - Cross-region replication
   - Global load balancing
