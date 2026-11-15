#!/usr/bin/env bash
# Writes a Play Developer API access token to the file given as $1.
# The service account in PLAY_SERVICE_ACCOUNT_JSON signs a short-lived JWT and
# trades it for an access token (Google's OAuth flow for service accounts); no
# extra API or role is needed. The key exists only in a mode 600 file under
# $RUNNER_TEMP while this runs.
set -euo pipefail
out="$1"
if [ -z "${PLAY_SERVICE_ACCOUNT_JSON:-}" ]; then
  echo "::error::A release needs the PLAY_SERVICE_ACCOUNT_JSON secret"
  exit 1
fi
umask 077
key="$RUNNER_TEMP/play-key.pem"
jq -er .private_key <<< "$PLAY_SERVICE_ACCOUNT_JSON" > "$key"
email="$(jq -er .client_email <<< "$PLAY_SERVICE_ACCOUNT_JSON")"
token_uri="$(jq -er .token_uri <<< "$PLAY_SERVICE_ACCOUNT_JSON")"
b64url() { openssl base64 -A | tr '+/' '-_' | tr -d '='; }
now="$(date +%s)"
header="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)"
claims="$(jq -cn --arg iss "$email" --arg aud "$token_uri" --argjson iat "$now" \
  '{iss: $iss, scope: "https://www.googleapis.com/auth/androidpublisher", aud: $aud,
    iat: $iat, exp: ($iat + 600)}' | b64url)"
signature="$(printf '%s.%s' "$header" "$claims" | openssl dgst -sha256 -sign "$key" | b64url)"
token="$(curl -sS --fail-with-body "$token_uri" \
  --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
  --data-urlencode "assertion=$header.$claims.$signature" | jq -er .access_token)"
echo "::add-mask::$token"
# A file, not a step output: outputs holding a secret are dropped.
printf '%s' "$token" > "$out"
