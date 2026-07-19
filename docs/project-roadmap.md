# Project Roadmap

Last updated: 2026-07-19

## Roadmap policy

This roadmap records evidence-based improvement candidates for the Herdr Orchestrator skill repository. It does not commit dates, owners, releases, provider support, integrations, or product promises.

Current source files remain the authority for behavior. Historical plans and research explain origin and validation at a point in time.

## Completed: v1 skill foundation

Status: complete based on tracked repository evidence.

Delivered foundation:

- Portable `SKILL.md` with `name` and `description` frontmatter.
- Shared installation model through symlinks into Claude Code and Codex skill directories.
- `agents/openai.yaml` interface metadata.
- Five focused reference files:
  - `references/herdr-control.md`
  - `references/routing-policy.md`
  - `references/runtime-profiles.md`
  - `references/worker-contract.md`
  - `references/verification-and-recovery.md`
- Expanded instructions in `docs/herdr-orchestrator-instructions.md`.
- Historical research and implementation plan under `plans/`.
- README documenting requirements, installation, usage, structure, docs, compatibility notes, and license status.

Completed foundation exit criteria:

- Skill source is portable and not tied to a package build.
- Outside-Herdr control is refused by mandatory preflight guidance.
- AgentKit, Herdr, CCS, headless orchestrator, and team boundaries are documented.
- Worker prompt contract includes ownership, constraints, validation, environment, and final status.
- Verification guidance treats worker completion as an unverified handoff.
- Parallel writer guidance requires worktrees or serialization.

## Completed: Round 1 — safe skill installer and verifier

Status: implementation plus macOS and Linux acceptance complete.

Delivered on 2026-07-19:

- `scripts/install.sh`: safe skill-link installer with strict flag parsing, all-target preflight, no-overwrite conflict rejection, full-preflight `--dry-run`, non-forceful link creation, post-install verification, and bounded current-run rollback.
- `scripts/verify.sh`: read-only verifier aggregating Herdr, runtime, and link diagnostics.
- `scripts/lib/skill-install-common.sh`: narrow shared target/path contract.
- `tests/install-scripts-test.sh`: dependency-free suite (48 checks) with isolated `HOME`/`PATH` fixtures.
- README and evergreen docs updated from verified behavior; forceful link-replacement guidance removed.

Acceptance evidence recorded on 2026-07-19:

- macOS `/bin/sh` on Darwin 25.5.0: syntax, 48/48 tests, and an isolated real-TTY smoke passed.
- Linux `/bin/sh` in `debian:stable-slim` on Docker Desktop/LinuxKit aarch64, with dash as `/bin/sh`: syntax and 48/48 tests passed as a non-root UID; an isolated real-TTY smoke selected All, created both links, and passed post-install verification.

## Ordered later initiatives

These execute in order after Round 1 closes, each with its own plan and validation cycle. They are roadmap entries only; no scripts, probes, or recipes for them exist yet.

### 1. Documentation validator

Problem: The repository has a documented manual checklist but no tracked validator.

Candidate work:

- Add a dependency-free `scripts/validate-docs.sh` covering line counts, relative link/path sanity, trailing whitespace, and `git diff --check`.
- Keep the checklist in `docs/code-standards.md` as the baseline; source-claim accuracy still requires human review.

Exit criteria:

- A maintainer can validate a docs-only change with commands available in a standard shell/Git environment.
- The validator is documented, dependency-light, and honest about what it cannot check.

### 2. Operational doctor

Problem: Installation verification and runtime health diagnosis are separate concerns; only the former exists.

Candidate work:

- Add a separate read-only `scripts/doctor.sh` that verifies skill links and runtime availability, reports the Herdr version, and inspects `HERDR_ENV`, `herdr status --json`, and integration status only when inside a Herdr pane.
- Never start/stop a server or install/modify integrations.

Exit criteria:

- Outside a Herdr pane, the doctor states that operational status cannot be checked instead of guessing.
- No doctor code path mutates anything.

### 3. Compatibility report

Problem: Compatibility values for Herdr, CCS, Codex CLI, and Claude Code are time-bound observations refreshed by hand.

Candidate work:

- After doctor probes stabilize, add a read-only report command capturing dated tool versions and safe help/capability observations to stdout.
- Never mutate authentication, profiles, integrations, or evergreen docs automatically.

Exit criteria:

- Maintainers can refresh compatibility notes without mutating auth/profile configuration.
- Output distinguishes local observations from guaranteed protocol rules.

### 4. Prompt recipes

Problem: Worker prompt requirements are clear, but users may benefit from a few complete examples.

Candidate work:

- Add concise recipes for read-only scout, single writer, read-only reviewer, and blocker follow-up, based on `references/worker-contract.md` and verified live-session behavior.
- Keep examples generic and path-explicit; avoid fake package commands, broad authority, secrets, or implied CI.

Exit criteria:

- Recipes follow `references/worker-contract.md` exactly.
- Recipes do not grant extra authority, leak secrets, or imply unavailable tests/CI.

## Maintenance candidates

### Link/path consistency review

Problem: More evergreen docs increase cross-link maintenance burden.

Candidate work:

- Periodically scan Markdown links in README and `docs/`.
- Remove or update links when files move.
- Keep historical links clearly labeled as historical.

Exit criteria:

- All relative Markdown links in README and `docs/` resolve to repository files or documented external URLs.
- No evergreen doc relies on a historical plan as current authority.

### First live-session learnings capture

Problem: The repository documents the orchestration model, but no current evergreen doc records lessons from a live end-to-end dispatch.

Candidate work:

- After an authorized real Herdr session, capture verified operational learnings.
- Update references only when behavior differs from or sharpens current guidance.
- Keep local environment details dated.

Exit criteria:

- Any new claims cite observed command output or source docs.
- No secrets, pane transcripts with sensitive data, or personal data are committed.

## Deferred or out of scope

| Item | Reason |
|---|---|
| Deployment docs | No deployed app or service exists. |
| UI/design guidelines | No UI exists. |
| API docs | No API exists in the repository. |
| Package scripts | No package manifest exists. |
| CI setup | No CI configuration exists; adding it would be implementation scope, not documentation maintenance. |
| License text | Requires owner decision. |
| CCS auth/profile setup automation | Out of scope; dispatch uses existing selected profiles only. |

## Success metrics

| Metric | Target |
|---|---|
| README length | Under 300 lines. |
| Evergreen docs length | Each Markdown doc under 800 lines. |
| Link hygiene | Relative links in README and `docs/` resolve. |
| Claim accuracy | CLI/version/tool claims are sourced to repository evidence or dated local observations. |
| Setup script health | `/bin/sh -n` and `/bin/sh tests/install-scripts-test.sh` pass on every setup-script change. |
| Scope discipline | No fake code, package commands, CI, deployment, API, UI, or license claims are added. |

## Source references

- [Project overview and PDR](./project-overview-pdr.md)
- [Codebase summary](./codebase-summary.md)
- [Code standards](./code-standards.md)
- [System architecture](./system-architecture.md)
- [Skill entry point](../SKILL.md)
- [Expanded instructions](./herdr-orchestrator-instructions.md)
- [Historical plan](../plans/260718-2353-herdr-orchestrator-skill/plan.md)
- [Historical research](../plans/reports/research-260718-2312-herdr-orchestrator.md)
