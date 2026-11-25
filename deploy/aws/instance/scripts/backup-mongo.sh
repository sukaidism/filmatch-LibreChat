#!/bin/bash
# Nightly backup (WS-C / WS-E automation). Run by the SSM State Manager association
# "<project>-nightly-mongodb-backup" at 02:00 Asia/Manila; also safe to run by hand.
#
# Backs up: the MongoDB "LibreChat" database (users, conversations, messages, presets)
# and the live Filmatch config. Knowledge docs are already versioned in S3; secrets are in
# Parameter Store. Retention is enforced by the S3 lifecycle rule (>= 7 days).

source "$(dirname "$0")/lib.sh"

ts=$(date -u +%Y%m%dT%H%M%SZ)
dump=$FILMATCH_ROOT/backup/mongodb-$ts.archive.gz
cfg=$FILMATCH_ROOT/backup/config-$ts.tgz
start=$(date +%s)

on_fail() {
  log "BACKUP FAILED (line $1)"
  put_metric Filmatch/Backup BackupSuccess 0
  rm -f -- "$dump" "$cfg"
}
trap 'on_fail $LINENO' ERR

mkdir -p "$FILMATCH_ROOT/backup"
log "dumping MongoDB database LibreChat"
docker exec filmatch-mongodb mongodump --db LibreChat --archive --gzip --quiet >"$dump"
size=$(stat -c %s "$dump")
[ "$size" -gt 200 ] || { log "dump is only $size bytes"; false; }

aws s3 cp --only-show-errors "$dump" "s3://$BACKUP_BUCKET/mongodb/$ts.archive.gz"
tar -czf "$cfg" -C "$FILMATCH_ROOT/config" librechat.filmatch.yaml
aws s3 cp --only-show-errors "$cfg" "s3://$BACKUP_BUCKET/config/$ts.tgz"

counts=$(mongo_eval filmatch-mongodb LibreChat \
  'JSON.stringify({users:db.users.countDocuments(),conversations:db.conversations.countDocuments(),messages:db.messages.countDocuments()})')
elapsed=$(($(date +%s) - start))

put_metric Filmatch/Backup BackupSuccess 1
put_metric Filmatch/Backup BackupSizeBytes "$size" Bytes
put_metric Filmatch/Backup BackupDurationSeconds "$elapsed" Seconds
rm -f -- "$dump" "$cfg"

echo "{\"event\":\"filmatch_backup\",\"ts\":\"$(date -u +%FT%TZ)\",\"ok\":1,\"key\":\"mongodb/$ts.archive.gz\",\"bytes\":$size,\"seconds\":$elapsed,\"counts\":$counts}"
log "backup complete -> s3://$BACKUP_BUCKET/mongodb/$ts.archive.gz"
