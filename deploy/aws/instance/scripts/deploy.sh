#!/bin/bash
# Deploy or redeploy Filmatch on this instance. Idempotent; safe to re-run.
# Called by: CloudFormation user data (first boot), GitHub Actions via SSM Run Command,
# or an operator: `sudo bash /opt/filmatch/deploy/scripts/deploy.sh`.
#
#  1. load secrets from Parameter Store into the shell (never to disk)
#  2. pull the image tagged in /<project>/app/image-tag from ECR
#  3. pull the config and the five knowledge documents from S3 (the AWS integration),
#     rebuild the prompt snapshot in a staging folder, and only swap it in if it validates
#  4. start MongoDB and recreate the api container, then wait for /health

source "$(dirname "$0")/lib.sh"
log "deploy started"

load_app_env
APP_DOMAIN=$(app_domain)
FILMATCH_IMAGE=$(image_ref)
export APP_DOMAIN FILMATCH_IMAGE
log "image=$FILMATCH_IMAGE domain=$APP_DOMAIN"

ecr_login
docker pull -q "$FILMATCH_IMAGE"

# ---------------------------------------------------------------- knowledge from S3
stage=$(mktemp -d)
trap 'rm -rf -- "$stage"' EXIT
aws s3 cp --only-show-errors "s3://$CONTENT_BUCKET/config/librechat.filmatch.yaml" "$stage/librechat.filmatch.yaml"
aws s3 sync --only-show-errors "s3://$CONTENT_BUCKET/knowledge/" "$stage/knowledge/" --exclude '*' --include '*.md'
doc_count=$(find "$stage/knowledge" -name '*.md' | wc -l)
[ "$doc_count" -ge 5 ] || die "expected 5 knowledge documents in s3://$CONTENT_BUCKET/knowledge/, found $doc_count - NOT deploying stale content"
log "fetched config + $doc_count knowledge documents from s3://$CONTENT_BUCKET"
aws s3api list-object-versions --bucket "$CONTENT_BUCKET" --prefix knowledge/ \
  --query 'Versions[?IsLatest].[Key,VersionId,LastModified]' --output text | sed 's/^/  s3 /'

staging=$FILMATCH_ROOT/config/staging
mkdir -p "$staging"
install -o 1000 -g 1000 -m 644 "$stage/librechat.filmatch.yaml" "$staging/librechat.filmatch.yaml"
chmod -R a+rX "$stage"
docker run --rm --user 1000:1000 --network none \
  -e FILMATCH_CONFIG_PATH=/staging/librechat.filmatch.yaml \
  -v "$staging:/staging" -v "$stage/knowledge:/knowledge:ro" \
  --entrypoint node "$FILMATCH_IMAGE" scripts/filmatch-refresh-knowledge.cjs /knowledge ||
  die "knowledge refresh failed validation - live config left unchanged"

live=$FILMATCH_ROOT/config/librechat.filmatch.yaml
[ -f "$live" ] && cp -p "$live" "$live.prev"
mv -f "$staging/librechat.filmatch.yaml" "$live"
log "config swapped in (previous kept as $live.prev)"

# ---------------------------------------------------------------- containers
docker compose -f "$COMPOSE_FILE" up -d mongodb
docker compose -f "$COMPOSE_FILE" up -d --no-deps --force-recreate api

for i in $(seq 1 60); do
  if curl -fsS -m 3 http://127.0.0.1/health >/dev/null 2>&1; then
    log "health OK after $((i * 3))s"
    break
  fi
  if [ "$i" -eq 60 ]; then
    docker logs --tail 80 filmatch-api || true
    die "api did not become healthy in 180s"
  fi
  sleep 3
done

# Keep the disk tidy: drop images not used for 3 days (old releases).
docker image prune -af --filter "until=72h" >/dev/null || true

# WS-F prevention (enable after the disk-full incident write-up, then commit this line):
# bash "$DEPLOY_DIR/scripts/log-guard.sh" install

log "deploy finished: version=$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "$FILMATCH_IMAGE" | sed -n 's/^BUILD_COMMIT=//p' | cut -c1-12)"
