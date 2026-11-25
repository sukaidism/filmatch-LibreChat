#!/bin/bash
# WS-C restore test. Restores a MongoDB dump from S3 into a FRESH, separate MongoDB container,
# compares document counts with the live database, and (optionally) starts a temporary Filmatch
# app against the restored data so you can log in and prove it works. The live system is untouched.
#
# Usage (on the instance, as root - e.g. via `aws ssm start-session` then `sudo -i`):
#   bash /opt/filmatch/deploy/scripts/restore-test.sh                 # latest dump, counts only
#   bash /opt/filmatch/deploy/scripts/restore-test.sh latest --with-app
#   bash /opt/filmatch/deploy/scripts/restore-test.sh mongodb/20261126T180000Z.archive.gz --with-app
#   bash /opt/filmatch/deploy/scripts/restore-test.sh --cleanup
#
# With --with-app, open a tunnel from your laptop and browse http://localhost:8081 :
#   aws ssm start-session --target <instance-id> --document-name AWS-StartPortForwardingSession \
#     --parameters portNumber=8081,localPortNumber=8081

source "$(dirname "$0")/lib.sh"

NET=filmatch-restore
DB=filmatch-restore-mongo
APP=filmatch-restore-app

cleanup() {
  docker rm -f "$APP" "$DB" >/dev/null 2>&1 || true
  docker network rm "$NET" >/dev/null 2>&1 || true
  rm -f "$FILMATCH_ROOT/backup/restore-test.archive.gz"
}

if [ "${1:-}" = "--cleanup" ]; then
  cleanup
  log "restore test containers removed"
  exit 0
fi

key=${1:-latest}
with_app=${2:-}
t0=$(date +%s)
log "=== RESTORE TEST START $(date -u +%FT%TZ) ==="

if [ "$key" = "latest" ]; then
  key=mongodb/$(aws s3 ls "s3://$BACKUP_BUCKET/mongodb/" | awk '{print $4}' | sort | tail -1)
  [ "$key" != "mongodb/" ] || die "no dumps found in s3://$BACKUP_BUCKET/mongodb/"
fi
log "using s3://$BACKUP_BUCKET/$key"

cleanup
file=$FILMATCH_ROOT/backup/restore-test.archive.gz
aws s3 cp --only-show-errors "s3://$BACKUP_BUCKET/$key" "$file"
log "downloaded $(stat -c %s "$file") bytes"

docker network create "$NET" >/dev/null
docker run -d --name "$DB" --network "$NET" "$MONGO_IMAGE" mongod --noauth --bind_ip_all >/dev/null
wait_for_mongo "$DB"
docker exec -i "$DB" mongorestore --archive --gzip --quiet <"$file"
t_restored=$(date +%s)
log "restore finished in $((t_restored - t0))s"

printf '\n%-16s %10s %10s %s\n' COLLECTION LIVE RESTORED MATCH
fail=0
for c in users conversations messages presets; do
  live=$(mongo_eval filmatch-mongodb LibreChat "db.$c.countDocuments()" 2>/dev/null || echo n/a)
  rest=$(mongo_eval "$DB" LibreChat "db.$c.countDocuments()" 2>/dev/null || echo n/a)
  # Live can legitimately be ahead (chats since the dump); restored must not be empty if live isn't.
  if [ "$rest" = "n/a" ] || { [ "$live" != "0" ] && [ "$rest" = "0" ]; }; then m=NO; fail=1; else m=yes; fi
  printf '%-16s %10s %10s %s\n' "$c" "$live" "$rest" "$m"
done
echo
log "restored users (emails are invented test accounts):"
mongo_eval "$DB" LibreChat 'db.users.find({}, {email:1, createdAt:1, _id:0}).limit(10).forEach(u => print("  " + u.email + "  created " + u.createdAt.toISOString()))'

if [ "$with_app" = "--with-app" ]; then
  load_app_env
  img=$(image_ref)
  ecr_login
  docker run -d --name "$APP" --network "$NET" -p 127.0.0.1:8081:3080 \
    -v "$FILMATCH_ROOT/config:/config:ro" \
    -e HOST=0.0.0.0 -e PORT=3080 -e NODE_ENV=production \
    -e MONGO_URI="mongodb://$DB:27017/LibreChat" \
    -e CONFIG_PATH=/config/librechat.filmatch.yaml \
    -e DOMAIN_CLIENT=http://localhost:8081 -e DOMAIN_SERVER=http://localhost:8081 \
    -e ALLOW_EMAIL_LOGIN=true -e ALLOW_REGISTRATION=false -e SEARCH=false -e APP_TITLE="Filmatch (restore test)" \
    -e GOOGLE_KEY -e GOOGLE_MODELS -e CREDS_KEY -e CREDS_IV -e JWT_SECRET -e JWT_REFRESH_SECRET \
    "$img" >/dev/null
  for i in $(seq 1 60); do
    curl -fsS -m 3 http://127.0.0.1:8081/health >/dev/null 2>&1 && break
    [ "$i" -eq 60 ] && { docker logs --tail 50 "$APP"; die "restored app did not start"; }
    sleep 3
  done
  log "restored app is healthy at 127.0.0.1:8081 after $(($(date +%s) - t0))s total (this is your measured RTO)"
  log "tunnel: aws ssm start-session --target $(ec2-metadata -i | awk '{print $2}') --document-name AWS-StartPortForwardingSession --parameters portNumber=8081,localPortNumber=8081"
  log "then log in at http://localhost:8081 with a test account; run with --cleanup when done"
else
  cleanup
fi

log "=== RESTORE TEST END $(date -u +%FT%TZ) elapsed=$(($(date +%s) - t0))s result=$([ $fail -eq 0 ] && echo PASS || echo FAIL) ==="
exit $fail
