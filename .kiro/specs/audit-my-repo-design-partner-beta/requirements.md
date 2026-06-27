# Requirements Document

## Introduction

본 스펙은 기존 `audit-my-repo` 도구를 현재 알파(alpha) 상태에서 "디자인 파트너 베타 후보(design-partner beta candidate)" 상태로 끌어올리는 것을 목표로 한다. 핵심은 현재 `design_partner_beta_candidate_ready = 0`으로 묶여 있는 게이트(gate)를 막고 있는 조건들을 실제 인간 라벨(human label) 증거로 닫는 것이다. 이 작업은 프로젝트에서 가장 빠른 로컬 PC 제품화 경로(local-PC productization path)에 해당한다.

이 스펙은 다음 5개의 구체적 작업을 EARS 요구사항으로 다룬다.

1. 5~10개의 실제 로컬 저장소(local repository)에 대해 quick/full 감사(audit) 실행
2. 첫 보고서(first report) 생성 시간이 10분 이내임을 측정
3. 라벨 템플릿(label template) → 라벨 인테이크(label intake) → 벤치마크 루프(benchmark loop)로 이어지는 인간 라벨 루프(human-label loop) 1회 완주
4. 실제 라벨 기반 벤치마크 결과로부터 거짓 양성(false positive) / 거짓 음성(false negative) 이슈 목록 생성
5. `design_partner_beta_candidate_ready`를 1로 전환하기 위해 정확히 무엇이 참이어야 하는지를 정의하는 체크리스트 생성

추가로 본 스펙은 기존 시스템의 **증거 경계(evidence boundary)** 와 **게이트 무결성(gate integrity)** 제약을 요구사항/제약으로 명시한다. 본 스펙은 기존 계약(contract)을 재발명하지 않으며, 기존 엔트리포인트/스키마/이슈 템플릿을 재사용한다.

**범위 밖(Out of Scope):** `release_ready`, `public_comparison_claim_ready`, `real_model_execution_ready`는 본 스펙에서 다루지 않으며 0/false로 유지된다. 새로운 도구/스크립트 생성, 새로운 계약 정의, 네트워크/GPU/다운로드 도입은 범위 밖이다.

## Glossary

- **audit-my-repo**: 로컬·오프라인 코드/문서/설정 감사 도구. 파일/라인/sha256 인용(citation)이 결합된 소스 바운드 발견(source-bound finding), 기권(abstention), 수동 검토 행, SARIF 2.1.0 출력, 단계별 타이밍, 결정론적 HTML 대시보드, 재현 명령을 기록한다.
- **Audit_Tool**: `scripts/audit_my_repo.py` 및 래퍼 `audit_my_repo.sh`. 단일 저장소 감사를 실행하는 시스템.
- **First_Report_Smoke**: `scripts/audit_my_repo_first_report_smoke.py`. 첫 보고서 경로를 종단 간(end-to-end)으로 검증하고 10분 알파 예산 내 완료를 요구하는 시스템.
- **Label_Template_Tool**: `scripts/audit_my_repo_label_template.py`. 검증된 감사 번들에서 템플릿 전용(template-only) 후보 라벨 행을 생성하는 시스템.
- **Label_Intake_Tool**: `scripts/audit_my_repo_label_intake.py`. 인간 결정(human decision) 행을 받아 벤치마크 라벨로 컴파일하는 시스템.
- **Benchmark_Harness**: `scripts/audit_my_repo_benchmark.py`. 라벨/피드백을 평가하고 `benchmark_readiness.json`을 포함한 증거 산출물을 작성하며 베타 게이트를 계산하는 시스템.
- **Review_Converter**: `scripts/audit_review_to_jsonl.py`. GitHub 이슈 기반 인간 검토 라벨을 JSONL 결정 행으로 정규화하는 보조 시스템.
- **Verifier**: 프로젝트 검증기(`tools/verify_local_audit.py` 및 각 도구의 `--verify-existing` 경로). 산출물 무결성과 readiness 경계를 검증하는 시스템.
- **design_partner_beta_candidate_ready**: 디자인 파트너 베타 후보 게이트. `Benchmark_Harness`가 하위 요구사항으로부터 계산하는 0/1 정수 플래그. 실제 인간 라벨 증거가 모든 하위 게이트를 만족할 때만 1이 된다.
- **human-label loop**: 라벨 템플릿 생성 → 인간 라벨 인테이크 → 벤치마크 평가로 이어지는 단일 증거 수집 사이클. 베타 게이트를 올릴 수 있는 유일한 경로.
- **real_benchmark namespace**: 비합성(non-synthetic) 인간 라벨 케이스만 제품 readiness 계산에 사용하는 벤치마크 네임스페이스. `--namespace real_benchmark` 사용 시 `--confirm-real-benchmark-namespace` 명시 확인이 필요하다.
- **evidence boundary**: 합성/픽스처(synthetic/fixture) 결과를 실제 증거(real evidence)로 승격(promote)하지 못하게 하는 엄격한 경계.
- **first report time budget**: 첫 검증 보고서 생성 총 소요 시간 상한, 10분(600초).
- **clean expected HEAD snapshot lock**: 각 벤치마크 케이스가 깨끗한(clean) git 워크트리이며 현재 HEAD가 라벨의 `expected_repo_git_head`와 일치하도록 잠그는 조건.
- **citation expectation**: 인간 라벨이 제공한 `expected_line_start`/`expected_line_end`/`expected_span_sha256`에 대해 매칭된 발견이 정확히 그 파일/라인/스팬을 인용하는지에 대한 기대.
- **FP/FN issue list**: 실제 라벨 벤치마크 결과의 혼동 행(confusion rows)에서 도출한 거짓 양성/거짓 음성 발견 목록.
- **beta readiness checklist**: `design_partner_beta_candidate_ready`를 1로 전환하기 위해 충족해야 하는 모든 하위 게이트의 관찰값/요구값/통과 비트/차단 사유를 정의한 체크리스트.

## Requirements

### Requirement 1: 실제 로컬 저장소 감사 실행

**User Story:** 디자인 파트너 검증 담당자로서, 5~10개의 실제 로컬 저장소에 대해 quick/full 감사를 실행하여, 베타 후보 증거의 기반이 되는 실제 감사 산출물을 확보하고 싶다.

#### Acceptance Criteria

1. WHEN 검증 담당자가 존재하는 로컬 저장소 경로와 `--mode quick` 또는 `--mode full` 중 하나를 지정하여 감사를 요청하면, THE Audit_Tool SHALL `results/` 하위의 출력 디렉터리에 소스 바운드 발견 결과와 `audit_manifest.json`을 포함한 감사 번들을 생성하고 종료 코드 0으로 종료한다.
2. WHEN 감사 번들을 생성할 때, THE Audit_Tool SHALL 입력 경로, 입력 sha256, `source_scope`를 단일 `audit_manifest.json` 파일에 기록한다.
3. WHEN 동일한 입력 경로와 동일한 `--mode` 값으로 감사를 재실행하면, THE Audit_Tool SHALL 직전 실행과 동일한 캐시 키와 동일한 의미 결과 sha를 생성한다.
4. IF 감사 출력 디렉터리가 대상 저장소 내부에 위치하거나, 기존 출력이 손상되었거나, `--overwrite-latest` 없이 `latest`가 충돌하면, THEN THE Audit_Tool SHALL 감사 산출물을 생성하지 않고 실패 원인을 나타내는 오류 메시지와 함께 종료 코드 2로 종료한다.
5. IF 지정된 로컬 저장소 경로가 존재하지 않거나 `--mode` 값이 `quick` 또는 `full`이 아니면, THEN THE Audit_Tool SHALL 감사를 시작하지 않고 입력 오류를 나타내는 오류 메시지와 함께 0이 아닌 종료 코드로 종료한다.
6. WHILE 본 스펙의 작업이 진행되는 동안, THE Audit_Tool SHALL 네트워크 접근, GPU 사용, 외부 다운로드 없이 로컬에서만 동작한다.
7. THE 디자인 파트너 베타 후보 증거 기반 SHALL 비합성 로컬 저장소 케이스를 최소 10개 포함한다.

### Requirement 2: 첫 보고서 생성 시간 측정

**User Story:** 검증 담당자로서, 첫 보고서 생성 시간이 10분 이내임을 측정하여, 도구가 디자인 파트너에게 제시 가능한 응답 시간을 만족하는지 확인하고 싶다.

#### Acceptance Criteria

1. WHEN First_Report_Smoke가 첫 보고서 경로의 실행을 완료하면, THE First_Report_Smoke SHALL 경로 시작부터 보고서 산출물 기록 완료까지의 총 벽시계 시간을 밀리초 단위 정수로 측정하여 스키마 검증된 `first_report_smoke.json`에 단일 측정값으로 기록한다.
2. IF 첫 보고서 경로의 측정된 총 벽시계 시간이 600,000밀리초(600초)를 초과하면, THEN THE First_Report_Smoke SHALL 종료 상태를 실패로 설정하고 시간 초과를 나타내는 실패 사유를 `first_report_smoke.json`에 기록한 뒤, 사용자 지정 `--out` 디렉터리에서 해당 실행이 생성한 관리 대상 산출물을 모두 제거한다.
3. WHEN Benchmark_Harness가 실제 라벨 케이스 1건의 평가를 완료하면, THE Benchmark_Harness SHALL 해당 케이스의 첫 검증 보고서 벽시계 시간을 밀리초 단위 정수로 `benchmark_run_metrics.csv`에 케이스 식별자와 함께 1개 행으로 기록한다.
4. THE First_Report_Smoke 영수증 SHALL 픽스처 전용 증거임을 나타내는 표시를 포함하며, 베타 또는 릴리스 readiness 상태를 나타내는 표시를 포함하지 않는다.
5. IF 측정된 첫 보고서 시간이 600,000밀리초(600초)를 초과하면, THEN THE Benchmark_Harness SHALL `first_report_requirement_met` 값을 0으로 설정하여 유지한다.
6. WHEN 측정된 첫 보고서 시간이 600,000밀리초(600초) 이하로 기록되면, THE Benchmark_Harness SHALL `first_report_requirement_met` 값을 1로 설정한다.

### Requirement 3: 인간 라벨 루프 1회 완주

**User Story:** 검증 담당자로서, 라벨 템플릿 생성부터 라벨 인테이크, 벤치마크 평가까지 인간 라벨 루프를 한 번 완주하여, 베타 게이트를 올릴 수 있는 실제 라벨 증거 경로를 가동하고 싶다.

#### Acceptance Criteria

1. WHEN 검증 담당자가 검증된 감사 번들과 `--case-id`를 지정하여 라벨 템플릿 생성을 요청하면, THE Label_Template_Tool SHALL 입력 감사 번들을 먼저 검증한 뒤 검증을 통과한 경우에만 `template_only=1` 및 `human_labeled=0`으로 표시된 후보 라벨 행을 생성한다.
2. THE Label_Template_Tool SHALL 각 후보 행에 소스 발견, 주 인용 스팬(primary citation span), 소스 수동 검토 큐 id를 결합한다.
3. WHEN 검증 담당자가 라벨 템플릿과 `human_labeled=true`인 결정 행을 Label_Intake_Tool에 제공하면, THE Label_Intake_Tool SHALL 템플릿 번들을 먼저 검증하고 검증을 통과한 경우에만 결정 입력 sha256과 템플릿 매니페스트 sha256을 결합하여 `benchmark_labels.jsonl`을 생성한다.
4. IF 결정 행에 `human_labeled=true`가 없으면, THEN THE Label_Intake_Tool SHALL 해당 행을 거부하고 거부 사유를 나타내는 오류를 반환하며 해당 행을 `benchmark_labels.jsonl`에서 제외한다.
5. WHEN 검증 담당자가 인테이크 디렉터리를 `--label-intake`로 Benchmark_Harness에 전달하면, THE Benchmark_Harness SHALL 인테이크 번들을 재검증하고 재검증을 통과한 경우에만 그 매니페스트와 sha 매니페스트를 벤치마크 매니페스트에 결합한다.
6. WHERE 인간 라벨 행이 `expected_repo_git_head`를 포함하면, THE Benchmark_Harness SHALL 해당 케이스가 현재 HEAD가 `expected_repo_git_head`와 일치하는 깨끗한 git 워크트리인지 검증한다.
7. IF 케이스가 dirty 저장소이거나 비-git 디렉터리이거나 HEAD가 일치하지 않거나 라벨에 기대 HEAD가 없으면, THEN THE Benchmark_Harness SHALL `repo_snapshot_requirement_met`을 0으로 유지한다.
8. THE 인간 라벨 루프 증거 기반 SHALL 최소 300개의 인간 라벨 행을 포함한다.
9. IF 입력 감사 번들 검증이 실패하면, THEN THE Label_Template_Tool SHALL 후보 라벨 행 생성을 중단하고 검증 실패를 나타내는 오류로 요청을 거부하며 기존 출력 파일을 변경하지 않는다.
10. IF 템플릿 번들 검증이 실패하면, THEN THE Label_Intake_Tool SHALL `benchmark_labels.jsonl` 생성을 중단하고 검증 실패를 나타내는 오류로 요청을 거부하며 부분 출력 파일을 남기지 않는다.
11. IF 인테이크 번들 재검증이 실패하면, THEN THE Benchmark_Harness SHALL 벤치마크 실행을 중단하고 재검증 실패를 나타내는 오류를 반환하며 벤치마크 매니페스트에 인테이크 매니페스트를 결합하지 않는다.

### Requirement 4: 거짓 양성 / 거짓 음성 이슈 목록 생성

**User Story:** 검증 담당자로서, 실제 라벨 벤치마크 결과로부터 거짓 양성/거짓 음성 발견 목록을 산출하여, 도구의 정확도 결함을 추적 가능한 이슈로 정리하고 싶다.

#### Acceptance Criteria

1. WHEN Benchmark_Harness가 인간 라벨 케이스를 평가하면, THE Benchmark_Harness SHALL 라벨별 TP/FP/FN/TN 및 미매칭 발견 행을 `benchmark_confusion_rows.csv`에 기록한다.
2. THE FP/FN 이슈 목록 SHALL `benchmark_confusion_rows.csv`의 거짓 양성 행과 거짓 음성 행에서만 도출된다.
3. THE FP/FN 이슈 목록의 각 항목 SHALL 케이스 식별자, 발견 식별자, 인용 스팬(파일/라인/sha256)을 포함한다.
4. THE Benchmark_Harness SHALL 전체 정밀도(precision), P0/P1 정밀도, 인용 유효성(citation validity)을 `benchmark_evaluation.json`에 기록한다.
5. IF 벤치마크 평가가 합성 케이스에 기반하면, THEN THE Benchmark_Harness SHALL 그 결과를 실제 증거로 승격하지 않는다.

### Requirement 5: 베타 readiness 체크리스트 생성

**User Story:** 검증 담당자로서, `design_partner_beta_candidate_ready`를 1로 전환하기 위해 정확히 무엇이 참이어야 하는지를 정의하는 체크리스트를 확보하여, 베타 전환 의사결정을 명시적 게이트 기준으로 수행하고 싶다.

#### Acceptance Criteria

1. THE Benchmark_Harness SHALL 각 베타 게이트의 관찰값(observed), 요구값(required), 통과 비트(pass bit), 차단 사유(blocked reason)를 스키마 검증된 `benchmark_readiness.json`에 기록한다.
2. THE beta readiness checklist SHALL `schemas/local_repo_audit_benchmark_readiness.schema.json` 스키마를 준수한다.
3. THE Benchmark_Harness SHALL `design_partner_beta_candidate_ready`를 다음 모든 조건이 충족될 때만 1로 설정한다: 실제 인간 라벨 기반, 최소 10개 로컬 저장소, 최소 300개 인간 라벨 행, 모든 케이스의 깨끗한 기대 git HEAD 스냅샷 잠금, broad/citation-unbound/duplicate/contradictory 라벨 행 부재, 매칭된 라벨 인용 기대, 최소 3개 유지보수자 피드백 소스, 전체 정밀도 80% 이상, P0/P1 정밀도 90% 이상, 인용 유효성 100%, 모든 케이스의 유효한 표준 JSON 발견, 성공한 설치/첫 보고서 검사, 성공한 재실행(rerun) 검사.
4. IF 위 조건 중 하나라도 충족되지 않으면, THEN THE Benchmark_Harness SHALL `design_partner_beta_candidate_ready`를 0으로 유지하고 해당 게이트 행에 차단 사유를 기록한다.
5. THE beta readiness checklist SHALL 게이트 행 수(gate_rows), 통과 게이트 행 수(passed_gate_rows), 차단 게이트 행 수(blocked_gate_rows)를 보고한다.

### Requirement 6: 증거 경계 보존

**User Story:** 프로젝트 관리자로서, 합성/픽스처 결과가 실제 증거로 승격되지 못하도록 증거 경계를 강제하여, 베타 후보 판정이 오직 실제 라벨에만 근거하도록 보장하고 싶다.

#### Acceptance Criteria

1. THE Benchmark_Harness SHALL 제품 readiness를 `real_benchmark` 네임스페이스에서 실행되고 합성 또는 픽스처 출처 표식이 없는 인간 라벨 케이스로부터만 계산하며, 그 외 출처(합성·픽스처·표식 미상)의 케이스는 readiness 계산 대상에서 제외한다.
2. IF 합성 또는 픽스처 템플릿 행이 라벨로 컴파일되면, THEN THE Label_Intake_Tool SHALL 그 행의 출처 표식을 합성/비실제 증거로 보존하고 실제 증거로 재분류하지 않는다.
3. IF 행의 감사가 확인된 `real_benchmark` 감사가 아니면, THEN THE Label_Intake_Tool SHALL 그 행으로부터 비합성 라벨을 생성하지 않고 그 행을 합성/비실제 증거로 유지한다.
4. THE Benchmark_Harness SHALL `release_ready`, `public_comparison_claim_ready`, `real_model_execution_ready` 플래그를 각각 정수 값 0으로 유지한다.
5. THE 모든 인테이크 및 벤치마크 매니페스트 SHALL 차단된 readiness 플래그를 각각 정수 값 0으로 기록한다.
6. IF 합성 또는 픽스처 출처 행이 실제 증거 또는 제품 readiness로 승격되려 시도되면, THEN THE Label_Intake_Tool SHALL 그 승격을 거부하고, 거부 사유를 나타내는 검증 실패 표시를 기록하며, 그 행의 합성/비실제 출처 상태를 변경 없이 보존한다.

### Requirement 7: real_benchmark 네임스페이스 확인

**User Story:** 검증 담당자로서, `real_benchmark` 네임스페이스 사용 시 명시적 확인을 요구받아, 실제 증거 채널을 실수로 사용하는 것을 방지하고 싶다.

#### Acceptance Criteria

1. WHEN 검증 담당자가 `--namespace real_benchmark`와 `--confirm-real-benchmark-namespace`를 함께 지정하여 벤치마크를 실행하면, THE Benchmark_Harness SHALL real_benchmark 네임스페이스로 벤치마크 실행을 진행한다.
2. IF `--namespace real_benchmark`가 `--confirm-real-benchmark-namespace` 플래그 없이 사용되면, THEN THE Benchmark_Harness SHALL 벤치마크 실행을 시작하지 않고, real_benchmark 네임스페이스에 명시적 확인 플래그가 필요함을 나타내는 오류 메시지를 표준 오류로 출력한 뒤 사용 오류 종료 코드 2로 종료한다.
3. IF `--namespace real_benchmark`가 `--confirm-real-benchmark-namespace` 플래그 없이 사용되면, THEN THE Benchmark_Harness SHALL real_benchmark 네임스페이스의 증거 채널에 어떤 결과 또는 산출물도 기록하지 않은 상태로 종료 직전의 상태를 보존한다.

### Requirement 8: 게이트 무결성 보존

**User Story:** 프로젝트 관리자로서, 게이트가 오직 인간 라벨 경로로만 올라가고 코드/대시보드/readiness 필드의 수동 편집으로는 올라가지 않도록 강제하여, 베타 게이트의 무결성을 보장하고 싶다.

#### Acceptance Criteria

1. THE 인간 라벨 SHALL `design_partner_beta_candidate_ready`를 올릴 수 있는 유일한 경로이다.
2. IF 누군가 코드, 대시보드, 또는 readiness 필드를 직접 편집하여 게이트를 올리려 하면, THEN THE Verifier SHALL 그 변경을 거부한다.
3. WHEN Benchmark_Harness가 `--verify-existing`으로 실행되면, THE Verifier SHALL 벤치마크 JSON 산출물을 스키마 검증하고 결합 값을 재계산하며 결합된 라벨 인테이크 번들과 모든 케이스별 감사 출력을 재검증한다.
4. IF 산출물 검증 또는 가드(guard)가 실패하면, THEN THE Verifier SHALL 종료 코드 1로 실패한다.

### Requirement 9: 기존 엔트리포인트 재사용

**User Story:** 개발자로서, 본 스펙이 기존 도구와 계약을 재사용하고 새로운 계약을 발명하지 않도록 하여, 검증 가능한 연구 산출물의 일관성을 유지하고 싶다.

#### Acceptance Criteria

1. THE 본 스펙의 구현 SHALL 다음 8개 기존 엔트리포인트만 사용한다: `scripts/audit_my_repo.py`, `audit_my_repo.sh`, `audit_my_repo_package.py`, `audit_my_repo_first_report_smoke.py`, `audit_my_repo_label_template.py`, `audit_my_repo_label_intake.py`, `audit_my_repo_benchmark.py`, `audit_review_to_jsonl.py`.
2. IF 본 스펙의 구현이 위 8개 목록에 없는 신규 엔트리포인트 또는 신규 계약을 도입하려고 시도하면, THEN THE 본 스펙의 구현 SHALL 해당 작업을 수행하지 않고 미허용 엔트리포인트/계약임을 식별하는 오류 표시를 반환한다.
3. THE 본 스펙의 구현 SHALL 기존 스키마 `schemas/local_repo_audit_benchmark_readiness.schema.json`와 기존 GitHub `design-partner-finding-review` 이슈 템플릿만 사용하며, 신규 스키마나 신규 이슈 템플릿을 생성하지 않는다.
4. THE 생성된 모든 증거 산출물 SHALL `results/` 디렉터리 하위에 위치하며, `results/` 디렉터리는 `.gitignore` 대상이어야 한다.
5. IF 증거 산출물이 `results/` 디렉터리 외부 경로에 생성되려고 시도되면, THEN THE 본 스펙의 구현 SHALL 해당 산출물 기록을 수행하지 않고 산출물 경로 위반임을 식별하는 오류 표시를 반환한다.
6. THE 본 스펙의 구현 SHALL 체크포인트 파일 및 단일 파일 크기 10 MB 이상의 산출물을 git 추적 대상(스테이징 또는 커밋)에 추가하지 않는다.
