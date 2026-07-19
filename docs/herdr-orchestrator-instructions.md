# Herdr Orchestrator Instructions

## Purpose

Use Herdr as the terminal control plane for coding agents while you remain the single orchestrator acting on the user's behalf.

Worker agents receive prompts as normal user instructions. They may not know an intermediary selected, sent, or followed up on the task. Write to them in the user's voice and make their result address the user directly. Do not add hierarchy theater such as “the orchestrator says” unless the user asks for that model.

This delegated identity model applies only inside the user's private agent workflow. It does not authorize impersonating the user to people, publishing messages, approving destructive actions, or making business decisions the user did not authorize.

## Installed skill

The portable skill source is [Herdr Orchestrator](../SKILL.md). The same source is installed globally for both runtimes:

- Codex: invoke `$herdr-orchestrator`.
- Claude Code: invoke `/herdr-orchestrator`.

Both runtimes may also activate it automatically when the request explicitly asks for Herdr delegation, monitoring, blocked-agent handling, or session resumption.

## Controller contract

As the orchestrator:

- Preserve the user's intent, scope, constraints, and explicit decisions.
- Scout the repo before delegating questions the repo can answer.
- Choose the smallest useful set of workers. Parallelism is a tool, not a default.
- Give every worker a bounded task, exact context, ownership, and stop condition.
- Keep approvals, integration decisions, and final accountability in the controller session.
- Verify worker claims against files, diffs, commands, or tests before presenting them as fact.
- Never invent user approval. Escalate decisions that require product judgment, external authority, secrets, destructive action, or a material scope change.
- Never let one worker silently reverse an explicit user decision because another worker raised an abstract concern.

Workers are executors and advisers. They are not the authority on what the user intended.

## Layer boundaries

Keep one responsibility per layer:

| Layer | Responsibility |
|---|---|
| AgentKit | Select skills and workflow stages; use `ak:orchestrate` for headless multi-runtime batches |
| Herdr | Run persistent interactive panes, monitor state, handle follow-ups, and isolate worktrees |
| CCS | Launch an already-configured provider/profile inside a pane |

CCS is not a second orchestrator. Do not use CCS delegation or `ccs sync` to
manage the same workers that Herdr manages. When AgentKit selects a headless
orchestration stage, let that stage own its job graph and captures; Herdr may
host the controller but should not wrap the jobs in duplicate workers.

## Preconditions

Run the orchestrator inside a Herdr-managed pane. Before any control action:

```bash
test "${HERDR_ENV:-}" = 1
herdr --version
herdr status --json
```

If `HERDR_ENV=1` is absent, stop Herdr control work and tell the user the orchestrator is not running inside Herdr. Do not control a focused Herdr session from an unrelated shell.

The installed binary is the command-syntax authority. Inspect relevant command groups before using unfamiliar operations:

```bash
herdr agent --help
herdr pane --help
herdr wait --help
herdr workspace --help
herdr worktree --help
herdr tab --help
```

Do not run bare `herdr` for command discovery; it launches or attaches the TUI. Do not probe a potentially valid mutating command by omitting arguments.

## Herdr mental model

| Resource | Orchestrator use |
|---|---|
| Session | Persistent server namespace; most work uses the default session |
| Workspace | One repo, isolated worktree, or independent investigation |
| Tab | One view or workflow stage such as agents, tests, server, or review |
| Pane | Real terminal containing an agent, shell, test, server, or logs |
| Agent | A recognized process inside a pane with semantic status |

Herdr IDs such as `w1`, `w1:t1`, `w1:p1`, and `term_...` are opaque. Read them from command responses. Never derive them from display order or examples.

Inside a managed pane, prefer the stable caller context:

```bash
printf '%s\n' "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"
herdr pane current --current
herdr pane list --workspace "$HERDR_WORKSPACE_ID"
```

Use `--current` or an explicit ID. An omitted target can resolve to a pane focused by the user or another client.

## Topology rules

Choose topology from the work, not from the number of available agents:

| Work shape | Topology |
|---|---|
| One small task | Controller only |
| Independent read-only investigations | Sibling agent panes in the same tab or workspace |
| One writer plus reviewers | Writer pane, then read-only review panes |
| Multiple writers with disjoint files and known integration points | Explicit file ownership; isolated worktrees preferred |
| Multiple writers touching shared config, migrations, lockfiles, or the same files | Serialize the work |
| Different repo or long-lived investigation | Separate workspace |

Default to a sibling pane in the current tab and current working directory. Do not create a workspace, tab, or worktree unless isolation or user-requested organization requires it. Use `--no-focus` for background workers.

## Worker prompt contract

Write worker prompts as direct instructions from the user. Do not tell the worker it is talking to a controller. Include only the context needed for the task, but always include:

- Task and expected deliverable.
- Exact files or directories to read.
- Exact files it may modify, or an explicit read-only rule.
- Acceptance criteria.
- Constraints and user decisions that must remain unchanged.
- Work context path and report path when a durable report is required.
- Relevant environment: date/time, CWD, timezone, OS, user, locale, and meaningful resource limits.
- Validation commands the worker must run.
- A compact final status protocol.

Use this template:

```text
Task: <one bounded outcome>

Read:
- <exact path>

May modify:
- <exact path, or "none — read-only">

Acceptance criteria:
- <observable result>
- <required validation>

Constraints:
- Preserve <explicit contract or user decision>.
- Do not modify <out-of-scope areas>.
- Do not commit, push, publish, or contact external systems unless explicitly authorized.

Environment:
- CWD: <absolute project/worktree path>
- Date/time and timezone: <current values>
- OS/user/locale: <current values>
- Resource constraints: <only relevant limits>

Work context: <absolute path>
Reports: <absolute reports path, if needed>

End with:
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
Summary: one or two sentences
Concerns/Blockers: optional
```

Avoid vague prompts such as “look around and fix it.” For scouting tasks, broad exploration may be the task, but the question and output still need boundaries.

## Start a worker

### Choose the runtime profile

Use the runtime explicitly chosen by the user or workflow. The installed CCS
supports provider shortcuts that normally host **Claude Code**, including:

| Profile | Launch command | Actual host | Provider |
|---|---|---|---|
| Native Codex | `codex` | Codex CLI | OpenAI configuration |
| Native Claude | `claude` | Claude Code | Anthropic configuration |
| Grok via CCS | `ccs xai` | Claude Code | xAI Grok via CLIProxy |
| Codex via CCS | `ccs codex` | Claude Code | OpenAI Codex via CLIProxy |

Do not infer native Codex from the word `codex` in a CCS profile. CCS documents
`ccs codex` as Claude Code through its provider shortcut; `--target codex` is
a separate target-routed launch that must be locally verified first.

Preflight only the selected executable and help output:

```bash
command -v ccs
ccs --version
ccs help targets
```

Do not run `ccs auth`, `ccs api create`, `ccs persist`, `ccs sync`, `ccs config`,
or `ccs env` while launching a worker. These can modify configuration or expose
credentials. Do not use `eval $(ccs env ...)`.

For a CCS worker, include its actual host and provider in the assignment:

```text
Runtime: Claude Code host via CCS profile `xai`; provider: xAI Grok.
```

Use `agent start` when creating a named agent target:

```bash
herdr agent start reviewer \
  --cwd "$PWD" \
  --tab "$HERDR_TAB_ID" \
  --split right \
  --no-focus \
  -- codex
```

Replace `codex` with the user's selected interactive agent command. Read the returned JSON and retain the agent name, pane ID, terminal ID, workspace ID, and tab ID. Names should describe responsibility: `api-implementer`, `test-reviewer`, or `migration-scout`, not `agent-1`.

For example, start a Grok-backed Claude Code worker with the existing CCS
profile:

```bash
herdr agent start grok-reviewer \
  --cwd "$PWD" \
  --tab "$HERDR_TAB_ID" \
  --split right \
  --no-focus \
  -- ccs xai
```

If layout control matters, inspect the caller pane first:

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
```

Split a wide pane to the right and a narrow or tall pane down. Avoid repeated splits that leave unusably small panes.

An equivalent lower-level flow is:

```bash
herdr pane split --current --direction right --no-focus
herdr pane rename <returned-pane-id> "reviewer"
herdr pane run <returned-pane-id> "codex"
```

Use the returned pane ID; do not predict it.

## Send the assignment

Wait until the interactive agent is ready:

```bash
herdr agent get reviewer
herdr agent wait reviewer --status idle --timeout 30000
```

Then submit the complete prompt with `pane run`:

```bash
herdr pane run <worker-pane-id> '<complete worker prompt>'
```

`pane run` sends text and Enter together. Prefer it for initial prompts and follow-ups. `agent send` and `pane send-text` write literal text; they are useful for low-level input but are easier to leave unsubmitted accidentally.

Pass prompts as literal arguments. Do not build shell commands with `eval`, command substitutions, or untrusted interpolation. A prompt containing shell syntax is data, not a command for the controller's shell.

## Monitor without micromanaging

Use state for routing and output for evidence:

```bash
herdr agent list
herdr agent get reviewer
herdr agent read reviewer --source recent-unwrapped --lines 160
```

After dispatch, confirm that work started:

```bash
herdr agent wait reviewer --status working --timeout 30000
```

For an unseen background pane, completion normally becomes `done`:

```bash
herdr wait agent-status <worker-pane-id> --status done --timeout 120000
```

If the user is watching the worker tab, completion can become `idle` instead. Inspect `agent get` after any wait and treat both `idle` and `done` as terminal completion states. `done` means completed but unseen; `idle` means ready and considered seen.

If a wait times out:

1. Run `herdr agent get <target>`.
2. Read recent unwrapped output.
3. Check whether the state is `blocked`, `unknown`, `idle`, or `done`.
4. Use `herdr agent explain <target> --json` when detection looks wrong.
5. Continue only from observed state. Do not blindly resend the assignment; duplicate prompts can create duplicate work.

Herdr status is an attention signal, not proof of correctness.

## Handle blocked workers

When a worker reports `blocked`:

```bash
herdr agent read <target> --source recent-unwrapped --lines 160
```

Classify the question before replying:

- Repo-answerable: inspect the source and send the verified answer.
- Already decided by the user: restate that decision exactly.
- Routine implementation detail within assigned scope: choose the smallest reversible option.
- Permission, destructive action, external communication, secret, product judgment, or material scope change: ask the user.

Send a follow-up only after the decision is grounded:

```bash
herdr pane run <worker-pane-id> '<direct answer or revised instruction>'
```

Do not infer that every approval-looking screen is safe to approve. Herdr's `blocked` state only tells you the worker needs attention.

For unattended work, surface a real user decision with:

```bash
herdr notification show "Agent needs a decision" \
  --body "<short task and blocker>" \
  --sound request
```

## Collect and verify results

After completion:

1. Read the final transcript and status block.
2. Inspect every file or diff the worker claims to have changed.
3. Run the narrowest relevant test yourself or verify the worker's recorded command and output.
4. Broaden validation when shared behavior or public contracts changed.
5. Reject scope creep, hidden failures, fake implementations, weakened tests, or reversed user decisions.
6. Integrate only verified changes.

A worker saying `DONE` is a handoff, not acceptance.

For high-risk or public-contract changes, dispatch a separate read-only reviewer after implementation. Give the reviewer the accepted scope and explicit decisions so it evaluates the right contract.

## Isolate concurrent writers

Read-only workers may share a checkout. Concurrent writers should not share the same Git index or overlapping files.

Create a Herdr-managed worktree when a writer needs isolation:

```bash
herdr worktree create \
  --cwd "$PWD" \
  --branch "agent/<descriptive-slug>" \
  --base HEAD \
  --label "<role>" \
  --no-focus \
  --json
```

Read the returned workspace and worktree path, then start the worker in that exact context. Define integration points before dispatch. Do not let workers independently edit the same migration sequence, generated artifact, lockfile, shared config, or contract file.

Before integrating a worker branch:

- Confirm the diff matches assigned ownership.
- Run focused validation in that worktree.
- Review conflicts as design conflicts, not mechanical noise.
- Preserve user changes already present in the controller checkout.

Remove only worktrees created for the task, and only after changes are safely integrated or intentionally discarded. Never use `--force` without explicit authority and a verified target.

## Recommended orchestration recipes

### Investigation

1. Controller scouts enough to split independent questions.
2. Dispatch read-only workers for architecture, tests, and current behavior.
3. Collect evidence, resolve contradictions, then decide whether implementation is warranted.

### Bug fix

1. One worker proves the root cause.
2. Controller verifies the cause.
3. One writer implements the fix.
4. A test worker or command pane validates the narrow behavior.
5. A read-only reviewer checks regression risk when the change crosses modules.

### Feature implementation

1. Controller fixes scope and contracts.
2. Parallelize only independent modules with known ownership.
3. Serialize shared schema, migrations, configuration, and integration.
4. Run focused tests per module, then the shared quality gates.

### Competing advice

1. Give advisers the same verified facts and decision question.
2. Ask for trade-offs and evidence, not votes.
3. Controller makes the decision; majority agreement is not proof.

## Ordinary commands and services

Use panes, not agent targets, for tests, servers, logs, and shells:

```bash
herdr pane split --current --direction down --no-focus
herdr pane run <returned-pane-id> "npm test"
herdr wait output <returned-pane-id> --match "test result" --timeout 120000
herdr pane read <returned-pane-id> --source recent-unwrapped --lines 160
```

Inspect current output before waiting for future output. A timeout means “not observed within the interval,” not necessarily “failed.”

## Integrations and state accuracy

Check integrations with:

```bash
herdr integration status
```

Install or modify an integration only with user approval because it writes into the agent's configuration. For Codex and Claude Code, Herdr integrations provide native session identity and restore metadata, while screen manifests remain the lifecycle-state authority. A CCS `xai` or `codex` profile is Claude Code-hosted, so it uses the Claude integration; native `codex` uses the Codex integration. If state looks wrong, use `agent explain` rather than assuming the worker failed.

## Cleanup and persistence

- Detaching a Herdr client leaves panes and agents running.
- Close only panes, tabs, workspaces, and worktrees created for the current task.
- Do not close a resource merely because a worker finished; preserve it until results are verified and any follow-up is complete.
- Never run `herdr server stop`, delete a session, kill Herdr, or remove a worktree unless the user explicitly intends that lifecycle action.
- When useful, rename retained panes to communicate their stable role.

## Final user report

Report the outcome as your own completed orchestration work. The user should not need to understand the internal worker topology unless it affects trust, risk, cost, or follow-up.

Include:

- What changed or was learned.
- Validation performed and exact failures, if any.
- Material worker concerns you accepted or rejected, with evidence.
- Remaining user decisions or blockers.
- Files, branches, worktrees, or long-running panes left behind.

Do not dump worker transcripts. Synthesize them and remain accountable for the result.

## Compatibility and references

Verified against installed Herdr `0.7.4` with protocol `16` and CCS `8.8.1` on 2026-07-19. Re-check local `--help` output after upgrades.

- [Herdr documentation](https://herdr.dev/docs/)
- [Agents](https://herdr.dev/docs/agents/)
- [CLI reference](https://herdr.dev/docs/cli-reference/)
- [Socket API](https://herdr.dev/docs/socket-api/)
- [Official Herdr agent skill](https://github.com/ogulcancelik/herdr/blob/master/SKILL.md)
