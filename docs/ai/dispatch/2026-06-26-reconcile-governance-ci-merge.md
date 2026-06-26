# Dispatch: (c) merge — reconcile local changeset verifiers with origin-merged CI/governance files

Source: Kiro Opus 4.8 prompt architect draft
Worker: Cursor CLI Composer 2.5 (`composer-2.5`)
Branch: `chore/local-changeset-governance-sync` (already 3 commits ahead of origin/main; do NOT touch `main`)
Routing: Codex goal owner -> Kiro prompt -> Cursor Composer 2.5 -> Codex diff review + ai-verify acceptance

## Goal

브랜치 `chore/local-changeset-governance-sync`에서 `tools/verify_ci_workflows.py`와
`tools/verify_repo_governance.py`가 **둘 다 통과**하도록, 로컬 changeset의 거버넌스/CI 계약과
origin이 이미 머지한(PR #17~#37) 같은 파일들의 내용을 **병합**한다. 두 쪽의 의도를 합치되,
양쪽 중 **더 강한 보안/거버넌스 요건을 보존**한다. verifier를 단순히 약화시켜 통과시키지 말 것.

현재 실패 원인:
- `verify_ci_workflows.py`: `ai-verify.yml`/`third-party-rerun.yml`의 origin 머지본 구조가 로컬
  verifier가 기대하는 구조(2-job 분리, 특정 job 이름/SHA-pin, env-var return_id 검증, offline-suite)와 어긋남.
- `verify_repo_governance.py`: origin의 `CODEOWNERS`/`CONTRIBUTING.md`/`pull_request_template.md`/
  `ISSUE_TEMPLATE/evidence-blocker.yml`/README가 로컬 verifier가 요구하는 snippet/headings를 결여.

## Scope (병합 규칙)

1. CI 워크플로우 (`.github/workflows/ai-verify.yml`, `third-party-rerun.yml`, `offline-suite.yml`):
   - 파일을 `verify_ci_workflows.py`가 요구하는 하드닝 구조로 맞춘다(2-job 분리: ephemeral `pr-safe-verify`
     on ubuntu-latest + non-PR `trusted-self-hosted-verify`; SHA-pin; env-var로 전달·정규식 검증되는 return_id;
     offline-suite는 self-hosted 금지).
   - **동시에 origin이 추가한 기능을 보존**: v54 reference smokes, `scripts/test_*.py` auto-discover,
     C++ CPU build smoke, offline-suite shard 실행 등.
   - **action SHA 핀 결정**: origin이 이미 핀한 SHA(예: `actions/checkout@11bd719...` v4.2.2)와 로컬
     verifier가 기대하는 SHA가 다르면, **origin이 핀한 SHA를 정답으로 채택**하고 그 SHA를 verifier 기대값에
     반영한다(둘 다 SHA-pin이므로 보안 동등). 핀되지 않은 옛 SHA로 되돌리지 말 것.
2. 거버넌스 파일 (`.github/CODEOWNERS`, `CONTRIBUTING.md`, `.github/pull_request_template.md`,
   `.github/ISSUE_TEMPLATE/evidence-blocker.yml`):
   - origin 내용을 유지하면서 `verify_repo_governance.py`가 요구하는 모든 snippet을 **추가/보강**한다
     (origin 내용 + 로컬 거버넌스 요건의 합집합). 기존 origin 항목을 삭제하지 말 것.
3. README (`README.md`, `README.ko.md`):
   - `verify_repo_governance.py`가 요구하는 dashboard headings/snippets로 정렬한다
     (`## Current Readiness`/`## What Works Now`/`## Next Blockers` 및 한글 대응, ≤140 lines,
     `readiness/typed_ready.json`, `docs/archive/IMPLEMENTATION_HISTORY.md`, 5개 스코프 언급),
     forbidden snippet(`v53-v54-query-evaluation-pipeline`, `codex/route-memory-local-energy-policy`,
     `Latest completed checkpoint`/`## 최신 완료 체크포인트`)은 제거.
   - origin이 추가한 `docs/STATUS.md`/`docs/INDEX.md` 링크는 유지.
4. verifier 자체(`verify_ci_workflows.py`, `verify_repo_governance.py`)는 위 1-3과 **상호 일치**하도록
   필요한 최소 조정만(예: origin 채택 SHA로 기대값 갱신). 보안 의도(PR 코드는 ephemeral runner에서만,
   self-hosted는 non-PR만, 명령 주입 방지, fixture를 real로 승격 금지)를 약화시키는 변경 금지.

## File candidates

- `.github/workflows/ai-verify.yml`, `.github/workflows/third-party-rerun.yml`, `.github/workflows/offline-suite.yml`
- `.github/CODEOWNERS`, `CONTRIBUTING.md`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/evidence-blocker.yml`
- `README.md`, `README.ko.md`, `docs/archive/IMPLEMENTATION_HISTORY.md`
- `tools/verify_ci_workflows.py`, `tools/verify_repo_governance.py` (최소 정합 조정만)
- read-only 참고: `docs/pm/LOCAL_CHANGESET_PR_DRAFT.md`, origin 머지본 (`git show origin/main:<file>`)

## Verification criteria

1. `python3 -m py_compile tools/verify_ci_workflows.py tools/verify_repo_governance.py tools/verify_artifact.py`
2. `python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/ai-verify.yml','.github/workflows/third-party-rerun.yml','.github/workflows/offline-suite.yml']]"`
3. `tools/verify_ci_workflows.py .`  -> `ci workflow verify ok`
4. `python3 tools/verify_repo_governance.py .`  -> 0 errors
5. `python3 tools/verify_github_governance_commands.py` / `verify_pr_cleanup_disposition_commands.py` / `verify_github_external_state.py --mode pending .` -> 여전히 통과
6. `git diff --check`
7. `./scripts/ai-verify.sh`  -> pass (네트워크 필요한 snapshot refresh 단계는 별도; 오프라인으로 가능한 범위까지)

## Forbidden changes / invariants

- 연구 설계, metric 정의, seed, data split, baseline, benchmark protocol, acceptance threshold, evidence boundary 변경 금지.
- CI 보안 의도 약화 금지: PR 코드는 ephemeral GitHub-hosted runner에서만, self-hosted는 non-PR 전용,
  credential-free + SHA-pinned checkout, return_id는 env-var 전달 + 정규식 검증(`..` 거부), 직접 셸 인라인 금지.
- verifier를 통과시키려고 보안/거버넌스 검사를 삭제·완화하지 말 것(파일을 계약에 맞추는 방향).
- fixture/replay 결과를 real evidence로 승격 금지. readiness는 typed-only 유지.
- `main` 브랜치, origin, 외부 GitHub(이슈/라벨/PR/설정) 일절 건드리지 말 것. push/PR 금지.
- 기존 origin 머지 기능(v54 smokes, offline-suite, auto-discover, INDEX/STATUS 링크) 삭제 금지.

## Runtime / dataset / checkpoint / network policy

- 로컬 경량 검증만. 네트워크 fetch/refresh, dataset/checkpoint/weight download, model generation,
  long GPU/ROCm job, remote/registry write, git push/merge, gh CLI mutation 금지.
- 새 산출물을 git에 추가하지 말 것(results 트리는 ignore). 새 추적 파일 임의 생성 금지.

## Worker output (요구 형식)

```
Changed files:
Test results:
Failing test names:
Core diff summary:
Blockers:
Specific files/diffs needing Codex review:
```
