# History

Major milestones only. Routine fixes and maintenance remain in the Git log.

## 2026-08-25 — v0.1.0 contract-tested baseline

- Added an opt-in, loopback-only Agent Vault deployment for low-value agent API
  access, with an immutable image pin, checksum-verified macOS ARM64 CLI,
  private secret-file custody, readiness checks, and documented recovery.
- Recorded the same-host threat model: this protects credentials from prompts
  and transcripts, not from a malicious agent on the host.
- Documented the ownership, private-overlay, and recovery design with explicit
  claim boundaries and an adversarial/editorial review receipt.
- Added macOS CI and six executable contract tests for takeover-safe configs,
  convergent marked blocks, the private sentinel gate, and Agent Vault inputs.

## 2026-07-24 — Private machine overlay

- Added the private overlay mechanism for machine-specific configuration,
  takeover-safe dotfiles, composition, and the private sentinel leak gate.

## 2026-07-17 — Machine-wide agent context

- Added `AGENTS.md` as the shared machine brief and wired it into Claude Code's
  user-level context.

## 2026-07-11 — Modern tooling baseline

- Modernized the fresh-Mac setup with Lean via elan, global Git defaults, and
  the machine-steward review workflow.
- Refreshed the local-first model/tooling posture for the mid-2026 baseline.

## 2026-07-02 — Project baseline

- Created the lean AI-forward macOS environment with Homebrew, Ghostty,
  Iosevka, modern CLI tools, managed runtimes, local-first AI, and the GRUE
  visual baseline.
