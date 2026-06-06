#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PACKET_DIR="$RESULTS_DIR/v34_official_benchmark_expansion_packet/packet_001"
SUMMARY_CSV="$RESULTS_DIR/v34_official_benchmark_expansion_packet_summary.csv"
DECISION_CSV="$RESULTS_DIR/v34_official_benchmark_expansion_packet_decision.csv"

"$ROOT_DIR/experiments/run_v34_official_benchmark_expansion_packet.sh" >/dev/null

python3 - "$PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

packet_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
official_dir = packet_dir / "official_expansion_return"

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def read_jsonl(path):
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]

with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
if len(rows) != 1:
    raise SystemExit(f"expected one v34 summary row, got {len(rows)}")
summary = rows[0]
expected_ones = [
    "v34_official_benchmark_expansion_packet_ready",
    "official_expansion_return_ready",
    "candidate_external_benchmark_expansion_ready",
    "v18_with_v34_official_ready",
    "one_axis_expansion_ready",
    "same_context_length",
    "official_source_snapshot_ready",
    "official_evaluator_ready",
    "raw_predictions_ready",
    "metrics_ready",
    "route_memory_prediction_lineage_ready",
    "candidate_external_benchmark_result_ready",
    "real_external_benchmark_verified",
]
for field in expected_ones:
    if summary.get(field) != "1":
        raise SystemExit(f"v34 {field}: expected 1, got {summary.get(field)}")
for field in ["human_review_completed", "oracle_prediction_used", "raw_input_extractor_used", "real_release_package_ready"]:
    if summary.get(field) != "0":
        raise SystemExit(f"v34 {field}: expected 0, got {summary.get(field)}")
if int(summary.get("expanded_prediction_rows", "0")) <= int(summary.get("v31_prediction_rows", "0")):
    raise SystemExit("v34 should expand beyond the v31 prediction row count")
if int(summary.get("artifact_rows", "0")) < 25:
    raise SystemExit("v34 packet should hash the expansion and evidence files")

with decision_csv.open(newline="", encoding="utf-8") as handle:
    decisions = {row["gate"]: row for row in csv.DictReader(handle)}
for gate in [
    "v34-official-benchmark-expansion-packet",
    "one-axis-expansion",
    "official-source-evaluator-reuse",
    "raw-predictions",
    "route-memory-lineage",
    "no-oracle-no-extractor",
    "v18-official-expansion-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v34 gate should pass: {gate}")
for gate in ["human-review", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v34 should leave {gate} blocked")

required_files = [
    "EXPANSION_BOUNDARY.md",
    "benchmark_expansion_manifest.json",
    "sha256_manifest.csv",
    "official_expansion_return/official_source_snapshot.json",
    "official_expansion_return/official_evaluator_status.json",
    "official_expansion_return/raw_predictions.jsonl",
    "official_expansion_return/prediction_lineage.jsonl",
    "official_expansion_return/metrics.json",
    "official_expansion_return/provenance_manifest.json",
    "official_expansion_return/reproducibility_package_manifest.json",
    "official_expansion_return/candidate_result_rows.csv",
    "expansion/query_axis_rows.csv",
    "expansion/expanded_result_rows.csv",
    "expansion/expansion_metrics.json",
    "evidence/v33_evidence_closure_manifest.json",
    "evidence/v33_v18_summary.csv",
    "evidence/v18_with_v34_official/v18_external_evidence_intake_summary.csv",
    "evidence/v18_with_v34_official/v18_external_evidence_intake_decision.csv",
]
for rel in required_files:
    path = packet_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v34 missing packet artifact: {rel}")

manifest = json.loads((packet_dir / "benchmark_expansion_manifest.json").read_text(encoding="utf-8"))
if manifest.get("one_axis_expansion_ready") != 1:
    raise SystemExit("v34 manifest should mark one-axis expansion ready")
if manifest.get("expanded_prediction_rows", 0) <= manifest.get("v31_prediction_rows", 0):
    raise SystemExit("v34 manifest should expand prediction rows beyond v31")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v34 manifest should keep review/release blocked")
if manifest.get("expansion_axis") != "more_queries_same_context_length":
    raise SystemExit("v34 manifest expansion axis mismatch")

boundary = (packet_dir / "EXPANSION_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "Allowed claim:",
    "Held constant:",
    "Blocked claims:",
    "not a public leaderboard result",
    "No oracle predictions",
]:
    if snippet not in boundary:
        raise SystemExit(f"v34 boundary missing: {snippet}")

source = json.loads((official_dir / "official_source_snapshot.json").read_text(encoding="utf-8"))
evaluator = json.loads((official_dir / "official_evaluator_status.json").read_text(encoding="utf-8"))
metrics = json.loads((official_dir / "metrics.json").read_text(encoding="utf-8"))
provenance = json.loads((official_dir / "provenance_manifest.json").read_text(encoding="utf-8"))
repro = json.loads((official_dir / "reproducibility_package_manifest.json").read_text(encoding="utf-8"))
if source.get("benchmark_family") != "RULER" or source.get("official_source_snapshot_ready") != 1:
    raise SystemExit("v34 official source snapshot should bind RULER")
if source.get("expansion_axis") != "more_queries_same_context_length":
    raise SystemExit("v34 source snapshot should record the expansion axis")
if evaluator.get("official_evaluator_ready") != 1 or "scripts/eval/evaluate.py" not in evaluator.get("evaluator_source", ""):
    raise SystemExit("v34 evaluator status should bind official evaluate.py")
if metrics.get("prediction_rows") != manifest.get("expanded_prediction_rows"):
    raise SystemExit("v34 metrics prediction rows should match manifest")
if metrics.get("exact_match") != 1.0 or metrics.get("one_axis_expansion_ready") != 1:
    raise SystemExit("v34 metrics should show exact-match expansion readiness")
if provenance.get("route_memory_prediction_lineage_ready") != 1:
    raise SystemExit("v34 provenance should mark lineage ready")
if provenance.get("oracle_prediction_used") != 0 or provenance.get("raw_input_extractor_used") != 0:
    raise SystemExit("v34 provenance should remain no-oracle/no-extractor")
if repro.get("reproducibility_package_ready") != 1:
    raise SystemExit("v34 reproducibility package should be ready")

raw_rows = read_jsonl(official_dir / "raw_predictions.jsonl")
lineage_rows = read_jsonl(official_dir / "prediction_lineage.jsonl")
if len(raw_rows) != manifest.get("expanded_prediction_rows"):
    raise SystemExit("v34 raw prediction row count mismatch")
if len(lineage_rows) != len(raw_rows):
    raise SystemExit("v34 lineage row count mismatch")
if len({row["sample_id"] for row in raw_rows}) != len(raw_rows):
    raise SystemExit("v34 raw prediction sample IDs should be unique")
if len({str(row["context_length"]) for row in raw_rows}) != 1:
    raise SystemExit("v34 should hold context length constant")
if any(row.get("benchmark_family") != "RULER" or row.get("task") != "niah_single_1" for row in raw_rows):
    raise SystemExit("v34 should stay in the RULER NIAH task family")
if any(row.get("oracle_prediction_used") != 0 or row.get("raw_input_extractor_used") != 0 for row in raw_rows):
    raise SystemExit("v34 raw predictions should be no-oracle/no-extractor")
if any(row.get("prediction") != row.get("target") for row in raw_rows):
    raise SystemExit("v34 raw predictions should match targets in this expansion slice")
lineage_by_id = {row["sample_id"]: row for row in lineage_rows}
for row in raw_rows:
    lineage = lineage_by_id.get(row["sample_id"])
    if not lineage or lineage.get("route_memory_prediction_lineage_ready") != 1:
        raise SystemExit(f"v34 missing lineage for {row['sample_id']}")
    if lineage.get("oracle_prediction_used") != 0 or lineage.get("raw_input_extractor_used") != 0:
        raise SystemExit(f"v34 lineage should be no-oracle/no-extractor for {row['sample_id']}")

candidate_rows = read_csv(official_dir / "candidate_result_rows.csv")
if len(candidate_rows) != 1:
    raise SystemExit("v34 should write one aggregate candidate row")
candidate = candidate_rows[0]
if candidate.get("candidate_external_benchmark_result_ready") != "1":
    raise SystemExit("v34 candidate row should be ready")
if int(candidate.get("query_count", "0")) != len(raw_rows):
    raise SystemExit("v34 candidate query_count should match raw rows")
if candidate.get("prediction_lineage_sha256") != sha256(official_dir / "prediction_lineage.jsonl"):
    raise SystemExit("v34 candidate lineage hash mismatch")

axis_rows = read_csv(packet_dir / "expansion" / "query_axis_rows.csv")
if len(axis_rows) != len(raw_rows):
    raise SystemExit("v34 query axis rows should match raw rows")
if any(row.get("held_constant") != "benchmark_family|task|context_length|official_evaluator|source_snapshot" for row in axis_rows):
    raise SystemExit("v34 axis rows should record held-constant fields")

with (packet_dir / "evidence" / "v18_with_v34_official" / "v18_external_evidence_intake_summary.csv").open(newline="", encoding="utf-8") as handle:
    v18 = list(csv.DictReader(handle))[0]
for field in [
    "independent_rerun_actual_ready",
    "candidate_external_benchmark_result_ready",
    "closed_corpus_poc_actual_ready",
    "real_external_benchmark_verified",
]:
    if v18.get(field) != "1":
        raise SystemExit(f"v34 copied v18 summary should keep {field}=1")
if v18.get("real_release_package_ready") != "0":
    raise SystemExit("v34 copied v18 summary must keep release blocked")

with (packet_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v34 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(packet_dir / rel):
        raise SystemExit(f"v34 sha mismatch for {rel}")
PY

echo "v34 official benchmark expansion packet smoke passed"
