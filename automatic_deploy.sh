#!/bin/bash

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"
MONITORING_DIR="${PROJECT_ROOT}/monitoring"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory.ini"
JAR_FILE="project2_dummy_service-1.0-SNAPSHOT.jar"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
print_header() {
    echo ""
    echo "================================================"
    echo "$1"
    echo "================================================"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_requirements() {
    local missing=0
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        missing=1
    fi
    
    if ! command -v ansible-playbook &> /dev/null; then
        print_error "Ansible is not installed"
        missing=1
    fi
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        missing=1
    fi
    
    if [ ! -f "$PROJECT_ROOT/$JAR_FILE" ]; then
        print_error "JAR file not found: $JAR_FILE"
        missing=1
    fi
    
    if [ $missing -eq 1 ]; then
        echo ""
        print_error "Please install missing requirements"
        exit 1
    fi
    
    print_success "All requirements met"
}

check_azure_login() {
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure"
        echo "Please run: az login"
        exit 1
    fi
    print_success "Azure login verified"
}

check_terraform_state() {
    if [ ! -f "${TERRAFORM_DIR}/terraform.tfstate" ]; then
        print_error "Terraform state not found. Run 'provision' first"
        exit 1
    fi
}

provision() {
    print_header "PROVISIONING INFRASTRUCTURE"
    
    check_requirements
    check_azure_login
    
    cd "$TERRAFORM_DIR"
    
    echo "Initializing Terraform..."
    terraform init
    
    echo ""
    echo "Planning infrastructure..."
    terraform plan -out=tfplan
    
    echo ""
    echo "Applying infrastructure..."
    terraform apply tfplan
    
    echo ""
    print_success "Infrastructure provisioned successfully"
    
    # Get outputs
    APP_IP=$(terraform output -raw app_server_public_ip)
    MONITOR_IP=$(terraform output -raw monitor_server_public_ip)
    
    # Update Ansible inventory
    sed -i "s/APP_SERVER_IP/$APP_IP/g" "$INVENTORY_FILE"
    sed -i "s/MONITOR_SERVER_IP/$MONITOR_IP/g" "$INVENTORY_FILE"
    
    echo ""
    print_success "Ansible inventory updated"
    echo "  App Server IP: $APP_IP"
    echo "  Monitor Server IP: $MONITOR_IP"
    
    echo ""
    print_warning "Waiting 60 seconds for VMs to fully boot..."
    sleep 60
    
    print_success "Infrastructure ready"
}

deploy() {
    print_header "DEPLOYING APPLICATION"
    
    check_terraform_state
    
    cd "$ANSIBLE_DIR"
    
    echo "Running Ansible playbook..."
    ansible-playbook -i inventory.ini deploy_app.yml
    
    print_success "Application deployed successfully"
}

check_status() {
    print_header "CHECKING APPLICATION STATUS"
    
    check_terraform_state
    
    cd "$TERRAFORM_DIR"
    APP_IP=$(terraform output -raw app_server_public_ip)
    
    echo "Connecting to app server: $APP_IP"
    ssh -o StrictHostKeyChecking=no azureuser@$APP_IP << 'ENDSSH'
echo "=== Service Status ==="
sudo systemctl status dummyapp --no-pager

echo ""
echo "=== Recent Logs ==="
sudo tail -n 20 /var/log/dummyapp/app.log

echo ""
echo "=== System Resources ==="
echo "CPU: $(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')%"
echo "Memory: $(free | grep Mem | awk '{print int($3/$2 * 100)}')%"
echo "Disk: $(df -h / | tail -1 | awk '{print $5}')"
ENDSSH
    
    print_success "Status check complete"
}

monitor() {
    print_header "SETTING UP MONITORING"
    
    check_terraform_state
    
    cd "$TERRAFORM_DIR"
    MONITOR_IP=$(terraform output -raw monitor_server_public_ip)
    APP_IP=$(terraform output -raw app_server_public_ip)
    
    echo "Copying monitoring files to monitor server..."
    scp -o StrictHostKeyChecking=no -r "$MONITORING_DIR"/* azureuser@$MONITOR_IP:~/
    
    echo ""
    echo "Setting up monitoring on server..."
    ssh -o StrictHostKeyChecking=no azureuser@$MONITOR_IP << ENDSSH
# Update monitoring config with app server IP
sed -i "s/localhost/$APP_IP/g" ~/monitoring.conf

# Run setup script
chmod +x ~/setup_monitoring.sh
sudo ~/setup_monitoring.sh
ENDSSH
    
    print_success "Monitoring setup complete"
    echo ""
    echo "Monitor Server IP: $MONITOR_IP"
    echo "To view logs: ssh azureuser@$MONITOR_IP 'tail -f ~/monitor.log'"
}

teardown() {
    print_header "TEARING DOWN INFRASTRUCTURE"
    
    read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Teardown cancelled"
        exit 0
    fi
    
    cd "$TERRAFORM_DIR"
    
    if [ ! -f "terraform.tfstate" ]; then
        print_warning "No terraform state found. Nothing to destroy."
        exit 0
    fi
    
    echo "Destroying infrastructure..."
    terraform destroy -auto-approve
    
    # Reset inventory
    sed -i "s/ansible_host=.* ansible_user/ansible_host=APP_SERVER_IP ansible_user/g" "$INVENTORY_FILE"
    sed -i "s/ansible_host=.* ansible_user/ansible_host=MONITOR_SERVER_IP ansible_user/g" "$INVENTORY_FILE" 
    
    print_success "Infrastructure destroyed"
}

show_usage() {
    cat << USAGE
Usage: $0 <command>

Commands:
  provision     - Create Azure VMs using Terraform
  deploy        - Deploy application using Ansible
  check-status  - Check application status
  monitor       - Setup and configure monitoring system
  teardown      - Destroy all Azure resources

Examples:
  $0 provision
  $0 deploy
  $0 check-status
  $0 monitor
  $0 teardown

USAGE
}

# Main
case "$1" in
    provision)
        provision
        ;;
    deploy)
        deploy
        ;;
    check-status)
        check_status
        ;;
    monitor)
        monitor
        ;;
    teardown)
        teardown
        ;;
    *)
        show_usage
        exit 1
        ;;
esac
