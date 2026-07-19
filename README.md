# Herdr Orchestrator

Portable AgentKit skill for managing persistent coding-agent panes through [Herdr](https://herdr.dev/). One controller keeps authority for user intent, approvals, verification, integration, and final reporting while Herdr owns interactive panes, lifecycle, monitoring, and worktree isolation.

This repository contains the portable skill source plus POSIX shell setup utilities and their dependency-free tests. It does not contain an application runtime, package manifest, CI, deployment target, or selected license.

## Requirements

Setup — installing or verifying the skill links — needs:

- Herdr installed and usable as `herdr` (`herdr --version` succeeds).
- Claude Code (`claude`) and/or Codex CLI (`codex`) on `PATH`.

Setup runs from an ordinary shell. It does not need `HERDR_ENV=1` and never runs `herdr status --json`.

Herdr control is stricter: the controller must run inside a Herdr-managed pane before it performs Herdr control actions. Before any Herdr control action, verify:

```bash
test "${HERDR_ENV:-}" = 1
herdr --version
herdr status --json
```

If `HERDR_ENV=1` is absent, launch the controller from a Herdr pane instead of controlling a focused session from an unrelated shell.

## Installation

Run the installer from an existing clone. It preflights every selected target before touching the filesystem and never replaces existing files, directories, or links; conflicts fail with a diagnostic instead.

```bash
git clone https://github.com/minhbi245/herdr-orchestrator.git
cd herdr-orchestrator

./scripts/install.sh --claude        # Claude Code link only
./scripts/install.sh --codex         # Codex CLI link only
./scripts/install.sh --all           # both links
./scripts/install.sh --dry-run --all # full preflight and plan, no changes
./scripts/install.sh --help          # complete CLI and safety contract
```

Both targets link the same portable source:

- `~/.claude/skills/herdr-orchestrator`
- `~/.codex/skills/herdr-orchestrator`

Without a target flag, an interactive terminal is required: the installer auto-selects the only detected runtime, or offers a one-shot Claude/Codex/All menu when both are detected. Non-interactive runs must pass a target flag or they exit with usage guidance.

Check an installation at any time with the read-only verifier, which aggregates Herdr, runtime, and link diagnostics without mutating anything:

```bash
./scripts/verify.sh --all
```

Manual fallback, if you prefer explicit commands — `ln -s` fails instead of replacing an existing destination:

```bash
mkdir -p ~/.claude/skills
ln -s "$PWD" ~/.claude/skills/herdr-orchestrator
```

If the destination already exists, inspect it and move it aside yourself; do not force-replace it.

The setup utilities are covered by a dependency-free test suite:

```bash
/bin/sh tests/install-scripts-test.sh
```

## Usage

- Claude Code: invoke `/herdr-orchestrator`.
- Codex CLI: invoke `$herdr-orchestrator`.
- The skill may also activate for explicit Herdr delegation, monitoring, blocked-agent handling, or session resumption requests.

Use Herdr when persistent interactive panes, follow-ups, visibility, or isolation materially help. Keep small tightly coupled tasks in the controller session.

## Operating model

- AgentKit selects skills and workflow stages.
- Herdr manages panes, prompts, lifecycle state, monitoring, and worktrees.
- CCS only launches an already-configured provider/profile inside a pane.
- One primary execution backend owns each stage: direct controller work, Herdr worker, headless orchestrator, or real agent team.
- Worker `DONE` is a handoff, not accepted work; the controller verifies transcripts, diffs, and checks before reporting success.

## Repository structure

```text
.
├── SKILL.md                 # Portable skill entry point
├── agents/                  # Runtime interface metadata
├── references/              # Focused control and policy references
├── docs/                    # Evergreen documentation and expanded instructions
├── scripts/                 # Safe skill installer and read-only verifier
│   └── lib/                 # Shared target/path contract for both scripts
├── tests/                   # Dependency-free shell tests for the scripts
└── plans/                   # Historical research and implementation records
```

Generated package archives may exist locally under `assets/generated/` and are excluded from Git.

## Documentation

Evergreen docs:

- [Project overview and PDR](docs/project-overview-pdr.md)
- [Codebase summary](docs/codebase-summary.md)
- [Code standards](docs/code-standards.md)
- [System architecture](docs/system-architecture.md)
- [Project roadmap](docs/project-roadmap.md)
- [Expanded operating instructions](docs/herdr-orchestrator-instructions.md)

Source references:

- [Portable skill](SKILL.md)
- [Herdr control reference](references/herdr-control.md)
- [Routing policy](references/routing-policy.md)
- [Runtime profiles](references/runtime-profiles.md)
- [Worker contract](references/worker-contract.md)
- [Verification and recovery](references/verification-and-recovery.md)

Historical records:

- [Initial implementation plan](plans/260718-2353-herdr-orchestrator-skill/plan.md)
- [Research report](plans/reports/research-260718-2312-herdr-orchestrator.md)

## Compatibility notes

Existing docs record verification against Herdr `0.7.4` protocol `16` and CCS `8.8.1` on 2026-07-19. The historical plan records Codex CLI `0.144.5` and Claude Code `2.1.214` at validation time. Treat these as time-bound observations and re-check local `--help` output after upgrades.

## License

No license has been selected. Copyright and reuse permissions remain with the repository owner unless a license is added later.
