---
phase: 2
title: "Implement Safe Installer"
status: done
priority: P1
effort: "3h"
dependencies: [1]
---

# Phase 2: Implement Safe Installer

## Overview

Add the mutating installer on top of Phase 1's shared contract. Prove all-target preflight, no-overwrite behavior, idempotency, dry-run, post-install verification, and current-invocation-only rollback.

## Context Links

- [Approved brainstorm](../reports/brainstorm-260719-2041-herdr-installer-upgrades.md)
- [Phase 1 contract](./phase-01-start.md)
- [Current README installation](../../README.md#installation)

## Requirements

- Functional:
  - Support `--claude`, `--codex`, `--all`, `--dry-run`, and standalone `--help`.
  - Dry-run performs the same Herdr, runtime, parent-chain, and conflict preflight as installation before returning without mutation.
  - Preflight every selected target before the first filesystem mutation.
  - Preserve correct links; create only missing targets; reject every conflict state.
  - Create absolute symlinks to the physical repository root.
  - Run `verify.sh` with explicit targets after installation.
  - Roll back only links created by the current invocation after unexpected failure.
- Non-functional:
  - Missing prerequisites, dry-run, and normal conflicts cause zero mutation.
  - Never use forceful `ln`, preemptive `rm`, or parent-directory cleanup.
  - No production-only test hooks or hidden environment bypasses.

## Architecture

```text
install.sh
  ├── sources common target/path contract
  ├── resolves explicit or TTY-selected targets
  ├── checks Herdr and runtimes
  ├── preflights all destinations and parent chains
  ├── prints preserve/create plan
  ├── creates only missing parents and links
  └── invokes verify.sh with exact explicit targets
        └── on failure: revalidate and remove current-run links only
```

There are only two fixed targets. Use explicit `created_claude` and `created_codex` flags instead of arrays or transaction abstractions.

## Related Code Files

- Create: `scripts/install.sh` (`0755`)
- Modify: `tests/install-scripts-test.sh`
- Consume unchanged: `scripts/lib/skill-install-common.sh`
- Consume unchanged: `scripts/verify.sh`
- Delete: none

## Implementation Steps

1. Parse one target flag plus optional `--dry-run` in documented order combinations. Standalone `--help` exits `0`; mixed help, unknown arguments, and duplicate/multiple target flags exit `2`. Do not add `install.sh --verify`.
2. Resolve repository and `HOME`, select targets, and require `herdr --version` plus every selected runtime before creating directories.
3. Classify all selected destinations. Accept only missing or correct states.
4. Validate the parent chain for each missing target: allow parent symlinks only when they resolve to directories; the resolved directory must be writable when creation is required; a file, broken parent link, or non-directory in the chain is fatal. Never modify parent symlinks.
5. If any selected target conflicts or has invalid parents, report every relevant failure and exit before `mkdir` or `ln`.
6. Print one complete action plan marking each target as preserve or create.
7. For `--dry-run`, complete full prerequisite, resolved-parent, and destination preflight, then return after output; assert no parent directory or link was created.
8. Create only missing parents with `mkdir -p`; create links with non-forceful `ln -s`.
9. Record each link only after successful creation. Never record pre-existing correct links.
10. Call `verify.sh` with exact explicit selected-target flags, never its interactive mode.
11. On post-write failure, recheck each recorded path is still a link resolving to the current repo before removal. Do not remove parent directories.
12. Expand tests for success, idempotency, conflicts, parents, dry-run, spaces, mixed pre-existing/new targets, and deterministic rollback.
13. Trigger rollback tests using a stateful Herdr stub that succeeds during installer preflight and fails during verifier execution.

## Todo

- [x] Implement installer argument and prerequisite flow.
- [x] Implement all-target destination and parent-chain preflight.
- [x] Add preserve/create plan and zero-mutation dry-run.
- [x] Add non-forceful link creation and fixed-target rollback tracking.
- [x] Invoke standalone verifier after mutation.
- [x] Complete installer and end-to-end test matrix.
- [x] Run syntax, portability, mode, and full test gates.

## Validation

```sh
/bin/sh -n scripts/install.sh scripts/verify.sh scripts/lib/skill-install-common.sh tests/install-scripts-test.sh
/bin/sh tests/install-scripts-test.sh

test -x scripts/install.sh
test -x scripts/verify.sh
test -x tests/install-scripts-test.sh
test -r scripts/lib/skill-install-common.sh

if grep -R -n -E '\[\[|\]\]|(^|[[:space:]])function[[:space:]]|(^|[[:space:]])local[[:space:]]|readlink[[:space:]]+-f|pipefail|ln[[:space:]].*-f' scripts tests; then
  printf '%s\n' 'unexpected non-portable or forceful shell pattern' >&2
  exit 1
fi
```

Required test scenarios:

- Claude-only, Codex-only, and all-target success.
- Repeated installation and pre-existing correct link preservation.
- Wrong/broken links, files, directories, invalid parent chains, valid resolved parent symlinks, and broken/non-directory parent symlinks.
- Multi-target conflict with no normal partial installation.
- Missing/failing Herdr and missing selected runtime with zero mutation.
- Dry-run with no directory or link creation.
- Paths containing spaces and non-TTY omission.
- Post-install verification failure rollback.
- Mixed pre-existing correct plus newly created target preserves the former during rollback.

## Success Criteria

- [x] Installer implements exactly the agreed CLI and exit codes.
- [x] No conflict state is overwritten, deleted, or repaired.
- [x] All targets are preflighted before mutation.
- [x] Correct links remain unchanged across repeated runs.
- [x] Dry-run runs full preflight yet creates nothing; prerequisite failures also create nothing.
- [x] Valid resolved parent directories are supported without modifying their symlinks.

<!-- Updated: Validation Session 1 - full-preflight dry-run, strict help, and resolved parent-symlink contract -->
- [x] Installer reuses `verify.sh`; verification logic is not duplicated.
- [x] Rollback removes only validated links created by the current invocation.
- [x] Full dependency-free suite passes on current macOS `/bin/sh` (48 checks, 0 failures, 2026-07-19).

## Risk Assessment

| Risk | Mitigation |
|---|---|
| `--all` partially installs | Preflight both targets before first mutation. |
| Rollback deletes user content | Track fixed current-run links and revalidate before removal. |
| Dry-run creates parents | Return before all mutation calls; assert absent paths in tests. |
| Correct links get normalized | Treat correct as preserve-only; never call `ln` on them. |
| Tests touch real home | Pass temporary `HOME` and controlled `PATH` to every invocation. |

## Security Considerations

- No network execution, package installation, auth, integration, or config mutation.
- Never follow a conflict with replacement behavior.
- Avoid TOCTOU claims: revalidate tracked links immediately before rollback deletion.
- Do not claim transactional atomicity; document the bounded rollback behavior.

## Next Steps

Phase 3 updates documentation only after this phase's behavior and tests pass.
