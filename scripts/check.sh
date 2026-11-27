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

bash tests/contracts.sh

printf 'Repository checks passed\n'
