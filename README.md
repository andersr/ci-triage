# ci-triage

A reusable GitHub Actions workflow that hands failed checks to Claude. Each failure gets one
of five outcomes, reported in a single PR comment, or a commit comment when there is no PR:

| Outcome | When | What happens |
| --- | --- | --- |
| **🔧 Fixed** | mechanical: formatting, an autofixable lint finding, an unused export, a small type error | one commit pushed to the branch |
| **🧩 Fix proposed** | mechanical, on a branch listed in `diagnose-only-branches` | nothing pushed; the fix posted as a diff |
| **🔁 Re-ran** | infrastructure: a runner timeout, an image pull, a network error | the failed jobs re-run once |
| **💬 Needs discussion** | a decision: changed behaviour, design, end-to-end, secrets, deployment, CI | nothing changed; the question asked |
| **🛑 Fix failed** | its own fix or re-run failed again | nothing changed; what it tried |

Fixes are pushed as a GitHub App, so the fix's own checks run. A run started by the App's
push or re-run only diagnoses, so each push of yours buys at most one fix attempt.

**Each PR gets one triage comment, updated in place.** A later failure replaces the report
at the top and moves the previous one into a collapsed "Earlier reports" section, keeping
the last five. A bot that rebases its branch on every change to the default branch would
otherwise add a comment each time. An edit sends no notification, so watch the PR's checks
rather than your inbox for a repeat failure.

## Setting it up

With Claude Code, in the repository:

```text
/plugin marketplace add andersr/ci-triage
/plugin install ci-triage@ci-triage
/setup-ci-triage
```

The skill reads the repository's CI, writes the two files, creates the App from a manifest
and the environment that holds its key, checks the result and opens a PR. Its procedure is
[SKILL.md](plugin/skills/setup-ci-triage/SKILL.md).

By hand, a repository needs:

1. **A GitHub App** under the repository's owner, installed on the repository, with
   Actions, Contents and Pull requests read and write, and no webhook. No Workflows
   permission: without it the App cannot change CI, this workflow included.
2. **An environment**, `ci-triage` by default, whose deployment branches are the default
   branch alone. It holds the variable `CI_TRIAGE_APP_CLIENT_ID` and the secret
   `CI_TRIAGE_APP_PRIVATE_KEY`. On a private repository, environment branch policies need a
   paid GitHub plan.
3. **A repository secret** `CLAUDE_CODE_OAUTH_TOKEN` (from `claude setup-token`) or
   `ANTHROPIC_API_KEY`.
4. **[`ci-triage.yml`](plugin/skills/setup-ci-triage/templates/ci-triage.yml)** in
   `.github/workflows/`, which calls this workflow. It passes the secrets by name:
   `secrets: inherit` does not carry one that exists only in an environment. A project
   using `ANTHROPIC_API_KEY` passes that instead of `CLAUDE_CODE_OAUTH_TOKEN`.
5. **[The dispatch step](plugin/skills/setup-ci-triage/templates/start-triage-step.yml)** at
   the end of the checks workflow's fast job, so triage starts when lint or unit tests fail
   rather than after the slowest job.

Both triggers run the default branch's copy, so it works only once merged.

## Inputs

| Input | Default | Purpose |
| --- | --- | --- |
| `run-id` | required | The failed checks run |
| `branch` | required | Its branch, for the concurrency group |
| `environment` | `ci-triage` | The environment holding the App's key |
| `fast-job` | | Part of the name of the job that dispatches triage; a completed run whose fast job failed is skipped as already triaged |
| `node-version-file` | | Set up Node from this file |
| `pnpm` | `false` | Set up pnpm from `packageManager` |
| `bun-version` | | Set up Bun at this version |
| `install-command` | | Installs dependencies |
| `allowed-tools` | | Tool patterns beyond the defaults, e.g. `Bash(bun:*)` |
| `disallowed-tools` | | Tool patterns refused, e.g. a suite the job cannot run |
| `instructions` | | Project notes added to the prompt |
| `diagnose-only-branches` | | Branch prefixes, comma-separated, where triage proposes a fix rather than pushing it, e.g. `renovate/,dependabot/`. A dependency bot stops updating a branch once someone else commits to it |

Everything project-specific (which commands verify a fix, which failures need a person)
belongs in the repository's own `CLAUDE.md`, which Claude reads first.

## What it can reach

- **The key is readable from the default branch alone**, through the environment's branch
  policy, since both triggers run the default branch's copy of the workflow.
- **Same-repository branches only.** A fork's branch would run its own code with the token
  present, so the job stops for one.
- **A branch's own code runs with the token present**: its install and the checks Claude
  re-runs. That is the trust `pull_request` already gives every branch that can push.
- **It never pushes to the default branch.** A failure there gets a `ci-fix-<sha>` branch and
  a PR.
- **A stale failure is skipped**: one whose branch has moved on already has a newer run.

## Debugging a run

The action hides Claude's transcript from the log. Each run uploads it as the
`claude-transcript` artifact, kept for seven days. A non-zero `permission_denials_count` in
the log's final result means a command fell outside the allowed tools.
[`traps.md`](plugin/skills/setup-ci-triage/references/traps.md) lists every failure seen so
far, each of which was silent.

## Versions

Pin the workflow to a release's commit SHA, with the tag as a comment, as for any action.
