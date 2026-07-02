# MODELS.md — model sovereignty

The same anti-lock-in posture as the rest of this setup, pointed at AI models: **use
vendors by choice, never by dependency.** Default to local; escalate to a cloud model
only when you decide a task needs it.

## The posture

1. **Default local.** Ollama is the vendor-free runtime. A capable open coding model
   runs entirely on your Mac — no API key, no per-keystroke network, no account.
2. **Keep every tool swappable.** Prefer tools whose model is a config value (Zed's
   assistant, aider, most OpenAI-compatible clients) over tools wired to one vendor.
   Switching models should be an edit, never a reinstall.
3. **Name the one deliberate exception.** **Claude Code** is Anthropic's own CLI — it is
   vendor-bound by design. Keep it for its strengths, but the counterweight is that
   everything else here can run local, so you are never *dependent* on any single vendor.
4. **No cloud-agent CLI is installed by default.** `aider` was removed on purpose. If you
   ever want a neutral terminal agent, add it and point it at Ollama first (below).

## Local coding models (open weights, sovereign licenses)

**Qwen2.5-Coder** is the recommended default — Apache-2.0, state-of-the-art open coding
model (the 32B edges out GPT-4 on HumanEval). Pick by your Mac's unified memory:

| Model | Disk (Q4) | Wants ~ | Good for |
|-------|-----------|---------|----------|
| `qwen2.5-coder:7b`  | ~5 GB  | 16 GB | safe default, fast, single-file edits |
| `qwen2.5-coder:14b` | ~9 GB  | 32 GB | best balance, multi-file work |
| `qwen2.5-coder:32b` | ~19 GB | 48–64 GB | strongest open option |

Alternatives worth knowing: `deepseek-coder-v2` (MoE, strong on less-common languages),
`gemma3` (general), `llama3.2` (small/general). Pull whichever:

```bash
ollama pull qwen2.5-coder        # add :14b or :32b for more capable, more RAM
```

## Pointing tools at local (no vendor)

**Any OpenAI-compatible / aider-style tool → Ollama:**

```bash
export OLLAMA_API_BASE=http://127.0.0.1:11434
# e.g. if you re-add aider later:
#   aider --model ollama_chat/qwen2.5-coder
# no API key needed; fully offline after the model download.
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
