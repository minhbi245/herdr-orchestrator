# Herdr Control

## Preflight and discovery

Skill setup is different from Herdr control: `scripts/install.sh` and `scripts/verify.sh` run from an ordinary shell and only require a usable `herdr --version`. The preflight below remains mandatory before every actual Herdr control action.

Run from a Herdr-managed controller pane:

```bash
test "${HERDR_ENV:-}" = 1
herdr --version
herdr status --json
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
```

Use the installed binary as syntax authority:

```bash
herdr agent --help
herdr pane --help
herdr wait --help
herdr workspace --help
herdr worktree --help
herdr tab --help
```

Do not run bare `herdr` for discovery; it launches or attaches the TUI. Do not probe valid mutating subcommands by omitting arguments.

## IDs and targeting

Treat workspace, tab, pane, and terminal IDs as opaque. Read returned JSON after every create, split, move, start, or list operation.

Prefer `--current` for the caller pane and explicit IDs elsewhere. Omitting a target can resolve to a pane focused by another client.

```bash
herdr pane current --current
herdr pane list --workspace "$HERDR_WORKSPACE_ID"
herdr agent list
```

## Start an interactive worker

Use a descriptive agent target and preserve controller focus:

```bash
herdr agent start auth-scout \
  --cwd "$PWD" \
  --tab "$HERDR_TAB_ID" \
  --split right \
  --no-focus \
  -- codex
```

Replace `codex` with the selected interactive CLI, such as `claude`, `pi`, or `opencode`. Retain the returned agent name, pane ID, terminal ID, workspace ID, and tab ID.

For lower-level layout control:

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
herdr pane split --current --direction right --no-focus
herdr pane rename <returned-pane-id> "auth-scout"
herdr pane run <returned-pane-id> "codex"
```

Use the returned pane ID; never predict it.

## Assign work

Wait until the interactive agent is ready:

```bash
herdr agent get auth-scout
herdr agent wait auth-scout --status idle --timeout 30000
```

Submit the complete prompt:

```bash
herdr pane run <worker-pane-id> '<complete prompt>'
```

`pane run` sends text plus Enter. `agent send` and `pane send-text` write literal text and can leave the prompt unsubmitted.

Pass prompt text as literal data. Avoid `eval`, command substitution, backtick evaluation, and unsafe interpolation.

## Monitor

```bash
herdr agent wait auth-scout --status working --timeout 30000
herdr agent get auth-scout
herdr agent read auth-scout --source recent-unwrapped --lines 160
```

An unseen background completion normally becomes `done`:

```bash
herdr wait agent-status <worker-pane-id> --status done --timeout 120000
```

If the user watches the tab, completion can become `idle`. Inspect `agent get` and accept `idle` or `done` as possible completed states. `done` means completed but unseen; `idle` means ready and considered seen.

If a wait times out, inspect state and output before resending anything:

```bash
herdr agent get auth-scout
herdr agent read auth-scout --source recent-unwrapped --lines 160
herdr agent explain auth-scout --json
```

Status routes attention. Transcript and artifacts provide evidence.

## Follow up and unblock

Read recent output, ground the response, then send it:

```bash
herdr pane run <worker-pane-id> '<verified answer or revised instruction>'
```

Never approve from status alone.

For a real unattended user decision:

```bash
herdr notification show "Agent needs a decision" \
  --body "<short task and blocker>" \
  --sound request
```

Do not include secrets or sensitive transcript content in notifications.

## Commands and services

Use ordinary panes, not agent targets, for tests, servers, logs, and shells:

```bash
herdr pane split --current --direction down --no-focus
herdr pane run <returned-pane-id> "npm test"
herdr wait output <returned-pane-id> --match "test result" --timeout 120000
herdr pane read <returned-pane-id> --source recent-unwrapped --lines 160
```

Inspect existing output before waiting for future output. Timeout means the match was not observed in time, not necessarily command failure.

## Worktree isolation

Create a Herdr-managed worktree for a concurrent writer:

```bash
herdr worktree create \
  --cwd "$PWD" \
  --branch "agent/<descriptive-slug>" \
  --base HEAD \
  --label "<role>" \
  --no-focus \
  --json
```

Read the returned workspace and path. Start the writer in that exact CWD. Never let concurrent writers share one checkout or edit overlapping integration surfaces.

Remove only a task-owned worktree after accepted changes are integrated or intentionally discarded. Never use `--force` without explicit authority and a verified target.

## Integrations and detection

```bash
herdr integration status
```

Install or modify integrations only with user approval because installation writes agent configuration. For Codex and Claude Code, Herdr integrations provide native session identity while screen manifests remain lifecycle-state authority.

Use `agent explain` when state looks wrong. A strict detector may classify an unfamiliar approval screen as idle.

## Persistence and cleanup

Detaching a client leaves panes and agents running. Reattach with `herdr` from outside the managed pane.

Close only task-owned resources after verification. Never stop the Herdr server, delete a session, kill Herdr, close unrelated panes, or force-remove a worktree without explicit user intent.
