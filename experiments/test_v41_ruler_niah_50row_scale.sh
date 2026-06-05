#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
SCALE_DIR="$RESULTS_DIR/v41_ruler_niah_50row_scale/scale_001"
SUMMARY_CSV="$RESULTS_DIR/v41_ruler_niah_50row_scale_summary.csv"
DECISION_CSV="$RESULTS_DIR/v41_ruler_niah_50row_scale_decision.csv"

"$ROOT_DIR/experiments/run_v41_ruler_niah_50row_scale.sh" >/dev/null

python3 - "$SCALE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

scale_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
engine_dir = scale_dir / "v34_engine_50row_packet"
official_dir = engine_dir / "official_expansion_return"

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
    raise SystemExit(f"expected one v41 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
for field in [
    "v41_ruler_niah_50row_scale_ready",
    "row_count_ready",
    "same_context_length",
    "official_source_snapshot_ready",
    "official_evaluator_ready",
    "route_memory_prediction_lineage_ready",
    "no_oracle_no_extractor_ready",
    "v18_verified",
]:
    if summary.get(field) != "1":
        raise SystemExit(f"v41 {field}: expected 1, got {summary.get(field)}")
if summary.get("target_rows") != "50" or summary.get("actual_rows") != "50":
    raise SystemExit("v41 should close exactly 50 rows")
if summary.get("context_length") != "4096":
    raise SystemExit("v41 should keep context length 4096")
if summary.get("human_review_completed") != "0" or summary.get("real_release_package_ready") != "0":
    raise SystemExit("v41 should keep review/release blocked")
if int(summary.get("artifact_rows", "0")) < 30:
    raise SystemExit("v41 should hash scale artifacts")

decisions = {row["gate"]: row for row in read_csv(decision_csv)}
for gate in [
    "v41-ruler-niah-50row-scale",
    "row-count",
    "same-context-length",
    "official-source-evaluator",
    "route-memory-lineage",
    "no-oracle-no-extractor",
    "v18-intake",
]:
    if decisions.get(gate, {}).get("status") != "pass":
        raise SystemExit(f"v41 gate should pass: {gate}")
for gate in ["human-review", "real-release-package"]:
    if decisions.get(gate, {}).get("status") != "blocked":
        raise SystemExit(f"v41 should leave {gate} blocked")

required_files = [
    "V41_RULER_NIAH_50ROW_BOUNDARY.md",
    "scale_rows.csv",
    "v41_ruler_niah_50row_scale_manifest.json",
    "sha256_manifest.csv",
    "evidence/v34_engine_50row_summary.csv",
    "evidence/v34_engine_50row_decision.csv",
    "evidence/v34_engine_50row_manifest.json",
    "evidence/candidate_result_rows.csv",
    "evidence/expanded_result_rows.csv",
    "v34_engine_50row_packet/benchmark_expansion_manifest.json",
    "v34_engine_50row_packet/official_expansion_return/raw_predictions.jsonl",
    "v34_engine_50row_packet/official_expansion_return/prediction_lineage.jsonl",
    "v34_engine_50row_packet/official_expansion_return/metrics.json",
    "v34_engine_50row_packet/official_expansion_return/provenance_manifest.json",
    "v34_engine_50row_packet/evidence/v18_with_v34_official/v18_external_evidence_intake_summary.csv",
]
for rel in required_files:
    path = scale_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"v41 missing artifact: {rel}")

manifest = json.loads((scale_dir / "v41_ruler_niah_50row_scale_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v41_ruler_niah_50row_scale_ready") != 1:
    raise SystemExit("v41 manifest should be ready")
if manifest.get("target_rows") != 50 or manifest.get("actual_rows") != 50:
    raise SystemExit("v41 manifest row counts should be 50")
if manifest.get("context_length") != 4096:
    raise SystemExit("v41 manifest context length should be 4096")
if manifest.get("human_review_completed") != 0 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v41 manifest should keep review/release blocked")

raw_rows = read_jsonl(official_dir / "raw_predictions.jsonl")
lineage_rows = read_jsonl(official_dir / "prediction_lineage.jsonl")
if len(raw_rows) != 50 or len(lineage_rows) != 50:
    raise SystemExit("v41 should write 50 raw and lineage rows")
if len({row["sample_id"] for row in raw_rows}) != 50:
    raise SystemExit("v41 raw sample IDs should be unique")
if {int(row["context_length"]) for row in raw_rows} != {4096}:
    raise SystemExit("v41 raw rows should hold context length fixed")
if any(row.get("benchmark_family") != "RULER" or row.get("task") != "niah_single_1" for row in raw_rows):
    raise SystemExit("v41 raw rows should stay in RULER NIAH")
if any(row.get("oracle_prediction_used") != 0 or row.get("raw_input_extractor_used") != 0 for row in raw_rows):
    raise SystemExit("v41 raw rows should remain no-oracle/no-extractor")
if any(row.get("prediction") != row.get("target") for row in raw_rows):
    raise SystemExit("v41 raw predictions should match targets in this scale slice")

lineage_by_id = {row["sample_id"]: row for row in lineage_rows}
for row in raw_rows:
    lineage = lineage_by_id.get(row["sample_id"])
    if not lineage or lineage.get("route_memory_prediction_lineage_ready") != 1:
        raise SystemExit(f"v41 missing lineage for {row['sample_id']}")
    if lineage.get("oracle_prediction_used") != 0 or lineage.get("raw_input_extractor_used") != 0:
        raise SystemExit(f"v41 lineage should remain no-oracle/no-extractor for {row['sample_id']}")

scale_rows = read_csv(scale_dir / "scale_rows.csv")
if len(scale_rows) != 1:
    raise SystemExit("v41 should write one scale row")
scale = scale_rows[0]
if scale.get("success_message") != "official-evaluator no-oracle RouteMemory lineage preserved through 50 rows at 4096 context length":
    raise SystemExit("v41 success message mismatch")
if scale.get("v18_verified") != "1":
    raise SystemExit("v41 scale row should record v18 verification")

boundary = (scale_dir / "V41_RULER_NIAH_50ROW_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "First academic scale-up",
    "50 rows",
    "4096",
    "No oracle",
    "Not long-context solved",
    "Not Transformer replacement",
]:
    if snippet not in boundary:
        raise SystemExit(f"v41 boundary missing: {snippet}")

with (scale_dir / "sha256_manifest.csv").open(newline="", encoding="utf-8") as handle:
    sha_rows = list(csv.DictReader(handle))
by_path = {row["path"]: row for row in sha_rows}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if rel not in by_path:
        raise SystemExit(f"v41 sha manifest missing {rel}")
    if by_path[rel]["sha256"] != sha256(scale_dir / rel):
        raise SystemExit(f"v41 sha mismatch for {rel}")
PY

echo "v41 RULER NIAH 50-row scale smoke passed"
