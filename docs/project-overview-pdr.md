# Project Overview and PDR

Last updated: 2026-07-19

## Product intent

Herdr Orchestrator is a portable AgentKit skill for coordinating persistent coding-agent panes through Herdr. It keeps one controller accountable for user intent, approvals, verification, integration, and final reporting while Herdr provides the terminal control plane for interactive workers.

This repository is the portable skill source plus POSIX shell setup utilities (a safe installer, a read-only verifier, and their dependency-free tests). It does not implement an application runtime, API, service, UI, deployment, package, or CI pipeline.

## Current users

| User | Need |
|---|---|
| Controller agent | Decide whether Herdr delegation is appropriate, dispatch bounded workers, monitor progress, resolve blockers, verify results, and report final outcomes. |
| Worker coding agents | Receive direct user-style task prompts with exact scope, paths, constraints, validation, and final status protocol. |
| Repository maintainer | Maintain portable instructions that work for Claude Code and Codex CLI without duplicating source. |

## Current behavior

The skill currently provides:

- `SKILL.md` portable skill entry point for explicit Herdr orchestration requests.
- `agents/openai.yaml` runtime interface metadata for Codex-style invocation.
- Focused references for Herdr control, routing, runtime profiles, worker contracts, and verification/recovery.
- Expanded operating instructions in `docs/herdr-orchestrator-instructions.md`.
- Setup utilities: `scripts/install.sh` (safe skill-link installer), `scripts/verify.sh` (read-only setup verifier), and `scripts/lib/skill-install-common.sh` (shared target/path contract).
- Dependency-free shell tests in `tests/install-scripts-test.sh`.
- Historical research and implementation records under `plans/`.

The skill does not run workers by itself. It instructs a controller on when and how to use the installed `herdr`, `claude`, `codex`, or selected `ccs` command line tools.

## Goals

| Goal | Current requirement |
|---|---|
| Preserve authority | One controller owns intent, approvals, integration, verification, and user reporting. |
| Use Herdr only when useful | Prefer direct work for small or tightly coupled tasks; use Herdr for persistent, visible, interactive, or follow-up-heavy work. |
| Keep layer boundaries clear | AgentKit routes skills/stages; Herdr owns panes/lifecycle/worktrees; CCS only launches existing profiles. |
| Make worker work verifiable | Worker prompts must include bounded task, ownership, acceptance criteria, validation, constraints, environment, and final status. |
| Prevent unsafe concurrency | Read-only workers may share a checkout; concurrent writers require isolated worktrees or serialization. |
| Treat state as attention, not truth | Status such as `done`, `idle`, or `blocked` guides follow-up; transcripts, diffs, and checks provide evidence. |

## Non-goals

- Replacing Herdr, Claude Code, Codex CLI, CCS, AgentKit, `ak:orchestrate`, or `ak:team`.
- Creating CCS profiles, authenticating providers, installing integrations, or managing credentials.
- Adding package commands, generated application code, CI, deployment, or runtime services.
- Auto-cloning or updating the repository, installing Herdr or other external tools, uninstalling, authenticating providers, or mutating integrations from the setup scripts.
- Authorizing destructive actions, external communication, publishing, deployment, secrets access, or business decisions without the user.
- Simulating unavailable Agent Teams or headless orchestration through ordinary panes while claiming those runtimes were used.

## Functional requirements

| ID | Requirement | Evidence |
|---|---|---|
| FR-1 | Stop Herdr control work unless the controller is inside Herdr. | `SKILL.md`, `references/herdr-control.md`, `docs/herdr-orchestrator-instructions.md` require `test "${HERDR_ENV:-}" = 1`, `herdr --version`, and `herdr status --json`. |
| FR-2 | Use installed Herdr CLI syntax as authority. | `SKILL.md` and `references/herdr-control.md` require reading relevant `herdr ... --help` output before unfamiliar operations or after upgrades. |
| FR-3 | Use returned Herdr IDs as opaque values. | `references/herdr-control.md` and expanded instructions warn not to derive workspace, tab, pane, terminal, or agent IDs. |
| FR-4 | Submit prompts with `herdr pane run`. | `references/herdr-control.md` states `pane run` sends text plus Enter; `agent send` and `pane send-text` can leave text unsubmitted. |
| FR-5 | Define worker ownership before dispatch. | `references/worker-contract.md` requires exact read/modify paths, constraints, acceptance criteria, validation, and final status. |
| FR-6 | Verify worker outputs before acceptance. | `references/verification-and-recovery.md` requires transcript, diff, ownership, and validation checks before integration. |
| FR-7 | Keep CCS as a profile/launch layer only. | `references/runtime-profiles.md` defines CCS as existing profile/provider selection, not delegation or pane control. |
| FR-8 | Verify setup without mutation. | `scripts/verify.sh` aggregates Herdr, runtime, and link diagnostics for all requested targets and performs no writes, even on failure. |
| FR-9 | Install skill links without replacing existing content. | `scripts/install.sh` preflights every selected destination and parent chain before the first mutation, rejects all conflict states, preserves correct links, supports full-preflight `--dry-run`, and rolls back only links created by the current invocation after post-install verification failure. |
| FR-10 | Keep setup separate from Herdr control. | Both scripts require only a usable `herdr --version`; they never require `HERDR_ENV=1`, never run `herdr status --json`, and never execute Herdr installation commands. |

## Non-functional requirements

| Requirement | Current standard |
|---|---|
| Portability | One source repository can be symlinked into both `~/.claude/skills/herdr-orchestrator` and `~/.codex/skills/herdr-orchestrator`. Setup scripts are POSIX `/bin/sh` with no Bash-only syntax, no GNU-only `readlink -f`, and support for paths containing spaces. |
| Setup safety | Missing prerequisites, dry-run, usage errors, and conflicts cause zero filesystem mutation; no forceful link flags or preemptive deletion are used; rollback removes only revalidated links created by the current run. |
| Concision | `SKILL.md` and references are intentionally focused; evergreen docs should stay modular and under 800 lines each. |
| Safety | Prompts are literal data; no `eval`, command substitution, credential exposure, hidden permission bypass, or unauthorized destructive/external action. |
| Recoverability | Controller reconstructs state from Herdr status, snapshots, agent lists, pane lists, worktree lists, transcripts, and metadata after interruption. |
| Maintainability | Historical plans remain historical; evergreen docs in `docs/` describe current source-traceable behavior. |

## Acceptance and success criteria

The current v1 skill foundation is successful when:

- Claude Code and Codex can resolve the same linked skill source.
- The controller refuses Herdr control outside `HERDR_ENV=1`.
- A Herdr worker prompt includes exact scope, ownership, constraints, environment, validation, and final status.
- Concurrent writer guidance requires isolated worktrees or serialization.
- Worker completion is documented as an unverified handoff.
- README and docs link to current source files without inventing package, CI, deployment, or license claims.
- The installer and verifier follow their documented CLI, exit-code, and no-overwrite contracts, proven by the dependency-free test suite.

Operational success for future maintenance can be measured by:

- All Markdown docs remain below 800 lines.
- New code/tool claims cite existing repository files or documented local commands.
- `git diff --check` passes before handoff.
- Local link/path checks pass for docs updated in a change.
- `/bin/sh -n` and `/bin/sh tests/install-scripts-test.sh` pass whenever the setup scripts change.

## Constraints

- No selected license is present.
- No package manifest, CI, deployment target, API, or UI is present. Executable content is limited to the POSIX setup scripts and their shell tests.
- Compatibility observations are time-bound: docs record Herdr `0.7.4` protocol `16` and CCS `8.8.1` on 2026-07-19; the historical plan records Codex CLI `0.144.5` and Claude Code `2.1.214` at validation time.
- The repository source, not the historical plan, is the authority for current behavior.

## Roadmap distinction

Current behavior is the v1 skill described above: portable skill documentation and configuration plus the verified POSIX setup utilities and their shell tests, not an application runtime. Future improvements are tracked in [Project Roadmap](./project-roadmap.md) and should not be treated as committed dates, owners, or product promises.

## Source references

- [Skill entry point](../SKILL.md)
- [Expanded operating instructions](./herdr-orchestrator-instructions.md)
- [Herdr control](../references/herdr-control.md)
- [Routing policy](../references/routing-policy.md)
- [Runtime profiles](../references/runtime-profiles.md)
- [Worker contract](../references/worker-contract.md)
- [Verification and recovery](../references/verification-and-recovery.md)
