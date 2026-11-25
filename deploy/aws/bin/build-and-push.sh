#!/bin/bash
# Manual fallback for the GitHub Actions build: build the Filmatch image locally and push to ECR,
# then point /<project>/app/image-tag at it. Needs Docker Desktop and ~8 GB free RAM for the build.
#
#   bash deploy/aws/bin/build-and-push.sh && bash deploy/aws/bin/remote.sh deploy
source "$(dirname "$0")/common.sh"

repo=$(stack_output EcrRepositoryUri)
[ -n "$repo" ] || die "stack $APP_STACK has no EcrRepositoryUri output - deploy the app stack first"
sha=$(git -C "$REPO_ROOT" rev-parse HEAD)
tag=${sha:0:12}
[ -z "$(git -C "$REPO_ROOT" status --porcelain)" ] || log "warning: uncommitted changes are included in this build"

aws ecr get-login-password | docker login --username AWS --password-stdin "${repo%%/*}"
docker build "$REPO_ROOT" -f "$REPO_ROOT/Dockerfile" \
  --build-arg BUILD_COMMIT="$sha" \
  --build-arg BUILD_BRANCH="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)" \
  --build-arg BUILD_DATE="$(date -u +%FT%TZ)" \
  -t "$repo:$tag" -t "$repo:latest"
docker push "$repo:$tag"
docker push "$repo:latest"
aws ssm put-parameter --name "/$PROJECT/app/image-tag" --value "$tag" --type String --overwrite >/dev/null
log "pushed $repo:$tag and set /$PROJECT/app/image-tag=$tag"
