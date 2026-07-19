---
title: "Safe Herdr Skill Installer and Verifier"
description: "Add non-overwriting POSIX setup utilities for Claude Code and Codex skill links, with dependency-free tests and accurate documentation."
status: completed
priority: P1
effort: 8h
branch: main
tags: [feature, infra, docs]
blockedBy: []
blocks: []
created: 2026-07-19
---

# Safe Herdr Skill Installer and Verifier

## Overview

Implement Round 1 from the approved [brainstorm report](../reports/brainstorm-260719-2041-herdr-installer-upgrades.md): a split installer and read-only verifier for the portable skill. Preserve user-owned uncommitted documentation, prohibit overwrite behavior, and keep setup separate from Herdr runtime control.

## Scope

Included:

- POSIX `/bin/sh` support on macOS and Linux.
- `scripts/install.sh`, `scripts/verify.sh`, and one narrow shared library.
- Dependency-free filesystem and CLI behavior tests.
- README, evergreen docs, roadmap, and Herdr-control clarification.

Excluded:

- Auto-clone, update, uninstall, external-tool installation, auth, provider setup, or integration mutation.
- Doctor, docs validator, compatibility reporter, and prompt recipes implementation.
- Package manifest, CI, deployment, API, UI, or application runtime.

## Goals

| # | Goal | Priority |
|---|---|---|
| 1 | Verify Herdr, selected runtime, and skill-link state without mutation | P1 |
| 2 | Install absolute links idempotently without replacing existing content | P1 |
| 3 | Prove failure, dry-run, rollback, and path portability behavior | P1 |
| 4 | Document only implemented and verified behavior | P2 |

## Phases

| # | Phase | Status |
|---|---|---|
| 1 | [Establish Shared Contract and Verifier](./phase-01-start.md) | Done |
| 2 | [Implement Safe Installer](./phase-02-implement-safe-installer.md) | Done |
| 3 | [Reconcile Documentation and Validate Platforms](./phase-03-reconcile-documentation-and-validate-platforms.md) | Done |

## Dependencies

- Existing cloned repository checkout.
- Installed Herdr, Claude Code, and/or Codex CLI for real smoke checks.
- Linux `/bin/sh` on a host, VM, or container before claiming Linux verification.
- Existing docs are an uncommitted baseline and must be re-read before modification.

## Execution Constraints

- Phases run sequentially; Phase 3 documents verified behavior from Phases 1-2.
- Never use `git reset`, `git checkout`, `git clean`, forced symlink replacement, or destructive cleanup.
- `SKILL.md` remains focused on orchestration and unchanged in this round.
- If Linux execution is unavailable, implementation may finish but plan remains incomplete at the platform acceptance gate.

## Success Criteria

- [x] Installer/verifier CLI and exit-code contracts pass the full test matrix.
- [x] Missing prerequisites, dry-run, verify, and normal conflicts cause zero mutation.
- [x] Existing files, directories, wrong links, and broken links are never replaced or deleted.
- [x] Post-install failure rolls back only links created by the current invocation.
- [x] macOS and Linux `/bin/sh` evidence passes before both-platform support is claimed. **macOS passed 2026-07-19; Linux passed 2026-07-19 in a non-root `debian:stable-slim` container under Docker Desktop/LinuxKit, including 48/48 tests and a real interactive TTY smoke.**
- [x] README and evergreen docs match actual behavior and stay within size/link/whitespace standards.

## Open Questions

None for Round 1.

## Validation Log

### Session 1 — 2026-07-19

**Trigger:** User requested critical-questions validation before implementation.

### Verification Results

- **Tier:** Standard — Fact Checker + Contract Verifier
- **Claims checked:** 30
- **Verified:** 27 | **Failed:** 0 | **Unverified:** 3
- **Verified evidence:** current install destinations and `ln -sfn` commands in `README.md:23-36`; setup/control preflight in `README.md:13-21`, `SKILL.md:39-51`, and `references/herdr-control.md:3-25`; portability and repository claims in current PDR, standards, summary, architecture, and roadmap; all planned create paths are currently absent; current working-tree baseline matches the plan.
- **Unverified until implementation:** physical-path behavior through an installed skill symlink; bounded rollback after induced post-install verifier failure; pass result on a real Linux `/bin/sh` environment.
- **Failures:** none.

**Questions asked:** 7

#### Questions & Answers

1. **[Architecture]** If Herdr or a runtime is missing, how should `verify.sh` report results?
   - Options: Aggregate all checks | Fail on Herdr first | Fail per target
   - **Answer:** Aggregate all checks.
   - **Rationale:** One read-only run should expose all prerequisite and link failures without becoming a mutating doctor.
2. **[Assumption]** How should target selection behave in an interactive terminal without flags?
   - Options: Auto one, menu for two | Always show menu | Always require flags
   - **Answer:** Auto one, menu for two.
   - **Rationale:** Avoid unnecessary prompts while retaining an explicit choice when both runtimes exist.
3. **[Risk]** How should valid symlinked parent directories be handled?
   - Options: Allow resolved directories | Reject parent symlinks
   - **Answer:** Allow resolved directories.
   - **Rationale:** Support common dotfiles layouts while never replacing or deleting parent links.
4. **[Acceptance]** What Linux evidence satisfies the platform gate?
   - Options: Host, VM, or container | Host or VM only | Static audit enough
   - **Answer:** Host, VM, or container.
   - **Rationale:** The suite must execute under real Linux `/bin/sh`; static review alone is insufficient.
5. **[Contract]** Should `install.sh --dry-run` require working prerequisites?
   - Options: Full preflight | Filesystem preview only
   - **Answer:** Full preflight.
   - **Rationale:** Dry-run should predict whether the real install can proceed, differing only by mutation.
6. **[Contract]** How should `--help` behave with additional arguments?
   - Options: Help must stand alone | Help always wins
   - **Answer:** Help must stand alone.
   - **Rationale:** Strict usage is deterministic: standalone help exits `0`; mixed help exits `2`.
7. **[Testing]** How should dependency-free tests cover interactive TTY behavior?
   - Options: Pure logic plus manual smoke | Platform `script` tool | Flags only in tests
   - **Answer:** Pure logic plus manual smoke.
   - **Rationale:** Automate menu-choice logic without platform-specific pseudo-TTY commands, then smoke-test the real TTY branch per platform.

#### Confirmed Decisions

- Verifier aggregates Herdr, runtime, and link diagnostics for all requested targets before exit `1`.
- Interactive default auto-selects one detected runtime; two detected runtimes offer Claude, Codex, or All once.
- Parent symlinks are allowed only when they resolve to writable directories; they are never modified.
- Linux host, VM, or container execution counts; no Linux execution means the platform gate stays pending.
- Dry-run performs full prerequisite and conflict preflight, then returns before all mutation.
- `--help` must be the sole option.
- TTY choice logic is automated as pure shell logic; actual TTY flow receives a manual smoke check on each supported platform.

#### Action Items

- [x] Propagate aggregate verifier diagnostics and exact TTY behavior to Phase 1.
- [x] Propagate parent-link, dry-run, and strict help contracts to Phase 2.
- [x] Propagate accepted Linux environments and manual TTY smoke to Phase 3.

#### Impact on Phases

- Phase 1: tighter parser, aggregate verification, pure choice-function tests, and manual TTY smoke.
- Phase 2: full-preflight dry-run and explicit support for resolved writable parent links.
- Phase 3: Linux host/VM/container acceptance plus real TTY smoke evidence.

### Whole-Plan Consistency Sweep

- Files reread: `plan.md`, all three `phase-*.md` files.
- Decision deltas checked: 7.
- Reconciled stale references: 11.
- Unresolved contradictions: 0.

## Execution Log

### Session 2 — 2026-07-19 (implementation)

Executor: single writer, macOS Darwin 25.5.0, `/bin/sh`.

**Created:** `scripts/lib/skill-install-common.sh` (0644), `scripts/verify.sh` (0755), `scripts/install.sh` (0755), `tests/install-scripts-test.sh` (0755).

**Modified:** `README.md`, `docs/project-overview-pdr.md`, `docs/codebase-summary.md`, `docs/code-standards.md`, `docs/system-architecture.md`, `docs/project-roadmap.md`, `references/herdr-control.md`. `SKILL.md` and `docs/herdr-orchestrator-instructions.md` unchanged (the latter was re-read; it contains no false setup claims).

**Verified on macOS `/bin/sh` (2026-07-19):**

- `/bin/sh -n` passes for all four shell files.
- `/bin/sh tests/install-scripts-test.sh`: 48 passed, 0 failed. Matrix covers syntax, modes, strict help/usage, duplicate/multiple/unknown flags, verifier `--dry-run` rejection, non-TTY exit `2` before the Herdr check, pure menu-choice mapping, missing/failing Herdr with guidance output, missing runtimes, all destination states (missing/correct/non-canonical/wrong/broken/file/directory), aggregate diagnostics, installer success/idempotency/mixed-preserve, all conflict rejections with content preservation, multi-target no-partial-install, parent-chain (file, broken link, valid resolved link, non-writable resolved dir), full-preflight dry-run with zero mutation in both flag orders, bounded rollback (including preserving a pre-existing correct link), spaces in repo and `HOME` paths, relative-link acceptance, and repository-marker validation.
- Portability grep gate (no `[[`, `function`/scoped declarations, `readlink -f`, `pipefail`, forceful `ln`) passes over `scripts/` and `tests/`.
- Interactive TTY evidence on macOS, in three tiers:
  - **Accepted manual smoke (acceptance basis):** the controller ran the installer in an ordinary interactive terminal (Herdr pane) with an isolated `HOME`/`PATH` on 2026-07-19. The two-runtime menu was displayed, a Claude target selection was accepted, only the Claude link was created, `verify.sh` was invoked, and the run completed successfully.
  - **Automated pure menu-choice tests:** the suite exercises `skill_menu_selection` mapping for every valid and invalid reply without any pseudo-TTY.
  - **Supplemental `/usr/bin/script` pty exercises (not the acceptance basis):** two-runtime menu with reply `3` installed and verified both targets (exit 0); single-runtime auto-selection read no input (verify exit 1 on missing link; install exit 0 creating only that target); invalid menu reply exited `2` with zero mutation.
- Docs gates: README 132 lines; all docs under 800 lines; stale-claim grep clean; trailing-whitespace grep clean over README/scripts/tests/docs/references; relative link and anchor audit clean; `git diff --check` clean; final `git status` contains only the user-owned baseline plus approved Round 1 files.

**Linux acceptance completed on 2026-07-19:**

- Docker Desktop 4.82.0 provided a LinuxKit 6.12.76/aarch64 engine; the approved `debian:stable-slim` image used dash as `/bin/sh`.
- Syntax passed and the complete suite passed as a non-root UID: 48 passed, 0 failed. The first root run reported 47 passed, 1 failed because root bypassed the fixture's non-writable-directory permission assumption; this was an environment mismatch, not an installer defect.
- A real interactive Debian TTY smoke displayed the two-runtime menu, accepted All, created both isolated skill links, invoked `verify.sh`, and completed successfully.
- ShellCheck remained unavailable and was skipped as an optional gate.

<!-- slug: safe-herdr-skill-installer-and-verifier -->
