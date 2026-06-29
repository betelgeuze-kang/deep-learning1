# Central Readiness Status


This is the human-readable mirror of the machine-enforced typed readiness contract.


- Source of truth: [`readiness/typed_ready.json`](../readiness/typed_ready.json)
- Enforced by: `tools/verify_artifact.py typed-readiness readiness/typed_ready.json` (run from `./scripts/ai-verify.sh`)
- Schema: [`schemas/typed_readiness.schema.json`](../schemas/typed_readiness.schema.json)

Each scope advances along a typed ladder. Only the typed flags below are claimable; bare `vXX_ready` wording is forbidden (`ready_wording_policy: typed-ready-only`). `ready` means the typed flag is `true`; `—` means it is still `false` (blocked) and must not be claimed.


Ladder order: `contract_ready -> fixture_execution_ready -> real_model_execution_ready -> heldout_metric_ready -> human_review_ready -> independent_reproduction_ready -> release_ready`.


## Scope status


| scope_id | contract_ready | fixture_execution_ready | real_model_execution_ready | heldout_metric_ready | human_review_ready | independent_reproduction_ready | release_ready | evidence_path |
|---|---|---|---|---|---|---|---|---|
| pm-foundation-bundle | ready | ready | — | — | — | — | — | `results/v59e_one_command_pm_foundation_demo_summary.csv` |
| v53-benchmark-foundation | ready | ready | — | — | — | — | — | `benchmarks/v53_source_bound_freeze.json` |
| v54-free-running-generation | ready | ready | ready | ready | — | — | — | `results/v54_minimal_real_model_smoke_summary.csv` |
| v58-blind-eval | ready | — | — | — | — | — | — | `results/v1_0_pm_pr_claim_slice_gate/gate_001/pm_blocker_required_artifact_rows.csv` |
| h10-scorer-real-label-promotion | ready | — | — | — | — | — | — | `results/v10_h10_real_label_promotion_readiness_gate/gate_001/pm_h10_real_label_acceptance_rows.csv` |
| v61-ssd-moe-runtime | ready | ready | — | — | — | — | — | `results/v61j_one_command_ssd_resident_demo_summary.csv` |
| v61-real-100b-inference | — | — | — | — | — | — | — | `results/v61j_one_command_ssd_resident_demo_summary.csv` |
| v61i-logical-100b-fixture | ready | ready | — | — | — | — | — | `results/v61j_one_command_ssd_resident_demo_summary.csv` |
| v60-release | ready | — | — | — | — | — | — | `results/v60_architecture_challenge_release_contract_summary.csv` |
| operator-review-return-workflow | ready | — | — | — | — | — | — | `operations/review_return_workflow.json` |
| docs-readme-pr2-cleanup | ready | — | — | — | — | — | — | `docs/PR2_REWRITE_DRAFT.md` |

## v53 / v54 scope separation


`v53` and `v54` are tracked as separate scopes, not one combined `v53-v54-query-evaluation-pipeline` row.


- `v53-benchmark-foundation` is `contract_ready` and `fixture_execution_ready`. It mirrors `benchmarks/v53_source_bound_freeze.json` (`machine_foundation_freeze_ready: true`, 7/7 requirements `pass`). Real-model execution, heldout metric, human review, independent reproduction, and release remain blocked.
- `v54-free-running-generation` is now `contract_ready`, `fixture_execution_ready`, `real_model_execution_ready`, and `heldout_metric_ready` via the minimal local real-model smoke at `results/v54_minimal_real_model_smoke_summary.csv`. This is a tiny heldout execution closure only: external/human labels, independent reproduction, public comparison, and release remain blocked.


The full v54f 1000-row external-label generation intake remains separately blocked until non-fixture generation evidence, verified external labels, and review/adjudication artifacts return through the canonical intake.
