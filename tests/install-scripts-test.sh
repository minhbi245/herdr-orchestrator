#!/bin/sh
# install-scripts-test.sh — dependency-free tests for install.sh and verify.sh.
# Every script invocation runs with an isolated fixture HOME, a controlled
# PATH (stub herdr/claude/codex plus a minimal tool directory), stdin from
# /dev/null, and separate stdout/stderr capture. Real skill directories and
# developer-installed runtimes are unreachable by construction.
set -u

case $0 in
  */*) TEST_SELF_DIR=${0%/*} ;;
  *) TEST_SELF_DIR=. ;;
esac
TEST_SELF_DIR=$(CDPATH= cd -P -- "$TEST_SELF_DIR" && pwd -P) || exit 1
REPO_ROOT=$(CDPATH= cd -P -- "$TEST_SELF_DIR/.." && pwd -P) || exit 1
INSTALL="$REPO_ROOT/scripts/install.sh"
VERIFY="$REPO_ROOT/scripts/verify.sh"
COMMON="$REPO_ROOT/scripts/lib/skill-install-common.sh"

BASE=$(mktemp -d "${TMPDIR:-/tmp}/herdr-skill-tests.XXXXXX") || exit 1
trap 'rm -rf "$BASE"' EXIT
# Canonicalize so expected paths match the physical paths the scripts print
# (macOS /var is a symlink to /private/var).
BASE=$(CDPATH= cd -P -- "$BASE" && pwd -P) || exit 1
trap 'exit 1' INT TERM

# Minimal tool directory: the only external commands the scripts under test
# may execute besides the stubbed herdr/claude/codex commands.
TOOLBIN="$BASE/toolbin"
mkdir -p "$TOOLBIN" || exit 1
for tool_name in ln mkdir rm; do
  tool_path=$(command -v -- "$tool_name") || {
    printf 'missing required tool: %s\n' "$tool_name" >&2
    exit 1
  }
  ln -s "$tool_path" "$TOOLBIN/$tool_name" || exit 1
done

PASS=0
FAIL=0
T_NAME=
T_ERR=

t_start() { T_NAME=$1; T_ERR=; }
t_fail() { [ -n "$T_ERR" ] || T_ERR=$1; }
t_end() {
  if [ -z "$T_ERR" ]; then
    PASS=$((PASS + 1))
    printf 'ok   %s\n' "$T_NAME"
  else
    FAIL=$((FAIL + 1))
    printf 'FAIL %s: %s\n' "$T_NAME" "$T_ERR"
  fi
}

OUT="$BASE/stdout"
ERR="$BASE/stderr"
STATUS=0

# run <home> <stub-bin> <command...> — isolated non-TTY invocation.
run() {
  run_home=$1
  run_stub=$2
  shift 2
  env HOME="$run_home" PATH="$run_stub:$TOOLBIN" "$@" \
    </dev/null >"$OUT" 2>"$ERR"
  STATUS=$?
}

assert_status() { [ "$STATUS" -eq "$1" ] || t_fail "expected exit $1, got $STATUS"; }
assert_absent() { if [ -e "$1" ] || [ -L "$1" ]; then t_fail "unexpected path exists: $1"; fi; }
assert_present() { if [ ! -e "$1" ] && [ ! -L "$1" ]; then t_fail "expected path missing: $1"; fi; }
assert_link_resolves_to() {
  if [ ! -L "$1" ]; then
    t_fail "not a symlink: $1"
    return
  fi
  alr_resolved=$(CDPATH= cd -P -- "$1" 2>/dev/null && pwd -P) || {
    t_fail "unresolvable link: $1"
    return
  }
  [ "$alr_resolved" = "$2" ] || t_fail "link $1 resolves to $alr_resolved, expected $2"
}
assert_file_has() {
  afh_data=$(cat -- "$1" 2>/dev/null) || afh_data=
  case $afh_data in
    *"$2"*) ;;
    *) t_fail "$3 missing text: $2" ;;
  esac
}
assert_out_has() { assert_file_has "$OUT" "$1" "stdout"; }
assert_err_has() { assert_file_has "$ERR" "$1" "stderr"; }
assert_out_lacks() {
  aol_data=$(cat -- "$OUT" 2>/dev/null) || aol_data=
  case $aol_data in
    *"$1"*) t_fail "stdout unexpectedly has text: $1" ;;
  esac
}

FIX_N=0
FIX=
FIX_HOME=
FIX_BIN=
fixture() {
  FIX_N=$((FIX_N + 1))
  FIX="$BASE/fix$FIX_N"
  FIX_HOME="$FIX/home"
  FIX_BIN="$FIX/bin"
  mkdir -p "$FIX_HOME" "$FIX_BIN" || exit 1
}

stub_ok() {
  printf '#!/bin/sh\nexit 0\n' >"$FIX_BIN/$1"
  chmod 755 "$FIX_BIN/$1"
}
stub_fail() {
  printf '#!/bin/sh\nexit 1\n' >"$FIX_BIN/$1"
  chmod 755 "$FIX_BIN/$1"
}
# herdr stub that succeeds on its first execution and fails afterwards,
# so installer preflight passes and post-install verification fails.
stub_herdr_ok_once() {
  printf '#!/bin/sh\nif [ -e "%s" ]; then exit 1; fi\n: > "%s"\nexit 0\n' \
    "$FIX/herdr-ran" "$FIX/herdr-ran" >"$FIX_BIN/herdr"
  chmod 755 "$FIX_BIN/herdr"
}
stub_all_ok() {
  stub_ok herdr
  stub_ok claude
  stub_ok codex
}

claude_dest() { printf '%s\n' "$1/.claude/skills/herdr-orchestrator"; }
codex_dest() { printf '%s\n' "$1/.codex/skills/herdr-orchestrator"; }

# ---------------------------------------------------------------------------
# Syntax and file-mode gates
# ---------------------------------------------------------------------------

t_start "sh -n accepts every shell file"
for shell_file in "$COMMON" "$VERIFY" "$INSTALL" "$TEST_SELF_DIR/install-scripts-test.sh"; do
  /bin/sh -n "$shell_file" || t_fail "syntax check failed: $shell_file"
done
t_end

t_start "entry points are executable and library is readable"
[ -x "$VERIFY" ] || t_fail "verify.sh is not executable"
[ -x "$INSTALL" ] || t_fail "install.sh is not executable"
[ -r "$COMMON" ] || t_fail "library is not readable"
t_end

# ---------------------------------------------------------------------------
# Help and usage contract
# ---------------------------------------------------------------------------

t_start "verify --help is standalone success"
fixture
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --help
assert_status 0
assert_out_has "Usage: verify.sh"
assert_absent "$FIX_HOME/.claude"
t_end

t_start "install --help is standalone success"
fixture
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --help
assert_status 0
assert_out_has "Usage: install.sh"
assert_out_has "--dry-run"
assert_absent "$FIX_HOME/.claude"
t_end

t_start "help mixed with other arguments is a usage error"
fixture
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --help --claude
assert_status 2
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude --help
assert_status 2
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --help --dry-run
assert_status 2
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --all --help
assert_status 2
t_end

t_start "duplicate and multiple target flags are usage errors"
fixture
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude --claude
assert_status 2
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude --codex
assert_status 2
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --codex --all
assert_status 2
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --dry-run --dry-run --claude
assert_status 2
t_end

t_start "unknown arguments are usage errors"
fixture
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --frobnicate
assert_status 2
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" extra-word
assert_status 2
t_end

t_start "verify rejects --dry-run because it is always read-only"
fixture
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --dry-run --claude
assert_status 2
assert_err_has "read-only"
t_end

t_start "non-TTY without a target exits 2 before checking herdr"
fixture
run "$FIX_HOME" "$FIX_BIN" "$VERIFY"
assert_status 2
assert_err_has "no interactive terminal"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL"
assert_status 2
assert_err_has "no interactive terminal"
assert_absent "$FIX_HOME/.claude"
assert_absent "$FIX_HOME/.codex"
t_end

# ---------------------------------------------------------------------------
# Pure menu-choice logic (no pseudo-TTY required)
# ---------------------------------------------------------------------------

t_start "menu selection maps every valid reply"
for menu_pair in "1 claude" "claude claude" "2 codex" "codex codex" "3 all" "all all"; do
  menu_reply=${menu_pair% *}
  menu_expect=${menu_pair#* }
  menu_got=$(. "$COMMON" && skill_menu_selection "$menu_reply") || menu_got="<error>"
  [ "$menu_got" = "$menu_expect" ] || t_fail "reply '$menu_reply' mapped to '$menu_got'"
done
t_end

t_start "menu selection rejects invalid replies"
for menu_reply in "" "0" "4" "x" "claude codex" "-1"; do
  if menu_got=$(. "$COMMON" && skill_menu_selection "$menu_reply"); then
    t_fail "reply '$menu_reply' unexpectedly mapped to '$menu_got'"
  fi
done
t_end

# ---------------------------------------------------------------------------
# Prerequisite failures (zero mutation)
# ---------------------------------------------------------------------------

t_start "verify fails when herdr is missing and prints manual guidance"
fixture
stub_ok claude
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 1
assert_err_has "herdr not found"
assert_err_has "https://herdr.dev/docs/install/"
assert_absent "$FIX_HOME/.claude"
t_end

t_start "verify fails when herdr --version fails"
fixture
stub_fail herdr
stub_ok claude
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 1
assert_err_has "'herdr --version' failed"
t_end

t_start "verify fails when the selected runtime is missing"
fixture
stub_ok herdr
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 1
assert_err_has "runtime command 'claude' not found"
t_end

t_start "install with missing herdr creates nothing"
fixture
stub_ok claude
stub_ok codex
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --all
assert_status 1
assert_err_has "herdr not found"
assert_err_has "nothing was created"
assert_absent "$FIX_HOME/.claude"
assert_absent "$FIX_HOME/.codex"
t_end

t_start "install with failing herdr creates nothing"
fixture
stub_fail herdr
stub_ok claude
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 1
assert_absent "$FIX_HOME/.claude"
t_end

t_start "install with a missing selected runtime creates nothing"
fixture
stub_ok herdr
stub_ok claude
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --codex
assert_status 1
assert_err_has "runtime command 'codex' not found"
assert_absent "$FIX_HOME/.codex"
t_end

# ---------------------------------------------------------------------------
# Verifier destination classification
# ---------------------------------------------------------------------------

t_start "verify reports a missing skill link"
fixture
stub_all_ok
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 1
assert_err_has "skill link is missing"
assert_err_has "install.sh --claude"
t_end

t_start "verify accepts a correct absolute link"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills"
ln -s "$REPO_ROOT" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 0
assert_out_has "resolves to this repository"
assert_out_has "all requested checks passed"
t_end

t_start "verify accepts a non-canonical link that resolves to the repo"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills"
ln -s "$REPO_ROOT/scripts/.." "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 0
t_end

t_start "verify rejects a wrong symlink without touching it"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills" "$FIX/otherdir"
ln -s "$FIX/otherdir" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 1
assert_err_has "does not resolve to this repository"
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$FIX/otherdir"
t_end

t_start "verify rejects a broken symlink without touching it"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills"
ln -s "$FIX/does-not-exist" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 1
assert_err_has "broken symlink"
assert_present "$(claude_dest "$FIX_HOME")"
t_end

t_start "verify rejects an existing regular file"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills"
printf 'user content\n' >"$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 1
assert_err_has "regular file"
assert_file_has "$(claude_dest "$FIX_HOME")" "user content" "conflict file"
t_end

t_start "verify rejects an existing real directory"
fixture
stub_all_ok
mkdir -p "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --claude
assert_status 1
assert_err_has "real directory"
[ -d "$(claude_dest "$FIX_HOME")" ] || t_fail "directory disappeared"
t_end

t_start "verify aggregates herdr, runtime, and link diagnostics in one run"
fixture
stub_fail herdr
stub_ok codex
mkdir -p "$FIX_HOME/.claude/skills" "$FIX/otherdir"
ln -s "$FIX/otherdir" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$VERIFY" --all
assert_status 1
assert_err_has "'herdr --version' failed"
assert_err_has "runtime command 'claude' not found"
assert_err_has "does not resolve to this repository"
assert_err_has "codex skill link is missing"
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$FIX/otherdir"
assert_absent "$(codex_dest "$FIX_HOME")"
t_end

# ---------------------------------------------------------------------------
# Installer success paths
# ---------------------------------------------------------------------------

t_start "install --claude creates only the claude link"
fixture
stub_all_ok
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 0
assert_out_has "plan: claude: create link"
assert_out_has "installed and verified"
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$REPO_ROOT"
assert_absent "$FIX_HOME/.codex"
t_end

t_start "install --codex creates only the codex link"
fixture
stub_all_ok
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --codex
assert_status 0
assert_link_resolves_to "$(codex_dest "$FIX_HOME")" "$REPO_ROOT"
assert_absent "$FIX_HOME/.claude"
t_end

t_start "install --all creates both links"
fixture
stub_all_ok
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --all
assert_status 0
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$REPO_ROOT"
assert_link_resolves_to "$(codex_dest "$FIX_HOME")" "$REPO_ROOT"
t_end

t_start "repeated install is idempotent and preserves the correct link"
fixture
stub_all_ok
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 0
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 0
assert_out_has "plan: claude: preserve existing correct link"
assert_out_lacks "plan: claude: create link"
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$REPO_ROOT"
t_end

t_start "install --all preserves an existing correct link and creates the other"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills"
ln -s "$REPO_ROOT" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --all
assert_status 0
assert_out_has "plan: claude: preserve existing correct link"
assert_out_has "plan: codex: create link"
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$REPO_ROOT"
assert_link_resolves_to "$(codex_dest "$FIX_HOME")" "$REPO_ROOT"
t_end

# ---------------------------------------------------------------------------
# Installer conflict rejection (never replace, delete, or repair)
# ---------------------------------------------------------------------------

t_start "install rejects a wrong symlink and leaves it unchanged"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills" "$FIX/otherdir"
ln -s "$FIX/otherdir" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 1
assert_err_has "does not resolve to this repository"
assert_err_has "nothing was created"
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$FIX/otherdir"
t_end

t_start "install rejects a broken symlink and leaves it unchanged"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills"
ln -s "$FIX/does-not-exist" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 1
assert_err_has "broken symlink"
assert_present "$(claude_dest "$FIX_HOME")"
t_end

t_start "install rejects a regular file and preserves its content"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills"
printf 'sentinel user data\n' >"$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 1
assert_err_has "regular file"
assert_file_has "$(claude_dest "$FIX_HOME")" "sentinel user data" "conflict file"
t_end

t_start "install rejects a real directory and leaves it in place"
fixture
stub_all_ok
mkdir -p "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 1
assert_err_has "real directory"
[ -d "$(claude_dest "$FIX_HOME")" ] || t_fail "directory disappeared"
t_end

t_start "multi-target conflict blocks every mutation"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills" "$FIX/otherdir"
ln -s "$FIX/otherdir" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --all
assert_status 1
assert_err_has "nothing was created"
assert_absent "$FIX_HOME/.codex"
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$FIX/otherdir"
t_end

# ---------------------------------------------------------------------------
# Parent-chain preflight
# ---------------------------------------------------------------------------

t_start "install rejects a regular file in the parent chain"
fixture
stub_all_ok
printf 'not a directory\n' >"$FIX_HOME/.claude"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 1
assert_err_has "not a directory"
assert_file_has "$FIX_HOME/.claude" "not a directory" "parent file"
t_end

t_start "install rejects a broken parent symlink"
fixture
stub_all_ok
ln -s "$FIX/missing-parent" "$FIX_HOME/.claude"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 1
assert_err_has "parent path is a broken symlink"
assert_present "$FIX_HOME/.claude"
t_end

t_start "install follows a valid parent symlink without modifying it"
fixture
stub_all_ok
mkdir -p "$FIX/real-skills" "$FIX_HOME/.claude"
ln -s "$FIX/real-skills" "$FIX_HOME/.claude/skills"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 0
[ -L "$FIX_HOME/.claude/skills" ] || t_fail "parent symlink was replaced"
assert_link_resolves_to "$FIX_HOME/.claude/skills" "$FIX/real-skills"
assert_link_resolves_to "$FIX/real-skills/herdr-orchestrator" "$REPO_ROOT"
t_end

t_start "install rejects a non-writable resolved parent directory"
fixture
stub_all_ok
mkdir -p "$FIX/locked-skills" "$FIX_HOME/.claude"
ln -s "$FIX/locked-skills" "$FIX_HOME/.claude/skills"
chmod 555 "$FIX/locked-skills"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
install_locked_status=$STATUS
chmod 755 "$FIX/locked-skills"
[ "$install_locked_status" -eq 1 ] || t_fail "expected exit 1, got $install_locked_status"
assert_err_has "not writable"
assert_absent "$FIX/locked-skills/herdr-orchestrator"
t_end

# ---------------------------------------------------------------------------
# Dry-run: full preflight, zero mutation
# ---------------------------------------------------------------------------

t_start "dry-run passes preflight and creates no directories or links"
fixture
stub_all_ok
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --dry-run --claude
assert_status 0
assert_out_has "plan: claude: create link"
assert_out_has "dry-run: full preflight passed"
assert_absent "$FIX_HOME/.claude"
t_end

t_start "dry-run accepts either documented flag order"
fixture
stub_all_ok
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude --dry-run
assert_status 0
assert_absent "$FIX_HOME/.claude"
t_end

t_start "dry-run still fails on missing herdr"
fixture
stub_ok claude
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --dry-run --claude
assert_status 1
assert_err_has "herdr not found"
assert_absent "$FIX_HOME/.claude"
t_end

t_start "dry-run still fails on destination conflicts"
fixture
stub_all_ok
mkdir -p "$FIX_HOME/.claude/skills"
printf 'keep me\n' >"$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --dry-run --claude
assert_status 1
assert_file_has "$(claude_dest "$FIX_HOME")" "keep me" "conflict file"
t_end

# ---------------------------------------------------------------------------
# Bounded rollback after post-install verification failure
# ---------------------------------------------------------------------------

t_start "post-install verification failure rolls back the created link"
fixture
stub_ok claude
stub_ok codex
stub_herdr_ok_once
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --claude
assert_status 1
assert_err_has "post-install verification failed"
assert_err_has "rollback: removed link created by this run"
assert_absent "$(claude_dest "$FIX_HOME")"
t_end

t_start "rollback removes only links created by the current run"
fixture
stub_ok claude
stub_ok codex
stub_herdr_ok_once
mkdir -p "$FIX_HOME/.claude/skills"
ln -s "$REPO_ROOT" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$INSTALL" --all
assert_status 1
assert_link_resolves_to "$(claude_dest "$FIX_HOME")" "$REPO_ROOT"
assert_absent "$(codex_dest "$FIX_HOME")"
t_end

# ---------------------------------------------------------------------------
# Path portability: spaces, relative links, repository markers
# ---------------------------------------------------------------------------

make_fake_repo() {
  # $1: fake repository root to create with markers and script copies.
  mkdir -p "$1/references" "$1/.git"
  printf '# marker\n' >"$1/SKILL.md"
  printf '# marker\n' >"$1/references/herdr-control.md"
  cp -R "$REPO_ROOT/scripts" "$1/scripts"
}

t_start "install and verify work with spaces in repo and home paths"
fixture
stub_all_ok
SPACE_REPO="$FIX/repo with spaces"
SPACE_HOME="$FIX/home with spaces"
make_fake_repo "$SPACE_REPO"
mkdir -p "$SPACE_HOME"
run "$SPACE_HOME" "$FIX_BIN" "$SPACE_REPO/scripts/install.sh" --all
assert_status 0
assert_link_resolves_to "$(claude_dest "$SPACE_HOME")" "$SPACE_REPO"
assert_link_resolves_to "$(codex_dest "$SPACE_HOME")" "$SPACE_REPO"
run "$SPACE_HOME" "$FIX_BIN" "$SPACE_REPO/scripts/verify.sh" --all
assert_status 0
t_end

t_start "verify accepts a relative symlink that resolves to the repo"
fixture
stub_all_ok
REL_REPO="$FIX/rel repo"
make_fake_repo "$REL_REPO"
mkdir -p "$FIX_HOME/.claude/skills"
ln -s "../../../rel repo" "$(claude_dest "$FIX_HOME")"
run "$FIX_HOME" "$FIX_BIN" "$REL_REPO/scripts/verify.sh" --claude
assert_status 0
t_end

t_start "verify fails outside a marked repository checkout"
fixture
stub_all_ok
BARE_DIR="$FIX/not-a-repo"
mkdir -p "$BARE_DIR"
cp -R "$REPO_ROOT/scripts" "$BARE_DIR/scripts"
run "$FIX_HOME" "$FIX_BIN" "$BARE_DIR/scripts/verify.sh" --claude
assert_status 1
assert_err_has "missing repository marker"
t_end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
