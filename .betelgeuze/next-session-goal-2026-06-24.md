# Next Session Goal Handoff - 2026-06-24

## Current State

- Repository: `/home/betelgeuze/딥러닝 연구`
- Branch: `main`
- Last pushed commit: `3402054 Verify v54f generation intake decisions`
- `origin/main` and local `main` were aligned at `3402054` before the current uncommitted work.
- Current worktree is dirty. Do not revert unrelated user changes.

## User-Visible Requirement

Continue the active Codex goal from:

`/home/betelgeuze/.codex/attachments/0fe535df-10b9-4f44-904a-23f185d29b07/goal-objective.md`

The immediate priority is still v53 evaluation integrity / machine foundation freeze before D/E baselines or RouteMemory generator promotion.

## Current Uncommitted Work

Known Codex changes in progress:

- `scripts/ai-verify.sh`
  - v53 source benchmark verification now treats v53 summary evidence plus v1 exit ledger as all-or-none.
  - If any of `v53i`, `v53t`, `v53ap`, `v53aq` summaries or the v53t v1 exit ledger exists, all must exist or `ai-verify` exits with:
    `v53 source benchmark has partial summary/exit-ledger artifacts`
- `tools/verify_artifact.py`
  - `v53-source-benchmark` CLI now rejects partial evidence args:
    `v53-source-benchmark: v53 summaries and --v1-exit-ledger must be supplied together`
- `experiments/test_v53t_complete_source_audit_readiness_gate.sh`
  - Adds positive verifier call with all v53 evidence.
  - Adds negative control proving `--v53i-summary` alone is rejected.

Observed unrelated or separate user changes also exist:

- `AGENTS.md`
- `docs/ai/GOAL-LOOP-PLAYBOOK.md`
- `docs/ai/profiles/deep-learning-research.md`
- `docs/ai/prompts/deep_learning_research_goal_start.md`
- `scripts/ai-preflight.sh`
- untracked `docs/ai/prompts/kiro_opus_prompt_architect.md`

Do not revert these unless the user explicitly asks.

## Verification Already Run For Current v53 Partial-Evidence Patch

Passed:

- `python3 -m py_compile tools/verify_artifact.py`
- `bash -n scripts/ai-verify.sh experiments/test_v53t_complete_source_audit_readiness_gate.sh`
- `tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json --v53i-summary results/v53i_complete_source_query_instantiation_summary.csv`
  - expected failure with partial evidence
- Full v53 verifier call with all four summaries plus v1 exit ledger
  - passed
- `./experiments/test_v53t_complete_source_audit_readiness_gate.sh`
  - passed

Not completed after this patch:

- Full `./scripts/ai-verify.sh` was started, then intentionally stopped after worker feedback.

## Worker Feedback Still To Address

Worker `Dewey` found two important v53 blockers:

1. `future_neighbor_used=0` is not represented or verified in v53 summary/manifest/benchmark checks.
2. v53 verification was too summary-only. The all-or-none partial evidence patch addresses part of this, but row-level/manifest binding should be strengthened further.

Recommended next small implementation:

- Add `future_neighbor_used=0` to `v53aq` summary, manifest, boundary, and tests.
- Pass `v53aq_future_neighbor_used=0` and `v53aq_source_span_oracle_selection_used=0` through `v53t` summary, metric row, manifest, boundary, and tests.
- Add benchmark contract checks in `benchmarks/v53_source_bound_freeze.json` and `tools/verify_artifact.py` expected v53 summary checks.
- Update reuse fast paths so stale artifacts missing these new fields are not reused.
- Run:
  - `python3 -m py_compile tools/verify_artifact.py`
  - `bash -n scripts/ai-verify.sh experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh experiments/test_v53t_complete_source_audit_readiness_gate.sh`
  - `V53AQ_REUSE_EXISTING=0 ./experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh`
  - `V53T_REUSE_EXISTING=0 ./experiments/test_v53t_complete_source_audit_readiness_gate.sh`
  - full v53 verifier call
  - `./scripts/ai-verify.sh`

## New Session GOAL Prompt

Paste the following into the next Codex session:

```text
/goal
한글로 진행하라. current main에서 작업하라. 먼저 AGENTS.md, docs/ai/profiles/deep-learning-research.md, 그리고 /home/betelgeuze/.codex/attachments/0fe535df-10b9-4f44-904a-23f185d29b07/goal-objective.md 를 읽어라.

목표는 v53 evaluation integrity / machine foundation freeze를 먼저 닫는 것이다. D/E 30B/70B 실제 외부 evidence, RouteMemory real scorer/generator, v61 SSD-MoE는 이번 작은 슬라이스의 범위가 아니다.

현재 상태:
- main은 마지막 push 기준 origin/main과 3402054에서 맞춰져 있었다.
- 현재 worktree는 dirty다. unrelated user changes를 절대 되돌리지 마라.
- Codex가 진행한 미커밋 변경은 v53 source benchmark partial-evidence fail-closed 보강이다:
  - scripts/ai-verify.sh: v53 summary/v1-exit-ledger evidence를 all-or-none으로 요구
  - tools/verify_artifact.py: v53-source-benchmark partial evidence CLI args 거부
  - experiments/test_v53t_complete_source_audit_readiness_gate.sh: full verifier positive call과 partial evidence negative control 추가
- 이미 통과한 검증:
  - python3 -m py_compile tools/verify_artifact.py
  - bash -n scripts/ai-verify.sh experiments/test_v53t_complete_source_audit_readiness_gate.sh
  - partial v53 verifier call은 기대대로 실패
  - full v53 verifier call은 통과
  - ./experiments/test_v53t_complete_source_audit_readiness_gate.sh 통과
- full ./scripts/ai-verify.sh 는 아직 현재 패치 이후 최종 완료하지 않았다.

다음 즉시 할 일:
1. 현재 git status와 diff를 확인하고 unrelated changes를 분리해서 이해하라.
2. v53 blocker를 마저 구현하라:
   - future_neighbor_used=0 를 v53aq summary/manifest/boundary/test에 추가
   - v53t가 v53aq_future_neighbor_used=0 및 v53aq_source_span_oracle_selection_used=0 를 metric/summary/manifest/boundary/test로 pass-through하게 하라
   - benchmarks/v53_source_bound_freeze.json 과 tools/verify_artifact.py 의 EXPECTED_V53_SUMMARY_CHECKS에 해당 checks를 추가하라
   - reuse fast-path가 새 필드 없는 stale artifact를 재사용하지 않게 grep guard를 추가하라
3. v53 verifier가 summary-only spoof에 더 강해지도록 가능한 작은 row/manifest hash 결합 보강을 검토하되, 대규모 리팩터는 하지 마라.
4. 검증:
   - python3 -m py_compile tools/verify_artifact.py
   - bash -n scripts/ai-verify.sh experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh experiments/test_v53t_complete_source_audit_readiness_gate.sh
   - V53AQ_REUSE_EXISTING=0 ./experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh
   - V53T_REUSE_EXISTING=0 ./experiments/test_v53t_complete_source_audit_readiness_gate.sh
   - tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json --v53i-summary results/v53i_complete_source_query_instantiation_summary.csv --v53t-summary results/v53t_complete_source_audit_readiness_gate_summary.csv --v53ap-summary results/v53ap_complete_source_abgh_same_query_measured_summary.csv --v53aq-summary results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv --v1-exit-ledger results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv
   - ./scripts/ai-verify.sh

금지:
- 외부 네트워크, GPU 작업, checkpoint/download, release, merge, push 금지 unless explicitly approved.
- codex/route-memory-local-energy-policy 브랜치 통째 merge 또는 대규모 cherry-pick 금지.
- unrelated dirty worktree 변경 revert 금지.
- fixture 결과를 real evidence로 승격 금지.

최종 보고에는 current main 대비 변경 파일, 검증 결과, 사용자 가치 개선, 남은 blocker를 포함하라.
```
