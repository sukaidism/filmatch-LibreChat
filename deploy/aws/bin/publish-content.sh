#!/bin/bash
# Upload what the instance pulls at deploy time to the private, versioned content bucket:
#   deploy/     docker-compose.aws.yml + on-instance scripts
#   config/     librechat.filmatch.yaml (theme, model spec, assistant instructions)
#   knowledge/  the five invented Filmatch documents (filmatch-document/*.md)
# Used by GitHub Actions and by hand. S3 versioning keeps every previous copy.
source "$(dirname "$0")/common.sh"

bucket=${CONTENT_BUCKET:-$(content_bucket)}
log "publishing to s3://$bucket"

aws s3 sync --only-show-errors --delete "$AWS_DIR/instance/" "s3://$bucket/deploy/"
aws s3 cp --only-show-errors "$REPO_ROOT/librechat.filmatch.yaml" "s3://$bucket/config/librechat.filmatch.yaml"
aws s3 sync --only-show-errors "$REPO_ROOT/filmatch-document/" "s3://$bucket/knowledge/" --exclude '*' --include '*.md'

aws s3 ls "s3://$bucket/" --recursive --human-readable | sed 's/^/  /'
