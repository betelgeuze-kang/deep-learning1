#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v10_h10_real_label_promotion_readiness_gate/gate_001"
SUMMARY_CSV="$RESULTS_DIR/v10_h10_real_label_promotion_readiness_gate_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_h10_real_label_promotion_readiness_gate_decision.csv"
FIXTURE_LABEL_CSV="$RESULTS_DIR/v10_h10_real_label_fixture_evidence.csv"
MALFORMED_LABEL_CSV="$RESULTS_DIR/v10_h10_real_label_malformed_evidence.csv"

"$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected = {
    "v10_h10_real_label_promotion_readiness_gate_ready": "1",
    "h10_real_label_promotion_ready": "0",
    "h10_source_verified_eval_ready": "0",
    "h10_diagnostic_scorer_signal_ready": "1",
    "source_provenance_binding_ready": "1",
    "v53ap_adapter_trace_provenance_ready": "1",
    "v53ap_adapter_trace_rows": "4000",
    "v53ap_system_distinct_adapter_trace_ready": "1",
    "missing_query_abstain_ready": "1",
    "wrong_answer_guard_ready": "1",
    "same_query_abgh_ready": "1",
    "external_human_label_evidence_ready": "0",
    "supplied_real_label_evidence_rows": "0",
    "accepted_real_label_evidence_rows": "0",
    "fixture_or_synthetic_label_evidence_rows": "0",
    "v53q_complete_source_symmetric_scorer_policy_ready": "1",
    "v53ap_complete_source_abgh_same_query_measured_ready": "1",
    "v54c_complete_source_grounded_generation_1000_ready": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"h10 real-label PM gate {field}: expected {value}, got {summary.get(field)}")

required_files = [
    "pm_h10_real_label_acceptance_rows.csv",
    "h10_real_label_evidence_template.csv",
    "h10_real_label_evidence_acceptance_rows.csv",
    "V10_H10_REAL_LABEL_PROMOTION_READINESS_BOUNDARY.md",
    "v10_h10_real_label_promotion_readiness_manifest.json",
    "sha256_manifest.csv",
    "source_h10s/v10_source_verified_learned_chunk_scorer_eval_gate_smoke_summary.csv",
    "source_v53q/symmetric_system_metric_rows.csv",
    "source_v53ap/abgh_system_metric_rows.csv",
    "source_v53ap/abgh_adapter_trace_rows.csv",
    "source_v54c/wrong_answer_guard_rows.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing h10 real-label gate artifact: {rel}")

criteria = {row["criterion"]: row for row in read_csv(run_dir / "pm_h10_real_label_acceptance_rows.csv")}
for criterion in [
    "coherent-wrong-key-reduction",
    "chunk-exact-increase",
    "near-miss-slash",
    "missing-query-abstain",
    "source-provenance-binding",
    "external-human-label-evidence",
]:
    if criterion not in criteria:
        raise SystemExit(f"missing PM h10 criterion: {criterion}")
if criteria["source-provenance-binding"]["machine_evidence_status"] != "pass":
    raise SystemExit("source provenance should be machine-bound")
if "v53ap_adapter_trace_rows=4000" not in criteria["source-provenance-binding"]["evidence"]:
    raise SystemExit("source provenance criterion should cite v53ap adapter trace rows")
if criteria["external-human-label-evidence"]["real_label_status"] != "blocked":
    raise SystemExit("external/human label evidence should remain blocked by default")

adapter_traces = read_csv(run_dir / "source_v53ap/abgh_adapter_trace_rows.csv")
if len(adapter_traces) != 4000:
    raise SystemExit("h10 PM gate should copy 4000 v53ap adapter trace rows")
if {row["system_id"] for row in adapter_traces} != {"A", "B", "G", "H"}:
    raise SystemExit("h10 PM gate v53ap adapter traces should cover A/B/G/H")
if any(row["source_span_binding_match"] != "1" or row["expected_answer_oracle_replay"] != "0" for row in adapter_traces):
    raise SystemExit("h10 PM gate v53ap adapter traces should preserve provenance/non-oracle boundary")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in [
    "v53-complete-source-symmetric-scorer-policy",
    "v53ap-abgh-same-query-prebaseline",
    "v54c-grounded-generation-guard",
    "h10-diagnostic-scorer-signal",
]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"h10 PM gate should pass machine evidence gate: {gate}")
for gate in [
    "h10-source-verified-eval",
    "h10-external-human-label-evidence",
    "h10-real-label-promotion",
    "release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"h10 PM gate should block: {gate}")

manifest = json.loads((run_dir / "v10_h10_real_label_promotion_readiness_manifest.json").read_text(encoding="utf-8"))
if manifest.get("h10_real_label_promotion_ready") != 0:
    raise SystemExit("manifest must keep h10 real-label promotion blocked")
if manifest.get("source_provenance_binding_ready") != 1 or manifest.get("same_query_abgh_ready") != 1:
    raise SystemExit("manifest should record machine evidence readiness")
if manifest.get("v53ap_adapter_trace_provenance_ready") != 1 or manifest.get("v53ap_adapter_trace_rows") != 4000:
    raise SystemExit("manifest should record v53ap adapter trace provenance readiness")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"h10 PM gate sha mismatch: {rel}")

boundary = (run_dir / "V10_H10_REAL_LABEL_PROMOTION_READINESS_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "h10_real_label_promotion_ready=0",
    "external_human_label_evidence_ready=0",
    "source_provenance_binding_ready=1",
    "v53ap_adapter_trace_provenance_ready=1",
    "v53ap_adapter_trace_rows=4000",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"h10 PM gate boundary missing: {snippet}")
PY

{
  echo "label_evidence_id,label_scope,label_source,label_source_uri,label_artifact_sha256,reviewer_id,reviewer_conflict_checked,human_reviewed,external_source_verified,non_fixture_declared,fixture_or_synthetic_declared,query_rows,label_rows,coherent_wrong_key_labels,chunk_exact_labels,near_miss_labels,missing_query_labels,source_provenance_labels,acceptance_summary_sha256,routing_trigger_rate,active_jump_rate"
  echo "fixture-001,v53i-1000,fixture-human-return,https://review.invalid/h10.csv,sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa,reviewer-fixture,1,1,1,0,1,1000,1000,50,1000,50,30,1000,sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb,0,0"
} >"$FIXTURE_LABEL_CSV"

V10_H10_REAL_LABEL_EVIDENCE_CSV="$FIXTURE_LABEL_CSV" \
  "$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" <<'PY'
import csv
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
checks = {
    "supplied_real_label_evidence_rows": "1",
    "accepted_real_label_evidence_rows": "0",
    "rejected_real_label_evidence_rows": "1",
    "fixture_or_synthetic_label_evidence_rows": "1",
    "external_human_label_evidence_ready": "0",
    "h10_real_label_promotion_ready": "0",
}
for field, expected in checks.items():
    if summary.get(field) != expected:
        raise SystemExit(f"fixture label evidence should not pass {field}: expected {expected}, got {summary.get(field)}")

rows = read_csv(run_dir / "h10_real_label_evidence_acceptance_rows.csv")
if rows[0]["acceptance_status"] != "rejected" or "non-fixture" not in rows[0]["failed_checks"]:
    raise SystemExit("fixture h10 label row should be rejected by non-fixture check")
PY

{
  echo "label_evidence_id,label_scope,label_source"
  echo "bad-001,v53i-1000,fixture"
} >"$MALFORMED_LABEL_CSV"

if V10_H10_REAL_LABEL_EVIDENCE_CSV="$MALFORMED_LABEL_CSV" \
  "$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null 2>/dev/null; then
  echo "h10 real-label gate should reject malformed supplied evidence CSV" >&2
  exit 50
fi

"$ROOT_DIR/experiments/run_v10_h10_real_label_promotion_readiness_gate.sh" >/dev/null

echo "v10 h10 real-label promotion readiness gate smoke passed"
