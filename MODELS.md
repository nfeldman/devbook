# MODELS.md — model sovereignty

The same anti-lock-in posture as the rest of this setup, pointed at AI models: **use
vendors by choice, never by dependency.** Default to local; escalate to a cloud model
only when you decide a task needs it.

## The posture

1. **Default local.** Ollama is the vendor-free runtime. A capable open coding model
   runs entirely on your Mac — no API key, no per-keystroke network, no account.
2. **Keep every tool swappable.** Prefer tools whose model is a config value (Zed's
   assistant, opencode, most OpenAI-compatible clients) over tools wired to one vendor.
   Switching models should be an edit, never a reinstall.
3. **The one vendor-bound tool is temporary — and has a named exit.** **Claude Code**
   (and the Claude desktop app) is Anthropic's own client, vendor-bound by design. It
   stays only as a *temporary expedient*. The planned replacement is **Chorusmith** — a
   self-built client that speaks the OpenAI-compatible protocol and assumes local or
   OpenRouter, making the AI-client layer swappable like everything else. Documenting the
   exit before it's built is the point: the lock-in is time-boxed, not accepted.
4. **No cloud-agent CLI is installed by default.** If you want a neutral terminal agent,
   add one and point it at Ollama first (below) — **opencode** is the current pick:
   open source, bring-your-own-model, one `brew install` away.

## Local coding models (open weights, sovereign licenses)

The current generation is **MoE models** — huge total capacity, only a few billion
active parameters per token — which is exactly what Apple Silicon's unified memory
is good at: plenty of room to hold the weights, speed set by the small active set.
All picks below are Apache-2.0. Choose by your Mac's unified memory:

| Memory | Pull | Disk | Notes |
|--------|------|------|-------|
| 16 GB | `ollama pull gpt-oss:20b` | ~14 GB | OpenAI's open-weights model; the consensus 16 GB pick |
| 32 GB | `ollama pull qwen3-coder:30b` | ~19 GB | 30B MoE (3.3B active), 256K context — the mainstream default |
| 32 GB, agent work | `ollama pull devstral-small-2:24b` | ~15 GB | Mistral's agent-first coder (~66% SWE-bench Verified), 384K context |
| 64 GB+ | `ollama pull qwen3-coder-next` | ~52 GB | 80B MoE (3B active) — strongest local coding model today |
| 96 GB+ | `ollama pull gpt-oss:120b` | ~65 GB | needs real headroom; don't attempt on 64 GB |

For inline **tab-autocomplete** (fill-in-the-middle), small-and-dense still wins:
`qwen2.5-coder:1.5b` or `:7b` remain the right tools for that one job.

Worth knowing, not defaults: **GLM-4.6** (MIT) is excellent but too large to run
locally at these tiers — treat it as an API/cloud option. DeepSeek R1 distills are
stale for coding now; `deepseek-coder-v2`, `gemma3`, `llama3.2` have aged out of
the coding shortlist.

```bash
ollama pull qwen3-coder:30b      # or the pick for your RAM tier above
```

## Pointing tools at local (no vendor)

**Any OpenAI-compatible / agent-style tool → Ollama:**

```bash
export OLLAMA_API_BASE=http://127.0.0.1:11434         # aider-style tools
export OPENAI_BASE_URL=http://127.0.0.1:11434/v1      # generic OpenAI-compatible tools
# e.g. opencode — open-source terminal agent, bring-your-own-model, speaks to
# Ollama directly (brew install opencode). The modern "neutral agent" pick;
# aider still works too. No API key needed; fully offline after the pull.
```

**Zed** — set the assistant provider to Ollama in Zed's settings (it speaks to a local
Ollama endpoint directly).

**Optional gateway (one switch for everything).** If you want *all* tools to point at a
single endpoint while you swap the backing model — local or any cloud — from one file,
run a local OpenAI-compatible proxy such as **LiteLLM**. Then every tool targets
`http://localhost:4000` and the model choice lives in the proxy config, not in each tool.
Not required; a nice future addition.

## The honest tradeoff

Local models are weaker than frontier ones at multi-file edit formats and long-context
reasoning — but the gap is smaller than it used to be, and it costs RAM, not money or
privacy. The sovereign move is to keep local as the **floor** you always have, and treat
any cloud model as an **opt-in ceiling** you reach for deliberately — with the wiring
already in place to swap it out the day a vendor changes terms, prices, or availability.

## Trajectory

The endgame for the AI-client layer is **Chorusmith** — a self-built, OpenAI-compatible
client intended to replace the Claude desktop app (an early milestone of the project).
Once it lands, the last vendor-bound piece here becomes swappable too: local by default,
OpenRouter or any provider by choice, all behind the standard protocol.
