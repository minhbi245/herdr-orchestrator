#!/bin/sh
# verify.sh — read-only verification of Herdr Orchestrator skill setup.
# Aggregates Herdr, runtime, and skill-link diagnostics for all requested
# targets and never creates, repairs, deletes, or chmods anything.
set -u

case $0 in
  */*) SKILL_SCRIPT_DIR=${0%/*} ;;
  *) SKILL_SCRIPT_DIR=. ;;
esac
SKILL_SCRIPT_DIR=$(CDPATH= cd -P -- "$SKILL_SCRIPT_DIR" && pwd -P) || exit 1
. "$SKILL_SCRIPT_DIR/lib/skill-install-common.sh"

skill_usage() {
  printf '%s\n' \
    'Usage: verify.sh [--claude | --codex | --all | --help]' \
    '' \
    'Read-only checks of the Herdr Orchestrator skill setup:' \
    '  - herdr is on PATH and "herdr --version" succeeds' \
    '  - each selected runtime command (claude, codex) is on PATH' \
    '  - each selected skill link resolves to this repository' \
    '' \
    'Options:' \
    '  --claude   Verify the Claude Code target (~/.claude/skills).' \
    '  --codex    Verify the Codex CLI target (~/.codex/skills).' \
    '  --all      Verify both targets.' \
    '  --help     Show this help. It must be the only argument.' \
    '' \
    'Without a target flag an interactive terminal is required: one detected' \
    'runtime is selected automatically; two detected runtimes present a' \
    'one-shot Claude/Codex/All menu. Non-interactive runs must pass a target.' \
    '' \
    'Exit codes: 0 all requested checks passed, 1 check failure, 2 usage error.'
}

skill_opt_help=0
skill_opt_target=
for skill_arg in "$@"; do
  case $skill_arg in
    --help)
      skill_opt_help=1
      ;;
    --claude|--codex|--all)
      if [ -n "$skill_opt_target" ]; then
        skill_err "error: only one target flag is allowed"
        exit 2
      fi
      skill_opt_target=${skill_arg#--}
      ;;
    --dry-run)
      skill_err "error: verify.sh has no --dry-run mode; it is always read-only"
      exit 2
      ;;
    *)
      skill_err "error: unknown argument: $skill_arg"
      skill_err "usage: verify.sh [--claude | --codex | --all | --help]"
      exit 2
      ;;
  esac
done

if [ "$skill_opt_help" -eq 1 ]; then
  if [ $# -ne 1 ]; then
    skill_err "error: --help must be the only argument"
    exit 2
  fi
  skill_usage
  exit 0
fi

SKILL_REPO_ROOT=$(CDPATH= cd -P -- "$SKILL_SCRIPT_DIR/.." && pwd -P) || exit 1
skill_validate_repo "$SKILL_REPO_ROOT" || exit 1
skill_validate_home || exit 1

skill_select_targets "$skill_opt_target" "verify.sh"
skill_select_rc=$?
if [ "$skill_select_rc" -ne 0 ]; then
  exit "$skill_select_rc"
fi

skill_fail=0

if skill_check_herdr; then
  skill_note "ok: herdr is installed and 'herdr --version' succeeds"
else
  skill_fail=1
fi

for skill_target in $SKILL_SELECTED; do
  if skill_check_runtime "$skill_target"; then
    skill_note "ok: runtime command '$skill_target' found on PATH"
  else
    skill_fail=1
  fi

  skill_dest=$(skill_target_dest "$skill_target")
  skill_state=$(skill_classify_dest "$skill_dest" "$SKILL_REPO_ROOT")
  case $skill_state in
    correct)
      skill_note "ok: $skill_target skill link resolves to this repository: $skill_dest"
      ;;
    missing)
      skill_err "fail: $skill_target skill link is missing: $skill_dest"
      skill_err "      run ./scripts/install.sh --$skill_target to create it"
      skill_fail=1
      ;;
    wrong)
      skill_err "fail: $skill_target destination is a symlink that does not resolve to this repository: $skill_dest"
      skill_err "      it was not modified; inspect it and remove it manually if it is unwanted"
      skill_fail=1
      ;;
    broken)
      skill_err "fail: $skill_target destination is a broken symlink: $skill_dest"
      skill_err "      it was not modified; inspect it and remove it manually if it is unwanted"
      skill_fail=1
      ;;
    file)
      skill_err "fail: $skill_target destination is an existing regular file: $skill_dest"
      skill_err "      it was not modified; move it away before installing"
      skill_fail=1
      ;;
    directory)
      skill_err "fail: $skill_target destination is an existing real directory: $skill_dest"
      skill_err "      it was not modified; move it away before installing"
      skill_fail=1
      ;;
    *)
      skill_err "fail: $skill_target destination has an unsupported filesystem type: $skill_dest"
      skill_err "      it was not modified; inspect it manually"
      skill_fail=1
      ;;
  esac
done

if [ "$skill_fail" -eq 0 ]; then
  skill_note "verify: all requested checks passed"
  exit 0
fi
skill_err "verify: one or more checks failed"
exit 1
