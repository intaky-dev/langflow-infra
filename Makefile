.PHONY: help init plan apply destroy validate fmt clean status

NAMESPACE ?= langflow

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init

validate: ## Validate Terraform configuration
	terraform validate
	terraform fmt -check

fmt: ## Format Terraform files
	terraform fmt -recursive

plan: ## Show Terraform execution plan
	terraform plan

apply: ## Apply Terraform configuration
	terraform apply

destroy: ## Destroy all resources
	terraform destroy

clean: ## Clean Terraform files
	rm -rf .terraform/
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*

# Kubernetes helpers
status: ## Show deployment status
	@echo "=== Pods ==="
	kubectl get pods -n $(NAMESPACE)
	@echo "\n=== Services ==="
	kubectl get svc -n $(NAMESPACE)
	@echo "\n=== Ingress ==="
	kubectl get ingress -n $(NAMESPACE)
	@echo "\n=== KEDA ScaledObjects ==="
	kubectl get scaledobject -n $(NAMESPACE)

logs-ide: ## Show Langflow IDE logs
	kubectl logs -n $(NAMESPACE) -l app=langflow-ide --tail=100 -f

logs-runtime: ## Show Langflow Runtime logs
	kubectl logs -n $(NAMESPACE) -l app=langflow-runtime --tail=100 -f

logs-keda: ## Show KEDA operator logs
	kubectl logs -n keda-system -l app=keda-operator --tail=100 -f

port-forward-ide: ## Port-forward Langflow IDE
	kubectl port-forward -n $(NAMESPACE) svc/langflow-ide 7860:7860

port-forward-runtime: ## Port-forward Langflow Runtime
	kubectl port-forward -n $(NAMESPACE) svc/langflow-runtime-lb 8000:8000

port-forward-grafana: ## Port-forward Grafana
	kubectl port-forward -n $(NAMESPACE) svc/prometheus-grafana 3000:80

port-forward-prometheus: ## Port-forward Prometheus
	kubectl port-forward -n $(NAMESPACE) svc/prometheus-kube-prometheus-prometheus 9090:9090

get-grafana-password: ## Get Grafana admin password
	@kubectl get secret -n $(NAMESPACE) grafana-credentials -o jsonpath='{.data.admin-password}' | base64 -d && echo

get-postgres-password: ## Get PostgreSQL password
	@kubectl get secret -n $(NAMESPACE) postgresql-credentials -o jsonpath='{.data.password}' | base64 -d && echo

scale-runtime: ## Scale runtime workers (usage: make scale-runtime REPLICAS=5)
	kubectl scale statefulset -n $(NAMESPACE) langflow-runtime --replicas=$(REPLICAS)

restart-ide: ## Restart IDE pods
	kubectl rollout restart deployment -n $(NAMESPACE) langflow-ide

restart-runtime: ## Restart runtime workers
	kubectl rollout restart statefulset -n $(NAMESPACE) langflow-runtime

describe-scaler: ## Describe KEDA ScaledObject
	kubectl describe scaledobject -n $(NAMESPACE) langflow-runtime-scaler

test-connection: ## Test database connection
	kubectl exec -it -n $(NAMESPACE) postgresql-0 -- psql -U langflow -d langflow -c "SELECT version();"

backup-db: ## Backup PostgreSQL database
	@mkdir -p backups
	kubectl exec -n $(NAMESPACE) postgresql-0 -- pg_dump -U langflow langflow > backups/backup-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Backup saved to backups/"

restore-db: ## Restore PostgreSQL database (usage: make restore-db BACKUP=backups/backup.sql)
	kubectl exec -i -n $(NAMESPACE) postgresql-0 -- psql -U langflow langflow < $(BACKUP)
