#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SCORER_DIR="$RESULTS_DIR/v46_source_verified_scorer_mainline/scorer_001"
RETURN_DIR="$SCORER_DIR/commercial_return"
SUMMARY_CSV="$RESULTS_DIR/v46_source_verified_scorer_mainline_summary.csv"
DECISION_CSV="$RESULTS_DIR/v46_source_verified_scorer_mainline_decision.csv"

"$ROOT_DIR/experiments/run_v46_source_verified_scorer_mainline.sh" >/dev/null

python3 - "$ROOT_DIR" "$SCORER_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
scorer_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v46 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected_ones = [
    "v46_source_verified_scorer_mainline_ready",
    "scorer_model_ready",
    "ranking_improvement_ready",
    "wrong_candidate_guard_ready",
    "privacy_review_ready",
    "resource_envelope_ready",
    "v18_closed_corpus_poc_actual_ready",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v46 {field}: expected 1, got {summary.get(field)}")
expected_values = {
    "source_verified_label_rows": "12",
    "source_bound_label_rows": "12",
    "local_teacher_harness_labels_used": "0",
    "eval_query_rows": "6",
    "baseline_top1_accuracy": "0.000000",
    "scorer_top1_accuracy": "1.000000",
    "wrong_candidate_guard_rate": "1.000000",
    "human_review_completed": "0",
    "real_release_package_ready": "0",
}
for field, expected in expected_values.items():
    if summary.get(field) != expected:
        raise SystemExit(f"v46 {field}: expected {expected}, got {summary.get(field)}")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v46-source-verified-scorer-mainline",
    "source-verified-labels",
    "no-local-teacher-harness",
    "scorer-model",
    "ranking-improvement",
    "wrong-candidate-guard",
    "v18-commercial-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v46 gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v46 should leave release blocked")

required_files = [
    "V46_SOURCE_VERIFIED_SCORER_BOUNDARY.md",
    "source_verified_label_rows.csv",
    "source_verified_scorer_model.json",
    "scorer_eval_rows.csv",
    "v46_source_verified_scorer_manifest.json",
    "sha256_manifest.csv",
    "evidence/v18_source_verified_scorer_summary.csv",
    "evidence/v18_source_verified_scorer_decision.csv",
    "evidence/v45_longbench_v2_small_slice_summary.csv",
    "commercial_return/domain_manifest.json",
    "commercial_return/corpus_manifest.json",
    "commercial_return/query_set.csv",
    "commercial_return/poc_result_rows.csv",
    "commercial_return/audit_trail.csv",
    "commercial_return/resource_envelope.json",
    "commercial_return/privacy_review.json",
    "commercial_return/acceptance_review.csv",
]
for rel in required_files:
    path = scorer_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v46 missing artifact: {rel}")

manifest = json.loads((scorer_dir / "v46_source_verified_scorer_manifest.json").read_text(encoding="utf-8"))
if manifest.get("source_verified_scorer_mainline_ready") != 1:
    raise SystemExit("v46 manifest should be ready")
if manifest.get("source_verified_label_rows") != 12 or manifest.get("source_bound_label_rows") != 12:
    raise SystemExit("v46 manifest should record 12 source-bound labels")
if manifest.get("local_teacher_harness_labels_used") != 0:
    raise SystemExit("v46 manifest should use no local teacher harness labels")
if manifest.get("baseline_top1_accuracy") != 0 or manifest.get("scorer_top1_accuracy") != 1:
    raise SystemExit("v46 manifest should record scorer improvement")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v46 manifest should keep review/release blocked")

label_rows = read_csv(scorer_dir / "source_verified_label_rows.csv")
eval_rows = read_csv(scorer_dir / "scorer_eval_rows.csv")
model = json.loads((scorer_dir / "source_verified_scorer_model.json").read_text(encoding="utf-8"))
if len(label_rows) != 12 or len(eval_rows) != 6:
    raise SystemExit("v46 should write 12 labels and 6 eval rows")
if any(row["source_verified"] != "1" for row in label_rows):
    raise SystemExit("v46 labels should all be source verified")
if any(row["local_teacher_harness_label"] != "0" for row in label_rows):
    raise SystemExit("v46 labels should not use local teacher harness")
if len({row["sample_id"] for row in label_rows}) != 6:
    raise SystemExit("v46 labels should cover six samples")
if any(not row["source_uri"].startswith("https://github.com/THUDM/LongBench/tree/") for row in label_rows):
    raise SystemExit("v46 labels should bind to official LongBench source URI")
if any(not row["provenance_hash"].startswith("sha256:") for row in label_rows):
    raise SystemExit("v46 labels should carry provenance hashes")
if model.get("label_source") != "v45-longbench-v2-official-source-snapshot":
    raise SystemExit("v46 model should use v45 source labels")
if model.get("local_teacher_harness_labels_used") != 0:
    raise SystemExit("v46 model should record zero local teacher harness labels")
for row in eval_rows:
    if row["baseline_correct"] != "0" or row["scorer_correct"] != "1":
        raise SystemExit("v46 scorer should improve every eval row")
    if row["wrong_candidate_slashed"] != "1":
        raise SystemExit("v46 should slash wrong candidates")
    if row["source_verified_labels_used"] != "2" or row["local_teacher_harness_labels_used"] != "0":
        raise SystemExit("v46 eval rows should use source-verified labels only")

domain = json.loads((return_dir / "domain_manifest.json").read_text(encoding="utf-8"))
resource = json.loads((return_dir / "resource_envelope.json").read_text(encoding="utf-8"))
privacy = json.loads((return_dir / "privacy_review.json").read_text(encoding="utf-8"))
if domain.get("domain") != "codebase_qa" or domain.get("query_count") != 6:
    raise SystemExit("v46 domain should be codebase_qa with 6 queries")
if resource.get("resource_envelope_ready") != 1 or privacy.get("privacy_review_ready") != 1:
    raise SystemExit("v46 privacy/resource should be ready")

query_rows = read_csv(return_dir / "query_set.csv")
poc_rows = read_csv(return_dir / "poc_result_rows.csv")
audit_rows = read_csv(return_dir / "audit_trail.csv")
acceptance_rows = read_csv(return_dir / "acceptance_review.csv")
if len(query_rows) != 6 or len(poc_rows) != 6 or len(audit_rows) != 6:
    raise SystemExit("v46 query/result/audit rows should all be 6")
for field in ["wrong_answer_guard_pass", "citation_accuracy_pass", "abstain_behavior_pass", "query_to_evidence_latency_ready", "audit_trail_bound"]:
    if any(row[field] != "1" for row in poc_rows):
        raise SystemExit(f"v46 result rows should pass {field}")
for row in poc_rows:
    citation_path = root / row["citation_path"]
    if row["citation_sha256"] != sha256(citation_path):
        raise SystemExit(f"v46 citation hash mismatch: {row['query_id']}")
if any(row["status"] != "pass" for row in audit_rows):
    raise SystemExit("v46 audit trail rows should pass")
if len(acceptance_rows) < 7 or any(row["status"] != "pass" for row in acceptance_rows):
    raise SystemExit("v46 acceptance rows should pass")

with (scorer_dir / "evidence" / "v18_source_verified_scorer_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
if v18.get("commercial_poc_supplied") != "1" or v18.get("closed_corpus_poc_actual_ready") != "1":
    raise SystemExit("v46 copied v18 summary should verify commercial PoC")
if v18.get("real_release_package_ready") != "0":
    raise SystemExit("v46 copied v18 summary should keep release blocked")

boundary = (scorer_dir / "V46_SOURCE_VERIFIED_SCORER_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Promote candidate ranking beyond the local teacher harness",
    "source-verified labels rather than fixture labels",
    "not full distillation",
    "not claim a general learned scorer",
]:
    if snippet not in boundary:
        raise SystemExit(f"v46 boundary missing: {snippet}")

with (scorer_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v46 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(scorer_dir / rel):
        raise SystemExit(f"v46 sha mismatch for {rel}")
PY

echo "v46 Source-Verified Scorer mainline smoke passed"
