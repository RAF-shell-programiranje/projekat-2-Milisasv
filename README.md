# Projekat 2 - Azure Cloud Infrastructure & Monitoring

## Opis Projekta
Automatizovani deployment Java aplikacije na Azure cloud platformu sa kompletnim monitoring sistemom.

## Arhitektura
- 2 Azure VM instance: App Server + Monitor Server
- Azure Virtual Network: 10.0.0.0/16
- Network Security Groups: Port 22 (SSH), 80 (HTTP), 8080 (App)
- Java Aplikacija: Background worker sa 500 agenata
- Monitoring: Automatski health checks svakih 5 minuta

## Tehnologije
- Terraform: Infrastruktura kao kod
- Ansible: Automatizacija deployment-a
- Azure Cloud: Cloud provider
- Java: Aplikaciona logika
- Systemd: Servisno upravljanje
- Cron: Automatizacija monitoringa

## Deployment

### Prerequisites
- Terraform >= 1.0
- Ansible >= 2.9
- Azure CLI
- SSH key pair

### 1. Deploy Infrastrukture
cd terraform/
terraform init
terraform apply -auto-approve

### 2. Deploy Aplikacije
cd ../
./automatic_deploy.sh app

### 3. Setup Monitoring Sistema
./automatic_deploy.sh monitor

## Testiranje

### Provera Aplikacije
ssh azureuser@<APP_IP> 'systemctl status dummyapp'
ssh azureuser@<APP_IP> 'sudo tail -f /var/log/dummyapp/app.log'

### Provera Monitoringa
ssh azureuser@<MONITOR_IP> 'tail -f ~/monitor.log'

## Monitoring Features
- Provera statusa aplikacije
- Analiza log fajlova
- Pracenje sistema (CPU, RAM, Disk)
- Email notifikacije
- Automatsko pokretanje svakih 5 minuta

## Cleanup
cd terraform/
terraform destroy -auto-approve
