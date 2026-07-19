---
phase: 3
title: "Reconcile Documentation and Validate Platforms"
status: completed
priority: P1
effort: "2.5h"
dependencies: [2]
---

# Phase 3: Reconcile Documentation and Validate Platforms

## Overview

Update the current uncommitted docs in place after implementation evidence exists. Separate setup from Herdr control, record deferred initiatives only in the roadmap, and complete macOS/Linux acceptance before claiming both platforms.

## Context Links

- [Approved brainstorm](../reports/brainstorm-260719-2041-herdr-installer-upgrades.md)
- [Phase 1 contract](./phase-01-start.md)
- [Phase 2 installer](./phase-02-implement-safe-installer.md)
- [Project roadmap](../../docs/project-roadmap.md)
- [Herdr control](../../references/herdr-control.md)

## Requirements

- Functional:
  - Replace forceful manual-link guidance with tested installer/verifier commands and a safe fallback.
  - Describe the setup utilities, tests, repository map, architecture boundary, and roadmap accurately.
  - Validate the complete suite on macOS and Linux `/bin/sh` on a host, VM, or container.
- Non-functional:
  - Preserve existing uncommitted README/docs content and make targeted edits only.
  - Keep README below 300 lines and evergreen docs below 800 lines.
  - Keep later initiatives out of implementation.
  - Do not claim Linux verification without Linux evidence.

## Architecture

Add a setup plane separate from runtime control:

```text
Existing clone ──> install.sh ──> Claude/Codex skill links
       │                │
       └────────> verify.sh ────> read-only setup report

AgentKit discovers linked SKILL.md
Controller performs Herdr control only after HERDR_ENV/status preflight
```

Installer/verifier may run from an ordinary shell and check `herdr --version`. They must not run `herdr status --json`, start Herdr, or mutate integrations.

## Related Code Files

- Modify: `README.md`
- Modify: `docs/project-overview-pdr.md`
- Modify: `docs/codebase-summary.md`
- Modify: `docs/code-standards.md`
- Modify: `docs/system-architecture.md`
- Modify: `docs/project-roadmap.md`
- Modify: `references/herdr-control.md`
- Preserve unchanged: `SKILL.md`
- Preserve unless a direct false setup claim is found: `docs/herdr-orchestrator-instructions.md`
- Preserve historical: `plans/reports/brainstorm-260719-2041-herdr-installer-upgrades.md`
- Delete: none

## Implementation Steps

1. Capture `git status --short`, then re-read README and every Phase 3-owned doc. Stop if unrelated concurrent changes appeared.
2. Update README:
   - Run from an existing clone.
   - Show target, all, dry-run, verify, and help invocations.
   - Explain auto-selection for one detected runtime, one-shot Claude/Codex/All menu for two runtimes, and the non-TTY target requirement.
   - Remove `ln -sfn`; include only a non-overwriting manual fallback.
   - Separate setup prerequisites from Herdr control preflight.
   - Add `scripts/` and `tests/` to repository structure.
3. Update PDR:
   - Reframe repo as portable skill source plus setup utilities, not an application runtime.
   - Add installer/verifier functional and portability/safety requirements.
   - Remove automated tests from non-goals/constraints while preserving no package/CI/deployment/API/UI claims.
4. Update codebase summary and code standards:
   - Map all new artifacts and actual shell-test evidence.
   - Add POSIX syntax, path quoting, explicit exits, stdout/stderr, preflight, no-force, bounded rollback, fixture isolation, and validation standards.
5. Update architecture with the separate setup plane and unchanged Herdr runtime-control boundary.
6. Update roadmap:
   - Mark Round 1 complete only after both OS gates pass; otherwise leave in progress with the Linux gate explicit.
   - Order later work: docs validator, operational doctor, compatibility report, prompt recipes.
   - Do not create those features or promise detailed CLI contracts.
7. Add a concise note to Herdr control reference distinguishing ordinary-shell setup verification from mandatory operational preflight.
8. Run complete syntax/tests on macOS `/bin/sh`.
9. Run equivalent commands in a Linux checkout under `/bin/sh` on a host, VM, or container; record only safe, dated environment evidence and results.
10. Run one real interactive TTY smoke check on both macOS and Linux. Automated tests cover the pure menu-choice function and all non-TTY entry-point behavior.
11. Run line, link/path, stale-claim, whitespace, portability, and Git diff checks over tracked and untracked files.
12. Inspect final status; reject out-of-scope files or changes before claiming completion.

## Todo

- [x] Reconfirm and preserve the uncommitted documentation baseline.
- [x] Update README and safe manual fallback from verified behavior.
- [x] Update PDR, codebase summary, standards, architecture, and roadmap.
- [x] Clarify setup versus control preflight in Herdr control reference.
- [x] Pass macOS `/bin/sh` acceptance.
- [x] Pass Linux `/bin/sh` acceptance on a host, VM, or container. **Passed 2026-07-19 in Docker Desktop 4.82.0 using `debian:stable-slim` on LinuxKit 6.12.76/aarch64 with `/bin/sh` linked to dash: syntax passed and the non-root suite completed 48 passed, 0 failed. An initial root run produced 47 passed, 1 failed only because root can write through the non-writable-directory fixture; rerunning as UID 501 exercised the intended permission contract and passed.**
- [x] Pass real interactive TTY smoke checks on macOS and Linux. **macOS passed in an ordinary Herdr terminal pane with isolated `HOME`/`PATH`: the two-runtime menu accepted Claude, created only its link, and completed via `verify.sh`. Linux passed in an interactive Debian container with isolated `HOME`/`PATH`: the two-runtime menu accepted All, created both links, and completed post-install verification. Automated pure menu-choice tests and supplemental macOS `/usr/bin/script` exercises remain supporting evidence.**
- [x] Pass docs, portability, whitespace, links, and final-scope checks.

## Validation

Run on macOS and equivalent Linux checkout:

```sh
/bin/sh -n scripts/install.sh scripts/verify.sh scripts/lib/skill-install-common.sh tests/install-scripts-test.sh
/bin/sh tests/install-scripts-test.sh
```

Repository checks:

```sh
git status --short
git diff --check
wc -l README.md docs/*.md | sort -rn

if grep -R -n -E 'documentation/configuration only|No automated test suite is tracked|No executable tests|ln -sfn' README.md docs references; then
  printf '%s\n' 'review stale setup/test claims above' >&2
  exit 1
fi

if grep -R -n '[[:blank:]]$' README.md scripts tests docs references; then
  printf '%s\n' 'trailing whitespace found' >&2
  exit 1
fi
```

Also run the repository's existing local-link/anchor audit over README and `docs/*.md`; extend it to changed reference links. Because new files and current docs may be untracked, do not rely on `git diff --check` alone.

## Success Criteria

- [x] Shell syntax, complete automated tests, and real TTY smoke checks pass on macOS and Linux `/bin/sh` (host, VM, or container). **macOS passed 2026-07-19 on Darwin 25.5.0 with 48/48 tests and an ordinary-terminal smoke. Linux passed 2026-07-19 in `debian:stable-slim` on Docker Desktop/LinuxKit aarch64, `/bin/sh` as dash, with 48/48 non-root tests and an interactive All-target smoke.**

<!-- Updated: Validation Session 1 - accepted Linux environments and portable TTY validation strategy -->
- [x] README no longer recommends forceful link replacement and remains below 300 lines (132 lines).
- [x] Evergreen docs remain below 800 lines and describe actual tracked behavior.
- [x] Setup verification and Herdr control preflight are consistently separated.
- [x] Deferred initiatives exist only as roadmap entries.
- [x] `SKILL.md` remains unchanged.
- [x] Relative links, anchors, whitespace, stale-claim, portability, and diff checks pass.
- [x] Final status contains only baseline docs plus approved Round 1 plan/implementation changes.

## Risk Assessment

| Risk | Mitigation |
|---|---|
| User-owned docs are overwritten | Re-read before edit; use targeted changes; stop on concurrent drift. |
| Docs describe intent instead of behavior | Start after Phases 1-2 pass; copy only tested commands/contracts. |
| Linux support is overclaimed | Keep plan/roadmap incomplete until real Linux evidence passes. |
| Deferred work leaks into implementation | Permit roadmap prose only; create no related scripts or recipes. |
| Untracked files bypass diff checks | Run direct whitespace, links, line-count, and stale-claim checks. |

## Security Considerations

- Documentation must never suggest automatic execution of remote installers.
- Preserve explicit approval requirements for auth, providers, integrations, publishing, and destructive actions.
- Do not include raw local environment values, credentials, or sensitive transcripts in compatibility evidence.

## Next Steps

Both platform gates and docs checks pass; Round 1 is complete. Later initiatives each require their own plan/implementation cycle.
