#!/bin/bash

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/monitoring.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

source "$CONFIG_FILE"

MONITOR_LOG="${SCRIPT_DIR}/monitor.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Logging function
log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$MONITOR_LOG"
}

# Email notification function
send_email() {
    local subject="$1"
    local body="$2"
    
    if [ "$EMAIL_ENABLED" != "true" ]; then
        log_message "Email notifications disabled. Skipping: $subject"
        return
    fi
    
    echo -e "$body" | mail -s "$subject" \
        -a "From: $SMTP_USER" \
        -S smtp="$SMTP_SERVER:$SMTP_PORT" \
        -S smtp-use-starttls \
        -S smtp-auth=login \
        -S smtp-auth-user="$SMTP_USER" \
        -S smtp-auth-password="$SMTP_PASSWORD" \
        "$EMAIL_TO" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        log_message "Email sent: $subject"
    else
        log_message "Failed to send email: $subject"
    fi
}

# Check application availability
check_app_availability() {
    log_message "=== Checking Application Availability ==="
    
    if ssh -o ConnectTimeout=5 azureuser@4.223.230.158 "systemctl is-active --quiet dummyapp"; then
        log_message "✓ Application service is running"
        return 0
    else
        log_message "✗ Application service is NOT running"
        send_email "CRITICAL: Application Down" "The dummy application service has stopped running on $(hostname)"
        return 1
    fi
}

# Analyze logs
analyze_logs() {
    log_message "=== Analyzing Application Logs ==="
    
    if [ ! -f "$APP_LOG" ]; then
        log_message "ERROR: Log file not found: $APP_LOG"
        send_email "Monitoring Alert: Log File Missing" "Application log file $APP_LOG is missing on $(hostname)"
        return 1
    fi
    
    local total_lines=$(wc -l < "$APP_LOG" 2>/dev/null || echo 0)
    local errors=$(grep -i "error\|exception\|failed" "$APP_LOG" 2>/dev/null | wc -l)
    local warnings=$(grep -i "warn\|warning" "$APP_LOG" 2>/dev/null | wc -l)
    
    log_message "Total log lines: $total_lines"
    log_message "Errors: $errors"
    log_message "Warnings: $warnings"
    
    if [ "$errors" -gt "$LOG_ERROR_THRESHOLD" ]; then
        local last_errors=$(grep -i "error\|exception\|failed" "$APP_LOG" | tail -n 5)
        send_email "Alert: High Error Count" "Detected $errors errors in application logs.\n\nRecent errors:\n$last_errors"
    fi
}

# Check system resources
check_resources() {
    log_message "=== Checking System Resources ==="
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    cpu_usage=${cpu_usage%.*}
    log_message "CPU Usage: ${cpu_usage}%"
    
    if [ "$cpu_usage" -gt "$CPU_THRESHOLD" ]; then
        send_email "Alert: High CPU Usage" "CPU usage is ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%) on $(hostname)"
    fi
    
    # Memory usage
    local mem_usage=$(free | grep Mem | awk '{print int($3/$2 * 100)}')
    log_message "Memory Usage: ${mem_usage}%"
    
    if [ "$mem_usage" -gt "$MEMORY_THRESHOLD" ]; then
        send_email "Alert: High Memory Usage" "Memory usage is ${mem_usage}% (threshold: ${MEMORY_THRESHOLD}%) on $(hostname)"
    fi
    
    # Disk usage
    local disk_usage=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
    log_message "Disk Usage: ${disk_usage}%"
    
    if [ "$disk_usage" -gt "$DISK_THRESHOLD" ]; then
        send_email "Alert: High Disk Usage" "Disk usage is ${disk_usage}% (threshold: ${DISK_THRESHOLD}%) on $(hostname)"
    fi
}

# Main monitoring function
main() {
    log_message "=========================================="
    log_message "Starting Monitoring Check"
    log_message "=========================================="
    
    check_app_availability
    analyze_logs
    check_resources
    
    log_message "=========================================="
    log_message "Monitoring Check Completed"
    log_message "=========================================="
    echo ""
}

# Run main function
main
