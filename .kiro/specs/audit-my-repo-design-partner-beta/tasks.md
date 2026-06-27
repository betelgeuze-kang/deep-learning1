# Implementation Plan: audit-my-repo 디자인 파트너 베타 후보

## Overview

본 계획은 **새 코드·엔트리포인트·스키마·계약을 만들지 않는다** (Req 9). 산출물은 두 종류다.

1. **검증 하니스(verification harness)** — 기존 게이트/판정 로직을 고정하는 속성 기반 테스트(PBT)와 통합 드라이버. 기존 스크립트(`scripts/audit_my_repo*.py`)와 스키마(`schemas/local_repo_audit_*.schema.json`)를 **변경 없이** import/서브프로세스로 호출하여 동작을 단언한다. 합성/픽스처만 사용하며 이 경로는 `real_benchmark`로 절대 승격되지 않는다(게이트 0 유지).
2. **실제 증거 번들** — 인간이 제공한 ≥10개 실제 저장소·≥300개 인간 라벨·≥3개 유지보수자 피드백을 기존 라벨 루프에 통과시켜 `results/`(gitignored) 하위에 만드는 증거. 이 단계의 인간 입력은 에이전트가 조작할 수 없으며, 에이전트 작업은 **하니스 구축·실행·검증**만 담당한다.

구현 언어는 기존 도구 체계와 동일하게 **Python**(`hypothesis`)을 사용한다(설계 Testing Strategy). 테스트는 `scripts/` 하의 기존 `test_*.py` 관례를 따른다. 모든 증거 산출물은 `results/` 하위(gitignore 대상)에 둔다.

각 작업은 충족하는 요구사항 절(Req 1..9)과 설계 컴포넌트(C1..C7)를 명시한다.

## Tasks

- [ ] 1. 검증 하니스 스캐폴딩
  - [x] 1.1 게이트/판정 함수 호출용 테스트 하니스 모듈 골격 작성
    - `scripts/audit_my_repo_benchmark.py`의 `readiness_gate_rows`, `write_benchmark_readiness_json`, `real_human_label_basis` 계산 경로, `READINESS_GATES`, 임계 상수(`MIN_REAL_REPOS_FOR_BETA`/`MIN_HUMAN_LABELS_FOR_BETA`/`MIN_MAINTAINER_FEEDBACK_FOR_BETA`/정밀도 임계)를 **변경 없이** import하는 헬퍼를 작성
    - 합성 메트릭 딕셔너리·합성 라벨/발견 행 빌더와 `tmp_path`/`results/` 하위 fixture 경로 유틸 추가(모든 fixture는 gitignore 대상 경로)
    - `hypothesis` 가용성 확인(미설치 시 설치 안내, 네트워크 금지 정책 준수)
    - _Requirements: 8.3, 9.4 / C5, C7_
  - [ ]* 1.2 핵심 산출물 형태 단위 테스트
    - `audit_manifest.json`(입력 경로/sha256/`source_scope`), `first_report_smoke.json`(측정 형태·`fixture_only`·readiness=0), `benchmark_run_metrics.csv` 케이스 행, `benchmark_evaluation.json` 키, `benchmark_readiness.json` 행 4필드(`gate_id`/`passed`/`observed`/`required`/`blocked_reason`) 형태를 단언
    - _Requirements: 1.2, 2.1, 2.3, 2.4, 4.4, 5.1 / C1, C2, C5_

- [ ] 2. 게이트 계산 로직 속성 고정 (PBT)
  - [ ]* 2.1 Property 2 — 임계 게이트 단조성 테스트 작성
    - **Property 2: 실제 저장소 수 임계 게이트 단조성** (basis·count 조합 100회 이상)
    - `real_repo_requirement_met == (basis==1 AND n>=10)` 및 300/3 임계 동형성 단언, 전용 파일 `scripts/test_amr_beta_p02_threshold_gates.py`
    - **Validates: Requirements 1.7, 3.8 / C5**
  - [ ]* 2.2 Property 8 — 증거 기반 정의 테스트 작성
    - **Property 8: real_human_label_basis 정의**
    - `(namespace, confirm, cases, human_labeled/synthetic)` 조합 생성, `product_readiness_calculated_from_real_labels` 정의식 단언, 전용 파일 `scripts/test_amr_beta_p08_basis_definition.py`
    - **Validates: Requirements 4.5, 6.1, 8.1 / C5**
  - [ ]* 2.3 Property 9 — basis=0 강제 0 전파 테스트 작성
    - **Property 9: basis=0이면 모든 하위 게이트와 베타 게이트가 0**
    - 임의 메트릭 집합에 basis=0 주입 시 14개 `*_requirement_met`와 `design_partner_beta_candidate_ready`가 모두 0임을 단언, 전용 파일 `scripts/test_amr_beta_p09_basis_zero.py`
    - **Validates: Requirements 4.5, 6.1 / C5**
  - [ ]* 2.4 Property 10 — 베타 게이트 논리곱 테스트 작성
    - **Property 10: 베타 게이트는 하위 게이트의 논리곱**
    - 14개 비트 조합에 대해 `beta == AND(subgates)`, `beta==1 ⇒ blocked_gate_rows==0`, `beta==0 ⇒ blocked_gate_rows>0` 단언, 전용 파일 `scripts/test_amr_beta_p10_beta_conjunction.py`
    - **Validates: Requirements 5.3, 5.4 / C5**
  - [x]* 2.5 Property 11 — 체크리스트 집계 보존 테스트 작성
    - **Property 11: 체크리스트 집계 보존**
    - `passed_gate_rows + blocked_gate_rows == gate_rows == len(rows)`, `blocked_reason`은 passed=1에서 빈 문자열·passed=0에서 비어있지 않음 단언, 전용 파일 `scripts/test_amr_beta_p11_checklist_aggregation.py`
    - **Validates: Requirements 5.5, 5.1 / C5**
  - [x]* 2.6 Property 13 — 차단 readiness 플래그 0 불변식 테스트 작성
    - **Property 13: 차단 readiness 플래그 0 불변식**
    - 임의 산출물에 대해 `release_ready`/`public_comparison_claim_ready`/`real_model_execution_ready`가 0, 위반 산출물은 readiness 스키마(`const 0`) 검증에서 거부됨을 단언, 전용 파일 `scripts/test_amr_beta_p13_blocked_flags_zero.py`
    - **Validates: Requirements 6.4, 6.5 / C5, C7**

- [ ] 3. 증거 경계·라벨 루프 판정 속성 고정 (PBT)
  - [ ]* 3.1 Property 4 — 템플릿 행 불변식 테스트 작성
    - **Property 4: 템플릿 행 불변식**
    - 검증된 합성 감사 번들에서 생성한 모든 템플릿 행이 `template_only==1`, `human_labeled==0`이고 `case_id`/`candidate_label_id`/`source_finding_id`/`source_review_queue_id`/주 인용 스팬을 비어있지 않게 결합, readiness 4필드 0 유지 단언, 전용 파일 `scripts/test_amr_beta_p04_template_invariants.py`
    - **Validates: Requirements 3.1, 3.2 / C3**
  - [ ]* 3.2 Property 5 — human_labeled 결정만 수용 테스트 작성
    - **Property 5: human_labeled 결정만 수용**
    - `human_labeled`/별칭 `human_reviewed`가 참이 아닌 행이 하나라도 있으면 인테이크 컴파일이 거부되고 그 행이 `benchmark_labels.jsonl`에서 제외됨을 단언, 전용 파일 `scripts/test_amr_beta_p05_human_labeled_only.py`
    - **Validates: Requirements 3.4 / C4**
  - [ ]* 3.3 Property 6 — 저장소 스냅샷 잠금 판정·집계 테스트 작성
    - **Property 6: 저장소 스냅샷 잠금 판정 및 집계**
    - git 가용/dirty/기대 HEAD 유무/일치 조합에 대해 `repo_snapshot_locked` 판정식과, 미잠금 케이스 존재 시 `repo_snapshot_requirement_met==0` 단언(소형 git fixture 또는 상태 매개변수화), 전용 파일 `scripts/test_amr_beta_p06_repo_snapshot.py`
    - **Validates: Requirements 3.6, 3.7 / C5**
  - [ ]* 3.4 Property 7 — 혼동 분류·정밀도 정합 테스트 작성
    - **Property 7: 혼동 행 분류 일관성과 정밀도 정합**
    - 라벨/발견 쌍 집합에서 `tp/fp/fn/tn` 상호 배타(합 1), `precision==tp/(tp+fp)`(분모>0), P0/P1 부분집합 동일 관계 단언, 전용 파일 `scripts/test_amr_beta_p07_confusion_precision.py`
    - **Validates: Requirements 4.1 / C5**
  - [ ]* 3.5 Property 12 — 합성/픽스처 출처 보존 테스트 작성
    - **Property 12: 합성/픽스처 출처 보존(재분류 불가)**
    - 인테이크 라벨의 `synthetic`이 후보의 `synthetic`과 동일, 확인된 `real_benchmark`가 아니면 템플릿 행 `synthetic`이 항상 1임을 단언, 전용 파일 `scripts/test_amr_beta_p12_synthetic_preservation.py`
    - **Validates: Requirements 6.2, 6.3, 6.6 / C3, C4**

- [ ] 4. 시간·결정성·검증 재계산 속성 고정 (PBT)
  - [ ]* 4.1 Property 3 — 첫 보고서 시간 예산 경계 테스트 작성
    - **Property 3: 첫 보고서 시간 예산 경계**
    - 임의 `(total_wall_ms>=0, max_wall_ms>0)`에 대해 `within_time_budget==int(total_wall_ms<=max_wall_ms)`, `max_wall_ms==600000`에서 `total_wall_ms>600000 ⇒ within_time_budget==0` 단언, 전용 파일 `scripts/test_amr_beta_p03_time_budget.py`
    - **Validates: Requirements 2.2, 2.5, 2.6 / C2, C5**
  - [ ]* 4.2 Property 1 — 감사 결정성(재실행 멱등) 테스트 작성
    - **Property 1: 감사 결정성**
    - 소형 랜덤 fixture 저장소에 대해 동일 경로·동일 `--mode quick` 두 번 실행 시 `cache_key`·`semantic_result_sha256` 동일 단언(비용 통제를 위해 quick·소형 fixture로 제한), 전용 파일 `scripts/test_amr_beta_p01_audit_determinism.py`
    - **Validates: Requirements 1.3 / C1**
  - [ ]* 4.3 Property 14 — 검증 재계산이 수동 편집을 거부 테스트 작성
    - **Property 14: 검증 재계산이 수동 편집을 거부**
    - 검증을 통과하는 `benchmark_readiness.json`/결합 매니페스트/요약의 readiness·게이트 필드를 임의 변조 후 `--verify-existing`이 드리프트로 거부(종료 코드 1)함을 단언(tamper 환경변수 훅 활용), 전용 파일 `scripts/test_amr_beta_p14_verify_rejects_tamper.py`
    - **Validates: Requirements 8.2, 8.4 / C5, C7**

- [ ] 5. Checkpoint - 속성/단위 테스트 통과 확인
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. 픽스처 기반 라벨 루프 하니스 와이어링 (비승격)
  - [ ] 6.1 첫 보고서 스모크 통합 드라이버 작성
    - `audit_my_repo_first_report_smoke.py`를 픽스처에 대해 서브프로세스로 실행, `within_time_budget`·`fixture_only=1`·`design_partner_beta_candidate_ready=0` 단언, 실패/초과 시 `--out` 관리 산출물 정리 동작 검증, 파일 `scripts/test_amr_beta_loop_first_report.py`
    - _Requirements: 2.1, 2.2, 2.4 / C2_
  - [ ] 6.2 template→intake→benchmark 합성 픽스처 통합 드라이버 작성
    - `audit_my_repo_label_template.py` → `audit_my_repo_label_intake.py` → `audit_my_repo_benchmark.py`를 합성/픽스처 입력으로 연결 실행(비-real_benchmark 또는 합성 케이스 포함). 게이트가 0으로 유지되고 `synthetic` 표식이 라벨까지 보존되며 product readiness가 0임을 단언(증거 경계). 파일 `scripts/test_amr_beta_loop_label_pipeline.py`
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 6.1, 6.2, 6.3 / C3, C4, C5_
  - [ ] 6.3 네임스페이스 확인 가드 통합 테스트 작성
    - `--namespace real_benchmark`를 `--confirm-real-benchmark-namespace` 없이 호출 시 종료 코드 2·산출물 미기록·표준오류 메시지를 단언, 확인 플래그 동반 시 진행을 단언. 파일 `scripts/test_amr_beta_loop_namespace_guard.py`
    - _Requirements: 7.1, 7.2, 7.3 / C5_
  - [ ] 6.4 `--verify-existing` 드리프트 거부 통합 테스트 작성
    - 픽스처 벤치마크 산출물에 대해 `--verify-existing`이 정상 통과, 변조/스키마 위반/인테이크·케이스 감사 재검증 실패 시 종료 코드 1을 단언(`AUDIT_MY_REPO_*_TAMPER_BEFORE_VERIFY` 음성 통제 활용). 파일 `scripts/test_amr_beta_loop_verify_existing.py`
    - _Requirements: 8.3, 8.4 / C5, C7_

- [ ] 7. readiness 체크리스트 + FP/FN 도출 하니스 (픽스처)
  - [ ] 7.1 readiness 체크리스트 산출·집계 검증 드라이버 작성
    - 픽스처 벤치마크에서 `benchmark_readiness.json`을 산출하고 스키마 검증(`tools/validate_json_schemas.py --schema-instance`), `gate_rows/passed_gate_rows/blocked_gate_rows` 균형과 차단 사유 기록, 차단 플래그 const 0을 단언. 파일 `scripts/test_amr_beta_readiness_checklist.py`
    - _Requirements: 5.1, 5.2, 5.5, 6.4, 6.5 / C5, C7_
  - [ ] 7.2 FP/FN 목록 도출 헬퍼 작성 (results/ 하 비커밋)
    - `benchmark_confusion_rows.csv`의 FP/FN 행만 추출하여 케이스 식별자·발견 식별자·인용 스팬(파일/라인/sha256)을 포함한 FP/FN 목록을 `results/` 하위에 산출하는 헬퍼와 검증 테스트 작성. 신규 커밋 엔트리포인트/계약을 만들지 않고 `results/`(gitignore) 내 ad-hoc 도출로 유지하며 기존 `design-partner-finding-review` 이슈 템플릿 필드와 정합. 파일 `scripts/test_amr_beta_fp_fn_derivation.py`
    - _Requirements: 4.1, 4.2, 4.3, 9.3, 9.4 / C5, C6_

- [ ] 8. Checkpoint - 하니스 통과 확인
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. 실제 증거 수집 (HUMAN-INPUT — 에이전트가 조작 불가)
  - [ ] 9.1 [HUMAN-INPUT] 최소 10개의 실제 로컬 저장소(clean git worktree) 제공
    - 사람이 비합성 실제 저장소 ≥10개를 로컬에 준비하고 각 케이스의 기대 HEAD를 고정. 에이전트는 이 입력을 생성·합성하지 않으며, 제공된 경로만 감사 대상으로 사용한다.
    - _Requirements: 1.7, 3.6 / C1_
  - [ ] 9.2 [HUMAN-INPUT] 최소 300개의 인간 라벨 결정 JSONL 제공
    - 디자인 파트너가 `candidate_label_id`로 키된 `human_labeled=true` 결정 행(`expected`/`priority`/`reviewer_id`)을 ≥300개 작성. 에이전트는 라벨을 날조하지 않으며 픽스처/합성 라벨로 대체하지 않는다.
    - _Requirements: 3.4, 3.8 / C4_
  - [ ] 9.3 [HUMAN-INPUT] 최소 3개의 유지보수자 피드백 소스 JSONL 제공
    - 사람이 고유 `maintainer_id`·`human_feedback`를 가진 피드백을 ≥3개 제공. 에이전트는 피드백을 생성하지 않는다.
    - _Requirements: 5.3 / C5_

- [ ] 10. 실제 real_benchmark 증거 실행 (사용자 런타임 승인 후; 합성 라벨 조작 금지)
  - [ ] 10.1 ≥10개 실제 저장소 감사 실행
    - 9.1에서 제공된 각 저장소에 대해 `audit_my_repo.sh <repo> --mode quick|full --out results/<repo>_audit`를 실행하여 소스 바운드 발견과 `audit_manifest.json`을 생성(종료 코드 0). 오프라인 동작 확인(`external_network_used==0`). 합성 저장소를 만들어 보충하지 않는다.
    - _Requirements: 1.1, 1.2, 1.3, 1.6, 1.7 / C1_
  - [ ] 10.2 첫 보고서 시간 예산 측정 기록
    - `audit_my_repo_first_report_smoke.py --out results/audit_first_report_smoke`로 600초 이내 완료를 1회 측정, `within_time_budget` 영수증을 fixture-only로 기록(베타/릴리스 readiness 미상승).
    - _Requirements: 2.1, 2.2, 2.4 / C2_
  - [ ] 10.3 감사별 라벨 템플릿 생성
    - 검증된 각 감사 번들에 대해 `audit_my_repo_label_template.py --audit-output results/<repo>_audit --out results/<repo>_label_template --case-id <repo>`로 `template_only=1` 후보 행 생성, 입력 감사 검증 실패 시 중단.
    - _Requirements: 3.1, 3.2, 3.9 / C3_
  - [ ] 10.4 인간 결정 인테이크 컴파일
    - 9.2의 결정 JSONL과 10.3의 템플릿으로 `audit_my_repo_label_intake.py`를 실행하여 `benchmark_labels.jsonl` 생성. `human_labeled` 미충족 행 거부, `synthetic` 출처 보존, 결정/템플릿 sha256 결합 확인.
    - _Requirements: 3.3, 3.4, 3.10, 6.1, 6.2, 6.3, 6.6 / C4_
  - [ ] 10.5 real_benchmark 벤치마크 실행
    - `audit_my_repo_benchmark.py --label-intake results/<repo>_label_intake --feedback <9.3 feedback> --namespace real_benchmark --confirm-real-benchmark-namespace --mode full --out results/audit_benchmark`로 평가. 인테이크 재검증, 혼동 행·정밀도·인용 유효성·재실행 검사·`benchmark_readiness.json` 게이트 산출.
    - _Requirements: 3.5, 3.6, 3.7, 3.11, 4.1, 4.4, 5.1, 7.1 / C5_
  - [ ] 10.6 실제 FP/FN 이슈 목록 산출
    - 10.5의 `benchmark_confusion_rows.csv` FP/FN 행에서 7.2 헬퍼로 실제 FP/FN 목록을 `results/` 하위에 산출하고 `design-partner-finding-review` 이슈 템플릿 필드로 정리(케이스/발견/인용 스팬 포함). 합성 케이스 미승격 확인.
    - _Requirements: 4.2, 4.3, 4.5 / C5, C6_
  - [ ] 10.7 전 산출물 `--verify-existing` 재검증
    - 벤치마크·인테이크·케이스별 감사 산출물에 `--verify-existing`을 실행하여 스키마 검증·결합 값 재계산·재검증 통과를 확인, 드리프트/가드 실패 시 종료 코드 1로 차단됨을 확인.
    - _Requirements: 8.2, 8.3, 8.4 / C5, C7_
  - [ ] 10.8 readiness 게이트 상태·차단 사유 기록
    - `benchmark_readiness.json`의 14개 게이트 관찰값/요구값/통과 비트/차단 사유와 `design_partner_beta_candidate_ready`/`product_readiness_calculated_from_real_labels` 최종 상태를 정리. 인간 라벨이 유일 상승 경로임을 확인(수동 편집 불가).
    - _Requirements: 5.3, 5.4, 5.5, 8.1 / C5, C7_

- [ ] 11. 거버넌스·기존 엔트리포인트 재사용 검증
  - [ ] 11.1 출력 경계·git 추적·엔트리포인트 재사용 검증
    - 모든 증거가 `results/` 하위이고 `.gitignore` 대상임을 확인, 10MB 이상/체크포인트 산출물이 git 추적에 추가되지 않음을 확인, 8개 기존 엔트리포인트·기존 readiness 스키마·기존 이슈 템플릿만 사용했고 신규 계약/스키마가 없음을 `audit_my_repo_package.py --verify-existing`의 `REQUIRED_PRODUCT_FILES`/스키마 sha 목록으로 단언. 파일 `scripts/test_amr_beta_governance.py`
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6 / C1, C5_

- [ ] 12. Final Checkpoint - 저장소 전체 검증
  - `./scripts/ai-verify.sh`를 실행하여 전체 검증 통과를 확인. Ensure all tests pass, ask the user if questions arise.

## Notes

- `*` 표시 하위 작업(2.x, 3.x, 4.x, 1.2)은 선택적 속성/단위 테스트로, 빠른 진행을 위해 건너뛸 수 있으나 게이트 로직 회귀 방지를 위해 권장된다.
- **각 속성 테스트는 단일 속성을 다루는 독립 파일**이며 최소 100회 반복(`@settings(max_examples=100)` 이상)으로 검증한다(설계 Testing Strategy).
- **새 코드/엔트리포인트/스키마/계약을 만들지 않는다(Req 9).** 모든 작업은 기존 스크립트·스키마·이슈 템플릿을 import/서브프로세스로 호출해 동작을 단언하거나 증거를 생성한다. 테스트와 `results/` 하 비커밋 도출 헬퍼는 신규 계약이 아니다.
- **증거 경계:** 합성/픽스처는 절대 `real_benchmark`로 승격되지 않는다. `release_ready`/`public_comparison_claim_ready`/`real_model_execution_ready`는 항상 0이며 `design_partner_beta_candidate_ready`만 본 스펙 범위다.
- **9.1–9.3은 인간 입력 작업**으로, 에이전트가 실제 라벨·저장소·피드백을 날조할 수 없다. 에이전트는 하니스(1–8)와 실제 실행·검증(10–12)만 수행하며, 픽스처/합성은 비승격 하니스 테스트에만 쓴다.
- **런타임 승인:** 10.x의 실제 `real_benchmark` 전체 실행(≥10 저장소·≥300 라벨)은 긴 실행/증거 수집이므로 AGENTS.md에 따라 사용자 승인 후 수행한다. 네트워크/GPU/다운로드/체크포인트 materialization은 금지.
- **9.1–9.3(인간 입력) 작업은 에이전트 병렬 스케줄링 대상이 아니므로 아래 Task Dependency Graph에서 의도적으로 제외**한다. 단, 10.1은 9.1에, 10.4는 9.2에, 10.5는 9.3에 논리적으로 의존하므로 해당 인간 입력이 준비된 뒤에 시작해야 한다.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "2.1", "2.2", "2.3", "2.4", "2.5", "2.6", "3.1", "3.2", "3.3", "3.4", "3.5", "4.1", "4.2", "4.3"] },
    { "id": 2, "tasks": ["6.1", "6.2", "6.3", "6.4"] },
    { "id": 3, "tasks": ["7.1", "7.2"] },
    { "id": 4, "tasks": ["10.1", "10.2"] },
    { "id": 5, "tasks": ["10.3"] },
    { "id": 6, "tasks": ["10.4"] },
    { "id": 7, "tasks": ["10.5"] },
    { "id": 8, "tasks": ["10.6", "10.7"] },
    { "id": 9, "tasks": ["10.8"] },
    { "id": 10, "tasks": ["11.1"] }
  ]
}
```
