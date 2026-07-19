#!/bin/sh
# install.sh — create Herdr Orchestrator skill links safely.
# Preflights every selected target before the first filesystem mutation,
# never replaces existing content, and rolls back only links created by
# the current invocation when post-install verification fails.
set -u

case $0 in
  */*) SKILL_SCRIPT_DIR=${0%/*} ;;
  *) SKILL_SCRIPT_DIR=. ;;
esac
SKILL_SCRIPT_DIR=$(CDPATH= cd -P -- "$SKILL_SCRIPT_DIR" && pwd -P) || exit 1
. "$SKILL_SCRIPT_DIR/lib/skill-install-common.sh"

skill_usage() {
  printf '%s\n' \
    'Usage: install.sh [--claude | --codex | --all] [--dry-run]' \
    '       install.sh --help' \
    '' \
    'Creates absolute symlinks from runtime skill directories to this' \
    'repository checkout:' \
    '  claude: ~/.claude/skills/herdr-orchestrator' \
    '  codex:  ~/.codex/skills/herdr-orchestrator' \
    '' \
    'Options:' \
    '  --claude   Install the Claude Code skill link.' \
    '  --codex    Install the Codex CLI skill link.' \
    '  --all      Install both targets.' \
    '  --dry-run  Run the full prerequisite and conflict preflight, print the' \
    '             action plan, and exit without creating anything.' \
    '  --help     Show this help. It must be the only argument.' \
    '' \
    'Safety contract: existing files, directories, wrong links, and broken' \
    'links are never replaced or deleted; conflicts fail the run before any' \
    'directory or link is created. Correct existing links are preserved.' \
    '' \
    'Without a target flag an interactive terminal is required: one detected' \
    'runtime is selected automatically; two detected runtimes present a' \
    'one-shot Claude/Codex/All menu. Non-interactive runs must pass a target.' \
    '' \
    'Exit codes: 0 success, 1 prerequisite/conflict/verification failure,' \
    '2 usage error.'
}

skill_opt_help=0
skill_opt_target=
skill_opt_dry=0
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
      if [ "$skill_opt_dry" -eq 1 ]; then
        skill_err "error: duplicate --dry-run flag"
        exit 2
      fi
      skill_opt_dry=1
      ;;
    *)
      skill_err "error: unknown argument: $skill_arg"
      skill_err "usage: install.sh [--claude | --codex | --all] [--dry-run] | --help"
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

skill_select_targets "$skill_opt_target" "install.sh"
skill_select_rc=$?
if [ "$skill_select_rc" -ne 0 ]; then
  exit "$skill_select_rc"
fi

# Prerequisites: require usable herdr plus every selected runtime before any
# directory or link is created. All failures are reported before exiting.
skill_prereq_fail=0
if skill_check_herdr; then
  skill_note "ok: herdr is installed and 'herdr --version' succeeds"
else
  skill_prereq_fail=1
fi
for skill_target in $SKILL_SELECTED; do
  if skill_check_runtime "$skill_target"; then
    skill_note "ok: runtime command '$skill_target' found on PATH"
  else
    skill_prereq_fail=1
  fi
done
if [ "$skill_prereq_fail" -ne 0 ]; then
  skill_err "install: prerequisite checks failed; nothing was created"
  exit 1
fi

# Validate the ancestor chain of a missing destination without modifying it.
# Parent symlinks are allowed only when they resolve to directories; the
# first existing ancestor must be a writable directory because creation is
# required. Broken links and non-directories in the chain are fatal.
skill_check_parent_chain() {
  skill_pc_path=${1%/*}
  while [ ! -e "$skill_pc_path" ]; do
    if [ -L "$skill_pc_path" ]; then
      skill_err "fail: parent path is a broken symlink: $skill_pc_path"
      return 1
    fi
    case $skill_pc_path in
      */*) skill_pc_next=${skill_pc_path%/*} ;;
      *) skill_err "fail: invalid parent path for: $1"; return 1 ;;
    esac
    if [ -z "$skill_pc_next" ] || [ "$skill_pc_next" = "$skill_pc_path" ]; then
      skill_err "fail: no existing parent directory found for: $1"
      return 1
    fi
    skill_pc_path=$skill_pc_next
  done
  if [ ! -d "$skill_pc_path" ]; then
    skill_err "fail: parent path component is not a directory: $skill_pc_path"
    return 1
  fi
  if [ ! -w "$skill_pc_path" ]; then
    skill_err "fail: parent directory is not writable: $skill_pc_path"
    return 1
  fi
  return 0
}

# Destination preflight for every selected target before the first mutation.
skill_state_claude=
skill_state_codex=
skill_conflict=0
for skill_target in $SKILL_SELECTED; do
  skill_dest=$(skill_target_dest "$skill_target")
  skill_state=$(skill_classify_dest "$skill_dest" "$SKILL_REPO_ROOT")
  case $skill_state in
    correct)
      ;;
    missing)
      skill_check_parent_chain "$skill_dest" || skill_conflict=1
      ;;
    wrong)
      skill_err "fail: $skill_target destination is a symlink that does not resolve to this repository: $skill_dest"
      skill_conflict=1
      ;;
    broken)
      skill_err "fail: $skill_target destination is a broken symlink: $skill_dest"
      skill_conflict=1
      ;;
    file)
      skill_err "fail: $skill_target destination is an existing regular file: $skill_dest"
      skill_conflict=1
      ;;
    directory)
      skill_err "fail: $skill_target destination is an existing real directory: $skill_dest"
      skill_conflict=1
      ;;
    *)
      skill_err "fail: $skill_target destination has an unsupported filesystem type: $skill_dest"
      skill_conflict=1
      ;;
  esac
  case $skill_target in
    claude) skill_state_claude=$skill_state ;;
    codex) skill_state_codex=$skill_state ;;
  esac
done
if [ "$skill_conflict" -ne 0 ]; then
  skill_err "install: conflicting destinations were left untouched; nothing was created"
  exit 1
fi

skill_state_for() {
  case $1 in
    claude) printf '%s\n' "$skill_state_claude" ;;
    codex) printf '%s\n' "$skill_state_codex" ;;
  esac
}

# One complete action plan covering every selected target.
for skill_target in $SKILL_SELECTED; do
  skill_dest=$(skill_target_dest "$skill_target")
  case $(skill_state_for "$skill_target") in
    correct)
      skill_note "plan: $skill_target: preserve existing correct link: $skill_dest"
      ;;
    missing)
      skill_note "plan: $skill_target: create link: $skill_dest -> $SKILL_REPO_ROOT"
      ;;
  esac
done

if [ "$skill_opt_dry" -eq 1 ]; then
  skill_note "dry-run: full preflight passed; no directories or links were created"
  exit 0
fi

skill_created_claude=0
skill_created_codex=0

# Remove only links created by the current invocation, and only after
# revalidating that each recorded path is still a link resolving to this
# repository. Parent directories are never removed.
skill_rollback() {
  for skill_rb_target in claude codex; do
    case $skill_rb_target in
      claude) [ "$skill_created_claude" -eq 1 ] || continue ;;
      codex) [ "$skill_created_codex" -eq 1 ] || continue ;;
    esac
    skill_rb_dest=$(skill_target_dest "$skill_rb_target")
    if [ "$(skill_classify_dest "$skill_rb_dest" "$SKILL_REPO_ROOT")" = "correct" ]; then
      if rm -- "$skill_rb_dest"; then
        skill_err "rollback: removed link created by this run: $skill_rb_dest"
      else
        skill_err "rollback: could not remove $skill_rb_dest; remove it manually"
      fi
    else
      skill_err "rollback: $skill_rb_dest no longer matches the link created by this run; left untouched"
    fi
  done
}

skill_fail_and_rollback() {
  skill_err "$1"
  skill_rollback
  skill_err "install: failed; links created by this run were rolled back"
  exit 1
}

for skill_target in $SKILL_SELECTED; do
  if [ "$(skill_state_for "$skill_target")" != "missing" ]; then
    continue
  fi
  skill_dest=$(skill_target_dest "$skill_target")
  skill_parent=${skill_dest%/*}
  if ! mkdir -p -- "$skill_parent"; then
    skill_fail_and_rollback "fail: could not create parent directory: $skill_parent"
  fi
  if ! ln -s -- "$SKILL_REPO_ROOT" "$skill_dest"; then
    skill_fail_and_rollback "fail: could not create link: $skill_dest"
  fi
  case $skill_target in
    claude) skill_created_claude=1 ;;
    codex) skill_created_codex=1 ;;
  esac
  skill_note "created: $skill_dest -> $SKILL_REPO_ROOT"
done

if [ "$SKILL_SELECTED" = "claude codex" ]; then
  skill_verify_flag=--all
else
  skill_verify_flag=--$SKILL_SELECTED
fi
if "$SKILL_SCRIPT_DIR/verify.sh" "$skill_verify_flag"; then
  skill_note "install: all requested targets are installed and verified"
  exit 0
fi
skill_fail_and_rollback "fail: post-install verification failed"
