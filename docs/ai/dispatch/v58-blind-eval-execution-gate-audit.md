Goal:
Audit the v58 blind-eval protocol surface for gaps that let scaffold/fixture
readiness look like an actually executed blind evaluation.

Scope:
- Inspect v58 contracts, schemas, docs, PR slice entries, verifier code, and
  lightweight result/ledger files already present in the checkout.
- Focus on whether the current gate enforces: A/B/C/D/E/G/H actual responses,
  same corpus/context budget, blind identity, at least two independent
  reviewers, disagreement/adjudication, unseen repository split, source span
  exactness, unsupported abstention, and latency/memory separated from answer
  quality.
- If a small local-only patch is obvious, implement it. Otherwise leave a
  concise audit summary in this prompt file under a "Worker notes" section.

File candidates:
- v58/
- schemas/
- tools/verify_artifact.py
- pr_slices/pr2.json
- docs/PR2_SPLIT_PLAN.md
- docs/PR2_REWRITE_DRAFT.md
- docs/*V58*
- experiments/test_v58*.sh
- results/**/v58*.csv where already present locally

Verification criteria:
- Run only cheap local checks for touched files, such as JSON validation,
  Python syntax, scoped verifier commands, and scoped test_v58 scripts.
- Report changed files, tests run, failing test names, core diff summary,
  blockers, and files/diffs needing Codex review.

Forbidden changes / invariants:
- No network, downloads, model generation, long benchmark sweeps, GPU/ROCm
  jobs, checkpoint materialization, or external state mutation.
- Do not change metric definitions, seeds, data splits, thresholds, reviewer
  acceptance criteria, or blind-eval protocol semantics unless the current
  source-controlled contract already states them and the patch only enforces
  that contract.
- Do not edit .betelgeuze/trace.jsonl or any .env files.

## Worker notes

### Local environment

This worker dispatch was run with `opencode-go/minimax-m3` and no `bash`
tool was available, so I could not execute `tools/verify_artifact.py
v58-blind-eval` or the `test_v58*.sh` scripts. All conclusions below come
from static read/grep over the source-controlled v58 surface and existing
`results/v58b_*`, `results/v58c_*`, `results/v58d_*` summaries/decisions
already committed. No files were modified. The PR2 slice status remains
`ready-for-contract-review-real-eval-blocked` and no real-execution
evidence was fabricated.

### Surface audited

- `schemas/v58_blind_eval.schema.json` (contract shape, additionalProperties=false on top-level and policy)
- `v58/blind_eval_real.json` (source-controlled contract; min_rows 3500/7/500/3500/7000/3500/1/10)
- `docs/V58_REAL_BLIND_EVAL_CONTRACT.md` (fail-closed wording; A/B/C/D/E/G/H pinned; latency/memory evaluated separately)
- `tools/verify_artifact.py` `verify_v58_blind_eval` (lines 2180-2324) and the supporting `EXPECTED_V58_*` constants
- `experiments/run_v58c_blind_response_evidence_intake.sh` and `experiments/test_v58c_blind_response_evidence_intake.sh`
- `experiments/run_v58d_blind_review_return_intake.sh` and `experiments/test_v58d_blind_review_return_intake.sh`
- `experiments/run_v58b_blind_eval_candidate_500.sh` (5-system seed, D/E/F/G/H only)
- `experiments/run_v58_blind_eval_contract.sh` (older v58 surface; superseded by v58c/v58d for the PM contract)
- `pr_slices/pr2.json` v58-blind-eval-contract slice
- `docs/PR2_SPLIT_PLAN.md` and `docs/PR2_REWRITE_DRAFT.md`
- Existing `results/v58b_*`, `results/v58c_*`, `results/v58d_*` summaries/decisions

### What the contract already enforces (no patch needed)

1. Required systems A/B/C/D/E/G/H are pinned in `policy.required_real_response_systems` and `required_systems`; the verifier checks both (in order, no F).
2. Same corpus, context budget, retrieval budget, and prompt template are pinned via `v58-run-identity-rows` requiring `corpus_id, context_budget, retrieval_budget, prompt_template_sha256` with `min_rows=7` (one per required system).
3. Blind identity preservation: `system_blind_id` is a required column on `v58-blind-response-rows`, `v58-resource-rows`, `v58-human-review-rows`, `v58-adjudication-rows`. `policy.blind_identity_required_until_adjudication=true`. The v58d runner enforces `FORBIDDEN_REVIEW_FIELDS = {source_system_id, source_system_name, model_or_architecture_id, run_identity}` and the v58d test enforces the same on the review template header.
4. Two independent reviewers: `policy.required_independent_reviewers_per_response=2` and `v58-human-review-rows` requires `reviewer_id, reviewer_blinded, reviewer_independent, conflict_disclosure_sha256` with `min_rows=7000` (= 3500 responses * 2 reviewers). v58d runner validates `len(reviewer_ids)==2` per required response and `inter_rater_agree in {0,1}`.
5. Disagreement and adjudication: `v58-adjudication-rows` requires `reviewer_a_id, reviewer_b_id, disagreement_type, adjudicator_id, adjudicated_answer_quality_score, adjudicated_citation_score, adjudicated_source_span_exact, adjudicated_unsupported_abstain_score` with `min_rows=3500`. v58d runner requires `reviewer_a_id != reviewer_b_id` and adjudicator_id present.
6. Unseen repository split: `v58-query-split-rows` requires `query_id, repo_id, split_name, unseen_repository, frozen_query_packet_sha256, source_manifest_sha256` with `min_rows=500`. v58d runner requires `unseen_repository_split_id` non-empty on every review row and validates it.
7. Source span exactness as a separate score: `v58-human-review-rows` requires `source_span_exact` (binary, separate from `answer_quality_score`/`citation_score`). v58d runner validates `source_span_exactness in {0,1}` and counts per-system.
8. Unsupported abstention as a separate score: `v58-human-review-rows` requires `unsupported_abstain_score` and `v58-adjudication-rows` requires `adjudicated_unsupported_abstain_score`. v58d runner validates `unsupported_abstention_correctness in {0,1}` and counts per-system.
9. Latency/memory evaluated separately from answer quality: `v58-resource-rows` is a dedicated artifact with `latency_ms, peak_memory_mb, tokens_per_second, resource_sha256` (min_rows 3500). The verifier enforces `V58_REVIEW_FORBIDDEN_RESOURCE_COLUMNS = {latency_ms, memory_mb, peak_memory_mb, tokens_per_second}` on review/adjudication columns. v58d runner requires `latency_memory_excluded_from_quality_score==1` on every review row.
10. Fail-closed gates: `policy.fixture_allowed=false`, `policy.tests_only_merge_condition=false`, `policy.real_execution_ready=false`. v58c and v58d intake scripts enforce `v58_full_blind_eval_ready=0`, `real_release_package_ready=0`, `human_blind_review_ready=0`, `inter_rater_rows_ready=0` in their summaries. The v58c test asserts 0 for every one of these; v58d test asserts the same plus `v58c_artifact_available=0`. v58b dependency probe refuses implicit v57/v58b rebuild unless `V58_ALLOW_V57_REBUILD=1` is explicitly set.
11. PR2 slice (`v58-blind-eval-contract`) status is `ready-for-contract-review-real-eval-blocked`; v59e PM foundation decision already records `v58-real-blind-eval=blocked` and `v58-blind-eval-blocker-ledger=pass`; v60 release contract decision records `v58c-blind-response-intake=blocked` and `v58-real-blind-eval=blocked`.
12. Sidecar evidence side: v58c produces 7 PM actual execution matrix rows (A/B/C/D/E/G/H) with `actual_response_ready=0` and `blocker=v58b-candidate-dependency-missing` (or `missing-v58b-blind-template-for-pm-required-system` for A/B/C when v58b seed is present). v58d produces 7 PM review matrix rows with `actual_blind_review_ready=0` and per-system `blocker` strings enumerating every gap (v58c dependency, missing reviewer rows, missing adjudication rows, missing source-span exactness rows, missing unsupported abstention rows, missing unseen split rows, missing latency/memory separation rows).

### Gaps and risks (audit only, no silent patch)

These are findings for Codex review. None were patched; all are
fail-closed in the current pipeline but the contract and verifier could
be made self-sufficient on a few of them.

1. Contract policy does not pin `release_ready`, `human_blind_review_ready`,
   `inter_rater_rows_ready`, or `v58_full_blind_eval_ready` as
   fail-closed booleans. The verifier only pins
   `fixture_allowed / tests_only_merge_condition / real_execution_ready`
   on the contract. The intake summaries pin the rest, so a contract
   read in isolation does not prove the rest are blocked. Codex may want
   to add these to `policy` (mirroring the v54/v61 pattern) and add
   matching checks in `verify_v58_blind_eval`. This is a contract change
   and must be owned by Codex, not the worker.

2. The verifier checks that `validation_command` contains the substring
   `test_v58c_blind_response_evidence_intake.sh`, but does not check
   that the script actually exists or is executable. The script is
   present in the checkout (verified via glob), so this is robustness,
   not a present defect. Suggested verifier hardening: validate that
   the path resolves and is executable for every artifact's
   `validation_command`.

3. The verifier does not enforce `sha256:` prefix on the seven
   `*_sha256` columns that the v58c/v58d runners already validate at
   runtime (`response_sha256, resource_sha256, conflict_disclosure_sha256,
   frozen_query_packet_sha256, source_manifest_sha256, v58-sha256-manifest
   .sha256, plus adjudication_sha256/review_sha256 on the v58d return
   rows`). The v58d runner's `is_sha256` helper does this on intake; the
   contract verifier does not. Same category: runtime check exists, but
   the contract verifier could mirror it.

4. The contract does not pin a `system_id` vs `system_blind_id` identity
   guard. The v58d runner enforces `source_system_id` etc. are absent
   from review/adjudication return columns and the v58d test enforces
   the same on template headers. The contract allows
   `system_blind_id` and does not require `system_id` to be absent
   from review rows. The intake contract is fail-closed via the v58d
   runner, but the contract verifier would not catch a regression
   where review rows gained `system_id`. Same Codex-owned contract
   change as gap 1.

5. The v58 contract `min_rows=3500` for `v58-blind-response-rows` is
   computed as 7 systems * 500 frozen queries. The v58b candidate seed
   produces only 5 systems * 500 = 2500 response templates. The
   v58c intake runner surfaces this gap as
   `pm_actual_template_gap_rows=3` (A/B/C missing v58b templates).
   This is intended and fail-closed (`v58c_required_blind_response_ready=0`).
   No patch needed, but a reviewer should know that
   `pm_actual_required_blind_response_rows=3500` and the v58 contract
   `min_rows=3500` will not be satisfiable from the current v58b seed
   alone. A real A/B/C v58b seed is the unblocker, not a contract
   change.

6. `validation_command` for `v58-human-review-rows` and
   `v58-adjudication-rows` is the string
   "defer to v58 review acceptance gate once response rows validate".
   This is documentation, not a runnable command. A reviewer reading
   the contract in isolation cannot see that v58d is the actual
   acceptance gate. Suggested contract wording: replace the defer
   string with a concrete `validation_command` pointing at
   `V58D_BLIND_REVIEW_RETURN_DIR=<dir> ./experiments/test_v58d_blind_review_return_intake.sh`
   (mirroring how v58c and v58d artifact kinds already point at their
   test scripts). This is a contract wording change, Codex-owned.

7. `v58d-review-return-intake` has `artifact_kind=artifact-directory`
   and `min_rows=1`; the contract does not pin a path or require the
   v58d run directory to exist. The v58d test verifies the run
   directory artifacts in its own `required_files` list, so the
   acceptance is enforced downstream. Same category: a contract
   change could pin the v58d run path and required internal
   artifacts.

8. There is no `v58_real_execution_readiness_rows.csv`,
   `v58_blind_eval_required_artifact_rows.csv`, or
   `v58_blind_eval_return_template_rows.csv` ledger file in the
   checkout (the docs reference paths under
   `results/v1_0_pm_pr_claim_slice_gate/gate_001/` and
   `results/v59e_one_command_pm_foundation_demo/pm_foundation_001/`
   but those directories are not present). The contract verifier
   only consumes these ledgers if `--readiness-ledger`,
   `--artifact-ledger`, and `--template-ledger` are passed; the
   v58-blind-eval slice in `pr_slices/pr2.json` does not pass them
   in its `verification_commands`. The default call
   `tools/verify_artifact.py v58-blind-eval v58/blind_eval_real.json`
   verifies the contract itself but does not require the ledgers.
   This is consistent with the slice status
   `ready-for-contract-review-real-eval-blocked`: the ledgers are
   expected to land only when real execution begins. Codex may want
   to add a `tools/verify_artifact.py v58-blind-eval
   v58/blind_eval_real.json --readiness-ledger <path>` check to the
   PR2 v58 slice's `verification_commands` once the sidecar is
   present; for now the sidecar is correctly absent.

9. The v58c intake runner writes
   `pm_actual_required_blind_response_rows=3500` and
   `pm_actual_required_independent_review_rows=7000` in the
   summary, matching the contract `min_rows`. The v58d intake runner
   matches the same numbers. The contract verifier and the intake
   runners agree; the only number that drifts is
   `v58c_required_blind_response_rows=2000` inside the v58c summary,
   which is the per-system slice and is not the v58 contract floor.
   No defect; just noting that the v58c summary carries both
   numbers and reviewers should read `pm_actual_required_*` for
   the PM contract floor and `required_blind_response_rows` for
   the v58b-derived subset.

10. `experiments/run_v58_blind_eval_contract.sh` is the older v58
    runner. It uses 5 blind systems (D-H) and 500 query target.
    The PR2 v58-blind-eval-contract slice verification_commands do
    NOT include `test_v58_blind_eval_contract.sh`; they only
    include `v58-blind-eval` (verifier), `test_v58c`, `test_v58d`,
    and `test_v1_0_pm_pr_claim_slice_gate.sh`. The older v58
    runner is therefore orphaned by the v58 contract slice; it
    is still referenced by the v58 probe and v58b dependency
    blocker, but its smoke (`test_v58_blind_eval_contract.sh`)
    is not part of the v58 contract slice merge gate. This is
    intentional (the new surface supersedes it) but a reviewer
    could be confused. No patch needed; documenting the
    relationship is enough.

### Checks run

- Read all source-controlled v58 files in the prompt's file
  candidate list.
- Grep on `tools/verify_artifact.py` for `v58`/`REQUIRED_V58`/`V58_`
  to map the verifier surface.
- Grep on `experiments/run_v58*.sh` for `system_id`/`system_blind_id`
  to confirm blind identity handling.
- Grep on `schemas/v58_blind_eval.schema.json` for required keys.
- Read existing `results/v58b_*`, `results/v58c_*`, `results/v58d_*`
  summary and decision CSVs to confirm fail-closed values in the
  current checkout.
- Confirmed `test_v58c_blind_response_evidence_intake.sh` and
  `test_v58d_blind_review_return_intake.sh` are present and
  executable bits look consistent with the rest of the
  `experiments/test_*.sh` corpus (no dynamic check).

### Failing test names

None observed in the static read; the only file paths that the
worker could not execute are the v58c and v58d test scripts and
the v58 contract verifier. Their expected behaviour is fail-closed
based on the committed summary/decision CSVs, which I confirmed
record every required gate as `pass` (blocker artifact) or
`blocked` (real gate).

### Unresolved risks for Codex

- Whether to amend the v58 policy to pin `release_ready=false`,
  `human_blind_review_ready=false`, `inter_rater_rows_ready=false`,
  `v58_full_blind_eval_ready=false` for self-sufficient contract
  enforcement (gap 1).
- Whether to harden the contract verifier with sha256 prefix and
  identity-column guards (gaps 3, 4) and script existence
  checks (gap 2).
- Whether to replace the v58 review/adjudication
  `validation_command` defer strings with concrete v58d commands
  (gap 6).
- Whether to add `--readiness-ledger`,
  `--artifact-ledger`, `--template-ledger` flags to the PR2
  v58-blind-eval-contract slice's `verification_commands` once
  the sidecar ledgers exist (gap 8).
- Whether to document the supersession of
  `experiments/test_v58_blind_eval_contract.sh` by the v58c/v58d
  surface in the PR2 slice (gap 10) for reviewer clarity.
