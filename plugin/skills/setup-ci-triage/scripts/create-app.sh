#!/usr/bin/env bash
# Opens GitHub's create-App page with the triage App's name and permissions filled in.
# Usage: create-app.sh <owner> <repo> <app-name>
set -euo pipefail

owner=$1
repo=$2
name=$3
url="https://github.com/$owner/$repo"

if [ "$(gh api "users/$owner" --jq .type)" = Organization ]; then
  action="https://github.com/organizations/$owner/settings/apps/new"
else
  action="https://github.com/settings/apps/new"
fi

# No Workflows permission, deliberately: the App cannot change CI, this workflow included.
manifest=$(jq -n --arg name "$name" --arg url "$url" '{
  name: $name,
  url: $url,
  redirect_url: $url,
  public: false,
  hook_attributes: { url: $url, active: false },
  default_events: [],
  default_permissions: { actions: "write", contents: "write", pull_requests: "write", metadata: "read" }
}')

page="$(mktemp -d)/create-ci-triage-app.html"
cat > "$page" <<EOF
<!doctype html>
<meta charset="utf-8">
<title>Create the CI triage App</title>
<form method="post" action="$action">
  <input type="hidden" name="manifest" value="$(jq -r @html <<<"$manifest")">
  <p>Creates the private GitHub App <b>$(jq -rn --arg n "$name" '$n | @html')</b> under <b>$owner</b>,
  with Actions, Contents and Pull requests write, no Workflows, and no webhook.</p>
  <p>After you confirm on GitHub, it returns you to the repository with <code>?code=…</code>
  in the address bar. Copy that code back to Claude; it expires in an hour.</p>
  <button>Continue to GitHub</button>
</form>
EOF

if command -v open >/dev/null; then open "$page"; else xdg-open "$page"; fi
echo "$page"
