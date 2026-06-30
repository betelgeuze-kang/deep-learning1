# audit-my-repo Alpha

`audit-my-repo` is a local, offline code/document/config audit tool. It writes source-bound findings with file/line/sha256 citations, abstentions, manual-review rows, SARIF 2.1.0 output, phase timing, a deterministic HTML dashboard, and reproduction commands.

It does not claim release readiness, public comparison readiness, real model execution, automatic accuracy, or production-grade precision.

## Install

Use a clean checkout of this repository with Python 3 available. No model weights, checkpoints, datasets, or network downloads are required for the alpha audit path.

```bash
python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py
```

To verify the first-report path end to end on a local fixture, run:

```bash
./scripts/audit_my_repo_first_report_smoke.py --out results/audit_first_report_smoke
./scripts/audit_my_repo_first_report_smoke.py --verify-existing results/audit_first_report_smoke
```

The smoke creates a small local git repository, runs quick mode, verifies the published bundle, writes schema-validated `first_report_smoke.json`, and requires the total wall time to stay within the ten-minute alpha budget. The receipt binds the report, audit manifest, and audit summary by sha256; `--verify-existing` schema-validates the receipt, recomputes those bindings, and re-verifies the audit output. Failed self-verification removes the managed smoke artifacts from a user-specified `--out` directory. The receipt is fixture-only evidence and does not mark beta or release readiness.

## Run

Quick mode uses a smaller plugin set and default budget. Full mode enables the full local deterministic plugin set and larger default budget.

```bash
./scripts/audit_my_repo.sh /path/to/repo --mode quick --out results/my_repo_audit
./scripts/audit_my_repo.sh /path/to/repo --mode full --out results/my_repo_audit_full
```

Budget flags are separate:

```bash
--max-files 220 --max-total-bytes 15000000 --max-file-bytes 700000 --max-findings 100
```

`--max-queries` remains as a compatibility alias for `--max-findings`.

For PR or local diff workflows, pass a newline-delimited file of target-repo-relative paths:

```bash
git -C /path/to/repo diff --name-only main...HEAD > changed-files.txt
./scripts/audit_my_repo.sh /path/to/repo --mode quick \
  --changed-files-from changed-files.txt --out results/my_repo_audit_changed
```

Changed-file scoped runs only scan auditable files from that list. The input path, input sha256, `source_scope`, and changed-file row count are bound into `audit_invocation.json`, `audit_manifest.json`, `resource_envelope.json`, `audit_summary.json`, `reproduce.sh`, and the cache key. Absolute paths, parent-directory escapes, NUL bytes, and `.env`-like changed-file inputs are rejected with exit code 2.

For local GitHub PR-style runs, the wrapper derives the changed-file list from local refs only and preserves that list next to the output directory so `reproduce.sh` keeps working:

```bash
./scripts/audit_my_repo_pr.sh /path/to/repo --base-ref main --head-ref HEAD \
  --mode quick --out results/my_repo_audit_pr
```

The PR wrapper does not fetch, push, or contact GitHub. `--base-ref` and `--head-ref` must already resolve in the local clone. Passing `--changed-files-from` to the wrapper is rejected because the wrapper owns that generated input.

Suppression/allowlist files are local schema-validated JSON and are bound into the manifest/cache key:

```json
{
  "schema_version": "local_repo_audit_suppressions.v1",
  "suppressions": [
    {
      "suppression_id": "accepted-distutils-example",
      "plugin_id": "deprecated_api",
      "rule_id": "deprecated-api-01",
      "file_path": "legacy.py",
      "reason": "accepted local compatibility debt"
    }
  ]
}
```

```bash
./scripts/audit_my_repo.sh /path/to/repo --mode full --allowlist allowlist.json --out results/my_repo_audit
```

Suppressed findings remain in the artifact set with `suppressed=1`, `suppression_ids`, and a row in `suppressed_findings.csv`; benchmark scoring ignores suppressed findings as active positives. `.env`-like paths are rejected as allowlist inputs.

## Parser Boundaries

Deprecated API checks are parser-bound where the alpha has deterministic local support. Python uses AST import/call detection. JavaScript/TypeScript uses a lexical executable-code candidate parser that masks comments, strings, template literal text, and regex literals while preserving `${...}` template expressions before matching deprecated API patterns. C/C++ uses a lexical executable-code candidate parser that masks comments, ordinary strings, character literals, and raw strings before matching.

Unsupported-claim checks ignore claim-boundary files, negated readiness wording, Markdown fenced examples, Markdown inline-code examples, JS/TS regex literals, and code-file comments/string literals before flagging risky readiness or capability terms.

## Baseline Diff

A previous verified audit output can be passed via `--baseline <verified audit output dir>` to produce a source-bound change triage. The baseline directory must pass artifact verification before the current run starts; the preflight allows source drift so an older baseline can be compared after the target repository changes. Missing or unverified baselines fail with exit code 2.

```bash
./scripts/audit_my_repo.sh /path/to/repo --mode quick \
  --baseline results/my_repo_audit_previous --out results/my_repo_audit
```

When a baseline is supplied, the run emits `baseline_diff_rows.csv`, `baseline_diff_summary.json`, and `BASELINE_DIFF.md`. Each diff row is keyed by `finding_fingerprint` and labeled `new`, `changed`, `resolved`, or `unchanged`. The baseline output path, baseline output sha256, baseline manifest sha256, and baseline cache key are bound into `audit_invocation.json`, `audit_manifest.json`, `reproduce.sh`, and the cache key. Without `--baseline`, the diff rows are labeled `not_compared`.

Diff rows are source-bound change triage only. They do not claim release readiness, public comparison readiness, or real model execution.

Every run also emits `audit_dashboard.json` and `AUDIT_DASHBOARD.html`, deterministic local dashboards over the run summary, finding rows, manual-review status, and baseline diff counts. The verifier checks run id, cache key, readiness boundary, finding rows, links, and diff metrics so stale or tampered dashboard output is rejected.

## Verify

Each run publishes a complete versioned bundle under `runs/run-<cache>/`, then atomically updates `latest`. Top-level artifact paths are compatibility symlinks into `latest`.

Findings are emitted as CSV, standard JSON, JSONL, and SARIF:

```text
audit_findings.csv
audit_findings.json
audit_findings.jsonl
audit_findings.sarif.json
audit_dashboard.json
AUDIT_DASHBOARD.html
audit_semantic_summary.json
accuracy_rows.json
citation_correctness_rows.json
manual_review_queue.csv
manual_review_queue.json
```

`plugin_rule_rows.csv` records each rule's `confidence`, `evidence_policy`, and `parser_id`; deprecated Python checks use `python_ast`, while JavaScript/TypeScript and C/C++ checks use deterministic lexical code-candidate parsers that exclude comments and strings. JavaScript/TypeScript template literal text is excluded, but executable `${...}` expressions remain eligible for source-bound citations.

`accuracy_rows.json`, `citation_correctness_rows.json`, and `manual_review_queue.json` are schema-validated mirrors of their CSV rows after type normalization. Every finding remains queued for accuracy, citation-correctness, and false-positive review; `auto_promoted` stays `0`, and no automatic accuracy claim is made.

`audit_semantic_summary.json` records a stable semantic result sha over the source manifest, findings, citation spans, abstain/unsupported rows, baseline diff rows, and manual-review queue. Re-running the same input should preserve this sha; changing meaningful inputs such as the user question should change it.

```bash
./scripts/audit_my_repo.sh --verify-existing results/my_repo_audit
results/my_repo_audit/verify.sh
results/my_repo_audit/reproduce.sh
```

A different input/cache key will not replace `latest` unless `--overwrite-latest` is passed. Old versioned runs are not deleted by the tool.

## Local Alpha Package

The local alpha package command writes a pinned package manifest, deterministic changelog, and package sha manifest. It does not upload, release, or claim package readiness.

```bash
./scripts/audit_my_repo_package.py --out results/audit_my_repo_alpha_package
./scripts/audit_my_repo_package.py --verify-existing results/audit_my_repo_alpha_package
```

`package_manifest.json` binds the alpha version, audit entrypoints, verifier commands, product source sha256 values, local audit schema sha256 values, and blocked readiness flags. The writer stages and self-verifies package artifacts before publishing them, and restores existing managed package files if publish or final verification fails. `--verify-existing` schema-validates the manifest before recomputing those bindings and rejects stale package-managed artifacts outside the sha manifest. Existing package artifacts are not replaced unless `--overwrite` is passed, and unrelated files in the output directory are not deleted.

## Exit Codes

`0`: verified success.

`1`: artifact verification or guard failure.

`2`: user-correctable input or publish error, including invalid budgets, invalid namespace use, output inside target repo, corrupt existing output, or non-overwrite latest conflict.

## Diagnostics (Local Opt-In Only)

The audit bundle always emits a `diagnostics.json` artifact, but the default is opt-out. With the flag off the artifact records `diagnostics_opt_in=0`, `diagnostics_collected=0`, `external_network_used=0`, `scope=none`, and `reason=default-opt-out`, and it never carries raw target paths, source file paths, citations, secrets, `.env` content, or question text.

Pass `--emit-diagnostics` to opt in to coarse run metrics only. The artifact will then expose `mode`, `namespace`, budgets, `source_file_count`, `finding_rows`, `suppression_rows`, `active_plugin_ids`, the measured phase timings, and `install_verified`/`first_report_verified` flags. The opt-in flag is bound into `audit_invocation.json`, `audit_manifest.json`, `diagnostics.json`, the cache key, and `reproduce.sh`. The diagnostics never claim release, public-comparison, or real-model-execution readiness, and they never include raw source snippets, source file paths, citations, secrets, `.env` content, or question text.

```bash
# Default opt-out (no extra metrics collected)
./scripts/audit_my_repo.sh /path/to/repo --mode quick --out results/my_repo_audit

# Explicit local opt-in to coarse run metrics
./scripts/audit_my_repo.sh /path/to/repo --mode quick --emit-diagnostics --out results/my_repo_audit
```

## Human Label Templates

Create template-only candidate rows from a verified audit bundle before asking a design partner to label findings. Each candidate binds the source finding, primary citation span, and source manual-review queue id so human labels stay tied to the unreviewed queue row:

```bash
./scripts/audit_my_repo_label_template.py --audit-output results/my_repo_audit --out results/my_repo_label_template --case-id my_repo
./scripts/audit_my_repo_label_template.py --verify-existing results/my_repo_label_template
```

The template writer verifies the input audit bundle first, emits `label_template.csv`, `label_template.jsonl`, schema-validated `label_template.json`, `label_template_manifest.json`, and `label_template_sha256sums.txt`, and refuses to overwrite existing files unless `--overwrite` is passed. Rows are explicitly `template_only=1` and `human_labeled=0`; they do not count as benchmark labels, maintainer feedback, release readiness, public comparison readiness, or design-partner beta readiness.

Human decisions are recorded in a separate JSON/JSONL file keyed by `candidate_label_id`; the template artifacts remain immutable verification inputs. Compile reviewed decisions into benchmark labels like this:

```bash
printf '{"candidate_label_id":"my_repo_0001","human_labeled":true,"expected":"present","priority":"P1","reviewer_id":"reviewer-one"}\n' > decisions.jsonl
./scripts/audit_my_repo_label_intake.py --template results/my_repo_label_template --decisions decisions.jsonl --out results/my_repo_label_intake
./scripts/audit_my_repo_label_intake.py --verify-existing results/my_repo_label_intake
./scripts/audit_my_repo_benchmark.py --label-intake results/my_repo_label_intake --out results/audit_benchmark --mode full
```

The intake writer verifies the template bundle first, requires `human_labeled=true` on each decision row, rejects placeholder or unsafe `candidate_label_id`, `label_id`, `reviewer_id`, and decision-level `maintainer_id` values, binds the decision input sha256 and template manifest sha256, and emits `benchmark_labels.jsonl`, `label_intake_manifest.json`, and `label_intake_sha256sums.txt`. Fixture and synthetic template rows remain synthetic/non-real evidence in the compiled labels; only templates from a confirmed `real_benchmark` audit can emit non-synthetic labels. Intake manifests keep all readiness flags at `0`. Passing the intake directory to the benchmark with `--label-intake` re-verifies the intake bundle and binds its manifest and sha manifest in the benchmark manifest.

## Benchmark Harness

Evaluate user-provided local repositories with labels only:

```bash
./scripts/audit_my_repo_benchmark.py --labels labels.jsonl --feedback feedback.jsonl --out results/audit_benchmark --mode full
./scripts/audit_my_repo_benchmark.py --verify-existing results/audit_benchmark
```

Benchmark label rows may include `changed_files_from` to evaluate a case using the same PR/diff scope as `audit_my_repo.sh --changed-files-from`. Relative `changed_files_from` paths are resolved from the label file directory, and conflicting values inside one `case_id` are rejected.

Human label rows may also include `expected_line_start`, optional `expected_line_end`, and `expected_span_sha256`. When supplied, the benchmark records whether the matched finding cites that exact file/line/span. Present labels without a citation expectation still run, but they are counted as citation-unbound label-quality rows and cannot satisfy design-partner beta readiness.

The harness records TP/FP/FN, precision, recall, abstain correctness, citation validity, standard JSON findings validity, human labels, label-input quality, and repo snapshot locking separately. It writes schema-validated `benchmark_manifest.json` and `benchmark_sha256sums.txt`, `benchmark_labels.csv` plus schema-validated `benchmark_labels.json` for scored human-label rows, `benchmark_label_citation_expectations.csv` plus schema-validated `benchmark_label_citation_expectations.json` for exact human-provided citation span matches, `benchmark_confusion_rows.csv` for per-label TP/FP/FN/TN and unmatched-finding rows, `benchmark_abstain_correctness.csv` for expected-vs-actual abstention checks, schema-validated `benchmark_evaluation.json` that binds those evaluation rows and summary metrics, schema-validated `benchmark_readiness.json` that lists each beta gate's observed value, required value, pass bit, and blocker reason without making release/model claims, `benchmark_label_quality.csv` for broad, citation-unbound, duplicate, contradictory, and specific label rows, `benchmark_repo_snapshots.csv` for per-case clean git HEAD/status binding, `benchmark_findings.csv` plus schema-validated `benchmark_findings.json` for case-bound finding rows, `benchmark_maintainer_feedback.csv` plus schema-validated `benchmark_maintainer_feedback.json` for design-partner maintainer feedback evidence, and `benchmark_run_metrics.csv` with local install/preflight success, first verified report wall time, standard JSON findings parity, rerun success, cache-key repeatability, and semantic result repeatability. Rerun checks are enabled by default and can be disabled with `--no-rerun-check` for exploratory runs.

Label rows may include `allowlist` or `suppression_file`; relative paths resolve from the label file, the case audit forwards the allowlist into the manifest/cache key, and `benchmark_findings.csv/json` include only active unsuppressed findings while the per-case audit artifacts keep suppressed rows.

Each benchmark output writes `benchmark_manifest.json` and `benchmark_sha256sums.txt`. The manifest binds the benchmark runner source sha, audit entrypoint sha, local verifier sha, label source kind, label input sha, optional label-intake manifest shas, optional feedback input sha, mode, namespace, budgets, case audit manifests, repo snapshot gate counts, readiness thresholds, `benchmark_readiness.json` blocker rows, and blocked readiness flags. Benchmark runs require a fresh output directory by default; `--overwrite` replaces benchmark-managed artifacts, including the managed `case_runs/` tree, refuses to delete unrelated output-root files, and restores existing managed artifacts if the benchmark run fails before final verification. `--verify-existing` schema-validates the benchmark JSON artifacts, recomputes those bindings, re-verifies any bound label-intake bundle, and re-verifies every per-case audit output.

Human-label rows may include `expected_repo_git_head` and optional `expected_repo_snapshot_sha256`. A design-partner beta candidate requires every real benchmark case to be a clean git worktree whose current HEAD matches `expected_repo_git_head`; mismatches, dirty repos, non-git directories, or labels without an expected HEAD keep `repo_snapshot_requirement_met` at `0`. The snapshot artifact hashes git status and tracked-file lists but does not emit raw status path names.

`benchmark_label_quality.csv` is also included in the manifest hash set. The summary exposes `label_quality_requirement_met`, `label_citation_expectation_rows`, `label_citation_expectation_met_rows`, and `label_citation_expectation_requirement_met`, but these are recorded as separate evidence and do not by themselves mark the product beta-ready.

Feedback rows are local JSON/JSONL records linked to a benchmark `case_id`. They must include `maintainer_id`, `human_feedback: true`, and either `feedback_text` or `feedback_text_sha256`. Raw feedback text is not emitted; the benchmark output records only `maintainer_id_sha256`, `feedback_text_sha256`, byte count, and whether the row counts for the beta gate.

Citation validity rows are emitted in `benchmark_citation_validity.csv`; each row recomputes file existence, file sha256, source-manifest sha256, line bounds, span sha256, and preview matching against the provided local repository.

Synthetic cases cannot be promoted into the `real_benchmark` namespace, and product readiness is calculated only from non-synthetic human-labeled cases run in `real_benchmark`.
Benchmark runs using `--namespace real_benchmark` must also pass `--confirm-real-benchmark-namespace`; without that explicit confirmation the harness exits with usage error code `2`.

`design_partner_beta_candidate_ready` remains `0` unless the benchmark is based on real human labels, at least 10 local repositories, at least 300 human label rows, clean expected git HEAD snapshot locking for every case, no broad/citation-unbound/duplicate/contradictory label rows, matched label citation expectations, at least 3 maintainer feedback sources, overall precision >= 80%, P0/P1 precision >= 90%, citation validity 100%, valid standard JSON findings for every case, successful install/first-report checks, and successful rerun checks.
