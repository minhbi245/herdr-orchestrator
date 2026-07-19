# Worker Contract

## Identity and authority

Write the prompt as a direct instruction from the user. Do not announce an intermediary, controller hierarchy, or hidden delegation unless the user asks for that model.

This convention applies only to private coding-agent interaction. Never instruct a worker to impersonate the user to people, publish statements, approve actions, or claim decisions the user did not make.

The worker receives execution authority only for the stated task, paths, tools, and validation. The controller retains product decisions, approvals, integration, and final accountability.

## Required prompt fields

Include:

- One bounded task and expected deliverable.
- Exact paths to read.
- Exact paths or globs the worker may modify, or `none — read-only`.
- Observable acceptance criteria.
- Required validation commands.
- Explicit user decisions and public contracts to preserve.
- Out-of-scope areas and prohibited external actions.
- Current date/time, timezone, CWD, OS, user, locale, and relevant resource limits.
- Runtime host and provider when the worker uses a CCS profile.
- Absolute work context and report path when a durable artifact is required.
- Final status protocol.

## Prompt template

```text
Task: <one bounded outcome>

Read:
- <absolute or project-relative path>

May modify:
- <exact path/glob, or "none — read-only">

Acceptance criteria:
- <observable result>
- <required check and expected outcome>

Constraints:
- Preserve <explicit decision or contract>.
- Do not modify <out-of-scope area>.
- Do not commit, merge, push, publish, deploy, or contact external systems unless explicitly authorized.
- Do not expose secrets, environment-secret values, credentials, personal data, or private keys.

Environment:
- Date/time and timezone: <current values>
- CWD: <absolute worker checkout/worktree>
- OS/user/locale: <current values>
- Runtime: <native CLI, or host CLI via CCS profile and provider>
- Resource constraints: <only relevant limits>

Work context: <absolute path>
Reports: <absolute path, or "none">

If blocked, state the missing fact or authority and stop at a safe point.

End with:
Status: DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
Summary: one or two sentences
Concerns/Blockers: optional
```

## Prompt quality rules

- Prefer exact paths over “look around the repo,” unless scouting is the task.
- Provide decisions, not the controller's internal deliberation.
- Provide the smallest context that lets the worker succeed.
- State whether the worker is advisory, read-only, or allowed to write.
- Name the expected artifact instead of asking for a generic report.
- Give read-only reviewers the accepted scope so they review the intended contract.
- Do not leak another worker's full transcript; summarize only relevant evidence.
- Do not include shell-interpretable secrets or construct prompt commands with unsafe interpolation.

## Naming

Use stable responsibility names:

- `auth-scout`
- `api-implementer`
- `migration-reviewer`
- `test-runner`

Avoid positional names such as `agent-1`. Reuse a worker only for a coherent follow-up to its existing context; create a new role for an unrelated task.

## Blocker responses

When a worker asks a question, send one of:

- Verified repository fact with its source path.
- Exact prior user decision.
- Small reversible implementation choice within assigned scope.
- Revised scope explicitly approved by the user.

If none applies, surface the question to the user. Do not guess.

## Completion interpretation

Treat the final status as routing metadata:

- `DONE`: claimed deliverable complete; verification still required.
- `DONE_WITH_CONCERNS`: verify deliverable and assess each concern.
- `BLOCKED`: authority or external state prevents completion.
- `NEEDS_CONTEXT`: controller omitted necessary task-local information.

Never convert a worker status into user-facing success without evidence.
