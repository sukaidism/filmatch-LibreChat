#!/bin/bash
# Create or update a CloudFormation stack.
#
#   ALERT_EMAIL=you@example.com bash deploy/aws/bin/deploy-stack.sh baseline
#   ALERT_EMAIL=you@example.com GITHUB_REPO=owner/repo bash deploy/aws/bin/deploy-stack.sh app
#
# Optional: TEAM (tag), INSTANCE_TYPE, BUDGET_USD, CREATE_TRAIL=false, ENABLE_GUARDDUTY=true,
#           CREATE_OPERATORS_GROUP=false (if an organisation SCP denies iam:CreateGroup),
#           CREATE_OIDC=false (if the GitHub OIDC provider already exists in the account)
source "$(dirname "$0")/common.sh"

which=${1:-}
: "${ALERT_EMAIL:?set ALERT_EMAIL to the inbox that should receive alerts}"
TEAM=${TEAM:-filmatch-team}
TAGS=(Project=SAM10 "Team=$TEAM" Application="$PROJECT")

case "$which" in
baseline)
  aws cloudformation deploy \
    --stack-name "$BASELINE_STACK" \
    --template-file "$AWS_DIR/cloudformation/filmatch-account-baseline.yaml" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset \
    --tags "${TAGS[@]}" \
    --parameter-overrides \
      ProjectName="$PROJECT" AlertEmail="$ALERT_EMAIL" \
      MonthlyBudgetUSD="${BUDGET_USD:-25}" \
      CreateCloudTrail="${CREATE_TRAIL:-true}" EnableGuardDuty="${ENABLE_GUARDDUTY:-false}" \
      CreateOperatorsGroup="${CREATE_OPERATORS_GROUP:-true}"
  aws cloudformation describe-stacks --stack-name "$BASELINE_STACK" --query 'Stacks[0].Outputs' --output table
  ;;
app)
  pl=$(aws ec2 describe-managed-prefix-lists \
    --filters Name=prefix-list-name,Values=com.amazonaws.global.cloudfront.origin-facing \
    --query 'PrefixLists[0].PrefixListId' --output text)
  [[ $pl == pl-* ]] || die "could not find the CloudFront origin-facing prefix list in $AWS_REGION"
  log "CloudFront prefix list: $pl"
  log "deploying $APP_STACK in $AWS_REGION (first run takes ~10 min: CloudFront)"
  aws cloudformation deploy \
    --stack-name "$APP_STACK" \
    --template-file "$AWS_DIR/cloudformation/filmatch-app.yaml" \
    --capabilities CAPABILITY_NAMED_IAM \
    --no-fail-on-empty-changeset \
    --tags "${TAGS[@]}" \
    --parameter-overrides \
      ProjectName="$PROJECT" AlertEmail="$ALERT_EMAIL" \
      CloudFrontPrefixListId="$pl" \
      GitHubRepo="${GITHUB_REPO:-}" \
      CreateGitHubOidcProvider="${CREATE_OIDC:-true}" \
      InstanceType="${INSTANCE_TYPE:-t3.medium}"
  aws cloudformation describe-stacks --stack-name "$APP_STACK" --query 'Stacks[0].Outputs' --output table
  log "Confirm the 'AWS Notification - Subscription Confirmation' email or alarms will not reach you."
  ;;
*)
  echo "usage: deploy-stack.sh baseline|app" >&2
  exit 2
  ;;
esac
