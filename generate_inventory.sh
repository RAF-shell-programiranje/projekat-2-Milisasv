#!/bin/bash

echo "Generating Ansible inventory from Terraform outputs..."

cd terraform

# Get IP addresses from Terraform
APP_IP=$(terraform output -raw app_server_public_ip 2>/dev/null)
MONITOR_IP=$(terraform output -raw monitor_server_public_ip 2>/dev/null)

if [ -z "$APP_IP" ] || [ -z "$MONITOR_IP" ]; then
    echo "Error: Could not get IPs from Terraform. Run 'terraform apply' first."
    exit 1
fi

cd ../ansible

# Generate inventory.ini
cat > inventory.ini << INV
[app]
$APP_IP ansible_user=azureuser ansible_ssh_private_key_file=~/.ssh/id_rsa

[monitor]
$MONITOR_IP ansible_user=azureuser ansible_ssh_private_key_file=~/.ssh/id_rsa

[all:vars]
ansible_python_interpreter=/usr/bin/python3
INV

echo "Inventory generated successfully!"
echo "  App Server: $APP_IP"
echo "  Monitor Server: $MONITOR_IP"
