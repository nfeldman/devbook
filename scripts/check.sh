#!/usr/bin/env bash
# Run portable contract checks without changing configured machine state.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v shellcheck >/dev/null 2>&1; then
  printf 'shellcheck is required (brew install shellcheck)\n' >&2
  exit 1
fi

scripts=(
  setup.sh
  agent-vault/run.sh
  githooks/pre-commit
  scripts/check.sh
  tests/contracts.sh
)

printf 'Checking Bash syntax (%d files)\n' "${#scripts[@]}"
for script in "${scripts[@]}"; do
  bash -n "$script"
done

printf 'Running ShellCheck (%d files)\n' "${#scripts[@]}"
shellcheck -s bash -S warning "${scripts[@]}"

printf 'Rendering the Agent Vault Compose configuration\n'
if docker compose version >/dev/null 2>&1; then
  AGENT_VAULT_MASTER_PASSWORD=contract-check-placeholder \
    docker compose --file agent-vault/compose.yaml config --quiet
elif command -v docker-compose >/dev/null 2>&1; then
  AGENT_VAULT_MASTER_PASSWORD=contract-check-placeholder \
    docker-compose --file agent-vault/compose.yaml config --quiet
else
  printf 'Docker Compose is required to validate agent-vault/compose.yaml\n' >&2
  exit 1
fi

bash tests/contracts.sh

printf 'Repository checks passed\n'
