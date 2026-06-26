# Evidence Backlog

Canonical readiness remains `readiness/typed_ready.json`. These backlog items
track work that should become GitHub issues before any readiness promotion.

## Epic Issues To Create

| Priority | Title | Scope | Boundary |
|---|---|---|---|
| P0 | v53 frozen benchmark canonicalization | v53 benchmark foundation | Keep machine foundation fixture-ready only until external review/adjudication returns exist. |
| P0 | D/E 30B-70B real evidence intake | D/E baselines | Fixture contracts must not be presented as real baseline evidence. |
| P1 | v54 real free-running generation | v54 generation | Intake contract is fixture-ready; real model generation remains blocked. |
| P1 | v58 blind human review execution | v58 blind evaluation | Blind-review contract exists, but human review/adjudication evidence is missing. |
| P2 | v61 one-token logits parity | v61 SSD-MoE | Fixture/runtime scaffolding must not imply release or generation quality readiness. |

## Recommended Labels

- `priority:P0`
- `priority:P1`
- `priority:P2`
- `type:architecture`
- `type:evidence`
- `type:security`
- `blocked:external-evidence`
- `blocked:human-review`
- `claim-boundary`
- `web-editable`
- `local-runtime-required`
- `superseded`

## PR Cleanup Notes

- PR #5, `v50 auditor correctness replay contract`, should either be rebased
  for the still-needed contract files, converted to an evidence blocker issue,
  or closed with the `superseded` label if main already contains the contract.
- PR #10, `v56 RULER/LongBench expanded replay blocker`, should follow the
  same rule: merge durable contract files to main, track missing external
  evidence as an issue, and avoid leaving blocker-only PRs open indefinitely.

## GitHub Settings To Apply Manually

These settings cannot be enforced from this repository without mutating GitHub
configuration:

- Require pull request before merging
- Require `AI verify` status checks
- Require conversation resolution
- Block force pushes
- Block branch deletion
- Automatically delete head branches
- Default `GITHUB_TOKEN` permission to read-only
- Require full SHA-pinned Actions where available
- Enable CodeQL default setup
- Enable secret scanning
- Enable dependency graph and Dependabot alerts
- Prefer one merge mode, with squash merge recommended for claim-bound slices
