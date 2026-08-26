# Local Agent Vault

This is an optional, local-only Agent Vault deployment for low-value agent API
access. In the intended workflow, upstream API keys live in broker configuration
rather than the wrapper's command line; a pre-authorized agent makes requests
through the broker.

It is not a hostile-agent boundary: the server, proxy, and agent run on the
same Mac. Use a separate host for stronger isolation. The Compose ports are
bound to loopback so another machine cannot reach the vault by default.

## Install and start

From the devbook checkout, with OrbStack running:

```bash
INSTALL_AGENT_VAULT=1 ./setup.sh
```

The setup does the following:

- starts the immutable `infisical/agent-vault` image for v0.39.1 (digest pinned
  in `compose.yaml`);
- persists its encrypted data in the Docker volume
  `devbook-agent-vault-data`;
- creates `~/.config/dev-env/agent-vault/.env` with a random master password,
  mode `600`; and
- extracts and byte-checks the matching `agent-vault-0.39.1` CLI into
  `~/.local/bin` without using the upstream unpinned installer script.

The generated master password is a local control-plane secret. Save a copy in
1Password without printing it, and never put it in this repository, a shell
command, an issue, or a transcript. The `.env` file is intentionally local so
the container can restart without asking you each time.

Open `http://127.0.0.1:14321/register` once and create the first user. The first
user owns the default vault. The HTTP API is on port `14321`; the agent proxy is
on port `14322`.

## Configure access once

Add only low-value, scoped credentials in the Agent Vault UI. Then configure
the matching services. `services.example.yaml` contains credential names, not
credential values; copy it to a private file if you want to apply it with the
CLI:

```bash
cp agent-vault/services.example.yaml agent-vault/services.yaml
"$HOME/.local/bin/agent-vault-0.39.1" vault service set \
  -f agent-vault/services.yaml --vault <VAULT_NAME>
```

Before using an agent, set the vault's `unmatched_host_policy` to `deny`. This
turns an accidental or unconfigured upstream request into a `403` instead of
forwarding it without broker authentication. Prefer narrow host/path matches
and least-privilege vendor keys.

Create an agent under **Agents → Add agent** and put only the resulting Agent
Vault connection settings in a local file at
`~/.config/dev-env/agent-vault/agent.env`:

```dotenv
AGENT_VAULT_ADDR=http://127.0.0.1:14321
AGENT_VAULT_TOKEN=av_agt_REPLACE_WITH_YOUR_AGENT_TOKEN
AGENT_VAULT_VAULT=REPLACE_WITH_YOUR_VAULT_NAME
```

Make that file readable only by you (`chmod 600 ...`). It must contain only
those three plain `KEY=VALUE` lines; the wrapper rejects shell metacharacters,
unknown keys, symlinks, and weaker ownership/mode. Do not put upstream API keys
or the master password in it. The repo's wrapper loads it without putting the
values in the command line:

```bash
bash agent-vault/run.sh codex
```

The wrapper is for CLI agents that support the Agent Vault quickstart. A desktop
agent that does not inherit this process environment will not automatically use
the proxy; use its supported wrapper/container integration instead.

## Recovery and maintenance

The master password and the Docker volume are a pair. Back up both before
removing or migrating the installation. A simple local backup, with the
container stopped, is:

```bash
mkdir -p ~/.config/dev-env/agent-vault/backups
docker compose --project-name devbook-agent-vault \
  --file agent-vault/compose.yaml \
  --env-file ~/.config/dev-env/agent-vault/.env down
docker run --rm \
  -v devbook-agent-vault-data:/data:ro \
  -v "$HOME/.config/dev-env/agent-vault/backups:/backup" \
  alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce \
  tar -czf /backup/agent-vault-data.tar.gz -C /data .
```

The `.env` file is the runtime copy of the master password; the matching
1Password item is the human recovery copy. Verify the archive before restoring:

```bash
docker run --rm \
  -v "$HOME/.config/dev-env/agent-vault/backups:/backup:ro" \
  alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce \
  tar -tzf /backup/agent-vault-data.tar.gz
```

For a deliberately empty target volume, stop the service, confirm the volume
name, and extract the archive:

```bash
docker volume inspect devbook-agent-vault-data
docker run --rm \
  -v devbook-agent-vault-data:/data \
  -v "$HOME/.config/dev-env/agent-vault/backups:/backup:ro" \
  alpine@sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce \
  sh -c 'test -z "$(find /data -mindepth 1 -maxdepth 1 -print -quit)" && tar -xzf /backup/agent-vault-data.tar.gz -C /data'
```

Restore the matching `.env` file, then run `INSTALL_AGENT_VAULT=1 ./setup.sh`.
The setup refuses to create a new empty vault when the password file or volume
pair is incomplete. If the old data is intentionally disposable, the explicit
escape hatch is `AGENT_VAULT_ALLOW_EMPTY_REINIT=1 INSTALL_AGENT_VAULT=1 ./setup.sh`.
Do not overwrite a live volume casually; the archive contains encrypted vault
state but remains sensitive operational data.

To stop without deleting data:

```bash
docker compose --project-name devbook-agent-vault \
  --file agent-vault/compose.yaml \
  --env-file ~/.config/dev-env/agent-vault/.env stop
```

To remove the container but preserve the named volume, use `down` without
`--volumes`; deleting `devbook-agent-vault-data` is the irreversible teardown.

## Review boundary

The image is pinned to Agent Vault `v0.39.1` by the immutable Docker manifest
digest in `compose.yaml`; the recovery image is pinned similarly. Before
changing either digest, verify the [upstream release checksum/signature](https://github.com/Infisical/agent-vault/releases/tag/v0.39.1),
update this file and `compose.yaml` together, run the devbook machine-steward
review, and repeat the loopback smoke check. The current design protects
against transcript leakage; it does not protect against a malicious local
agent with access to the host.
