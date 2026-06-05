# Post-v18 Research Roadmap

This roadmap closes the current internal mechanics mode and moves the project into externally checkable evidence. The architecture should keep testing on evidence-bound local QA/audit first, because that surface exposes retrieval, prediction lineage, abstention, citations, and wrong-answer guards without requiring a broad language-generation claim.

Current boundary:

- `v17` provides the handoff package.
- `v18` provides the supplied external evidence intake verifier.
- `v19` provides the external submission bundle.
- `v20` provides the external return tracker and missing-evidence preflight.
- `v21` provides the external review dispatch kit for human reviewers and PoC owners.
- `v22` provides host/container clean-machine execution support and return templates.
- `v23` provides official benchmark reconciliation templates, no-oracle/no-extractor contracts, and preflight checks.
- `v24` provides the current send/receive/verify handoff centered on v21 + v22 outbound packets and direct v18 intake verification.
- `v25` provides the outbound send manifest and receiver acknowledgement template for the v21 + v22 packets.
- `v26` provides the single auditable external send bundle to send outward.
- `v27` provides a transfer-friendly archive of the v26 send bundle.
- `v28` provides the inbound return inbox and v18 verifier hook.
- `v29` provides the receiver-side return preflight kit before returned artifacts are verified by v18.
- `v30` provides the first commercial codebase QA closed-corpus PoC return and v18 verification path.
- `v31` provides the first official RULER NIAH candidate return and v18 verification path.
- `v32` provides the GitHub Actions clean-runner path for the remaining third-party rerun return.
- `v33` provides the frozen evidence-closure packet for the verified v32/v31/v30/v18 intake.
- `v34` provides the first official benchmark expansion packet: RULER NIAH grows from 1 to 6 raw prediction rows at the same 4096-token context length while keeping the official source/evaluator snapshot, no-oracle/no-extractor contract, and RouteMemory lineage.
- `v35` provides the first post-v30 commercial pilot packet: an `internal_docs` buyer-visible workflow using the v30 commercial-return schema, five source-cited QA rows, one release-claim abstain row, and privacy/resource/acceptance review.
- `v36` provides the release-claim audit packet over v33/v34/v35 and decides the maximum allowed public wording while blocking release-ready product and stronger model-replacement claims.
- Current verified state after PR run `27029089994` plus v33/v34/v35/v36: `independent_rerun_actual_ready=1`, `candidate_external_benchmark_result_ready=1`, `candidate_external_benchmark_expansion_ready=1`, `closed_corpus_poc_actual_ready=1`, `real_external_benchmark_verified=1`, `v33_evidence_closure_packet_ready=1`, `v34_official_benchmark_expansion_packet_ready=1`, `v35_commercial_pilot_packet_ready=1`, and `v36_release_claim_audit_packet_ready=1`; `maximum_allowed_claim_decided=1`, but `human_review_completed=0` and `real_release_package_ready=0` remain blocked until external review accepts the evidence set.

## Current Handoff

Send:

- `results/v21_external_review_dispatch_kit/dispatch_001/`
- `results/v22_clean_machine_execution_kit/kit_001/`

Receive one or more:

- third-party rerun return directory
- official benchmark return directory
- commercial closed-corpus PoC return directory

Verify directly with v18:

```bash
V18_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return \
V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return \
V18_COMMERCIAL_POC_DIR=/path/to/commercial_return \
experiments/run_v18_external_evidence_intake.sh
```

Operational packet:

- `results/v24_external_handoff_send_receive_verify/handoff_001/`

Outbound send manifest:

- `results/v25_outbound_send_manifest/packet_001/outbound/OUTBOUND_FILE_MANIFEST.csv`
- `results/v25_outbound_send_manifest/packet_001/outbound/OUTBOUND_SHA256SUMS.txt`
- `results/v25_outbound_send_manifest/packet_001/receiver/RECEIVER_ACK_TEMPLATE.csv`

Single send bundle:

- `results/v26_external_send_bundle/bundle_001/`

Transfer archive:

- `results/v27_external_send_archive/archive_001/archive/v26_external_send_bundle_bundle_001.tar.gz`
- `results/v27_external_send_archive/archive_001/archive/ARCHIVE_SHA256SUMS.txt`

Inbound return inbox:

- `results/v28_inbound_return_inbox/inbox_001/returns/third_party_return/`
- `results/v28_inbound_return_inbox/inbox_001/returns/official_return/`
- `results/v28_inbound_return_inbox/inbox_001/returns/commercial_return/`

Receiver preflight:

- `results/v29_receiver_return_preflight/preflight_001/receiver/RECEIVER_RETURN_PREFLIGHT.md`
- `results/v29_receiver_return_preflight/preflight_001/receiver/preflight_rows.csv`
- `results/v29_receiver_return_preflight/preflight_001/receiver/missing_file_rows.csv`
- `results/v29_receiver_return_preflight/preflight_001/verify/VERIFY_AFTER_PREFLIGHT.md`

Commercial codebase QA PoC return:

- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/query_set.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/poc_result_rows.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/privacy_review.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/acceptance_review.csv`

Official RULER NIAH candidate return:

- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/official_source_snapshot.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/official_evaluator_status.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/raw_predictions.jsonl`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/prediction_lineage.jsonl`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/candidate_result_rows.csv`

GitHub Actions third-party rerun kit:

- `.github/workflows/third-party-rerun.yml`
- `results/v32_github_actions_third_party_rerun_kit/kit_001/GITHUB_ACTIONS_THIRD_PARTY_RERUN.md`
- `results/v32_github_actions_third_party_rerun_kit/kit_001/workflow/third-party-rerun.yml`

Receiver-side custom check:

```bash
V29_THIRD_PARTY_RETURN_DIR=/path/to/third_party_return \
V29_OFFICIAL_RETURN_DIR=/path/to/official_return \
V29_COMMERCIAL_RETURN_DIR=/path/to/commercial_return \
experiments/run_v29_receiver_return_preflight.sh
```

Commercial v30 verification:

```bash
V18_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return \
experiments/run_v18_external_evidence_intake.sh
```

Official v31 plus commercial v30 verification:

```bash
V18_OFFICIAL_BENCHMARK_DIR=results/v31_official_ruler_niah_candidate_return/return_001/official_return \
V18_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return \
experiments/run_v18_external_evidence_intake.sh
```

GitHub Actions third-party rerun:

```bash
gh workflow run third-party-rerun.yml -f return_id=github_actions_return_001
gh run list --workflow third-party-rerun.yml --limit 1
gh run watch
mkdir -p results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded
gh run download --name third-party-rerun-return --dir results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded
```

PR-based GitHub Actions rerun:

```bash
gh pr create --base main --head codex/route-memory-local-energy-policy --draft
gh run list --branch codex/route-memory-local-energy-policy --limit 5
gh run watch
gh run download --name third-party-rerun-return --dir results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded
```

GitHub Actions return verification:

```bash
V18_THIRD_PARTY_RERUN_DIR=results/v32_github_actions_third_party_rerun_kit/kit_001/downloaded_run_27029089994/github_actions_third_party_rerun/github_actions_return_27029089994/third_party_return \
V18_OFFICIAL_BENCHMARK_DIR=results/v31_official_ruler_niah_candidate_return/return_001/official_return \
V18_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return \
experiments/run_v18_external_evidence_intake.sh
```

Verified v18 summary:

```csv
intake_id,third_party_rerun_supplied,independent_rerun_actual_ready,official_benchmark_supplied,candidate_external_benchmark_result_ready,commercial_poc_supplied,closed_corpus_poc_actual_ready,real_external_benchmark_verified,real_release_package_ready,artifact_rows
intake_001,1,1,1,1,1,1,1,0,27
```

## After Current Mode Closes

Mode-closure result:

- The v32 workflow has been committed, pushed, run on GitHub Actions PR run `27029089994`, and its uploaded third-party rerun return artifact has been downloaded.
- v18 has been run with all three current evidence directories: v32 third-party rerun, v31 official RULER candidate, and v30 commercial codebase QA PoC.
- The verified closure flags are `independent_rerun_actual_ready=1`, `candidate_external_benchmark_result_ready=1`, `closed_corpus_poc_actual_ready=1`, and therefore `real_external_benchmark_verified=1`.
- v33 has frozen those evidence directories into `results/v33_evidence_closure_packet/packet_001/` with v18 summary/decision rows, copied evidence returns, `sha256_manifest.csv`, `CLAIM_BOUNDARY.md`, and a human-review request.
- v34 has expanded the official benchmark slice into `results/v34_official_benchmark_expansion_packet/packet_001/`, with 6 RULER NIAH raw prediction rows, official evaluator/source hashes, RouteMemory lineage, v18 re-verification, `EXPANSION_BOUNDARY.md`, and `sha256_manifest.csv`.
- v35 has expanded the commercial PoC track into `results/v35_commercial_pilot_packet/packet_001/`, with an `internal_docs` commercial pilot packet for one buyer-visible workflow, five source-cited rows, one abstain row, privacy/resource/acceptance review, v18 re-verification, `COMMERCIAL_PILOT_BOUNDARY.md`, and `sha256_manifest.csv`.
- v36 has audited the release claim boundary in `results/v36_release_claim_audit_packet/packet_001/`, with `claim_matrix.csv`, `release_decision_rows.csv`, `RELEASE_CLAIM_AUDIT.md`, and `sha256_manifest.csv`. It allows only the bounded local evidence-bound QA/audit wording and blocks release-ready product, general LLM replacement, Transformer replacement, frontier long-context solved, GPU acceleration, and full commercial deployment readiness.
- `real_release_package_ready` remains 0 until external human review accepts the evidence set and any required non-GitHub rerun is completed. Do not promote release language inside the v36 audit step.

Do not keep adding internal packaging layers after this mode closes unless a real return exposes a concrete verifier gap. The next roadmap should move from mechanics to evidence scale:

- Week 0: done. The current v14-v32 scripts, docs, and `.github/workflows/third-party-rerun.yml` are on the PR branch; GitHub Actions PR run `27029089994` returned the artifact; local v18 verified it together with v31 and v30.
- Week 1: done. `v33` freezes the v18 summary, decision rows, copied third-party return, official candidate return, commercial PoC return, sha256 manifest, and a plain-language claim boundary.
- Week 1-2: run one independent human-review pass over the `v33` packet. The reviewer should check that the GitHub-hosted runner identity is acceptable as third-party/clean-machine evidence or require a non-GitHub human reviewer rerun.
- Week 2-3: done. `v34` expands the v31 official benchmark slice only one axis at a time: more RULER NIAH rows at the same context length before adding LongBench v2 or another task family.
- Week 3-4: done. `v35` runs a second closed-corpus PoC in internal documentation. It keeps the same v30 schema: source spans, citations, abstentions, wrong-answer guard, privacy review, and acceptance review.
- Month 2: done. `v34` builds the official benchmark expansion packet with raw predictions, official evaluator hash, source snapshot, RouteMemory lineage, and metrics for a larger RULER NIAH slice.
- Month 2: done. `v35` builds a commercial pilot packet for one buyer-visible workflow: internal documentation QA. Do not mix all three in one pilot.
- Month 3: done. `v36` builds a release-claim audit packet that consumes v33/v34/v35 and explicitly decides the maximum allowed public claim. Expected claim shape: local evidence-bound QA/audit architecture with deterministic provenance and conservative abstention.
- Next: complete one independent human-review pass over the v33/v34/v35/v36 evidence set. The reviewer should either accept GitHub-hosted runner evidence for this stage or request a non-GitHub independent rerun before any release package can be marked ready.

Expansion discipline:

- Expand only one axis per experiment: more queries, another benchmark family, another domain, another reviewer, or a stricter privacy/audit requirement.
- Keep architecture changes out of benchmark-expansion runs. If the architecture changes, re-run the smallest v31/v30/v32-equivalent closure first.
- Keep all raw predictions and evidence rows before evaluation. No oracle, no raw-input extractor, and no post-hoc answer repair.
- Treat negative and abstain rows as first-class evidence. A pass is not only high answer accuracy; it is also correct refusal when the source does not support an answer.

Research priority:

- Prove citation/lineage correctness, abstention behavior, no-oracle prediction lineage, and independent rerun reproducibility.
- Publish as a bounded evidence-bound QA/audit architecture, not as a general language model replacement.

Commercial priority:

- Package a local-first codebase QA or internal-document QA PoC where privacy, audit trail, citations, and deterministic replay are buyer-visible advantages.
- Use incident-log QA and product-manual QA as the second and third verticals only after codebase QA produces clean acceptance rows.

## Recommended First Attachment

Recommended first attachment: codebase QA.

This is the best research and commercial bridge because every answer can be checked against a source span, mmap read row, RouteMemory prediction lineage row, evaluator row, negative case, citation, and audit trail. It is also a useful commercial wedge: local-first codebase QA, internal documentation QA, product manual QA, and incident-log evidence QA are concrete domains where bounded evidence and abstention matter more than broad conversational fluency.

Avoid positioning this as a Transformer replacement or general LLM replacement. The sharper claim is a local evidence-bound QA/audit system with deterministic memory, external-verifiable provenance, and conservative abstention.

## Phase 1: Third-Party Rerun

Implementation goal:

- Send the v19 third-party submission directory to a non-local reviewer or clean-machine environment.
- Have the reviewer run the exact reproduction command and return the required v18 directory.
- Verify the return with `V18_THIRD_PARTY_RERUN_DIR=/path/to/return experiments/run_v18_external_evidence_intake.sh`.

Acceptance evidence:

- reviewer identity and conflict disclosure
- clean-machine or independent environment manifest
- exact command, exit code, stdout hash, stderr hash
- frozen query and source snapshot verification
- metric delta rows within tolerance
- pass/fail review rows

Exit criterion:

- `independent_rerun_actual_ready=1`

Preflight command:

```bash
V20_THIRD_PARTY_RERUN_DIR=/path/to/third_party_return experiments/run_v20_external_return_tracker.sh
```

Reviewer packet:

- `results/v21_external_review_dispatch_kit/dispatch_001/dispatch/THIRD_PARTY_RERUN_REQUEST.md`

Clean-machine execution kit:

- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/HOST_CLEAN_MACHINE_RUNBOOK.md`
- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/CONTAINER_CLEAN_MACHINE_RUNBOOK.md`
- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/CAPTURE_THIRD_PARTY_RERUN.sh`

Current local rehearsal:

- `results/local_third_party_rerun_rehearsal/third_party_return/` was produced by the v22 capture script.
- v29 preflight sees this rehearsal return as complete for the third-party rerun track: `return_dirs_detected=1`, `complete_return_dirs=1`.
- v18 still keeps `independent_rerun_actual_ready=0` because this is a local owner-run rehearsal with `external_independent_reviewer=0` and `clean_machine=0`.
- The remaining real third-party task is therefore not file generation; it is obtaining reviewer identity and a true clean-machine or independent environment declaration from outside this local run.

## Phase 2: Official Benchmark Reconciliation

Implementation goal:

- Start with a small official RULER NIAH or LongBench v2 slice.
- Bind official source snapshot, official evaluator/container, raw predictions, metrics, provenance, reproducibility package, and RouteMemory prediction lineage.
- Verify the return with `V18_OFFICIAL_BENCHMARK_DIR=/path/to/official experiments/run_v18_external_evidence_intake.sh`.

Acceptance evidence:

- official source snapshot
- official evaluator or container digest
- raw predictions before evaluation
- no oracle prediction path
- no raw-input extractor prediction path
- RouteMemory-derived prediction lineage
- metrics and provenance manifest
- candidate result rows

Exit criterion:

- `candidate_external_benchmark_result_ready=1` is achieved for the first RULER NIAH candidate return in v31.

Preflight command:

```bash
V20_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v20_external_return_tracker.sh
```

Reviewer packet:

- `results/v21_external_review_dispatch_kit/dispatch_001/dispatch/OFFICIAL_BENCHMARK_REQUEST.md`

Execution notes:

- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/OFFICIAL_BENCHMARK_EXECUTION_NOTES.md`

Official benchmark reconciliation kit:

- `results/v23_official_benchmark_reconciliation_kit/kit_001/official_benchmark/OFFICIAL_SLICE_RECONCILIATION_RUNBOOK.md`
- `results/v23_official_benchmark_reconciliation_kit/kit_001/official_benchmark/NO_ORACLE_NO_EXTRACTOR_CONTRACT.md`
- `results/v23_official_benchmark_reconciliation_kit/kit_001/verification/CHECK_OFFICIAL_RETURN_FILES.sh`

v31 verified return:

- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/official_source_snapshot.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/official_evaluator_status.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/raw_predictions.jsonl`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/prediction_lineage.jsonl`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/metrics.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/provenance_manifest.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/reproducibility_package_manifest.json`
- `results/v31_official_ruler_niah_candidate_return/return_001/official_return/candidate_result_rows.csv`

v31 verification result:

- `official_benchmark_supplied=1`
- `candidate_external_benchmark_result_ready=1`
- `commercial_poc_supplied=1`
- `closed_corpus_poc_actual_ready=1`
- `independent_rerun_actual_ready=0`
- `real_external_benchmark_verified=0`
- `real_release_package_ready=0`

## Phase 3: Commercial Local QA/Audit PoC

Implementation goal:

- Run a closed-corpus PoC in one of four domains: codebase QA, internal documents, product manuals, or incident logs.
- Prefer codebase QA first because repository files, exact spans, and evaluator rows are easiest to audit.
- Verify the return with `V18_COMMERCIAL_POC_DIR=/path/to/poc experiments/run_v18_external_evidence_intake.sh`.

Acceptance evidence:

- domain and corpus manifest
- query set
- per-query evidence, answer, citation, abstention, and wrong-answer-guard rows
- privacy review
- resource envelope
- audit trail
- acceptance review

Exit criterion:

- `closed_corpus_poc_actual_ready=1` is achieved for the repository-only codebase QA PoC in v30.

Preflight command:

```bash
V20_COMMERCIAL_POC_DIR=/path/to/commercial_return experiments/run_v20_external_return_tracker.sh
```

Reviewer packet:

- `results/v21_external_review_dispatch_kit/dispatch_001/dispatch/COMMERCIAL_POC_REQUEST.md`

Execution notes:

- `results/v22_clean_machine_execution_kit/kit_001/clean_machine/COMMERCIAL_POC_EXECUTION_NOTES.md`

v30 verified return:

- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/domain_manifest.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/corpus_manifest.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/query_set.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/poc_result_rows.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/audit_trail.csv`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/resource_envelope.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/privacy_review.json`
- `results/v30_commercial_codebase_poc_return/return_001/commercial_return/acceptance_review.csv`

v30 verification result:

- `commercial_poc_supplied=1`
- `closed_corpus_poc_actual_ready=1`
- `V20_COMMERCIAL_POC_DIR=results/v30_commercial_codebase_poc_return/return_001/commercial_return experiments/run_v20_external_return_tracker.sh` also reports `commercial-poc-return=pass`.
- `independent_rerun_actual_ready=0`
- `candidate_external_benchmark_result_ready=0`
- `real_external_benchmark_verified=0`
- `real_release_package_ready=0`

## Phase 4: Release Review

Implementation goal:

- Re-run the v18 intake with all available real external directories.
- Re-run claim audit and release review only after the rerun and official benchmark tracks have real evidence.
- Keep product language narrow: local evidence-bound QA/audit, not replacement of a full LLM stack.

Exit criterion:

- `real_external_benchmark_verified=1` requires independent rerun actual plus official benchmark candidate.
- `real_release_package_ready=1` requires external benchmark evidence, commercial PoC evidence, privacy/reliability review, and release claim audit.

## Stop Rules

- Do not promote fixture evidence into real evidence.
- Do not raise official benchmark claims from runner-owned smoke results.
- Do not claim commercial readiness without closed-corpus privacy and acceptance review.
- Do not pursue GPU speed or broad NLG claims before the evidence-bound QA/audit track has external replay.
- Do not call the architecture a Transformer replacement unless a separate benchmark program proves that claim directly.
