#!/bin/bash

#################################################################
#  Load secrets (don't commit this file to GitHub)
#################################################################
source /etc/rundeck/secrets/dev_env_vars

#################################################################
#  Define constants and derived values
#################################################################
FILESTOKEEP=168
BACKUP_DIR=/home/rundeck/stagelogs
AWS_BACKUP=s3://pnlp-prod-backup-confidential/Stage/Stage-MySQL-Backup/
DATE=$(date +"%Y-%m-%d")
databases=stage_pharma
ENVIRONMENT="Stage"
KIND="MySQL"
ALERT_NAME="${RD_JOB_NAME:-Daily MySQL & Elasticsearch Backup}"
RESOURCE_NAME="pnlp-uat-rds-confidential"
RD_JOB_URL="${RD_JOB_URL:-http://rundeck.example.com/job/YOUR_JOB_ID}"

start_time=$(date +%s)

#################################################################
#  Ensure backup directory exists
#################################################################
mkdir -p "$BACKUP_DIR"

#################################################################
#  Create MySQL backup
#################################################################
for db in ${databases}; do
    mysqldump --port=3306 --host=$MYSQL_HOST --user=$MYSQL_USER -p$MYSQL_PWD --no-create-db --routines "$db" | gzip > "$BACKUP_DIR/$db@$DATE.sql.gz"
    BACKUP_STATUS=$?
done

#################################################################
#  Upload backup to S3
#################################################################
for db in ${databases}; do
    aws s3 cp "$BACKUP_DIR/$db@$DATE.sql.gz" "$AWS_BACKUP"
    S3_STATUS=$?
done

#################################################################
#  Cleanup old backups (older than 7 days)
#################################################################
find "$BACKUP_DIR/" -type f -ctime +7 -name '*.sql.gz' -execdir rm -- {} \;

#################################################################
#  Generate duration and size details
#################################################################
end_time=$(date +%s)
duration=$((end_time - start_time))
duration_formatted=$(printf '%d minutes %d seconds' $((duration/60)) $((duration%60)))
backup_file="$BACKUP_DIR/$db@$DATE.sql.gz"
backup_size=$(du -h "$backup_file" | cut -f1)
timestamp=$(date -u '+%Y-%m-%d %H:%M UTC')

#################################################################
#  Determine backup status
#################################################################
if [ $BACKUP_STATUS -eq 0 ] && [ $S3_STATUS -eq 0 ]; then
    STATUS=":white_check_mark: Success"
else
    STATUS=":x: Failure"
fi

#################################################################
#  Print summary to console
#################################################################
echo ""
echo "------------------------------------------------------------"
echo "Alert Name: $ALERT_NAME"
echo "Kind: $KIND"
echo "Resource Name: $RESOURCE_NAME"
echo "Environment: $ENVIRONMENT"
echo "Execution Time: $timestamp"
echo "Status: $STATUS"
echo "Duration: $duration_formatted"
echo "Size: $backup_size"
echo "S3 Backup URL: ${AWS_BACKUP}${db}@${DATE}.sql.gz"
echo "RunDeck Job URL: Click here => $RD_JOB_URL"
echo "------------------------------------------------------------"

#################################################################
#  Slack Notification
#################################################################
SLACK_MESSAGE=$(cat <<EOF
*${ALERT_NAME}*
*Kind:* $KIND
*Resource:* $RESOURCE_NAME
*Environment:* $ENVIRONMENT
*Execution Time:* $timestamp
*Status:* $STATUS
*Duration:* $duration_formatted
*Size:* $backup_size
*S3 Backup:* ${AWS_BACKUP}${db}@${DATE}.sql.gz
*RunDeck URL:* <$RD_JOB_URL|Click here>
EOF
)

curl -X POST -H 'Content-type: application/json' --data "{
    \"text\": \"$SLACK_MESSAGE\"
}" "$SLACK_WEBHOOK_URL"
