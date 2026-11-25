#!/bin/bash
# Run a command on the Filmatch instance through SSM Run Command (no SSH, no open port) and wait.
#
#   bash deploy/aws/bin/remote.sh deploy        # sync bundle from S3 + run deploy.sh
#   bash deploy/aws/bin/remote.sh backup        # run the nightly backup now
#   bash deploy/aws/bin/remote.sh restore-test  # restore latest dump into a side container
#   bash deploy/aws/bin/remote.sh status        # containers, disk, memory, last request log lines
#   bash deploy/aws/bin/remote.sh '<any shell command>'
source "$(dirname "$0")/common.sh"

S=/opt/filmatch/deploy/scripts
SYNC='source /etc/filmatch.env && aws s3 sync --only-show-errors --delete "s3://$CONTENT_BUCKET/deploy/" /opt/filmatch/deploy/'
case "${1:-}" in
deploy) cmd="$SYNC && bash $S/deploy.sh" ;;
backup) cmd="bash $S/backup-mongo.sh" ;;
restore-test) cmd="bash $S/restore-test.sh latest" ;;
status) cmd='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"; df -h /; free -m; uptime; tail -n 5 /opt/filmatch/logs/*.log 2>/dev/null | cut -c1-200' ;;
'') echo "usage: remote.sh deploy|backup|restore-test|status|'<command>'" >&2; exit 2 ;;
*) cmd="$1" ;;
esac

params="{\"commands\":[\"$(json_escape "$cmd")\"],\"executionTimeout\":[\"1800\"]}"
id=$(aws ssm send-command \
  --document-name AWS-RunShellScript \
  --targets "Key=tag:FilmatchRole,Values=app" \
  --comment "filmatch: ${1:0:90}" \
  --parameters "$params" \
  --query Command.CommandId --output text)
log "command $id sent; waiting..."

while true; do
  sleep 8
  status=$(aws ssm list-commands --command-id "$id" --query 'Commands[0].Status' --output text)
  case "$status" in Pending | InProgress | Delayed) continue ;; esac
  break
done

aws ssm list-command-invocations --command-id "$id" --details \
  --query 'CommandInvocations[].CommandPlugins[].[Output]' --output text
log "status: $status"
[ "$status" = "Success" ]
