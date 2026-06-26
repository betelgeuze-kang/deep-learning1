# Dispatch: v53 summary↔manifest sha256 binding (blocker #2)

Source: Kiro Opus 4.8 prompt architect draft
Worker: Cursor CLI Composer 2.5 (`composer-2.5`)
Routing: Codex goal owner -> Kiro prompt -> Cursor Composer 2.5 -> Codex diff review + ai-verify acceptance

## Goal

v53 source-benchmark 검증을 summary-only spoof에 강하게 만든다. 현재 `tools/verify_artifact.py`의
`v53-source-benchmark` 경로는 v53i/v53t/v53ap/v53aq summary CSV를 경로로 직접 읽어 필드값만 비교하고,
각 run 디렉터리의 `sha256_manifest.csv`에 대해 그 summary 파일을 hash-bind하지 않는다. run을 재생성하지
않고 `results/*_summary.csv`만 편집해도 통과되는 구멍을 닫는다.

(handoff 기준 blocker #1 `future_neighbor_used=0`는 이미 worktree에 구현 완료. 이 슬라이스에서 item 1은 건드리지 말 것.)

## Scope

- 각 v53 summary(v53i/v53t/v53ap/v53aq)에 대해, 해당 run 디렉터리의 `sha256_manifest.csv`에서 그 summary
  파일에 대응하는 row를 찾아 실제 파일 sha256과 manifest 기록 sha256이 일치하는지 검증하는 최소 binding 체크 추가.
- summary가 manifest에 미등재 / run 디렉터리·manifest 부재 / sha256 불일치이면 fail-closed
  (`machine_foundation_ready=True` 경로에서 error append).
- 기존 all-or-none partial-evidence 패치(summary 4종 + v1 exit ledger)와 충돌 금지.
- `v1_exit_ledger`의 기존 per-criterion sha256 바인딩 규약(`sha256:` prefix, 동일 헬퍼)을 재사용.
- 어느 manifest를 신뢰 기준으로 삼는지(각 summary의 `run_dir/sha256_manifest.csv`)를 코드 주석 한 줄로 명시.

## File candidates

- `tools/verify_artifact.py` (v53-source-benchmark 검증 블록, `DEFAULT_V53_SUMMARY_PATHS` 근방, 약 4842~4925행)
- `experiments/test_v53t_complete_source_audit_readiness_gate.sh` (positive + summary-tamper negative control 추가)
- (필요시) `experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh`
- read-only 참고: `experiments/run_v53t_*.sh`, `experiments/run_v53aq_*.sh` (`sha256_manifest.csv` 생성 위치/등재 여부 확인)

## Verification criteria

1. `python3 -m py_compile tools/verify_artifact.py`
2. `bash -n scripts/ai-verify.sh experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh experiments/test_v53t_complete_source_audit_readiness_gate.sh`
3. `V53AQ_REUSE_EXISTING=0 ./experiments/test_v53aq_complete_source_abgh_real_adapter_measured.sh`
4. `V53T_REUSE_EXISTING=0 ./experiments/test_v53t_complete_source_audit_readiness_gate.sh`
5. full v53 verifier (positive):
   ```
   tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json \
     --v53i-summary results/v53i_complete_source_query_instantiation_summary.csv \
     --v53t-summary results/v53t_complete_source_audit_readiness_gate_summary.csv \
     --v53ap-summary results/v53ap_complete_source_abgh_same_query_measured_summary.csv \
     --v53aq-summary results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv \
     --v1-exit-ledger results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv
   ```
   -> pass
6. negative control: summary 파일 임시 사본의 한 필드를 1글자 변경 후 동일 verifier 호출 -> sha256 불일치로 fail.
   (임시 사본에서만 수행, 원본 results 산출물은 끝나면 원상복구/정리)
7. `./scripts/ai-verify.sh` -> pass

## Forbidden changes / invariants

- 연구 설계, metric 정의, seed, data split, baseline, benchmark protocol, acceptance threshold, evidence boundary 변경 금지.
- route invariant 유지: value-bearing route hint path만. `routing_trigger_rate=active_jump_rate=0`, `future_neighbor_used=0` 불변.
- 기존 all-or-none partial-evidence 동작과 `EXPECTED_V53_SUMMARY_CHECKS` 계약을 약화시키지 말 것.
- fixture 결과를 real evidence로 승격 금지(이 슬라이스는 검증 강화일 뿐 promotion 아님).
- unrelated dirty worktree 변경(README, docs/ai/*, .github/* 등) revert/수정 금지.
- 대규모 리팩터 금지. v53 verifier 내 최소 binding 체크만 추가.

## Runtime / dataset / checkpoint / network policy

- 로컬 경량 검증만. 네트워크 fetch, dataset/checkpoint/weight download, model generation, long GPU/ROCm job,
  remote/registry write, git push/merge 금지.
- 새 산출물을 git에 추가하지 말 것(results 트리는 의도적으로 ignore). 새 추적 파일 생성 금지.

## Worker output (요구 형식)

```
Changed files:
Test results:
Failing test names:
Core diff summary:
Blockers:
Specific files/diffs needing Codex review:
```
