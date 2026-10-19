# Traps

Each of these fails quietly. Check every one when setting up a repository.

| Trap | Symptom | What prevents it |
| --- | --- | --- |
| A push made with `GITHUB_TOKEN` starts no workflow | The fix lands and its checks never run | Push with the App's installation token |
| A pre-push hook runs the whole suite | Claude commits, the push hangs until the job ends, and nothing reaches the branch | The workflow sets `HUSKY=0`, `LEFTHOOK=0`, `SKIP_SIMPLE_GIT_HOOKS=1` and pushes with `--no-verify`. A hook tool not on that list needs its own switch in `instructions` |
| claude-code-action refuses bot actors | The dispatched run fails in seconds: "Workflow initiated by non-human actor" | `allowed_bots: github-actions[bot],github-actions` (set in the workflow) |
| The commit author defaults to `github-actions[bot]` | Fixes look like any other Actions job | `bot_name` and `bot_id`, looked up from the App's token (set in the workflow) |
| A tool outside `--allowedTools` is refused silently | The run succeeds with nothing pushed; the log's final result shows `permission_denials_count` above 0 | Add the project's runner (`Bash(bun:*)`, `Bash(pnpm:*)`) to `allowed-tools`. Read the `claude-transcript` artifact to see what was refused |
| `workflow_run` and `workflow_dispatch` run the default branch's copy | Nothing can be tested before the caller workflow merges | Merge, then test with a throwaway PR |
| The App has no Workflows permission | A fix touching `.github/workflows/` is refused on push | Deliberate. Such failures are classed as needing a person |
| An environment secret is readable only from its environment | The token step fails: no private key | Create the environment in the calling repository, and limit it to the default branch |
| A `permissions` block sets every omitted scope to none | Adding `actions: write` to the fast job breaks a step that needed another scope | Carry over every scope the job already used |
| Closing and reopening a throwaway PR | Per-PR preview resources with fixed names can fail to recreate | Push to the open PR rather than reopening it |
| A push to a closed PR | No checks run, so nothing is triaged | Reopen it, or use a new PR |
