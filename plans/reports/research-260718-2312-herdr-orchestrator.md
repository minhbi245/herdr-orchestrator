---
type: research
title: Herdr Orchestrator Research
created: 2026-07-18T23:12:50+07:00
status: complete
---

# Research Report: Herdr as a Coding-Agent Orchestrator

## Summary

Herdr is a persistent terminal multiplexer with an agent-aware control plane. Its CLI can create and organize terminals, start named agent processes, inject prompts, read transcripts, wait on semantic states, manage worktrees, and notify the user. This makes it suitable as an execution layer beneath a controller agent.

Recommended model: one controller acts for the user; worker agents receive direct user-style prompts and answer the user, without needing orchestration metadata. The controller retains authority over scope, approvals, integration, and final verification. This identity model is appropriate for private coding agents but must not become authority to impersonate the user to people or external systems.

The resulting reusable instructions are in [Herdr Orchestrator Instructions](../../docs/herdr-orchestrator-instructions.md).

## Contents

- [Research scope](#research-scope)
- [Environment findings](#environment-findings)
- [Key findings](#key-findings)
- [Recommended control loop](#recommended-control-loop)
- [Risks and mitigations](#risks-and-mitigations)
- [Sources](#sources)
- [Unresolved questions](#unresolved-questions)

## Research scope

- Research date: 2026-07-18, Asia/Ho_Chi_Minh.
- Target: installed Herdr CLI plus current official documentation and repository source.
- Focus: orchestration, agent lifecycle, prompt delivery, status monitoring, worktree isolation, persistence, and delegated identity.
- Excluded: installing integrations, starting a live session, mutating user config, destructive lifecycle operations, and benchmarking.

Method:

- Inspected installed CLI help for all primary command groups.
- Inspected version, protocol, channel, config validation, integration status, session list, default config, and bundled API schema summary.
- Cross-checked official Agents, CLI, Socket API, Concepts, Quick Start, and Agent Skill documentation.
- Cloned and packed the official repository at commit `02a6e874f67800891b5a549297219ed6f3ce0f2f`; read the upstream `SKILL.md` and `website/agent-guide.md`.

## Environment findings

| Item | Observed value |
|---|---|
| Binary | `/Users/leonguyen/.local/bin/herdr` |
| Version | `0.7.4` |
| Channel | `stable` |
| Socket protocol | `16` |
| Config | valid |
| Default session | present, not running |
| Server | not running during research |
| Integrations | none installed |
| Config path | `/Users/leonguyen/.config/herdr/config.toml` |
| Logs | `/Users/leonguyen/.config/herdr/herdr.log` plus client/server logs |

Because the server was not running, `herdr api snapshot` correctly failed with a missing socket. No session was started solely for research.

## Key findings

### CLI is the right orchestration layer

Herdr recommends CLI wrappers for shell scripts, simple orchestration, and human debugging. The raw socket API is appropriate only for custom protocol clients or long-lived event subscriptions. Most CLI control responses are JSON, so orchestration should retain returned IDs rather than predict them.

### The resource hierarchy supports clean ownership

The hierarchy is session → workspace → tab → pane → agent. Workspaces fit repos or isolated investigations; tabs fit workflow views; panes hold real processes. Agent state rolls upward for attention management.

### Prompt delivery must include Enter

`herdr pane run <pane> <text>` writes text and submits it with Enter. `agent send` and `pane send-text` are literal input operations. Controller prompts and follow-ups should therefore use `pane run` unless low-level input is intentional.

### State is useful but not authoritative proof

Agent states include `working`, `blocked`, `done`, `idle`, and `unknown`. `done` and `idle` share a semantic ready state but differ by whether completion is unseen. Foreground visibility can turn completion into `idle`, so a controller must accept either after inspecting the live record.

Screen-manifest blocked detection is intentionally strict and may classify an unfamiliar prompt as idle. `herdr agent explain` exists to diagnose detection. A timeout or state label must never replace transcript inspection.

### Integrations have agent-specific authority

Integrations improve state or session reporting, but their authority differs. Codex and Claude Code integrations provide native session identity; screen detection remains their lifecycle-state authority. Integration installation writes agent configuration and should require user approval.

### Persistence changes cleanup behavior

Herdr's server owns the panes. Detaching a client does not stop agents. The controller should leave useful panes running until verification completes and close only resources it created. `server stop`, session deletion, forced worktree removal, and broad cleanup are materially destructive lifecycle actions.

### Worktrees are the safest multi-writer boundary

Read-only agents can share a checkout. Multiple writers sharing a Git index create collision risk even with nominally disjoint tasks. Herdr's worktree commands provide isolated checkouts and workspaces. Parallel work should still avoid overlapping config, migrations, generated files, lockfiles, and contracts.

### Delegated identity needs an authority boundary

Herdr injects terminal input; workers do not inherently receive a caller identity or hierarchy. A controller can therefore issue prompts in the user's voice and collect responses addressed to the user. However, acting on the user's behalf must preserve the user's actual authorization. The controller cannot manufacture approvals, secrets, external communications, product decisions, or scope changes.

## Recommended control loop

1. Verify `HERDR_ENV=1`, installed syntax, server status, and caller IDs.
2. Scout enough context to decide whether delegation helps.
3. Select topology: controller-only, read-only sibling panes, one writer plus reviewers, or isolated worktrees.
4. Start descriptive named agents without stealing focus.
5. Wait for idle, then send one complete bounded prompt with `pane run`.
6. Confirm working state; monitor status and recent transcript.
7. Resolve repo-answerable blockers; escalate missing authority to the user.
8. Collect the worker status block, diff, and validation output.
9. Independently verify claims and integrate only accepted work.
10. Report a synthesized outcome and preserve or clean only controller-owned resources.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Duplicate prompt after timeout | Inspect `agent get` and recent output before resending |
| Wrong pane due focus changes | Use `--current` or explicit returned IDs |
| Prompt not submitted | Use `pane run`, not literal send operations |
| State misclassification | Read transcript and use `agent explain` |
| Conflicting agent edits | Explicit ownership; isolate writers in worktrees; serialize shared files |
| Worker claims accepted uncritically | Controller inspects diffs and reruns proportional validation |
| Invented user approval | Centralize permission and business decisions in controller session |
| Shell injection through prompt text | Pass prompts as literal arguments; avoid `eval` and unsafe interpolation |
| Lost running work | Treat detach as persistence; close only known owned resources |
| Accidental destructive cleanup | No server stop, session delete, pane/workspace close, or forced worktree removal without exact verified scope |

## Sources

Official sources consulted:

- [Herdr documentation](https://herdr.dev/docs/)
- [Quick Start](https://herdr.dev/docs/quick-start/)
- [Concepts](https://herdr.dev/docs/concepts/)
- [Agents](https://herdr.dev/docs/agents/)
- [CLI Reference](https://herdr.dev/docs/cli-reference/)
- [Socket API](https://herdr.dev/docs/socket-api/)
- [Agent Skill](https://herdr.dev/docs/agent-skill/)
- [Official repository](https://github.com/ogulcancelik/herdr)
- [Upstream `SKILL.md`](https://github.com/ogulcancelik/herdr/blob/master/SKILL.md)

Local evidence:

- Installed `herdr 0.7.4` command help and API schema summary.
- `herdr status --json`, `herdr config check`, `herdr integration status`, and `herdr session list --json`.
- Official repository commit `02a6e874f67800891b5a549297219ed6f3ce0f2f`, committed 2026-07-18.

## Actionable next steps

1. Run the controller inside Herdr and adopt the evergreen instruction file.
2. Start with one read-only worker and verify the full dispatch → wait → read → validate loop.
3. Install the Codex or Claude integration only if the user wants native session restore metadata.
4. Use worktrees only when parallel writers provide a real latency benefit.

## Unresolved questions

None.
