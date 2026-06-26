# Tooling & packets index

A map of the readiness surface, CI lanes, evidence packets, and contributor
docs. Everything below is staging/verification only: tools admit no evidence and
flip no readiness flag (see each doc's boundary note).

## Readiness & status

- Central readiness (source of truth): [`readiness/typed_ready.json`](../readiness/typed_ready.json)
- Schema: [`schemas/typed_readiness.schema.json`](../schemas/typed_readiness.schema.json)
- Verifier: `tools/verify_artifact.py typed-readiness ...`
- Human-readable status mirror: [`STATUS.md`](STATUS.md)

## CI lanes

- Lane overview (what runs where; web vs self-hosted): [`CI_LANES.md`](CI_LANES.md)
- PR gate: `ai-verify.yml` -> `pr-safe-verify` (ephemeral ubuntu-latest; static
  verifiers + auto-discovered `scripts/test_*.py` smokes + C++ build)
- Offline suite: `offline-suite.yml` + [`scripts/run_offline_suite.sh`](../scripts/run_offline_suite.sh)
  (deterministic `experiments/test_*.sh`, 10-shard matrix)
- Workflow contract verifier: `tools/verify_ci_workflows.py`

## Evidence packets & preflight (staging only)

| Area | Doc | Tool |
|---|---|---|
| D/E 30B/70B baseline | [`DE_EXECUTION_PACKET.md`](DE_EXECUTION_PACKET.md) | [`scripts/de_execution_packet.py`](../scripts/de_execution_packet.py) (+ [`examples/de_packet_canary/`](../examples/de_packet_canary/)) |
| v54 training/heldout | [`V54_TRAINING_AND_HELDOUT_PACKET.md`](V54_TRAINING_AND_HELDOUT_PACKET.md) | [`scripts/v54_generation_training_packet.py`](../scripts/v54_generation_training_packet.py) |
| v54 reference model/training | [`V54_REFERENCE_TRAINING.md`](V54_REFERENCE_TRAINING.md) | [`scripts/route_scorer_reference.py`](../scripts/route_scorer_reference.py), [`scripts/free_running_generator_reference.py`](../scripts/free_running_generator_reference.py), [`scripts/v54_reference_training.py`](../scripts/v54_reference_training.py) |
| v58 blind eval | [`V58_BLIND_EVAL_PACKET.md`](V58_BLIND_EVAL_PACKET.md), [`V58_REVIEWER_GUIDE.md`](V58_REVIEWER_GUIDE.md) | [`scripts/v58_blind_eval_packet.py`](../scripts/v58_blind_eval_packet.py) (+ [`examples/v58/`](../examples/v58/)) |
| audit-my-repo design-partner review | [`AUDIT_DESIGN_PARTNER_REVIEW.md`](AUDIT_DESIGN_PARTNER_REVIEW.md) | [`scripts/audit_review_to_jsonl.py`](../scripts/audit_review_to_jsonl.py) |

## Contributor & PM

- Contributing guide (evidence boundary, readiness ladder, lockstep files):
  [`../CONTRIBUTING.md`](../CONTRIBUTING.md)
- Code owners: [`../.github/CODEOWNERS`](../.github/CODEOWNERS)
- PR template: [`../.github/pull_request_template.md`](../.github/pull_request_template.md)
- Issue forms: [`../.github/ISSUE_TEMPLATE/`](../.github/ISSUE_TEMPLATE/)
  (`evidence-blocker`, `readiness-transition`, `design-partner-finding-review`)
