#!/bin/bash
# DISASTER RECOVERY: replace the LIVE Filmatch database with a dump from S3.
# Everything written since that dump is lost (that is your RPO). Prefer restore-test.sh first.
#
#   bash /opt/filmatch/deploy/scripts/restore-live.sh mongodb/<timestamp>.archive.gz --yes
#   bash /opt/filmatch/deploy/scripts/restore-live.sh latest --yes

source "$(dirname "$0")/lib.sh"

key=${1:-}
[ -n "$key" ] && [ "${2:-}" = "--yes" ] || die "usage: restore-live.sh <s3-key|latest> --yes"
t0=$(date +%s)

if [ "$key" = "latest" ]; then
  key=mongodb/$(aws s3 ls "s3://$BACKUP_BUCKET/mongodb/" | awk '{print $4}' | sort | tail -1)
fi
file=$FILMATCH_ROOT/backup/restore-live.archive.gz
aws s3 cp --only-show-errors "s3://$BACKUP_BUCKET/$key" "$file"
log "downloaded s3://$BACKUP_BUCKET/$key ($(stat -c %s "$file") bytes)"

# Safety net: dump the current (possibly broken) state before overwriting it.
docker exec filmatch-mongodb mongodump --db LibreChat --archive --gzip --quiet \
  >"$FILMATCH_ROOT/backup/pre-restore-$(date -u +%Y%m%dT%H%M%SZ).archive.gz" || log "pre-restore dump failed (continuing)"

load_app_env
APP_DOMAIN=$(app_domain); FILMATCH_IMAGE=$(image_ref); export APP_DOMAIN FILMATCH_IMAGE
docker compose -f "$COMPOSE_FILE" stop api
docker compose -f "$COMPOSE_FILE" up -d mongodb
wait_for_mongo filmatch-mongodb
docker exec -i filmatch-mongodb mongorestore --archive --gzip --drop --quiet <"$file"
docker compose -f "$COMPOSE_FILE" up -d --no-deps api
for _ in $(seq 1 60); do curl -fsS -m 3 http://127.0.0.1/health >/dev/null 2>&1 && break; sleep 3; done
rm -f "$file"
log "LIVE RESTORE COMPLETE in $(($(date +%s) - t0))s from $key"
