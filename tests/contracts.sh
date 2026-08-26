#!/usr/bin/env bash
# Exercise devbook's state, privacy, and credential-boundary contracts.
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

write_docker_stub() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  cat > "$target" <<'STUB'
#!/usr/bin/env bash
set -eu
if [[ "${1:-}" == "info" ]]; then
  exit 0
fi
if [[ "${1:-}" == "volume" && "${2:-}" == "inspect" ]]; then
  [[ "${VOLUME_PRESENT:-0}" == "1" ]]
  exit
fi
exit 97
STUB
  chmod +x "$target"
}

test_vault_rejects_incomplete_recovery_pairs() {
  local function_file="$TEST_ROOT/vault-function.sh" stub_dir="$TEST_ROOT/vault-bin"
  local state_with_password="$TEST_ROOT/vault-password-only"
  local state_with_volume="$TEST_ROOT/vault-volume-only"
  extract_function setup_agent_vault "$function_file" || return 1
  write_docker_stub "$stub_dir/docker" || return 1
  mkdir -p "$state_with_password" "$state_with_volume"
  printf 'AGENT_VAULT_MASTER_PASSWORD=placeholder\n' > "$state_with_password/.env"
  chmod 600 "$state_with_password/.env"

  if (
    warn() { :; }
    info() { :; }
    ok() { :; }
    export DOTDIR="$ROOT"
    export AGENT_VAULT_VERSION="0.39.1"
    export AGENT_VAULT_IMAGE="test-image"
    export AGENT_VAULT_CLI_URL="https://invalid.example/test"
    export AGENT_VAULT_CLI_SHA256="not-used"
    # shellcheck source=/dev/null
    source "$function_file"
    PATH="$stub_dir:$PATH" INSTALL_AGENT_VAULT=1 VOLUME_PRESENT=0 \
      AGENT_VAULT_STATE_DIR="$state_with_password" setup_agent_vault
  ); then
    diagnose "vault accepted a password file without its volume"
    return 1
  fi

  if (
    warn() { :; }
    info() { :; }
    ok() { :; }
    export DOTDIR="$ROOT"
    export AGENT_VAULT_VERSION="0.39.1"
    export AGENT_VAULT_IMAGE="test-image"
    export AGENT_VAULT_CLI_URL="https://invalid.example/test"
    export AGENT_VAULT_CLI_SHA256="not-used"
    # shellcheck source=/dev/null
    source "$function_file"
    PATH="$stub_dir:$PATH" INSTALL_AGENT_VAULT=1 VOLUME_PRESENT=1 \
      AGENT_VAULT_STATE_DIR="$state_with_volume" setup_agent_vault
  ); then
    diagnose "vault accepted a volume without its password file"
    return 1
  fi
}

write_agent_cli_stub() {
  local target="$1"
  cat > "$target" <<'STUB'
#!/usr/bin/env bash
set -eu
printf 'addr=%s\n' "$AGENT_VAULT_ADDR"
printf 'vault=%s\n' "$AGENT_VAULT_VAULT"
printf 'arg=%s\n' "$@"
STUB
  chmod +x "$target"
}

test_agent_wrapper_validates_and_forwards() {
  local state_dir="$TEST_ROOT/wrapper-valid" env_file="$TEST_ROOT/wrapper-valid/agent.env"
  local cli_stub="$TEST_ROOT/agent-vault-stub" output="$TEST_ROOT/wrapper-valid.out"
  mkdir -p "$state_dir"
  cat > "$env_file" <<'ENV'
AGENT_VAULT_ADDR=http://127.0.0.1:14321
AGENT_VAULT_TOKEN=token_test_value
AGENT_VAULT_VAULT=devbook
ENV
  chmod 600 "$env_file"
  write_agent_cli_stub "$cli_stub" || return 1

  AGENT_VAULT_STATE_DIR="$state_dir" AGENT_VAULT_CLI_PATH="$cli_stub" \
    bash "$ROOT/agent-vault/run.sh" codex --help > "$output"
  assert_contains "addr=http://127.0.0.1:14321" "$output" || return 1
  assert_contains "vault=devbook" "$output" || return 1
  assert_contains "arg=run" "$output" || return 1
  assert_contains "arg=codex" "$output" || return 1
}

test_agent_wrapper_rejects_unsafe_values() {
  local state_dir="$TEST_ROOT/wrapper-unsafe" env_file="$TEST_ROOT/wrapper-unsafe/agent.env"
  local cli_stub="$TEST_ROOT/unsafe-agent-vault-stub" output="$TEST_ROOT/wrapper-unsafe.out"
  mkdir -p "$state_dir"
  cat > "$env_file" <<'ENV'
AGENT_VAULT_ADDR=http://127.0.0.1:14321
AGENT_VAULT_TOKEN=token$not_allowed
AGENT_VAULT_VAULT=devbook
ENV
  chmod 600 "$env_file"
  write_agent_cli_stub "$cli_stub" || return 1

  if AGENT_VAULT_STATE_DIR="$state_dir" AGENT_VAULT_CLI_PATH="$cli_stub" \
      bash "$ROOT/agent-vault/run.sh" codex > "$output" 2>&1; then
    diagnose "wrapper accepted a shell metacharacter"
    return 1
  fi
  assert_contains "Unsafe value" "$output" || return 1
}

run_test "sentinel gate passes safe input and rejects a staged marker" test_sentinel_gate_red_and_green
run_test "a real destination file remains user-owned" test_real_file_takeover_is_preserved
run_test "managed blocks converge without touching surrounding content" test_marked_block_converges
run_test "Agent Vault rejects either half of an incomplete recovery pair" test_vault_rejects_incomplete_recovery_pairs
run_test "Agent Vault wrapper validates its env file and forwards arguments" test_agent_wrapper_validates_and_forwards
run_test "Agent Vault wrapper rejects unsafe env values" test_agent_wrapper_rejects_unsafe_values

printf 'Contract tests passed: %d/%d\n' "$passed" "$total"
[[ "$passed" == "$total" ]]
