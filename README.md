# Herdr Orchestrator

Portable orchestration skill for managing persistent coding agents through [Herdr](https://herdr.dev/). It keeps one controller accountable for user intent, approvals, verification, and integration while Herdr manages interactive worker panes and lifecycle.

## Requirements

- Herdr installed and available as `herdr`.
- Claude Code or Codex CLI.
- The controller must run inside a Herdr-managed pane before it performs Herdr control actions.

## Installation

Clone the repository and link the repository root into the skill directory for the runtime you use:

```bash
git clone https://github.com/minhbi245/herdr-orchestrator.git
cd herdr-orchestrator

mkdir -p ~/.claude/skills ~/.codex/skills
ln -sfn "$PWD" ~/.claude/skills/herdr-orchestrator
ln -sfn "$PWD" ~/.codex/skills/herdr-orchestrator
```

Install either link or both. They point to the same portable source.

## Usage

- Claude Code: invoke `/herdr-orchestrator`.
- Codex CLI: invoke `$herdr-orchestrator`.
- The skill may also activate for explicit Herdr delegation, monitoring, blocked-agent handling, or session resumption requests.

Before any control action, the skill verifies that it is running inside Herdr:

```bash
test "${HERDR_ENV:-}" = 1
herdr --version
herdr status --json
```

If `HERDR_ENV=1` is absent, launch the controller from a Herdr pane instead of controlling a focused session from an unrelated shell.

## Design principles

- One controller remains authoritative for scope, approvals, integration, and the final report.
- Workers receive bounded direct instructions with exact ownership and acceptance criteria.
- Read-only workers may share a checkout; concurrent writers use isolated worktrees or run sequentially.
- Worker completion is an unverified handoff until the controller checks the transcript, diff, and tests.
- External communication, destructive actions, secrets, and material scope changes require user authority.
- Herdr is used for persistent interactive panes; it is not added to small, tightly coupled tasks without a concrete benefit.

## Repository structure

```text
.
├── SKILL.md                 # Portable skill entry point
├── agents/                  # Runtime interface metadata
├── references/              # Focused control and policy references
├── docs/                    # Expanded operating instructions
└── plans/                   # Original research and implementation records
```

Generated package archives are kept locally under `assets/generated/` and excluded from Git.

## Documentation

- [Portable skill](SKILL.md)
- [Expanded instructions](docs/herdr-orchestrator-instructions.md)
- [Herdr control reference](references/herdr-control.md)
- [Routing policy](references/routing-policy.md)
- [Runtime profiles](references/runtime-profiles.md)
- [Worker contract](references/worker-contract.md)
- [Verification and recovery](references/verification-and-recovery.md)
- [Research report](plans/reports/research-260718-2312-herdr-orchestrator.md)

## License

No license has been selected. Copyright and reuse permissions remain with the repository owner unless a license is added later.
