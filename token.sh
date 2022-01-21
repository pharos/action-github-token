#!/usr/bin/env bash

set -o pipefail
#set -x

APP_ID=${INPUT_APP_ID:?Usage: ${0}}
APP_PRIVATE_KEY=${INPUT_APP_PRIVATE_KEY:?Usage: ${0}}

APP_PRIVATE_KEY=$(echo -n $APP_PRIVATE_KEY | base64 -d)

API_URL=${GH_API_URL}
REPOSITORY=${INUT_REPOSITORY}
[[ -z "$REPOSITORY" ]] && REPOSITORY=$GITHUB_REPOSITORY
[[ -z "$API_URL" ]] && API_URL=$GITHUB_API_URL

build_payload() {
  local payload_template='{}'
  jq -c \
          --arg iat_str "$(date +%s)" \
          --arg APP_ID "${APP_ID}" \
  '
  ($iat_str | tonumber) as $iat
  | .iat = $iat
  | .exp = ($iat + 300)
  | .iss = ($APP_ID | tonumber)
  ' <<< "${payload_template}" | tr -d '\n'
}

b64enc() { openssl enc -base64 -A | tr '+/' '-_' | tr -d '='; }
json() { jq -c . | LC_CTYPE=C tr -d '\n'; }
rs256_sign() { openssl dgst -binary -sha256 -sign <(printf '%s\n' "$1"); }

jwt_signed() {
  local header='{
      "alg": "RS256",
      "typ": "JWT"
  }'
  local algo="RS256"
  local payload=$(build_payload) || return
  local signed_content="$(json <<<"$header" | b64enc).$(json <<<"$payload" | b64enc)"
  local sig=$(printf %s "$signed_content" | rs256_sign "$APP_PRIVATE_KEY" | b64enc)
  printf '%s.%s\n' "${signed_content}" "${sig}"
}

JWT=$(jwt_signed)
INSTALLATION_ID=$(curl -s \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github.machine-man-preview+json" \
  ${API_URL}/repos/${REPOSITORY}/installation | jq -r .id)

if [ "$INSTALLATION_ID" = "null" ]; then
  echo "Unable to get installation ID. Is the GitHub App installed on ${REPOSITORY}?"
  exit 1
fi

TOKEN=$(curl -s -X POST \
  -H "Authorization: Bearer ${JWT}" \
  -H "Accept: application/vnd.github.machine-man-preview+json" \
  ${API_URL}/app/installations/${INSTALLATION_ID}/access_tokens | jq -r .token)

if [ "$TOKEN" = "null" ]; then
  echo "Unable to generate installation access TOKEN"
  exit 1
fi

echo "::set-output name=token::$TOKEN"