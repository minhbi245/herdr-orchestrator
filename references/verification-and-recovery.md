# Verification and Recovery

## Acceptance gate

Treat worker completion as a handoff. Before acceptance:

1. Read the final transcript and status block.
2. Inspect every claimed file and diff.
3. Confirm changes stay inside assigned ownership.
4. Run the narrowest relevant test or check.
5. Broaden to lint, typecheck, build, integration, or public-contract tests when shared behavior changed.
6. Reject fake behavior, hidden failures, weakened tests, scope creep, unsupported claims, and reversed user decisions.
7. Use an independent read-only reviewer for high-risk, cross-module, security-sensitive, or public-contract changes.
8. Integrate only accepted work.

Record exact failures. Never hide a failing command or redefine success to match worker output.

## Evidence hierarchy

Prefer evidence in this order:

1. Focused test or empirical reproduction.
2. Diff and source inspection.
3. Build, lint, typecheck, or integration output.
4. Primary documentation for unstable APIs.
5. Worker explanation.

Do not reverse a verified decision because another worker raises an abstract concern without new evidence.

## Timeout recovery

A timeout is an observation failure, not proof of task failure.

1. Run `herdr agent get <target>`.
2. Read recent unwrapped output.
3. Check for `blocked`, `unknown`, `working`, `idle`, or `done`.
4. Run `herdr agent explain <target> --json` if detection conflicts with the screen.
5. Check files or processes for partial work.
6. Continue from observed state.

Do not silently retry or resend the original task. Duplicate prompts can create duplicate edits or conflicting actions.

## Blocked recovery

Classify the blocker:

- Missing repository fact: inspect and answer with evidence.
- Missing task context: supply only the omitted context.
- Existing user decision: restate it exactly.
- Routine reversible implementation detail: choose the smallest in-scope option.
- Product judgment, permission, secret, external action, destructive action, or scope expansion: ask the user.

Preserve the worker pane while waiting for the user.

## Interrupted controller recovery

Reconstruct live state instead of relying on memory:

```bash
herdr status --json
herdr api snapshot
herdr agent list
herdr workspace list
herdr pane list --workspace <workspace-id>
herdr worktree list --cwd <repo-path> --json
```

Match workers by descriptive agent name, pane metadata, CWD, worktree branch, and transcript. Treat ambiguous ownership as unowned until verified.

Do not close resources merely because the original controller context was lost.

## Writer integration

Before integrating an isolated writer:

- Verify its branch and worktree path.
- Inspect the complete diff against the assigned base.
- Run focused validation inside the worker worktree.
- Identify generated files, migrations, lockfiles, shared config, and public contracts requiring serialization or manual review.
- Preserve pre-existing user changes in the controller checkout.
- Resolve design conflicts explicitly; do not treat them as mechanical merge noise.

Merging, cherry-picking, committing, pushing, or deleting a branch requires the authority granted for the user task. Do not infer it from permission to implement.

## Failed worker

Keep the transcript and partial work long enough to diagnose the failure. Report:

- Worker role and target.
- Last observed state.
- Completed artifacts.
- Exact error or missing authority.
- Whether partial changes remain and where.
- Safe continuation options.

Replace a worker only after confirming the original cannot continue. Give the replacement current evidence, not the entire failed transcript.

## Cleanup

Maintain ownership for every created pane, tab, workspace, and worktree.

Clean only after result verification and follow-up completion:

- Close disposable command panes created for the task.
- Retain useful worker panes when further review or user decisions remain.
- Remove accepted or discarded task worktrees only when safe.
- Never use forced removal for convenience.
- Never stop the server or delete a session as ordinary cleanup.

Report all retained branches, worktrees, or long-running panes that matter to the user.

## Final report

Synthesize worker results; do not dump transcripts. Include:

- Outcome and affected contracts.
- Files or artifacts changed.
- Validation commands and results.
- Material worker concerns accepted or rejected, with evidence.
- Failures, blockers, and unresolved user decisions.
- Retained runtime resources.

Remain accountable for the result. The user should not need to reconstruct the internal worker topology to understand completion.
