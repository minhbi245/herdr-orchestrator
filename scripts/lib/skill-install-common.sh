# skill-install-common.sh — shared contract for install.sh and verify.sh.
# POSIX /bin/sh. Sourced only: defines constants and helpers, executes nothing.
# Shares only behavior needed by both entry points; installer mutations and
# parent-chain rules stay in install.sh.

SKILL_LINK_NAME="herdr-orchestrator"

skill_note() { printf '%s\n' "$*"; }
skill_err() { printf '%s\n' "$*" >&2; }

# Validate that the resolved repository root carries the expected markers.
skill_validate_repo() {
  skill_vr_ok=0
  if [ ! -e "$1/.git" ]; then
    skill_err "error: missing repository marker: .git under $1"
    skill_vr_ok=1
  fi
  if [ ! -f "$1/SKILL.md" ]; then
    skill_err "error: missing repository marker: SKILL.md under $1"
    skill_vr_ok=1
  fi
  if [ ! -f "$1/references/herdr-control.md" ]; then
    skill_err "error: missing repository marker: references/herdr-control.md under $1"
    skill_vr_ok=1
  fi
  return "$skill_vr_ok"
}

# Require HOME to name an existing directory without echoing its value.
skill_validate_home() {
  if [ -z "${HOME:-}" ] || [ ! -d "${HOME:-}" ]; then
    skill_err "error: HOME must be set to an existing directory"
    return 1
  fi
}

# Print the fixed skill-link destination for a target.
skill_target_dest() {
  case $1 in
    claude) printf '%s\n' "$HOME/.claude/skills/$SKILL_LINK_NAME" ;;
    codex) printf '%s\n' "$HOME/.codex/skills/$SKILL_LINK_NAME" ;;
    *) return 1 ;;
  esac
}

skill_runtime_detected() { command -v "$1" >/dev/null 2>&1; }

skill_check_runtime() {
  if skill_runtime_detected "$1"; then
    return 0
  fi
  skill_err "error: required runtime command '$1' not found on PATH"
  return 1
}

# Print manual Herdr installation guidance. Never executed by these scripts.
skill_print_herdr_guidance() {
  skill_err "Install Herdr manually before continuing:"
  skill_err "  docs:     https://herdr.dev/docs/install/"
  skill_err "  homebrew: brew install herdr"
  skill_err "  official: curl -fsSL https://herdr.dev/install.sh | sh"
  skill_err "This script never runs those commands for you."
}

# Require a usable herdr command. Setup only needs 'herdr --version';
# HERDR_ENV and 'herdr status --json' belong to Herdr control preflight.
skill_check_herdr() {
  if ! command -v herdr >/dev/null 2>&1; then
    skill_err "error: herdr not found on PATH"
    skill_print_herdr_guidance
    return 1
  fi
  if ! herdr --version >/dev/null 2>&1; then
    skill_err "error: 'herdr --version' failed; the installed herdr is unusable"
    skill_print_herdr_guidance
    return 1
  fi
}

# Classify a destination path against the physical repository root.
# Prints exactly one of: missing correct wrong broken file directory other.
# Symlink identity is tested before ordinary file/directory tests so broken
# and wrong links are never conflated with plain files.
skill_classify_dest() {
  if [ -L "$1" ]; then
    if [ ! -e "$1" ]; then
      printf 'broken\n'
    elif [ -d "$1" ]; then
      skill_cd_resolved=$(CDPATH= cd -P -- "$1" 2>/dev/null && pwd -P)
      if [ "$skill_cd_resolved" = "$2" ]; then
        printf 'correct\n'
      else
        printf 'wrong\n'
      fi
    else
      printf 'wrong\n'
    fi
  elif [ ! -e "$1" ]; then
    printf 'missing\n'
  elif [ -f "$1" ]; then
    printf 'file\n'
  elif [ -d "$1" ]; then
    printf 'directory\n'
  else
    printf 'other\n'
  fi
}

# Map one bounded interactive menu reply to a target keyword.
# Pure logic with no reads or writes so tests can call it directly.
skill_menu_selection() {
  case $1 in
    1|claude) printf 'claude\n' ;;
    2|codex) printf 'codex\n' ;;
    3|all) printf 'all\n' ;;
    *) return 1 ;;
  esac
}

# Resolve the requested target set into SKILL_SELECTED.
# $1: explicit target keyword or empty. $2: script name for usage hints.
# Returns 0 on success, 1 when no runtime is detected, 2 on usage errors.
# Reads stdin at most once, and only on a TTY with both runtimes detected.
skill_select_targets() {
  case $1 in
    claude) SKILL_SELECTED=claude; return 0 ;;
    codex) SKILL_SELECTED=codex; return 0 ;;
    all) SKILL_SELECTED="claude codex"; return 0 ;;
  esac
  if [ ! -t 0 ]; then
    skill_err "error: no target selected and no interactive terminal is available"
    skill_err "usage: $2 [--claude | --codex | --all]"
    return 2
  fi
  skill_st_claude=0
  skill_st_codex=0
  skill_runtime_detected claude && skill_st_claude=1
  skill_runtime_detected codex && skill_st_codex=1
  if [ "$skill_st_claude" -eq 0 ] && [ "$skill_st_codex" -eq 0 ]; then
    skill_err "error: neither 'claude' nor 'codex' was found on PATH; no target to select"
    return 1
  fi
  if [ "$skill_st_claude" -eq 1 ] && [ "$skill_st_codex" -eq 0 ]; then
    SKILL_SELECTED=claude
    skill_note "Auto-selected target: claude (only detected runtime)"
    return 0
  fi
  if [ "$skill_st_codex" -eq 1 ] && [ "$skill_st_claude" -eq 0 ]; then
    SKILL_SELECTED=codex
    skill_note "Auto-selected target: codex (only detected runtime)"
    return 0
  fi
  skill_err "Both runtimes were detected. Choose a target:"
  skill_err "  1) claude - $HOME/.claude/skills/$SKILL_LINK_NAME"
  skill_err "  2) codex  - $HOME/.codex/skills/$SKILL_LINK_NAME"
  skill_err "  3) all    - both targets"
  printf 'Selection (1/2/3): ' >&2
  if ! read -r skill_st_reply; then
    skill_err "error: could not read a selection"
    return 2
  fi
  skill_st_choice=$(skill_menu_selection "$skill_st_reply") || {
    skill_err "error: invalid selection '$skill_st_reply' (expected 1, 2, 3, claude, codex, or all)"
    return 2
  }
  case $skill_st_choice in
    all) SKILL_SELECTED="claude codex" ;;
    *) SKILL_SELECTED=$skill_st_choice ;;
  esac
  return 0
}
