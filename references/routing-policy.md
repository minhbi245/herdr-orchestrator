# Routing Policy

## Decision order

Choose the simplest backend that preserves correctness and user control.

1. Can the controller complete the task safely without delegation? Work directly.
2. Does a worker need a live terminal, follow-ups, approvals, persistence, or user visibility? Use Herdr. Select its native or CCS runtime profile separately.
3. Is the work a repeatable batch needing runtime/model routing, captured artifacts, timeouts, resume state, or an arbiter? Use `ak:orchestrate` when available.
4. Must workers message, debate, or challenge each other through shared tasks? Use `ak:team` only when the runtime exposes real Agent Teams.

## Selection table

| Work shape | Primary backend |
|---|---|
| One small module or tightly coupled fix | Direct controller work |
| Independent read-only investigations | Herdr sibling workers |
| One writer followed by review | Herdr writer, then read-only reviewer |
| Interactive work running across detach/reattach | Herdr |
| Multi-stage or multi-runtime repeatable jobs | `ak:orchestrate` |
| Competing debug hypotheses with peer challenge | `ak:team` |
| Simple plan → code → test chain | Direct or sequential Herdr workers |

These are heuristics, not hard size thresholds. Delegation must reduce real latency, context pressure, or risk.

## Topology

Default to a sibling pane in the current tab and CWD.

Create a separate tab when the user requested a distinct view or the current layout would become unusable. Create a separate workspace for another repo, an isolated worktree, or an independent long-lived investigation.

Inspect pane geometry before repeated splits. Split wide panes right and narrow or tall panes down. Keep background creation unfocused.

## Parallelism

Parallelize only tasks with clear ownership and known integration points.

- Read-only tasks may share a checkout.
- One writer plus read-only observers may share only when observers never mutate.
- Concurrent writers require isolated worktrees.
- Worktrees do not remove merge conflicts; they defer conflicts to integration.
- Serialize overlapping files, migrations, generated outputs, lockfiles, shared configuration, schemas, and public contracts.

## Relationship to AgentKit and other orchestrators

AgentKit routes skills and workflow stages. Herdr is the persistent interactive
control plane. CCS is only a launch/profile layer. `ak:orchestrate` is a
headless job engine. `ak:team` is a collaborative teammate protocol.

Select one primary coordinator per stage:

- Herdr may host the controller process without individually controlling internal `ak:team` teammates.
- A CCS profile may launch one Herdr worker, but it never owns worker prompts,
  task routing, pane lifecycle, or user approvals.
- A headless orchestration stage owns its job graph, state, worktrees, captures, and arbiter until that stage completes.
- A team stage owns its teammate task list and peer messaging until team cleanup.
- The outer controller remains accountable for user intent and accepts or rejects the stage result.

## Anti-patterns

- Do not spawn workers merely because slots are available.
- Do not run Herdr → headless orchestrator → agent team for one ordinary task.
- Do not use CCS delegation or `ccs sync` as a second worker-control plane.
- Do not ask multiple workers to edit the same checkout and resolve the damage later.
- Do not use majority vote as evidence.
- Do not delegate a missing product decision.
- Do not let a worker merge, push, publish, deploy, or contact external systems unless explicitly authorized.
- Do not substitute an unavailable Agent Teams runtime with ordinary subagents while claiming `ak:team` was used.

## Fallbacks

If Herdr is unavailable or the controller is outside `HERDR_ENV=1`, stop Herdr control and explain the required setup. Do not silently downgrade to another backend when the user explicitly requested Herdr.

If `ak:orchestrate` or `ak:team` is selected but unavailable, follow that skill's own preflight and failure rules. Return the blocker to the user rather than simulating the missing runtime.
