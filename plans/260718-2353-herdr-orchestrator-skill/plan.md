---
title: Herdr Orchestrator Skill
status: complete
created: 2026-07-18T23:53:10+07:00
---

# Herdr Orchestrator Skill

## Overview

Create one portable skill source for Codex and Claude Code. Keep one controller authoritative, use Herdr for persistent interactive workers, and route batch or team workflows only when justified.

## Phases

1. **Source package** — scaffold the standalone repository, write concise core instructions and focused references.
2. **Validation** — validate metadata, structure, size, Herdr 0.7.4 commands, security boundaries, and cross-runtime compatibility.
3. **Installation** — link the same source into Codex and Claude global skill discovery paths, then verify targets.

## Dependencies

- Installed Herdr `0.7.4`.
- Codex and Claude Code skill discovery directories.
- Existing research: [Herdr Orchestrator Research](../reports/research-260718-2312-herdr-orchestrator.md).

## Acceptance criteria

- `SKILL.md` contains only portable `name` and `description` frontmatter.
- `SKILL.md` and each reference stay below 300 lines.
- Outside-Herdr use stops before control actions.
- Routing prevents unnecessary delegation and nested orchestrators.
- Worker prompts preserve user intent without inventing user authority.
- Parallel writers use isolated worktrees or run sequentially.
- Worker completion remains subject to controller verification.
- Codex and Claude Code resolve the same canonical source.

## Validation

- Claude/AgentKit `quick_validate.py`: passed for source, Codex link, and Claude link.
- Portable YAML parse: passed; frontmatter contains only `name` and `description`.
- Size limits: `SKILL.md` 145 lines; every reference below 300 lines.
- Local package artifact: `assets/generated/herdr-orchestrator.zip` (excluded from Git).
- Installed runtimes: Codex CLI `0.144.5`, Claude Code `2.1.214`, Herdr `0.7.4`.
- Codex system validator could not start because its Python environment lacks the `yaml` module; equivalent metadata checks and the independent validator passed.
