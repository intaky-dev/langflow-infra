#!/bin/bash
# Script para gestionar Langflow en Minikube
# ==========================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

function print_header() {
    echo -e "${BLUE}===================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================${NC}"
}

function print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

function print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

function print_error() {
    echo -e "${RED}✗ $1${NC}"
}

function check_prerequisites() {
    print_header "Verificando prerequisitos"

    if ! command -v minikube &> /dev/null; then
        print_error "Minikube no está instalado"
        exit 1
    fi
    print_success "Minikube instalado"

    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl no está instalado"
        exit 1
    fi
    print_success "kubectl instalado"

    if ! command -v terraform &> /dev/null; then
        print_error "Terraform no está instalado"
        exit 1
    fi
    print_success "Terraform instalado"

    if ! minikube status &> /dev/null; then
        print_error "Minikube no está ejecutándose"
        print_warning "Ejecuta: minikube start --cpus=4 --memory=8192"
        exit 1
    fi
    print_success "Minikube ejecutándose"
}

function deploy() {
    print_header "Desplegando Langflow en Minikube"

    if [ ! -f "terraform.tfvars" ]; then
        print_error "No existe terraform.tfvars"
        print_warning "Crea el archivo de configuración primero"
        exit 1
    fi

    echo "Inicializando Terraform..."
    terraform init

    echo -e "\nGenerando plan..."
    terraform plan -out=tfplan

    echo -e "\n${YELLOW}¿Deseas aplicar este plan? (y/n)${NC}"
    read -r response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        echo "Aplicando configuración..."
        terraform apply tfplan
        print_success "Despliegue completado!"
        show_access_info
    else
        print_warning "Despliegue cancelado"
    fi
}

function destroy() {
    print_header "Eliminando Langflow de Minikube"

    echo -e "${RED}¿Estás seguro de eliminar toda la infraestructura? (y/n)${NC}"
    read -r response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        terraform destroy -auto-approve
        print_success "Infraestructura eliminada"
    else
        print_warning "Operación cancelada"
    fi
}

function status() {
    print_header "Estado del Cluster"

    echo -e "${BLUE}=== Minikube ===${NC}"
    minikube status

    echo -e "\n${BLUE}=== Namespaces ===${NC}"
    kubectl get namespaces | grep -E "langflow|keda-system|NAME"

    echo -e "\n${BLUE}=== Pods en langflow ===${NC}"
    kubectl get pods -n langflow 2>/dev/null || echo "Namespace langflow no existe aún"

    echo -e "\n${BLUE}=== Services en langflow ===${NC}"
    kubectl get svc -n langflow 2>/dev/null || echo "Namespace langflow no existe aún"

    echo -e "\n${BLUE}=== KEDA ScaledObjects ===${NC}"
    kubectl get scaledobject -n langflow 2>/dev/null || echo "No hay ScaledObjects aún"
}

function logs() {
    local component=$1

    if [ -z "$component" ]; then
        echo "Uso: $0 logs [ide|runtime|keda]"
        exit 1
    fi

    case $component in
        ide)
            print_header "Logs de Langflow IDE"
            kubectl logs -n langflow -l app=langflow-ide --tail=100 -f
            ;;
        runtime)
            print_header "Logs de Langflow Runtime"
            kubectl logs -n langflow -l app=langflow-runtime --tail=100 -f
            ;;
        keda)
            print_header "Logs de KEDA"
            kubectl logs -n keda-system -l app=keda-operator --tail=100 -f
            ;;
        *)
            print_error "Componente desconocido: $component"
            echo "Componentes disponibles: ide, runtime, keda"
            exit 1
            ;;
    esac
}

function port_forward() {
    local service=$1

    case $service in
        ide)
            print_header "Port-forward Langflow IDE"
            echo "Accede a http://localhost:7860"
            kubectl port-forward -n langflow svc/langflow-ide 7860:7860
            ;;
        runtime)
            print_header "Port-forward Langflow Runtime API"
            echo "API disponible en http://localhost:8000"
            kubectl port-forward -n langflow svc/langflow-runtime-lb 8000:8000
            ;;
        all)
            print_header "Port-forward todos los servicios"
            echo "Langflow IDE: http://localhost:7860"
            echo "Langflow API: http://localhost:8000"
            kubectl port-forward -n langflow svc/langflow-ide 7860:7860 &
            kubectl port-forward -n langflow svc/langflow-runtime-lb 8000:8000 &
            wait
            ;;
        *)
            print_error "Servicio desconocido: $service"
            echo "Servicios disponibles: ide, runtime, all"
            exit 1
            ;;
    esac
}

function show_access_info() {
    print_header "Información de Acceso"

    echo -e "${GREEN}Para acceder a Langflow IDE:${NC}"
    echo "  kubectl port-forward -n langflow svc/langflow-ide 7860:7860"
    echo "  Luego abre: http://localhost:7860"
    echo ""

    echo -e "${GREEN}Para acceder a Langflow Runtime API:${NC}"
    echo "  kubectl port-forward -n langflow svc/langflow-runtime-lb 8000:8000"
    echo "  API en: http://localhost:8000"
    echo ""

    echo -e "${GREEN}Comandos útiles:${NC}"
    echo "  ./setup-minikube.sh status       - Ver estado del cluster"
    echo "  ./setup-minikube.sh logs ide     - Ver logs del IDE"
    echo "  ./setup-minikube.sh logs runtime - Ver logs de workers"
    echo "  ./setup-minikube.sh forward ide  - Port-forward IDE"
    echo "  make status                      - Estado detallado (requiere make)"
}

function scale_runtime() {
    local replicas=$1

    if [ -z "$replicas" ]; then
        echo "Uso: $0 scale <número-de-réplicas>"
        exit 1
    fi

    print_header "Escalando Langflow Runtime a $replicas réplicas"
    kubectl scale statefulset -n langflow langflow-runtime --replicas=$replicas
    print_success "Runtime escalado a $replicas réplicas"
}

function show_help() {
    echo "Langflow en Minikube - Script de Gestión"
    echo ""
    echo "Uso: $0 [comando] [opciones]"
    echo ""
    echo "Comandos disponibles:"
    echo "  check      - Verificar prerequisitos"
    echo "  deploy     - Desplegar Langflow en Minikube"
    echo "  destroy    - Eliminar toda la infraestructura"
    echo "  status     - Mostrar estado del cluster"
    echo "  logs       - Ver logs (ide|runtime|keda)"
    echo "  forward    - Port-forward servicios (ide|runtime|all)"
    echo "  scale      - Escalar runtime workers"
    echo "  access     - Mostrar información de acceso"
    echo "  help       - Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 check                  # Verificar prerequisitos"
    echo "  $0 deploy                 # Desplegar infraestructura"
    echo "  $0 status                 # Ver estado"
    echo "  $0 logs ide               # Ver logs del IDE"
    echo "  $0 forward ide            # Port-forward IDE"
    echo "  $0 scale 3                # Escalar a 3 workers"
    echo "  $0 destroy                # Eliminar todo"
}

# Main
case "${1:-help}" in
    check)
        check_prerequisites
        ;;
    deploy)
        check_prerequisites
        deploy
        ;;
    destroy)
        destroy
        ;;
    status)
        status
        ;;
    logs)
        logs "$2"
        ;;
    forward|pf)
        port_forward "$2"
        ;;
    scale)
        scale_runtime "$2"
        ;;
    access|info)
        show_access_info
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Comando desconocido: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
