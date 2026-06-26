# [P2] v61 one-token logits parity

## Scope

v61 SSD-MoE

## Target Readiness Transition

fixture -> real execution

## Required Artifacts

- one-token logits parity contract output
- runtime provenance and sha256 manifest
- explicit no-checkpoint-payload repository proof
- fail-closed rows for missing real model evidence

## Claim Boundary

Allowed claim:

- v61 SSD-MoE fixture/runtime scaffolding can be tracked as typed readiness only.

Blocked claims:

- actual generation readiness
- near-frontier comparison claims
- release readiness

## Verification

- `./scripts/ai-verify.sh`
- relevant `tools/verify_artifact.py` command for v61 one-token path evidence
- checkpoint payloads must remain out of git
