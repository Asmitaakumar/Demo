#!/bin/bash

#################################################################
#  Define your variables here:
#################################################################
FILESTOKEEP=168
BACKUP_DIR=/home/rundeck/stagelogs
AWS_BACKUP=s3://pnlp-prod-backup-confidential/Stage/Stage-MySQL-Backup/
MYSQL_USER=pharmauatadmin
MYSQL_PWD='cHW7iCcgu9MkZ19W'
DATE=$(date +"%Y-%m-%d")
MYSQL_HOST=pnlp-uat-rds-confidential.celvmmljjdtg.us-west-2.rds.amazonaws.com
databases=stage_pharma
ENVIRONMENT="Stage"
KIND="MySQL"
ALERT_NAME="${RD_JOB_NAME:-Daily MySQL & Elasticsearch Backup}"
RESOURCE_NAME="pnlp-uat-rds-confidential"

# Injected at runtime by Rundeck
SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL}"

start_time=$(date +%s)

mkdir -p "$BACKUP_DIR"

for db in ${databases}; do
    mysqldump --port=3306 -
