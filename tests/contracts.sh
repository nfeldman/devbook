#!/usr/bin/env bash
# Exercise devbook's config ownership, convergence, and private sentinel contracts.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/devbook-contracts.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

passed=0
total=0

fail() {
  printf 'not ok %d - %s\n' "$total" "$1" >&2
  return 1
}

diagnose() {
  printf '# %s\n' "$1" >&2
  return 1
}

assert_contains() {
  local needle="$1" file="$2"
  grep -Fq "$needle" "$file" || diagnose "expected '$needle' in $file"
}

assert_not_contains() {
  local needle="$1" file="$2"
  if grep -Fq "$needle" "$file"; then
    diagnose "did not expect '$needle' in $file"
  fi
}

run_test() {
  local name="$1"
  shift
  total=$((total + 1))
  if "$@"; then
    passed=$((passed + 1))
    printf 'ok %d - %s\n' "$total" "$name"
  else
    fail "$name"
  fi
}

extract_function() {
  local name="$1" target="$2"
  awk -v signature="${name}()" '
    index($0, signature " {") == 1 { copying=1 }
    copying { print }
    copying && $0 == "}" { exit }
  ' "$ROOT/setup.sh" > "$target"
  [[ -s "$target" ]]
}

test_sentinel_gate_red_and_green() {
  local repo="$TEST_ROOT/sentinel-repo" test_home="$TEST_ROOT/sentinel-home"
  mkdir -p "$repo" "$test_home/.dotfiles.local"
  git -C "$repo" init -q
  printf 'private-marker\n' > "$test_home/.dotfiles.local/sentinels.txt"

  printf 'safe content\n' > "$repo/example.txt"
  git -C "$repo" add example.txt
  HOME="$test_home" bash "$ROOT/githooks/pre-commit"

  printf 'private-marker\n' > "$repo/example.txt"
  git -C "$repo" add example.txt
  if (cd "$repo" && HOME="$test_home" bash "$ROOT/githooks/pre-commit") \
      >"$TEST_ROOT/sentinel.out" 2>&1; then
    diagnose "sentinel gate accepted a staged marker"
    return 1
  fi
  assert_contains "BLOCKED" "$TEST_ROOT/sentinel.out" || return 1
}

test_real_file_takeover_is_preserved() {
  local function_file="$TEST_ROOT/link-function.sh"
  local source_file="$TEST_ROOT/source.toml" destination="$TEST_ROOT/user.toml"
  extract_function link "$function_file" || return 1
  printf 'baseline\n' > "$source_file"
  printf 'user-owned\n' > "$destination"

  (
    warn() { :; }
    ok() { :; }
    DIVERGED_LIST=""
    # shellcheck source=/dev/null
    source "$function_file"
    link "$source_file" "$destination"
    [[ "$(cat "$destination")" == "user-owned" ]]
    [[ "$DIVERGED_LIST" == *"$destination"* ]]
  )
}

test_marked_block_converges() {
  local function_file="$TEST_ROOT/marked-block-function.sh"
  local destination="$TEST_ROOT/managed.md"
  extract_function ensure_marked_block "$function_file" || return 1
  printf 'human content\n' > "$destination"

  (
    # shellcheck source=/dev/null
    source "$function_file"
    ensure_marked_block "$destination" "<!-- start -->" "<!-- end -->" "first"
    ensure_marked_block "$destination" "<!-- start -->" "<!-- end -->" "second"
  )

  [[ "$(grep -Fc '<!-- start -->' "$destination")" == "1" ]]
  [[ "$(grep -Fc '<!-- end -->' "$destination")" == "1" ]]
  assert_contains "human content" "$destination" || return 1
  assert_contains "second" "$destination" || return 1
  assert_not_contains "first" "$destination" || return 1
}

run_test "sentinel gate passes safe input and rejects a staged marker" test_sentinel_gate_red_and_green
run_test "a real destination file remains user-owned" test_real_file_takeover_is_preserved
run_test "managed blocks converge without touching surrounding content" test_marked_block_converges

printf 'Contract tests passed: %d/%d\n' "$passed" "$total"
[[ "$passed" == "$total" ]]
