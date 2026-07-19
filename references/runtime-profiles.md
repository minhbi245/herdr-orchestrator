# Runtime Profiles

## Layer boundaries

Keep one responsibility per layer:

| Layer | Owns | Does not own |
|---|---|---|
| AgentKit | Skills, workflow routing, headless job graphs | Interactive pane lifecycle |
| Herdr | Persistent panes, prompts, state, follow-ups, worktrees | Provider credentials or model routing policy |
| CCS | Existing profile/provider selection and target launch | Delegation, task ownership, pane control |

Use `ak:orchestrate` for a repeatable headless multi-runtime stage. Do not
wrap that stage in separately dispatched Herdr workers. Herdr may host the
controller process, but the selected stage owns its own lifecycle.

## Available launch shapes

Select a profile only when the user or the already-selected workflow specifies
it. Probe the selected executable without mutating configuration:

```bash
command -v codex
command -v claude
command -v ccs
ccs --version
ccs help targets
```

| Profile | Herdr launch command | Host CLI | Provider identity |
|---|---|---|---|
| `codex-native` | `codex` | Codex | OpenAI Codex account/configuration |
| `claude-native` | `claude` | Claude Code | Anthropic account/configuration |
| `ccs-xai-claude` | `ccs xai` | Claude Code | xAI Grok through CCS/CLIProxy |
| `ccs-codex-claude` | `ccs codex` | Claude Code | OpenAI Codex through CCS/CLIProxy |

For example, use an explicit profile command after the `--` separator:

```bash
herdr agent start grok-reviewer \
  --cwd "$PWD" \
  --tab "$HERDR_TAB_ID" \
  --split right \
  --no-focus \
  -- ccs xai
```

CCS also supports `--target claude|droid|codex`. Treat a target-routed launch
as a separate profile: verify its local CCS help and the target executable
before use. Do not assume that a profile named `codex` launches native Codex;
without `--target codex`, CCS documents `ccs codex` as Claude Code through its
provider shortcut.

## Prompt attribution

For every CCS worker, add a short runtime line to the worker prompt:

```text
Runtime: Claude Code host via CCS profile `xai`; provider: xAI Grok.
```

For a native worker, name only the actual host:

```text
Runtime: native Codex CLI.
```

This attribution is operational context, not an authority grant. Keep the
same scope, approval, secret-handling, and final-status requirements for every
profile.

## State and integrations

Use the host CLI to choose a Herdr integration, not the CCS provider:

- A `ccs xai` or `ccs codex` worker is Claude Code-hosted, so the optional
  Herdr Claude integration is the relevant one.
- A native `codex` worker uses the optional Herdr Codex integration.

Installing an integration writes into the host agent's configuration. Require
explicit user approval, then inspect `herdr integration status` afterwards.
Screen manifests remain lifecycle-state authority. When a wrapper or profile
causes an unexpected state, read the transcript and run:

```bash
herdr agent explain <target> --json
```

## Safety boundaries

- Do not run `ccs auth`, `ccs api create`, `ccs cliproxy create`, `ccs persist`,
  `ccs sync`, or `ccs config` while dispatching a worker.
- Do not use `ccs env` or `eval $(ccs env ...)`; they can expose credential
  material to the shell, process list, pane transcript, or controller output.
- Do not add unattended or permission-bypass flags through CCS or its hosted
  CLI without explicit user approval for that run.
- Never report a provider/model identity as verified unless the launched CLI
  confirms it in its own safe output.
