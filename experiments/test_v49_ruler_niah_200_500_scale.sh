#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SCALE_DIR="$RESULTS_DIR/v49_ruler_niah_200_500_scale/scale_001"
SUMMARY_CSV="$RESULTS_DIR/v49_ruler_niah_200_500_scale_summary.csv"
DECISION_CSV="$RESULTS_DIR/v49_ruler_niah_200_500_scale_decision.csv"

"$ROOT_DIR/experiments/run_v49_ruler_niah_200_500_scale.sh" >/dev/null

python3 - "$SCALE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

scale_dir = Path(sys.argv[1])
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

def read_jsonl(path):
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]

summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v49 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v49_ruler_niah_200_500_scale_ready": "1",
    "target_200_ready": "1",
    "target_500_ready": "1",
    "rows_200": "200",
    "rows_500": "500",
    "lineage_rows_200": "200",
    "lineage_rows_500": "500",
    "context_length": "4096",
    "context_length_fixed": "1",
    "architecture_fixed": "1",
    "official_evaluator_ready": "1",
    "route_memory_prediction_lineage_ready": "1",
    "no_oracle_no_extractor_ready": "1",
    "v18_verified": "1",
    "human_review_completed": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v49 {field}: expected {value}, got {summary.get(field)}")
if int(summary.get("artifact_rows", "0")) < 80:
    raise SystemExit("v49 should hash both scale packets")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v49-ruler-niah-200-500-scale",
    "row-count-200",
    "row-count-500",
    "fixed-context",
    "fixed-architecture",
    "official-source-evaluator",
    "route-memory-lineage",
    "no-oracle-no-extractor",
    "v18-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v49 gate should pass: {gate}")
if decisions.get("real-release-package", {}).get("status") != "blocked":
    raise SystemExit("v49 release gate should stay blocked")

required_files = [
    "V49_RULER_NIAH_200_500_BOUNDARY.md",
    "scale_rows.csv",
    "v49_ruler_niah_200_500_scale_manifest.json",
    "sha256_manifest.csv",
    "evidence/v34_engine_200row_summary.csv",
    "evidence/v34_engine_200row_decision.csv",
    "evidence/v34_engine_200row_manifest.json",
    "evidence/candidate_result_rows_200.csv",
    "evidence/expanded_result_rows_200.csv",
    "evidence/v34_engine_500row_summary.csv",
    "evidence/v34_engine_500row_decision.csv",
    "evidence/v34_engine_500row_manifest.json",
    "evidence/candidate_result_rows_500.csv",
    "evidence/expanded_result_rows_500.csv",
    "v34_engine_200row_packet/official_expansion_return/raw_predictions.jsonl",
    "v34_engine_200row_packet/official_expansion_return/prediction_lineage.jsonl",
    "v34_engine_200row_packet/official_expansion_return/metrics.json",
    "v34_engine_200row_packet/official_expansion_return/provenance_manifest.json",
    "v34_engine_200row_packet/official_expansion_return/candidate_result_rows.csv",
    "v34_engine_200row_packet/benchmark_expansion_manifest.json",
    "v34_engine_500row_packet/official_expansion_return/raw_predictions.jsonl",
    "v34_engine_500row_packet/official_expansion_return/prediction_lineage.jsonl",
    "v34_engine_500row_packet/official_expansion_return/metrics.json",
    "v34_engine_500row_packet/official_expansion_return/provenance_manifest.json",
    "v34_engine_500row_packet/official_expansion_return/candidate_result_rows.csv",
    "v34_engine_500row_packet/benchmark_expansion_manifest.json",
]
for rel in required_files:
    path = scale_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v49 missing artifact: {rel}")

manifest = json.loads((scale_dir / "v49_ruler_niah_200_500_scale_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v49_ruler_niah_200_500_scale_ready") != 1:
    raise SystemExit("v49 manifest should be ready")
if manifest.get("target_rows") != [200, 500] or manifest.get("context_length") != 4096:
    raise SystemExit("v49 manifest should record 200/500 rows at 4096")
if manifest.get("architecture_fixed") != 1 or manifest.get("context_length_fixed") != 1:
    raise SystemExit("v49 manifest should fix architecture/context")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v49 manifest should keep review/release blocked")

for rows in [200, 500]:
    engine_dir = scale_dir / f"v34_engine_{rows}row_packet"
    official_dir = engine_dir / "official_expansion_return"
    raw_rows = read_jsonl(official_dir / "raw_predictions.jsonl")
    lineage_rows = read_jsonl(official_dir / "prediction_lineage.jsonl")
    metrics = json.loads((official_dir / "metrics.json").read_text(encoding="utf-8"))
    provenance = json.loads((official_dir / "provenance_manifest.json").read_text(encoding="utf-8"))
    engine_manifest = json.loads((engine_dir / "benchmark_expansion_manifest.json").read_text(encoding="utf-8"))
    axis_rows = read_csv(engine_dir / "expansion" / "query_axis_rows.csv")
    if len(raw_rows) != rows or len(lineage_rows) != rows or len(axis_rows) != rows:
        raise SystemExit(f"v49 should write {rows} raw/lineage/axis rows")
    if len({row["sample_id"] for row in raw_rows}) != rows:
        raise SystemExit(f"v49 {rows} raw sample IDs should be unique")
    if {int(row["context_length"]) for row in raw_rows} != {4096}:
        raise SystemExit(f"v49 {rows} raw rows should hold context length fixed")
    if any(row.get("benchmark_family") != "RULER" or row.get("task") != "niah_single_1" for row in raw_rows):
        raise SystemExit(f"v49 {rows} raw rows should stay in RULER NIAH")
    if any(row.get("prediction") != row.get("target") for row in raw_rows):
        raise SystemExit(f"v49 {rows} raw predictions should match targets")
    if any(row.get("oracle_prediction_used") != 0 or row.get("raw_input_extractor_used") != 0 for row in raw_rows):
        raise SystemExit(f"v49 {rows} raw rows should remain no-oracle/no-extractor")
    if metrics.get("oracle_prediction_used") != 0 or metrics.get("raw_input_extractor_used") != 0:
        raise SystemExit(f"v49 {rows} metrics should remain no-oracle/no-extractor")
    if provenance.get("route_memory_prediction_lineage_ready") != 1:
        raise SystemExit(f"v49 {rows} provenance should keep RouteMemory lineage ready")
    lineage_by_id = {row["sample_id"]: row for row in lineage_rows}
    for row in raw_rows:
        lineage = lineage_by_id.get(row["sample_id"])
        if not lineage:
            raise SystemExit(f"v49 missing lineage for {row['sample_id']}")
        if lineage.get("route_memory_prediction_lineage_ready") != 1:
            raise SystemExit(f"v49 lineage not ready for {row['sample_id']}")
        if lineage.get("context_length") != 4096:
            raise SystemExit(f"v49 lineage context mismatch for {row['sample_id']}")
        if lineage.get("oracle_prediction_used") != 0 or lineage.get("raw_input_extractor_used") != 0:
            raise SystemExit(f"v49 lineage should remain no-oracle/no-extractor for {row['sample_id']}")
    v34_summary = read_csv(scale_dir / "evidence" / f"v34_engine_{rows}row_summary.csv")[0]
    if v34_summary.get("expanded_prediction_rows") != str(rows):
        raise SystemExit(f"v49 copied v34 summary should record {rows} expanded rows")
    if v34_summary.get("same_context_length") != "1" or engine_manifest.get("context_length") != 4096:
        raise SystemExit(f"v49 copied v34 summary should keep context fixed for {rows}")
    if v34_summary.get("v18_with_v34_official_ready") != "1":
        raise SystemExit(f"v49 copied v34 summary should verify v18 for {rows}")

scale_rows = read_csv(scale_dir / "scale_rows.csv")
if len(scale_rows) != 2:
    raise SystemExit("v49 should write two scale rows")
if {row["target_rows"] for row in scale_rows} != {"200", "500"}:
    raise SystemExit("v49 scale rows should cover 200 and 500")
if any(row["scale_target_ready"] != "1" or row["v18_verified"] != "1" for row in scale_rows):
    raise SystemExit("v49 scale rows should be ready and v18 verified")

boundary = (scale_dir / "V49_RULER_NIAH_200_500_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "200 and 500 rows",
    "Context length: 4096",
    "Architecture and evaluator path",
    "No oracle",
    "Not long-context solved",
    "Not Transformer replacement",
]:
    if snippet not in boundary:
        raise SystemExit(f"v49 boundary missing: {snippet}")

with (scale_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v49 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(scale_dir / rel):
        raise SystemExit(f"v49 sha mismatch for {rel}")
PY

echo "v49 RULER NIAH 200/500-row scale smoke passed"
