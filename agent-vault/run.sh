#!/usr/bin/env bash
# Run a supported CLI agent through the local Agent Vault proxy without putting
# the Agent Vault token or upstream credentials in command-line arguments.
set -euo pipefail

STATE_DIR="${AGENT_VAULT_STATE_DIR:-$HOME/.config/dev-env/agent-vault}"
AGENT_ENV_FILE="${AGENT_VAULT_AGENT_ENV_FILE:-$STATE_DIR/agent.env}"
AGENT_VAULT_CLI="${AGENT_VAULT_CLI_PATH:-$HOME/.local/bin/agent-vault-0.39.1}"

if [[ ! -f "$AGENT_ENV_FILE" || -L "$AGENT_ENV_FILE" || ! -r "$AGENT_ENV_FILE" ]]; then
  printf 'Missing readable Agent Vault agent env file: %s\n' "$AGENT_ENV_FILE" >&2
  printf 'Create it with mode 600 after registering an agent; do not commit or paste it.\n' >&2
  exit 1
fi
if [[ "$(stat -f '%u' "$AGENT_ENV_FILE")" != "$(id -u)" || "$(stat -f '%Lp' "$AGENT_ENV_FILE")" != "600" ]]; then
  printf 'Agent Vault agent env file must be owned by this user with mode 600: %s\n' "$AGENT_ENV_FILE" >&2
  exit 1
fi
if [[ "$#" -eq 0 ]]; then
  printf 'Usage: %s <agent-command> [args...]\n' "$0" >&2
  exit 2
fi

load_agent_env() {
  local line key value
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" != *=* ]]; then
      printf 'Invalid Agent Vault env line (expected KEY=VALUE)\n' >&2
      return 1
    fi
    key="${line%%=*}"
    value="${line#*=}"
    case "$key" in
      AGENT_VAULT_ADDR|AGENT_VAULT_TOKEN|AGENT_VAULT_VAULT) ;;
      *) printf 'Unexpected key in Agent Vault env file: %s\n' "$key" >&2; return 1 ;;
    esac
    case "$value" in
      *'$'*|*'`'*|*'\'*|*'"'*|*"'"*|*';'*|*'&'*|*'|'*|*[[:space:]]*)
        printf 'Unsafe value in Agent Vault env file for key: %s\n' "$key" >&2
        return 1
        ;;
    esac
    export "$key=$value"
  done < "$AGENT_ENV_FILE"
}

load_agent_env
for required_key in AGENT_VAULT_ADDR AGENT_VAULT_TOKEN AGENT_VAULT_VAULT; do
  if [[ -z "${!required_key:-}" ]]; then
    printf 'Missing required key in Agent Vault env file: %s\n' "$required_key" >&2
    exit 1
  fi
done
if [[ ! -x "$AGENT_VAULT_CLI" ]]; then
  printf 'Missing pinned Agent Vault CLI: %s\n' "$AGENT_VAULT_CLI" >&2
  printf 'Re-run INSTALL_AGENT_VAULT=1 ./setup.sh from the devbook checkout.\n' >&2
  exit 1
fi

exec "$AGENT_VAULT_CLI" run -- "$@"
