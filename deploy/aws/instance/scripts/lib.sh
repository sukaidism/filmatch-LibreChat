#!/bin/bash
# Shared helpers for the on-instance Filmatch scripts. Sourced, not executed.
# Non-secret settings come from /etc/filmatch.env (written by the CloudFormation user data).

set -euo pipefail
# shellcheck disable=SC1091
source /etc/filmatch.env
export AWS_REGION AWS_DEFAULT_REGION

FILMATCH_ROOT=/opt/filmatch
DEPLOY_DIR=$FILMATCH_ROOT/deploy
COMPOSE_FILE=$DEPLOY_DIR/docker-compose.aws.yml
MONGO_IMAGE=mongo:8.0.20

log() { echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) [$(basename "$0")] $*"; }
die() { log "ERROR: $*"; exit 1; }

# Export every /<project>/app-env/* parameter (SecureStrings decrypted) into THIS shell only.
# Secrets are never written to a file on disk.
load_app_env() {
  local out name value key count=0
  out=$(aws ssm get-parameters-by-path --path "$SSM_PREFIX/app-env" --recursive --with-decryption \
    --query 'Parameters[].[Name,Value]' --output text)
  while IFS=$'\t' read -r name value; do
    [ -z "$name" ] && continue
    key=${name##*/}
    [[ $key =~ ^[A-Z_][A-Z0-9_]*$ ]] || die "bad parameter name $name"
    export "$key=$value"
    count=$((count + 1))
  done <<<"$out"
  log "loaded $count settings from Parameter Store path $SSM_PREFIX/app-env"
}

ssm_value() { aws ssm get-parameter --name "$1" --query Parameter.Value --output text; }
image_ref() { echo "$ECR_REPOSITORY_URI:$(ssm_value "$SSM_PREFIX/app/image-tag")"; }
app_domain() { ssm_value "$SSM_PREFIX/app/domain"; }

ecr_login() {
  aws ecr get-login-password | docker login --username AWS --password-stdin "$ECR_REGISTRY" >/dev/null
}

put_metric() { # namespace name value [unit]
  aws cloudwatch put-metric-data --namespace "$1" --metric-name "$2" --value "$3" --unit "${4:-Count}" ||
    log "warning: could not publish metric $1/$2"
}

mongo_eval() { # container db js
  docker exec "$1" mongosh --quiet "$2" --eval "$3"
}

wait_for_mongo() { # container
  for _ in $(seq 1 60); do
    if docker exec "$1" mongosh --quiet --eval 'db.runCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
      return 0
    fi
    sleep 2
  done
  die "MongoDB in $1 did not become ready"
}
