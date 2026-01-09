#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/monitoring.conf"
MONITOR_SCRIPT="${SCRIPT_DIR}/monitor.sh"

echo "================================================"
echo "SETTING UP MONITORING SYSTEM"
echo "================================================"

# Check if configuration exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

if [ ! -f "$MONITOR_SCRIPT" ]; then
    echo "ERROR: Monitor script not found: $MONITOR_SCRIPT"
    exit 1
fi

# Load configuration
source "$CONFIG_FILE"

# Install mailutils for email notifications
echo "Installing mailutils..."
sudo apt-get update -qq
sudo apt-get install -y mailutils ssmtp > /dev/null 2>&1

# Configure SSMTP for Gmail
if [ "$EMAIL_ENABLED" == "true" ]; then
    echo "Configuring email notifications..."
    sudo tee /etc/ssmtp/ssmtp.conf > /dev/null << SSMTP_EOF
root=$SMTP_USER
mailhub=$SMTP_SERVER:$SMTP_PORT
AuthUser=$SMTP_USER
AuthPass=$SMTP_PASSWORD
UseSTARTTLS=YES
UseTLS=YES
FromLineOverride=YES
SSMTP_EOF
    
    sudo chmod 640 /etc/ssmtp/ssmtp.conf
    echo "✓ Email notifications configured"
fi

# Setup cron job for monitoring
CRON_JOB="*/$((CHECK_INTERVAL / 60)) * * * * $MONITOR_SCRIPT >> ${SCRIPT_DIR}/monitor.log 2>&1"

# Remove old cron job if exists
(crontab -l 2>/dev/null | grep -v "$MONITOR_SCRIPT") | crontab - 2>/dev/null || true

# Add new cron job
(crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -

echo "✓ Cron job configured (runs every $((CHECK_INTERVAL / 60)) minutes)"

# Run initial monitoring check
echo ""
echo "Running initial monitoring check..."
bash "$MONITOR_SCRIPT"

echo ""
echo "================================================"
echo "MONITORING SETUP COMPLETE"
echo "================================================"
echo "Monitoring runs every $((CHECK_INTERVAL / 60)) minutes"
echo "Logs: ${SCRIPT_DIR}/monitor.log"
echo ""
echo "To view cron jobs: crontab -l"
echo "To view logs: tail -f ${SCRIPT_DIR}/monitor.log"
