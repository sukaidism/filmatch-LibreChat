#!/bin/bash
# WS-D #4: check that nothing personal leaves the account.
# Scans (1) the knowledge documents and config sent to Gemini as the system prompt and
# (2) every question logged in the last N hours (these were also sent to Gemini) for
# e-mail addresses, phone numbers, payment-card-like numbers and Philippine IDs.
#
#   bash deploy/aws/bin/pii-check.sh            # last 24 h
#   HOURS=168 bash deploy/aws/bin/pii-check.sh  # last 7 days
source "$(dirname "$0")/common.sh"

HOURS=${HOURS:-24}
PATTERN='[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|(\+?63|0)9[0-9]{2}[ -]?[0-9]{3}[ -]?[0-9]{4}|\b([0-9]{4}[ -]?){3}[0-9]{4}\b|\b[0-9]{4}-[0-9]{7}-[0-9]\b'
hits=0

echo "== 1. Content sent to the model as instructions (repository copy)"
if grep -nEo "$PATTERN" "$REPO_ROOT"/filmatch-document/*.md "$REPO_ROOT/librechat.filmatch.yaml"; then
  hits=1
else
  echo "   no personal-data patterns found"
fi

echo "== 2. Questions logged in /$PROJECT/app in the last $HOURS h"
start=$(( ($(date +%s) - HOURS * 3600) * 1000 ))
questions=$(aws logs filter-log-events --log-group-name "/$PROJECT/app" --start-time "$start" \
  --filter-pattern '{ $.event = "filmatch_chat" }' --query 'events[].message' --output text | tr '\t' '\n')
total=$(printf '%s\n' "$questions" | grep -c filmatch_chat || true)
echo "   $total questions checked"
if printf '%s\n' "$questions" | grep -Eo "\"question\":\"[^\"]*\"" | grep -Eo "$PATTERN"; then
  hits=1
else
  echo "   no personal-data patterns found"
fi

echo "== Result $(date -u +%FT%TZ): $([ $hits -eq 0 ] && echo PASS || echo 'REVIEW THE MATCHES ABOVE')"
exit $hits
