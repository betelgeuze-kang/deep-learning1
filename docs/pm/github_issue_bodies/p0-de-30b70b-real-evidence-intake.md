# [P0] D/E 30B-70B real evidence intake

## Scope

D/E baseline

## Target Readiness Transition

fixture -> real execution

## Required Artifacts

- real D 30B baseline answer/citation/resource packet
- real E 70B baseline answer/citation/resource packet
- model identity and sha256 manifests for both baselines
- measured registry admission rows proving fixture exclusion

## Claim Boundary

Allowed claim:

- D/E baseline schemas and fixture evidence-intake contracts exist.

Blocked claims:

- 30B-150B public comparison wording
- D/E measured baseline readiness
- release readiness

## Verification

- `./scripts/ai-verify.sh`
- relevant `tools/verify_artifact.py baseline-admission ...` command
- D/E measured registry exclusion rows must reject fixture-only evidence
