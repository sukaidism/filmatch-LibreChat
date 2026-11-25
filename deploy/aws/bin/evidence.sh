#!/bin/bash
# Capture CLI evidence for the project website (Appendix B). Output cannot be accidentally edited,
# which is why the brief prefers it. Review it before publishing: it contains account IDs and
# resource names, but no secret values (SecureString values are never requested).
#
#   bash deploy/aws/bin/evidence.sh > evidence-$(date +%F).txt
source "$(dirname "$0")/common.sh"

h() { printf '\n===== %s  (%s)\n' "$1" "$(date -u +%FT%TZ)"; }
iid=$(stack_output InstanceId)
bb=$(stack_output BackupBucketName)
cb=$(stack_output ContentBucketName)

h "who am I (E-12)"; aws sts get-caller-identity --output table
h "IAM users and MFA devices (E-12)"
for u in $(aws iam list-users --query 'Users[].UserName' --output text); do
  printf '%-24s MFA devices: %s\n' "$u" "$(aws iam list-mfa-devices --user-name "$u" --query 'length(MFADevices)')"
done
h "account summary (root MFA)"; aws iam get-account-summary --query 'SummaryMap.{AccountMFAEnabled:AccountMFAEnabled,Users:Users}' --output table
h "instance (E-02)"; aws ec2 describe-instances --instance-ids "$iid" \
  --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,State:State.Name,AZ:Placement.AvailabilityZone,IMDSv2:MetadataOptions.HttpTokens,EbsEncrypted:BlockDeviceMappings[0].Ebs.VolumeId}' --output table
h "security group ingress (database not exposed, no SSH)"; aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=$PROJECT-app-sg" --query 'SecurityGroups[].IpPermissions' --output json
h "secrets in Parameter Store - names and types only (E-13)"
aws ssm get-parameters-by-path --path "/$PROJECT/app-env" --query 'Parameters[].[Name,Type,LastModifiedDate]' --output table
h "S3 versioning (WS-C #3)"
for b in "$cb" "$bb"; do echo "$b: $(aws s3api get-bucket-versioning --bucket "$b" --query Status --output text)"; done
h "latest MongoDB dumps (E-10)"; aws s3 ls "s3://$bb/mongodb/" | tail -10
h "backup lifecycle rule"; aws s3api get-bucket-lifecycle-configuration --bucket "$bb" --query 'Rules[].[ID,Prefix,Expiration.Days]' --output table
h "nightly backup association runs (E-14)"
aws ssm list-associations --association-filter-list "key=AssociationName,value=$PROJECT-nightly-mongodb-backup" \
  --query 'Associations[].[AssociationName,ScheduleExpression,LastExecutionDate,Overview.Status]' --output table
assoc=$(aws ssm list-associations --association-filter-list "key=AssociationName,value=$PROJECT-nightly-mongodb-backup" --query 'Associations[0].AssociationId' --output text)
aws ssm describe-association-executions --association-id "$assoc" --query 'AssociationExecutions[].[ExecutionId,Status,CreatedTime]' --output table || true
h "health-check automation runs (E-14)"
aws logs filter-log-events --log-group-name "/aws/lambda/$PROJECT-healthcheck" --filter-pattern '"filmatch_healthcheck"' \
  --start-time $(( ($(date +%s) - 86400) * 1000 )) --query 'events[-5:].message' --output text | tr '\t' '\n'
h "alarms (E-07)"; aws cloudwatch describe-alarms --alarm-name-prefix "$PROJECT-" \
  --query 'MetricAlarms[].[AlarmName,StateValue,Threshold,StateUpdatedTimestamp]' --output table
h "log groups and retention (WS-B #4)"; aws logs describe-log-groups --query "logGroups[?contains(logGroupName,'$PROJECT')].[logGroupName,retentionInDays]" --output table
h "request log sample (E-09)"
aws logs filter-log-events --log-group-name "/$PROJECT/app" --filter-pattern '{ $.event = "filmatch_chat" }' \
  --start-time $(( ($(date +%s) - 86400) * 1000 )) --query 'events[-5:].message' --output text | tr '\t' '\n'
h "CloudTrail"; aws cloudtrail describe-trails --query 'trailList[].[Name,HomeRegion,IsMultiRegionTrail,LogFileValidationEnabled]' --output table
h "budgets"; aws budgets describe-budgets --account-id "$(account_id)" --query 'Budgets[].[BudgetName,BudgetLimit.Amount,CalculatedSpend.ActualSpend.Amount]' --output table
