# Herdr Installer and Repository Upgrades Brainstorm

## Summary

Add a safe, split POSIX shell installer and verifier for the portable Herdr Orchestrator skill. Run both from an existing cloned checkout. Keep Herdr installation, repository updates, uninstall, authentication, provider setup, and integration mutation outside this round.

Agreed delivery sequence:

1. Split installer/verifier, tests, and documentation.
2. Dependency-free documentation validator.
3. Read-only operational doctor.
4. Compatibility report generator.
5. Evidence-based prompt recipe library.

## Problem

Current installation requires manual symlink commands in `README.md`:

```sh
ln -sfn "$PWD" ~/.claude/skills/herdr-orchestrator
ln -sfn "$PWD" ~/.codex/skills/herdr-orchestrator
```

This has three weaknesses:

- `-f` can replace an existing destination, conflicting with the desired no-overwrite safety contract.
- No automated prerequisite or installation-state verification exists.
- New users can install the skill without realizing Herdr is missing or that Herdr control must later run inside a Herdr-managed pane.

## Exact requirements

### Expected artifacts

Round 1:

```text
scripts/
├── install.sh
├── verify.sh
└── lib/
    └── skill-install-common.sh

tests/
└── install-scripts-test.sh
```

Update current setup and architecture documentation after behavior is implemented and verified.

### Supported environment

- POSIX `/bin/sh`.
- macOS and Linux.
- Existing cloned Herdr Orchestrator checkout.
- Existing `HOME` and standard POSIX filesystem tools.
- No package manifest or runtime dependency added.

### CLI contract

Installer:

```sh
./scripts/install.sh
./scripts/install.sh --claude
./scripts/install.sh --codex
./scripts/install.sh --all
./scripts/install.sh --dry-run --claude
./scripts/install.sh --dry-run --codex
./scripts/install.sh --dry-run --all
./scripts/install.sh --help
```

Verifier:

```sh
./scripts/verify.sh
./scripts/verify.sh --claude
./scripts/verify.sh --codex
./scripts/verify.sh --all
./scripts/verify.sh --help
```

`verify.sh` is the only verify entry point. Do not add an `install.sh --verify` alias because no backward-compatible contract exists yet.

Target flags are mutually exclusive. `--all` means Claude Code and Codex.

### Default target behavior

Without a target flag:

- Interactive TTY: detect `claude` and `codex`, then offer only installed runtimes.
- Non-interactive shell: exit with usage guidance rather than waiting for input.
- No detected runtime: fail without creating a directory or symlink.

If an explicitly selected runtime is not on `PATH`, fail that invocation without installing its skill link.

### Herdr prerequisite

Before any filesystem mutation:

1. Check `command -v herdr`.
2. Check `herdr --version` succeeds.
3. If missing or unusable, print official installation guidance and exit nonzero.

Verified official guidance on 2026-07-19:

- Documentation: <https://herdr.dev/docs/install/>
- Homebrew: `brew install herdr`
- Official installer: `curl -fsSL https://herdr.dev/install.sh | sh`

The repository installer must never execute these commands automatically.

Installer prerequisite checks are separate from Herdr control preflight. Installing or verifying the skill does not require `HERDR_ENV=1` or `herdr status --json`. Those checks remain mandatory before actual Herdr control actions.

### Installation destinations

```text
$HOME/.claude/skills/herdr-orchestrator
$HOME/.codex/skills/herdr-orchestrator
```

Create absolute symlinks to the physical cloned repository root.

### Conflict behavior

For every selected target:

| Existing state | Result |
|---|---|
| No destination | Eligible for installation. |
| Correct symlink to current repo | Idempotent success; preserve it. |
| Wrong symlink | Fail; do not replace. |
| Broken symlink | Fail; do not replace. |
| Regular file | Fail; do not replace. |
| Real directory | Fail; do not replace. |
| Invalid parent path | Fail; do not mutate other targets. |

Preflight all selected targets before mutation. Never use forceful link flags. If an unexpected later operation fails, remove only links created by the current invocation.

### Exit behavior

- `0`: requested install or verification completed successfully.
- `1`: prerequisite, conflict, filesystem, or verification failure.
- `2`: invalid command usage.

Errors go to stderr. Help and successful summaries go to stdout. Never print secrets or environment values unrelated to diagnosis.

## Evaluated approaches

### 1. Single multi-mode script

One `install.sh` implements install, verify, and dry-run.

**Advantages**

- Smallest file count.
- One parser and one target-selection flow.

**Disadvantages**

- Install and read-only verification contracts become coupled.
- Script grows harder to audit as more diagnostics appear.
- User rejected this approach in favor of explicit entry points.

### 2. Split installer and verifier with a small shared library

`install.sh` owns mutations, `verify.sh` remains read-only, and a focused library shares target/path logic.

**Advantages**

- Clear safety boundary.
- Verifier can be run independently after clone, upgrades, or troubleshooting.
- Shared path and detection behavior avoids drift.
- Future doctor remains a separate concern.

**Disadvantages**

- Three shell source files instead of one.
- Shared library interface must stay narrow.

**Decision:** selected.

### 3. Bootstrap and lifecycle installer

Automatically clone/update the repository, install Herdr, and support uninstall.

**Advantages**

- Fewer manual onboarding steps.

**Disadvantages**

- Expands network, supply-chain, Git ownership, dirty-tree, rollback, and deletion risks.
- Requires platform-specific package decisions.
- Violates the agreed first-round scope.

**Decision:** reject for this round.

## Detailed design

### `scripts/install.sh`

Responsibilities:

1. Parse target and `--dry-run` flags.
2. Resolve and validate the physical repository root.
3. Detect required binaries.
4. Select targets interactively or from explicit flags.
5. Preflight every parent and destination.
6. Print the planned actions.
7. Create missing parent directories and non-forceful symlinks unless dry-run.
8. Invoke `verify.sh` with explicit selected targets after mutation.
9. Roll back only links created by this invocation after an unexpected partial failure.

It must not clone, pull, update, uninstall, install external tools, or mutate integrations.

### `scripts/verify.sh`

Responsibilities:

1. Parse explicit targets or perform the same TTY selection behavior.
2. Validate repository markers.
3. Check Herdr and selected runtime availability.
4. Classify each destination state.
5. Confirm correct symlinks resolve to the physical current repository root.
6. Return a concise success summary or actionable failure.

It must remain read-only, including in failure cases.

### `scripts/lib/skill-install-common.sh`

Share only behavior required by both current entry points:

- Runtime and destination metadata.
- Portable physical-path resolution.
- Repository marker validation.
- Runtime detection.
- Target selection.
- Symlink classification.
- Common output and exit helpers.

Avoid GNU-only `readlink -f`; macOS does not provide it by default. Quote all paths and test repository paths containing spaces.

### Atomicity and rollback

POSIX shell cannot provide a filesystem transaction. Mitigate this by:

- Completing prerequisite and conflict checks for all targets first.
- Recording links created during the current run.
- Removing only those newly created links if a later selected target fails unexpectedly.
- Never touching pre-existing correct links during rollback.

## Validation

Use a dependency-free shell test with temporary `HOME` and stub executables on `PATH`.

Required cases:

1. `sh -n` succeeds for all shell files.
2. Help exits successfully without mutation.
3. Missing Herdr fails before creating directories or links.
4. Broken `herdr --version` fails before mutation.
5. Missing selected Claude/Codex runtime fails.
6. Claude-only install succeeds.
7. Codex-only install succeeds.
8. `--all` succeeds when both runtimes exist.
9. Repeated installation is idempotent.
10. Existing correct links remain unchanged.
11. Wrong and broken links are rejected.
12. Regular files and real directories are rejected.
13. Multi-target conflict causes no normal partial installation.
14. Dry-run produces no filesystem changes.
15. Verify reports each success and failure state accurately.
16. Repository and home paths containing spaces work.
17. Non-TTY invocation without a target exits instead of hanging.
18. Post-install verification failure rolls back only current-run links.

Run on both macOS `/bin/sh` and Linux POSIX `sh` before claiming both platforms as verified. `shellcheck` may be used when available but is not a required dependency.

## Documentation changes

Round 1 should update:

- `README.md`: replace forceful manual links with installer/verifier usage; retain a safe manual fallback.
- `docs/project-overview-pdr.md`: add setup utility requirements and explicit non-goals.
- `docs/codebase-summary.md`: add shell tooling and tests to the repository map.
- `docs/code-standards.md`: add POSIX portability, filesystem safety, and shell validation rules.
- `docs/system-architecture.md`: place setup tooling outside the Herdr runtime control plane.
- `docs/project-roadmap.md`: mark installer/verifier as the current next improvement and add accepted later initiatives.
- `references/herdr-control.md`: clarify installation checks versus Herdr control preflight.

Leave `SKILL.md` focused on orchestration unless setup itself later becomes a skill-handled workflow.

Reword current “documentation/configuration only” claims after shell tooling is added. Preserve these non-claims:

- No executable application runtime.
- No package manifest.
- No CI or deployment target.
- No UI or API.
- No selected license.

## Follow-up initiatives

### 1. Documentation validator

Add `scripts/validate-docs.sh` after Round 1 to check mechanical properties:

- README and evergreen-doc line limits.
- Relative Markdown file and anchor links.
- Trailing whitespace.
- `git diff --check`.

Source-claim accuracy still requires human review; do not pretend it can be fully automated.

### 2. Operational doctor

Add a separate read-only `scripts/doctor.sh`:

- Verify skill links and runtime availability.
- Report Herdr version.
- Outside a Herdr pane, report that operational status cannot be checked.
- Inside a pane, safely inspect `HERDR_ENV`, `herdr status --json`, and integration status.
- Never start/stop a server or install/modify integrations.

Keep installation verification and runtime health diagnosis separate.

### 3. Compatibility report

Add a read-only report command after doctor probes stabilize:

- Capture dated tool versions and safe help/capability observations.
- Print to stdout by default.
- Never mutate authentication, profiles, integrations, or evergreen docs automatically.
- Clearly distinguish local observations from guaranteed protocol rules.

### 4. Prompt recipes

Add concise recipes for:

- Read-only scout.
- Single writer.
- Read-only reviewer.
- Blocker follow-up.

Base examples on `references/worker-contract.md` and verified live-session behavior. Avoid fake package commands, broad authority, secrets, or implied CI.

## Risks and mitigations

| Risk | Mitigation |
|---|---|
| Existing README can overwrite destinations | Remove `ln -sfn`; document non-forceful fallback. |
| macOS lacks GNU path utilities | Use POSIX physical-directory resolution; test on both platforms. |
| Interactive command hangs in automation | Require target flag when no TTY. |
| `--all` partially installs | Preflight all targets; rollback only current-run links. |
| Installer confused with Herdr installer | Use explicit naming and guide-only missing-Herdr output. |
| Installer confused with Herdr control | Do not require `HERDR_ENV`; document control preflight separately. |
| Platform support overclaimed | Require actual macOS and Linux evidence before claiming verification. |
| Shell library grows into a framework | Share only current duplicate logic. |
| Official install instructions age | Link canonical docs and keep commands as dated observations. |
| Later initiatives inflate Round 1 | Track separately in roadmap and execute in phased order. |

## Success criteria

- Installer and verifier follow the agreed CLI contract.
- No conflict case overwrites or deletes pre-existing content.
- Missing prerequisites cause zero skill-link mutations.
- Correct installations are idempotent.
- Verify is read-only and accurately classifies every target state.
- Dry-run makes zero filesystem changes.
- Test matrix passes on macOS and Linux POSIX shells.
- README no longer recommends forceful symlink replacement.
- Documentation accurately separates setup checks from Herdr control preflight.
- README remains under 300 lines; evergreen docs remain under 800 lines.
- Markdown links and `git diff --check` pass.

## Dependencies and sequence

1. Implement and validate installer/verifier.
2. Update setup and architecture docs from verified behavior.
3. Add documentation validator.
4. Add operational doctor.
5. Build compatibility report on proven doctor probes.
6. Add prompt recipes using verified worker contracts and live-session evidence.

## Research notes

- Official Herdr installation documentation was checked on 2026-07-19.
- Documentation-impact review completed successfully.
- An independent planner run failed before analysis because its configured model provider returned HTTP 502. It was not retried with the same prompt; no required design evidence depended on it.

## Unresolved questions

None for Round 1.
