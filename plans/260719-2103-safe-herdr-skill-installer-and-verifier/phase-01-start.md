---
phase: 1
title: "Establish Shared Contract and Read-Only Verifier"
status: done
priority: P1
effort: "2.5h"
dependencies: []
---

# Phase 1: Establish Shared Contract and Read-Only Verifier

## Overview

Define portable target/path semantics and implement `verify.sh` before any mutating entry point. This freezes prerequisite, target-selection, link-classification, output, and exit-code behavior.

## Context Links

- [Approved brainstorm](../reports/brainstorm-260719-2041-herdr-installer-upgrades.md)
- [README installation](../../README.md#installation)
- [Code standards](../../docs/code-standards.md)
- [Herdr control preflight](../../references/herdr-control.md#preflight-and-discovery)

## Requirements

- Functional:
  - Support `--claude`, `--codex`, `--all`, and `--help`.
  - Without a target, auto-select one detected runtime; if both exist, offer Claude, Codex, or All once. Exit `2` without blocking in non-interactive use.
  - Check usable `herdr --version`, every selected runtime, and every selected link even when another check fails.
  - Classify missing, correct, wrong, broken, file, directory, and other destinations.
  - Aggregate all prerequisite and selected-target diagnostics; exit `0` only when every requested check passes.
- Non-functional:
  - POSIX `/bin/sh`; no Bashisms or GNU-only `readlink -f`.
  - Read-only in success and failure paths.
  - Quote every path; support checkout and `HOME` paths containing spaces.
  - Invalid usage exits `2`; operational failures exit `1`.

## Architecture

```text
verify.sh
  ├── parses target/help flags
  ├── sources lib/skill-install-common.sh
  ├── validates physical repository markers
  ├── verifies Herdr and selected runtime commands
  └── classifies each destination without mutation
```

The common library owns only behavior consumed by both planned entry points:

- Fixed Claude/Codex target metadata and destination paths.
- Physical path and repository-marker validation.
- `HOME`, command, TTY, and target selection checks.
- Symlink-state classification.
- Common message and exit helpers.

Do not add installer mutations, lifecycle abstractions, plugin registries, doctor probes, or future reporting hooks.

## Related Code Files

- Create: `scripts/lib/skill-install-common.sh` (`0644`)
- Create: `scripts/verify.sh` (`0755`)
- Create: `tests/install-scripts-test.sh` (`0755`, initial verifier matrix)
- Modify: none
- Delete: none

## Implementation Steps

1. Add `/bin/sh` entry-point and sourced-library structure.
2. Resolve the script directory and physical repository root with `cd -P` and `pwd -P`; validate `.git`, `SKILL.md`, and `references/herdr-control.md`.
3. Validate `HOME` without echoing unrelated environment data.
4. Define fixed runtime-to-destination mapping:
   - Claude: `$HOME/.claude/skills/herdr-orchestrator`
   - Codex: `$HOME/.codex/skills/herdr-orchestrator`
5. Parse one mutually exclusive target flag. Standalone `--help` exits `0`; combining help with any other argument, duplicate target flags, unknown flags, and unsupported `--dry-run` in verifier exits `2`.
6. Implement shared target selection:
   - Explicit flags select fixed targets.
   - Non-TTY without a target exits `2` before checking Herdr.
   - TTY with one detected runtime auto-selects it without reading input.
   - TTY with both runtimes offers Claude, Codex, or All and accepts one bounded response.
   - No detected runtime exits `1` without reading input.
   - Keep menu-choice mapping in a pure shell function so tests can call it without a pseudo-TTY.
7. Implement Herdr prerequisite check. On failure, print canonical docs and manual official install options; never execute them.
8. Classify symlinks before ordinary file/directory tests. Resolve directory links physically and accept relative links resolving to the current repo as correct.
9. Implement `verify.sh` to run every Herdr, runtime, and link check for all requested targets, print successes to stdout, actionable failures to stderr, aggregate the final result, and perform no writes.
10. Build a temporary fixture harness with isolated `HOME`, isolated `PATH`, stub runtimes, separate stdout/stderr capture, cleanup trap, and pass/fail summary.
11. Add Phase 1 automated cases: syntax, standalone/mixed help, usage errors, non-TTY behavior, pure one/two-runtime choice logic, missing/failing Herdr, missing runtimes, every destination state, aggregate diagnostics, spaces, and read-only failure behavior.
12. Run a real interactive smoke check on macOS; repeat the actual TTY branch on Linux in Phase 3.

## Todo

- [x] Create narrow common library and repository/path validation.
- [x] Implement strict help/target parsing and deterministic TTY behavior.
- [x] Implement portable destination classification.
- [x] Implement aggregate read-only verifier and exit/output contract.
- [x] Build isolated shell test harness and Phase 1 matrix.
- [x] Run syntax, test, executable-mode, and optional ShellCheck gates (ShellCheck not installed locally; skipped as permitted).

## Validation

```sh
/bin/sh -n scripts/lib/skill-install-common.sh scripts/verify.sh tests/install-scripts-test.sh
/bin/sh tests/install-scripts-test.sh
./scripts/verify.sh --help
/bin/sh -c './scripts/verify.sh </dev/null >/dev/null 2>/dev/null; [ "$?" -eq 2 ]'

test -x scripts/verify.sh
test -x tests/install-scripts-test.sh
test -r scripts/lib/skill-install-common.sh

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -s sh scripts/lib/skill-install-common.sh scripts/verify.sh tests/install-scripts-test.sh
fi
```

## Success Criteria

- [x] `verify.sh` is the sole read-only verification CLI.
- [x] Required destination states and selected targets are reported accurately.
- [x] Setup verification requires no `HERDR_ENV=1` and runs no `herdr status --json`.
- [x] No GNU-only utility or Bash syntax is used (portability grep gate passes).
- [x] Tests cannot reach real skill directories or satisfy fixtures with developer runtimes (isolated `HOME`, stub-plus-toolbin `PATH`).
- [x] All automated Phase 1 tests and a real TTY smoke check pass on current macOS `/bin/sh` (acceptance basis: manual smoke in an ordinary interactive Herdr-pane terminal with isolated `HOME`/`PATH`; `/usr/bin/script` pty exercises are supplemental — see plan execution log).

<!-- Updated: Validation Session 1 - aggregate verification, exact TTY defaults, strict help, and portable TTY test strategy -->

## Risk Assessment

| Risk | Mitigation |
|---|---|
| Shared library becomes a framework | Admit only behavior used by install and verify entry points. |
| Broken and wrong links are conflated | Test symlink identity before target existence and physical resolution. |
| Automation hangs | Check TTY before every `read`; never loop indefinitely. |
| Real binaries leak into tests | Build a controlled fixture `PATH`. |
| Logical and physical paths compare unequal | Normalize both sides with physical directory resolution. |

## Security Considerations

- Never execute remote installation commands.
- Do not print `HOME`, PATH contents, credentials, or unrelated environment values.
- Treat filesystem states as untrusted and inspect before action.
- Verifier must not create, repair, delete, or chmod anything.

## Next Steps

Phase 2 consumes the frozen common contract and calls `verify.sh` after installation.
