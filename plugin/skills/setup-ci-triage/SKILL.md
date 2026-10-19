---
name: setup-ci-triage
description: Set up Claude CI triage in the current repository — failed GitHub Actions checks get fixed and pushed when mechanical, re-run when flaky, and commented on otherwise. Use when asked to add CI triage, auto-fix failing CI, or install andersr/ci-triage in a repo.
---

# Set up CI triage

Installs the reusable workflow at `andersr/ci-triage` into the current repository. Paths
below are relative to this skill's directory. Read `references/traps.md` before starting:
every item in it has failed silently before.

Confirm with the user before each step that changes GitHub: creating an App, an environment,
a secret or a PR. Reads need no confirmation.

## 1. Read the project

- **The checks workflow**: the workflow under `.github/workflows/` that runs on
  `pull_request`. Note its `name:`, its jobs, and which job is fast (lint, format, types, unit
  tests) and which is slow (e2e, builds against services). If there is no single fast job,
  ask which job should dispatch triage, or leave `fast-job` empty and accept triage starting
  only when the whole run completes.
- **Setup**: the runtime and install command its jobs use: Node with a version file, pnpm
  (`packageManager` in `package.json`), Bun, or anything else. A runtime the workflow has no
  input for goes in `install-command` if it is a shell command.
- **The commands Claude will need**: the project's runner as tool patterns, e.g.
  `Bash(bun:*)`, `Bash(pnpm:*)`, `Bash(node:*)`, `Bash(npx:*)`.
- **What this job cannot run**: suites needing databases, services or secrets the triage job
  lacks. These go in `disallowed-tools`, e.g. `Bash(bun run test:e2e:*)`.
- **Git hooks**: husky, lefthook and simple-git-hooks are switched off by the workflow. Any
  other hook tool needs its switch named in `instructions`.
- **CLAUDE.md**: whether it names the project's check commands and what needs a person.
  Ask the user which failures need one (payments, migrations, infrastructure) and add a short
  "CI triage" section if it lacks one. Project specifics go there, not into this repository.

## 2. The App

One App per account or organisation, installed on each repository that uses it.

- **None yet**: run `scripts/create-app.sh <owner> <repo> "<Name> CI Triage"`. It opens a page
  that posts the App's manifest to GitHub. When the user returns with the `code` from the
  address bar, create the environment (step 3) first, then run
  `scripts/finish-app.sh <code> <owner/repo>`, which stores the client id and the key. Send the
  user to the install link it prints, choosing **Only select repositories**.
- **Already exists** (another repository in the same owner uses it): add this repository to
  its installation, `gh api -X PUT user/installations/<installation id>/repositories/<repo id>`.
  Its key cannot be read back, so ask the user to generate a new private key on the App's
  settings page and pass the downloaded file to
  `gh secret set CI_TRIAGE_APP_PRIVATE_KEY --env ci-triage --repo <owner/repo> < <file>`, then
  delete the file. Set `CI_TRIAGE_APP_CLIENT_ID` the same way, with `gh variable set`.

## 3. The environment

The key lives in an environment limited to the default branch, which is the ref both triggers
run on, so no PR branch can read it:

```bash
gh api -X PUT repos/<owner/repo>/environments/ci-triage \
  -F 'deployment_branch_policy[protected_branches]=false' \
  -F 'deployment_branch_policy[custom_branch_policies]=true'
gh api -X POST repos/<owner/repo>/environments/ci-triage/deployment-branch-policies \
  -f name=<default branch> -f type=branch
```

On a private repository this needs a paid GitHub plan. Without one, stop and tell the user:
the fallback is a repository secret, which every branch can read.

`CLAUDE_CODE_OAUTH_TOKEN` (or `ANTHROPIC_API_KEY`) must be a repository secret. If
`gh secret list` lacks both, ask the user to run `claude setup-token` and set the result.

## 4. The files

- Copy `templates/ci-triage.yml` to `.github/workflows/ci-triage.yml`. Fill each `__X__`;
  drop the inputs that do not apply. Pin `__SHA__` to the commit of the latest release tag,
  `gh api repos/andersr/ci-triage/commits/<tag> --jq .sha`, with the tag as `__VERSION__`.
  Keep the secrets passed by name, never `secrets: inherit`, which drops the environment's
  key. If the repository uses `ANTHROPIC_API_KEY`, pass it in place of the OAuth token.
- Add `templates/start-triage-step.yml` as the last step of the fast job, with its
  permissions, carrying over any scope the job already had.
- If the repository documents its CI, add a short section saying triage exists and linking
  `https://github.com/andersr/ci-triage`.

## 5. Verify, then open the PR

Check, and report each:
- the environment exists with the default branch as its only deployment branch;
- `CI_TRIAGE_APP_PRIVATE_KEY` is in it, and neither it nor the client id is at repository level;
- the App's installation covers this repository, with actions, contents and pull requests
  write and no workflows permission (`gh api orgs/<org>/installations`, or
  `gh api user/installations` for a personal account);
- `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` is set.

Then open the PR, following the repository's own branch and commit conventions.

## 6. After it merges

Both triggers run the default branch's copy, so nothing works before merge. Then, with the
user's go-ahead, test with a throwaway PR:

1. Introduce one formatting error, committed and pushed with `--no-verify`.
2. Expect a `workflow_dispatch` triage run within a minute or two of the fast job failing,
   a **🔧 Fixed** comment, and a fix commit authored by `<app-slug>[bot]` whose checks pass.
3. Confirm the completed checks run's `workflow_run` triage skipped Claude rather than
   triaging again.
4. Close the PR and delete its branch.

If a run succeeds with nothing pushed, download its `claude-transcript` artifact and look for
refused tools.
