# Codebase Summary

Last updated: 2026-07-19

## Summary

Herdr Orchestrator is a portable AgentKit skill repository. Its content is documentation and configuration that teaches a controller agent how to coordinate persistent Herdr panes safely, plus POSIX shell setup utilities that install and verify the skill links without ever replacing existing content.

This summary is based on direct reads of the repository files.

## Repository map

| Path | Type | Responsibility |
|---|---|---|
| `README.md` | Entry documentation | Requirements, installer/verifier usage, safe manual fallback, operating model, links, compatibility notes, license status. |
| `scripts/install.sh` | Setup utility | Safe skill-link installer: strict flag parsing, all-target preflight, no-overwrite conflict rejection, full-preflight `--dry-run`, non-forceful link creation, post-install verification, bounded current-run rollback. |
| `scripts/verify.sh` | Setup utility | Read-only verifier: aggregates Herdr, runtime, and skill-link diagnostics for all requested targets; performs no writes even on failure. |
| `scripts/lib/skill-install-common.sh` | Shared shell library | Fixed target metadata, repository-marker and `HOME` validation, runtime detection, destination classification, menu-choice mapping, target selection, output helpers. Shared only by the two entry points. |
| `tests/install-scripts-test.sh` | Shell test suite | Dependency-free matrix covering syntax, usage, prerequisites, destination states, conflicts, parent chains, dry-run, rollback, spaces, and non-TTY behavior with isolated `HOME`/`PATH` fixtures. |
| `SKILL.md` | Portable AgentKit skill | Skill metadata and concise orchestration workflow: scope, authority, preflight, routing, runtime selection, ownership, dispatch, monitoring, blockers, verification, cleanup, security. |
| `agents/openai.yaml` | Runtime metadata | Display name, short description, and default prompt for Codex/OpenAI-style skill discovery. |
| `references/herdr-control.md` | Control reference | Preflight, Herdr command discovery, IDs, worker start, prompt assignment, monitoring, follow-up, command panes, worktrees, integrations, persistence, cleanup. |
| `references/routing-policy.md` | Routing reference | Backend decision order, topology, parallelism, AgentKit/Herdr/CCS/headless/team boundaries, anti-patterns, fallbacks. |
| `references/runtime-profiles.md` | Runtime reference | Native Codex, native Claude, CCS profile launch shapes, host/provider attribution, integration relevance, CCS safety boundaries. |
| `references/worker-contract.md` | Prompt contract | Required worker prompt fields, template, prompt quality rules, naming, blocker responses, final status interpretation. |
| `references/verification-and-recovery.md` | Verification reference | Acceptance gate, evidence hierarchy, timeout/blocker/interruption recovery, writer integration, failed worker handling, cleanup, final report content. |
| `docs/herdr-orchestrator-instructions.md` | Expanded instructions | Long-form operating guide that expands the skill and references into one walkthrough. |
| `docs/project-overview-pdr.md` | Evergreen product/PDR | Current intent, users, goals, requirements, constraints, success criteria. |
| `docs/codebase-summary.md` | Evergreen codebase map | This file. |
| `docs/code-standards.md` | Evergreen standards | Documentation/configuration conventions, POSIX shell setup-script and test standards, and contribution expectations. |
| `docs/system-architecture.md` | Evergreen architecture | Conceptual components, flows, authority and trust boundaries, persistence/worktree model. |
| `docs/project-roadmap.md` | Evergreen roadmap | Completed v1 foundation and evidence-based improvement candidates. |
| `plans/260718-2353-herdr-orchestrator-skill/plan.md` | Historical plan | Original implementation plan and validation notes. Not the current source of truth. |
| `plans/reports/research-260718-2312-herdr-orchestrator.md` | Historical research | Herdr research findings and source links from 2026-07-18. Not an evergreen guarantee. |
| `.gitignore` | Git config | Ignores `.DS_Store` and local generated archives under `/assets/generated/`. |

## Tracked structure

The tracked repository contains:

- Root docs/config: `README.md`, `SKILL.md`, `.gitignore`.
- Agent metadata: `agents/openai.yaml`.
- References: five Markdown files under `references/`.
- Evergreen docs: Markdown files under `docs/`.
- Setup utilities: `scripts/install.sh`, `scripts/verify.sh`, `scripts/lib/skill-install-common.sh`.
- Shell tests: `tests/install-scripts-test.sh`.
- Historical records: plans and research reports under `plans/`.

A local generated archive may exist at `assets/generated/herdr-orchestrator.zip`, but `/assets/generated/` is ignored and not tracked.

## Module responsibilities

### Skill entry point

`SKILL.md` is the operational entry point. It defines when to handle or refuse a Herdr orchestration request, the authority model, mandatory preflight, workflow, security policy, and links to detailed references.

### References

The `references/` files are focused modules. They avoid one large instruction file by splitting control syntax, routing, runtime profile selection, worker prompt construction, and verification/recovery.

### Evergreen docs

The `docs/` directory contains maintainer-facing documentation. `docs/herdr-orchestrator-instructions.md` is an expanded operating guide. The other docs summarize product intent, codebase structure, standards, architecture, and roadmap.

### Setup utilities

`scripts/install.sh` creates absolute symlinks from `~/.claude/skills/herdr-orchestrator` and `~/.codex/skills/herdr-orchestrator` to the physical repository root. `scripts/verify.sh` is the sole read-only verification entry point. Both source `scripts/lib/skill-install-common.sh`, which stays narrow: it shares only behavior both entry points consume. Setup requires a usable `herdr --version` but never `HERDR_ENV=1` or `herdr status --json`; those belong to Herdr control preflight.

### Historical records

The `plans/` files record research and the original implementation. They are useful evidence for why the repository exists, but compatibility values inside them are time-bound observations.

## Control flow

1. User asks for Herdr delegation, monitoring, blocker handling, or session resumption.
2. AgentKit activates `herdr-orchestrator` through Claude Code or Codex skill discovery.
3. Controller reads repository/project context and decides whether delegation is useful.
4. Controller verifies `HERDR_ENV=1`, `herdr --version`, and `herdr status --json` before any Herdr control action.
5. Controller selects one primary backend for the stage: direct, Herdr worker, headless orchestrator, or real agent team.
6. If Herdr is selected, controller chooses native CLI or existing CCS profile, defines worker ownership, starts Herdr panes, waits for readiness, and sends prompts with `herdr pane run`.
7. Controller monitors Herdr state, reads transcripts, resolves blockers, and treats status as routing metadata.
8. Controller verifies final transcripts, diffs, and checks before accepting or integrating work.
9. Controller reports outcomes and cleans up only task-owned resources after verification.

## Data flow

| Data | Source | Consumer | Rule |
|---|---|---|---|
| User request and decisions | User/controller session | Controller, selected workers | Preserve explicit decisions; do not invent approvals. |
| Worker prompt | Controller | Herdr pane/worker CLI | Send as literal data with `herdr pane run`; include bounded task and authority. |
| Herdr IDs | Herdr JSON/status output | Controller | Treat as opaque; never derive from examples or display order. |
| Worker output | Pane transcript and artifacts | Controller | Untrusted until verified against files, diffs, and checks. |
| File changes | Worker checkout/worktree | Controller | Accept only after ownership and validation review. |
| Compatibility values | Local command observations and historical docs | Maintainers | Time-bound; re-check local command help after upgrades. |

## Dependencies

Documented external tools:

- `herdr`: required control plane.
- `claude`: native Claude Code worker host when selected.
- `codex`: native Codex CLI worker host when selected.
- `ccs`: optional existing profile/provider launch wrapper when explicitly selected.
- Git worktrees: used through Herdr worktree commands for concurrent writer isolation.

No repository-local package dependencies are defined because no package manifest exists.

## Testing and validation status

Current repository evidence shows:

- `tests/install-scripts-test.sh` is a dependency-free POSIX shell suite for the setup scripts. Run it with `/bin/sh tests/install-scripts-test.sh`; it uses temporary fixture homes, stubbed `herdr`/`claude`/`codex` commands, and a minimal tool `PATH`, so it never touches real skill directories or developer-installed runtimes.
- The suite passed on macOS `/bin/sh` on 2026-07-19 (48 checks). Linux `/bin/sh` execution is a separate acceptance gate tracked in the roadmap.
- No CI configuration is tracked.
- No package scripts or build commands are tracked.
- Historical plan validation recorded successful portable YAML/frontmatter checks and size checks at initial implementation time.
- Documentation maintenance should use line counts, link/path checks, `git diff --check`, and direct source verification.

## Known gaps

| Gap | Impact | Current handling |
|---|---|---|
| No selected license | Reuse permissions are unclear. | README states no license has been selected. |
| No automated docs validator in repo | Link and formatting checks are manual unless a maintainer adds tooling. | Run `wc -l`, `git diff --check`, and simple link/path checks before handoff. |
| Orchestration behavior itself is untestable from repository files | Herdr/CLI behavior depends on external tools and local installation; only the setup scripts have automated tests. | Treat installed CLI help/status as authority for command syntax. |
| Linux test evidence depends on maintainer environment | Both-platform support cannot be claimed from macOS runs alone. | Run the suite on a Linux host, VM, or container before claiming Linux verification. |
| Compatibility observations can age | Herdr/CCS/Codex/Claude behavior may change after upgrades. | Present versions as time-bound observations and re-check local help. |
| No live end-to-end fixture | Dispatch behavior cannot be proven from repository files alone. | Use the skill's preflight and conservative verification loop in real Herdr sessions. |

## Source references

- [README](../README.md)
- [Skill entry point](../SKILL.md)
- [Expanded instructions](./herdr-orchestrator-instructions.md)
- [Herdr control](../references/herdr-control.md)
- [Routing policy](../references/routing-policy.md)
- [Runtime profiles](../references/runtime-profiles.md)
- [Worker contract](../references/worker-contract.md)
- [Verification and recovery](../references/verification-and-recovery.md)
- [Historical plan](../plans/260718-2353-herdr-orchestrator-skill/plan.md)
- [Historical research](../plans/reports/research-260718-2312-herdr-orchestrator.md)
