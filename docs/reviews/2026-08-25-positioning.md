# Positioning review — 2026-08-25

Scope: the README's public story, the design notes, and the evidence introduced
with them. This is a review receipt, not evidence that the prose is effective in
the wild.

## Method

The process used practice catalog **2.10** (`f9a5c0c9dbde`) without building a
large review harness around a small documentation change:

- **GP3 / GP6 — blind, refutation-framed challenge.** A Claude Code session
  received ten claims plus the relevant implementation files and the observed
  `6/6` contract-test result. It did not receive the README, design rationale,
  or confidence labels. Its instruction was to try to overturn each claim and
  uphold what survived.
- **GP15 / GP17 — independent, single-purpose editorial lanes.** One session
  reviewed first-screen hierarchy and differentiation; another reviewed
  sentence-level precision and skeptical-reader trust. Neither received the
  other's output.
- **GP1 — verify before applying.** Findings were checked against the repository
  before edits were accepted. A response that had not actually received its
  artifact was treated as void and rerun with the text embedded.

The editorial sessions used the same provider, so this record does not claim
model diversity. The challenger and the authoring agent were different model
families.

## Findings applied

- Replaced the abstract title with the concrete ownership idea and moved the CI
  badge and architecture diagram to restore the sequence claim → evidence →
  mechanism.
- Replaced “read-only” validation with the narrower claim that tests write only
  to disposable temporary workspaces and leave configured machine state alone.
- Separated install-time CLI checksum verification from the wrapper's runtime
  executable-path check.
- Limited Agent Vault claims to what the wrapper and Compose configuration show;
  the broker's upstream substitution remains an intended workflow, not a result
  established by this repository.
- Recorded the asymmetric empty-vault override and the untested private-composite
  transition.
- Recast the AI reviewer as a documented review convention rather than a commit
  gate.
- Tightened several dense or self-assessing sentences in the README.

## Finding rejected

The line editor claimed that the private-overlay creation instructions were
missing. Its excerpt ended immediately before those instructions and resumed in
the following section. The full README already contains the command and option
list, so the finding was an uncovered-context artifact rather than a document
defect. No edit was made.

## Mechanical result

After the edits, `bash scripts/check.sh` exited zero and reported `6/6` contract
tests. That run establishes only the checks enumerated in `docs/design.md`; it
does not establish a fresh-machine install, adoption, productivity, or disaster
recovery.
