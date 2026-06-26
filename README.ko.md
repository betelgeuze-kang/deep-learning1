# discrete-local-energy 한국어 README

[English README](README.md)

이 저장소는 단계적으로 확장 중인 deterministic C++17 이산 local-energy 연구 프로토타입입니다.

**아티팩트 경계:** 이 패키지는 휴먼 리뷰를 거친 릴리스가 아니라, 자동 검증 가능한 연구 아티팩트입니다.

## Readiness 상태

중앙 readiness는 스코프별로 [`readiness/typed_ready.json`](readiness/typed_ready.json)에 기록되며, `./scripts/ai-verify.sh`의 `tools/verify_artifact.py typed-readiness`로 강제됩니다. 주장 가능한 것은 typed 플래그뿐이며, 단순 `vXX_ready` 표현은 금지됩니다.

- 휴먼 리더블 미러 및 전체 스코프 표: [`docs/STATUS.md`](docs/STATUS.md)
- 도구·패킷·문서 색인: [`docs/INDEX.md`](docs/INDEX.md)
- `v53`과 `v54`는 별도 스코프로 분리되어 추적됩니다:
  - `v53-benchmark-foundation`: `contract_ready` + `fixture_execution_ready` (`benchmarks/v53_source_bound_freeze.json` 미러).
  - `v54-free-running-generation`: `contract_ready`만 충족. `v54/free_running_generation_evidence_intake_contract.json`이 필수 산출물 7개 중 0개만 존재한다고 보고하므로 `fixture_execution_ready`는 `false`로 유지됩니다.
- 모든 스코프에서 real-model execution, heldout metric, human review, independent reproduction, release는 여전히 blocked입니다.

## v1.0 Architecture Challenge 로드맵

`discrete-local-energy`는 RouteMemory, compact RouteHint routing, source-bound evaluation, non-attention generation contract, SSD-resident MoE runtime mechanics를 연구합니다. 이 저장소의 상태 표시는 claim-bound artifact 방식입니다. 어떤 기능이 ready라고 말하려면 typed readiness row와 evidence path가 그 정확한 claim을 뒷받침해야 합니다.

공식 현재 상태는 [`readiness/typed_ready.json`](readiness/typed_ready.json)에 있습니다. 긴 과거 checkpoint 기록은 [`docs/archive/IMPLEMENTATION_HISTORY.md`](docs/archive/IMPLEMENTATION_HISTORY.md)로 옮겼습니다.

## 현재 Readiness

| Scope | Contract | Fixture | Real execution | Heldout | Human review | Release |
|---|---:|---:|---:|---:|---:|---:|
| v53 benchmark foundation | ✅ | ✅ | N/A | ⛔ | ⛔ | ⛔ |
| v54 generation | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| D/E 30B-70B baselines | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |
| v58 blind evaluation | ✅ | ⛔ | ⛔ | ⛔ | ⛔ | ⛔ |
| v61 SSD-MoE | ✅ | ✅ | ⛔ | ⛔ | ⛔ | ⛔ |

공식 상태: [`readiness/typed_ready.json`](readiness/typed_ready.json)

마지막 검토: 2026-06-25

## 현재 실제로 동작하는 것

- v53 benchmark foundation은 machine-prepared source-bound benchmark surface로 동결되어 있습니다. 10개 pinned public repository, 1000 query row, 1000 source-span row, direct query/span binding audit, unseen repository split, A/B/G/H internal pre-baseline evidence가 묶여 있습니다.
- v54 generation contract와 fixture path는 준비되어 있지만, real free-running generation evidence는 아직 blocked입니다.
- v61 SSD-MoE는 contract/fixture 수준의 R&D track입니다. real SSD-resident model runtime claim이 아닙니다.
- Local preview tooling은 evidence-bound repository audit와 scaling demo를 제공합니다. 다만 release나 public benchmark claim은 아닙니다.

## 다음 Blocker

- D/E 30B-70B real baseline evidence intake가 아직 없으므로 public comparison 문구는 계속 blocked입니다.
- v54 real free-running generation은 fixture readiness를 넘어가려면 실제 model execution evidence가 필요합니다.
- v58 blind evaluation은 real blind response, independent reviewer, disagreement adjudication, accepted human review evidence가 필요합니다.
- v61 one-token logits parity, real runtime execution, generation, latency, near-frontier quality claim은 아직 blocked입니다.
- Release readiness는 typed readiness, evidence ledger, human review, independent reproduction, artifact contract가 모두 일치하기 전까지 blocked입니다.

## 검증

먼저 저렴한 로컬 검증을 사용합니다.

```bash
./scripts/ai-verify.sh
tools/verify_artifact.py typed-readiness readiness/typed_ready.json
```

주요 contract 검증:

```bash
tools/verify_artifact.py v53-source-benchmark benchmarks/v53_source_bound_freeze.json   --v53i-summary results/v53i_complete_source_query_instantiation_summary.csv   --v53t-summary results/v53t_complete_source_audit_readiness_gate_summary.csv   --v53ap-summary results/v53ap_complete_source_abgh_same_query_measured_summary.csv   --v53aq-summary results/v53aq_complete_source_abgh_real_adapter_measured_summary.csv   --v1-exit-ledger results/v53t_complete_source_audit_readiness_gate/gate_001/complete_source_v1_exit_criteria_rows.csv
```

## 핵심 진입점

- 로드맵: [`docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md`](docs/V1_0_ARCHITECTURE_CHALLENGE_ROADMAP.md)
- v61 runtime 방향: [`docs/V61_SSD_RESIDENT_MOE_RUNTIME.md`](docs/V61_SSD_RESIDENT_MOE_RUNTIME.md)
- Pipeline migration 메모: [`docs/PIPELINE_MIGRATION.md`](docs/PIPELINE_MIGRATION.md)
- Review-return contract: [`operations/review_return_workflow.json`](operations/review_return_workflow.json)
- 과거 구현 이력: [`docs/archive/IMPLEMENTATION_HISTORY.md`](docs/archive/IMPLEMENTATION_HISTORY.md)
