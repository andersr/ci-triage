#!/usr/bin/env bash
# Exchanges the manifest code for the new App and stores its client id and key in the environment.
# The key goes from GitHub's response to the secret without being printed or written to disk.
# Usage: finish-app.sh <code> <owner/repo> [environment]
set -euo pipefail

code=$1
repo=$2
environment=${3:-ci-triage}

app=$(gh api -X POST "app-manifests/$code/conversions")

gh variable set CI_TRIAGE_APP_CLIENT_ID --env "$environment" --repo "$repo" --body "$(jq -r .client_id <<<"$app")"
jq -r .pem <<<"$app" | gh secret set CI_TRIAGE_APP_PRIVATE_KEY --env "$environment" --repo "$repo"

jq -r '"Created \(.slug). Install it on the repository: \(.html_url)/installations/new"' <<<"$app"
