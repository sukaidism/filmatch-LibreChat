#!/bin/bash
# WS-D: put every application secret into SSM Parameter Store as a SecureString.
# Run once before the first deploy (and again to rotate the Gemini key).
#
#   bash deploy/aws/bin/put-secrets.sh                 # prompts for the Gemini key (hidden)
#   bash deploy/aws/bin/put-secrets.sh --rotate-gemini # replace only the Gemini key
#
# Generated secrets (CREDS_KEY/IV, JWT_*) are only created if missing: rotating CREDS_KEY would
# make stored encrypted credentials unreadable, rotating JWT_* logs every user out.
source "$(dirname "$0")/common.sh"

P=/$PROJECT/app-env

exists() { aws ssm get-parameter --name "$1" >/dev/null 2>&1; }
put() { # name value type
  aws ssm put-parameter --name "$1" --value "$2" --type "$3" --overwrite \
    --description "Filmatch runtime setting (managed by put-secrets.sh)" >/dev/null
  log "set $1 ($3)"
}
put_if_missing() { exists "$1" && log "kept existing $1" || put "$1" "$2" SecureString; }

if [ "${1:-}" != "--rotate-gemini" ]; then
  put_if_missing "$P/CREDS_KEY" "$(openssl rand -hex 32)"
  put_if_missing "$P/CREDS_IV" "$(openssl rand -hex 16)"
  put_if_missing "$P/JWT_SECRET" "$(openssl rand -hex 32)"
  put_if_missing "$P/JWT_REFRESH_SECRET" "$(openssl rand -hex 32)"
  # Non-secret settings (String). ALLOW_REGISTRATION starts true so you can create the
  # invented test accounts; set it to false afterwards and redeploy.
  exists "$P/GOOGLE_MODELS" || put "$P/GOOGLE_MODELS" "${GOOGLE_MODELS:-gemini-3.5-flash-lite}" String
  exists "$P/ALLOW_REGISTRATION" || put "$P/ALLOW_REGISTRATION" true String
  exists "$P/APP_TITLE" || put "$P/APP_TITLE" Filmatch String
fi

if [ "${1:-}" = "--rotate-gemini" ] || ! exists "$P/GOOGLE_KEY"; then
  read -r -s -p "Paste the Gemini API key (input hidden): " key
  echo
  [ -n "$key" ] || die "empty key"
  put "$P/GOOGLE_KEY" "$key" SecureString
  unset key
fi

log "Parameters under $P (values hidden):"
aws ssm get-parameters-by-path --path "$P" --query 'Parameters[].[Name,Type,LastModifiedDate]' --output table
