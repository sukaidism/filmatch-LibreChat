#!/bin/bash
# Shared settings for the laptop / CI helper scripts. Sourced, not executed.
# Override any value by exporting it first, e.g.  AWS_PROFILE=filmatch-admin bash deploy/aws/bin/...
set -euo pipefail

# Git Bash on Windows rewrites arguments that start with "/" into Windows paths, which breaks
# SSM parameter names such as /filmatch/app-env. Turn that off.
export MSYS_NO_PATHCONV=1
export MSYS2_ARG_CONV_EXCL='*'

export AWS_REGION=${AWS_REGION:-ap-southeast-2}
export AWS_DEFAULT_REGION=$AWS_REGION
export AWS_PAGER=''
PROJECT=${PROJECT:-filmatch}
APP_STACK=${APP_STACK:-$PROJECT-app}
BASELINE_STACK=${BASELINE_STACK:-$PROJECT-account-baseline}

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
AWS_DIR=$REPO_ROOT/deploy/aws

log() { echo "$(date -u +%H:%M:%S) $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

account_id() { aws sts get-caller-identity --query Account --output text; }
content_bucket() { echo "$PROJECT-content-$(account_id)-$AWS_REGION"; }
stack_output() { # key
  aws cloudformation describe-stacks --stack-name "$APP_STACK" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

# JSON-escape a string without jq (Git Bash on Windows rarely has jq).
json_escape() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
