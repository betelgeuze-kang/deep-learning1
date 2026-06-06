#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v41_ruler_niah_50row_scale"
SCALE_ID="${V41_SCALE_ID:-scale_001}"
SCALE_DIR="${V41_SCALE_DIR:-$RESULTS_DIR/${PREFIX}/$SCALE_ID}"
ENGINE_DIR="$SCALE_DIR/v34_engine_50row_packet"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
TARGET_ROWS="${V41_TARGET_ROWS:-50}"
CONTEXT_LENGTH="${V41_CONTEXT_LENGTH:-4096}"
V34_SUMMARY="$RESULTS_DIR/v34_official_benchmark_expansion_packet_summary.csv"
V34_DECISION="$RESULTS_DIR/v34_official_benchmark_expansion_packet_decision.csv"
RESTORE_DIR="$(mktemp -d)"

restore_v34_globals() {
  if [ -f "$RESTORE_DIR/v34_summary.csv" ]; then
    cp "$RESTORE_DIR/v34_summary.csv" "$V34_SUMMARY"
  fi
  if [ -f "$RESTORE_DIR/v34_decision.csv" ]; then
    cp "$RESTORE_DIR/v34_decision.csv" "$V34_DECISION"
  fi
  rm -rf "$RESTORE_DIR"
}
trap restore_v34_globals EXIT

if [ -f "$V34_SUMMARY" ]; then
  cp "$V34_SUMMARY" "$RESTORE_DIR/v34_summary.csv"
fi
if [ -f "$V34_DECISION" ]; then
  cp "$V34_DECISION" "$RESTORE_DIR/v34_decision.csv"
fi

V34_PACKET_DIR="$ENGINE_DIR" \
V34_EXPANDED_QUERY_COUNT="$TARGET_ROWS" \
V34_CONTEXT_LENGTH="$CONTEXT_LENGTH" \
"$ROOT_DIR/experiments/run_v34_official_benchmark_expansion_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$SCALE_DIR" "$ENGINE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$TARGET_ROWS" "$CONTEXT_LENGTH" "$V34_SUMMARY" "$V34_DECISION" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
scale_dir = Path(sys.argv[2])
engine_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
target_rows = int(sys.argv[6])
context_length = int(sys.argv[7])
v34_summary_src = Path(sys.argv[8])
v34_decision_src = Path(sys.argv[9])

if target_rows != 50:
    raise SystemExit("v41 is fixed to the 50-row RULER NIAH scale target")
if context_length != 4096:
    raise SystemExit("v41 must keep context length fixed at 4096")

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")

def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def read_jsonl(path):
    with path.open(encoding="utf-8") as handle:
        return [json.loads(line) for line in handle if line.strip()]

def rel(path):
    return str(path.relative_to(root))

def copy_file(src, dst):
    if not src.is_file():
        raise SystemExit(f"missing required source file: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)

manifest = read_json(engine_dir / "benchmark_expansion_manifest.json")
v34_summary = read_csv(v34_summary_src)[0]
v34_decisions = {row["gate"]: row for row in read_csv(v34_decision_src)}
official_dir = engine_dir / "official_expansion_return"
metrics = read_json(official_dir / "metrics.json")
provenance = read_json(official_dir / "provenance_manifest.json")
source = read_json(official_dir / "official_source_snapshot.json")
evaluator = read_json(official_dir / "official_evaluator_status.json")
raw_rows = read_jsonl(official_dir / "raw_predictions.jsonl")
lineage_rows = read_jsonl(official_dir / "prediction_lineage.jsonl")
axis_rows = read_csv(engine_dir / "expansion" / "query_axis_rows.csv")

same_context = int(len({int(row["context_length"]) for row in raw_rows}) == 1 and int(raw_rows[0]["context_length"]) == context_length)
row_count_ready = int(len(raw_rows) == target_rows and len(lineage_rows) == target_rows and len(axis_rows) == target_rows)
official_ready = int(source.get("official_source_snapshot_ready") == 1 and evaluator.get("official_evaluator_ready") == 1)
lineage_ready = int(provenance.get("route_memory_prediction_lineage_ready") == 1 and all(row.get("route_memory_prediction_lineage_ready") == 1 for row in lineage_rows))
no_oracle_ready = int(
    metrics.get("oracle_prediction_used") == 0
    and metrics.get("raw_input_extractor_used") == 0
    and all(row.get("oracle_prediction_used") == 0 and row.get("raw_input_extractor_used") == 0 for row in raw_rows)
    and all(row.get("oracle_prediction_used") == 0 and row.get("raw_input_extractor_used") == 0 for row in lineage_rows)
)
v18_ready = int(v34_summary.get("v18_with_v34_official_ready") == "1" and v34_summary.get("real_external_benchmark_verified") == "1")
one_axis_ready = int(v34_summary.get("one_axis_expansion_ready") == "1" and v34_summary.get("same_context_length") == "1")
release_blocked = int(v34_summary.get("human_review_completed") == "0" and v34_summary.get("real_release_package_ready") == "0")
v41_ready = int(row_count_ready and same_context and official_ready and lineage_ready and no_oracle_ready and v18_ready and one_axis_ready and release_blocked)

boundary = scale_dir / "V41_RULER_NIAH_50ROW_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v41 RULER NIAH 50-row Scale Boundary",
            "",
            "Goal:",
            "",
            "- First academic scale-up after v40.",
            "",
            "Success message:",
            "",
            "- Official-evaluator, no-oracle RouteMemory lineage is preserved through 50 rows at the same 4096 context length.",
            "",
            "Held constant:",
            "",
            "- Benchmark family: RULER.",
            "- Task family: NIAH single-needle lite candidate.",
            "- Context length: 4096.",
            "- Official evaluator/source hash inherited from the v31/v34 chain.",
            "- No oracle, no raw-input extractor, and no post-hoc answer repair.",
            "",
            "Blocked claims:",
            "",
            "- Not a leaderboard result.",
            "- Not long-context solved.",
            "- Not Transformer replacement.",
            "- Not release-ready product.",
            "",
        ]
    ),
    encoding="utf-8",
)

evidence_dir = scale_dir / "evidence"
copy_file(v34_summary_src, evidence_dir / "v34_engine_50row_summary.csv")
copy_file(v34_decision_src, evidence_dir / "v34_engine_50row_decision.csv")
copy_file(engine_dir / "benchmark_expansion_manifest.json", evidence_dir / "v34_engine_50row_manifest.json")
copy_file(official_dir / "candidate_result_rows.csv", evidence_dir / "candidate_result_rows.csv")
copy_file(engine_dir / "expansion" / "expanded_result_rows.csv", evidence_dir / "expanded_result_rows.csv")

scale_rows = [
    {
        "scale_id": scale_dir.name,
        "benchmark_family": "RULER",
        "task": "niah_single_1",
        "target_rows": target_rows,
        "actual_rows": len(raw_rows),
        "context_length": context_length,
        "official_evaluator_sha256": evaluator.get("evaluator_sha256", ""),
        "source_head_sha": source.get("source_head_sha", ""),
        "route_memory_prediction_lineage_ready": lineage_ready,
        "oracle_prediction_used": 0,
        "raw_input_extractor_used": 0,
        "v18_verified": v18_ready,
        "success_message": "official-evaluator no-oracle RouteMemory lineage preserved through 50 rows at 4096 context length",
    }
]
write_csv(
    scale_dir / "scale_rows.csv",
    [
        "scale_id",
        "benchmark_family",
        "task",
        "target_rows",
        "actual_rows",
        "context_length",
        "official_evaluator_sha256",
        "source_head_sha",
        "route_memory_prediction_lineage_ready",
        "oracle_prediction_used",
        "raw_input_extractor_used",
        "v18_verified",
        "success_message",
    ],
    scale_rows,
)

v41_manifest = {
    "manifest_scope": "v41-ruler-niah-50row-scale",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "scale_id": scale_dir.name,
    "engine_packet": rel(engine_dir),
    "target_rows": target_rows,
    "actual_rows": len(raw_rows),
    "context_length": context_length,
    "source_head_sha": source.get("source_head_sha", ""),
    "official_evaluator_sha256": evaluator.get("evaluator_sha256", ""),
    "row_count_ready": row_count_ready,
    "same_context_length": same_context,
    "official_evaluator_ready": official_ready,
    "route_memory_prediction_lineage_ready": lineage_ready,
    "no_oracle_no_extractor_ready": no_oracle_ready,
    "v18_verified": v18_ready,
    "v41_ruler_niah_50row_scale_ready": v41_ready,
    "human_review_completed": 0,
    "real_release_package_ready": 0,
}
write_json(scale_dir / "v41_ruler_niah_50row_scale_manifest.json", v41_manifest)

sha_rows = []
for path in sorted(scale_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(scale_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(scale_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "scale_id": scale_dir.name,
        "v41_ruler_niah_50row_scale_ready": v41_ready,
        "row_count_ready": row_count_ready,
        "target_rows": target_rows,
        "actual_rows": len(raw_rows),
        "same_context_length": same_context,
        "context_length": context_length,
        "official_source_snapshot_ready": source.get("official_source_snapshot_ready", 0),
        "official_evaluator_ready": evaluator.get("official_evaluator_ready", 0),
        "route_memory_prediction_lineage_ready": lineage_ready,
        "no_oracle_no_extractor_ready": no_oracle_ready,
        "v18_verified": v18_ready,
        "human_review_completed": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v41-ruler-niah-50row-scale", "status": status(v41_ready), "reason": "50-row RULER NIAH scale is ready" if v41_ready else "v41 scale incomplete"},
    {"gate": "row-count", "status": status(row_count_ready), "reason": f"{len(raw_rows)} raw rows and {len(lineage_rows)} lineage rows"},
    {"gate": "same-context-length", "status": status(same_context), "reason": f"context_length={context_length}"},
    {"gate": "official-source-evaluator", "status": status(official_ready), "reason": evaluator.get("evaluator_sha256", "")},
    {"gate": "route-memory-lineage", "status": status(lineage_ready), "reason": "all rows lineage-bound"},
    {"gate": "no-oracle-no-extractor", "status": status(no_oracle_ready), "reason": "oracle_prediction_used=0 and raw_input_extractor_used=0"},
    {"gate": "v18-intake", "status": status(v18_ready), "reason": "v18 verifies expanded official return with existing external evidence"},
    {"gate": "human-review", "status": "blocked", "reason": "human review remains optional/deferred"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release-ready wording remains blocked"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

if not v41_ready:
    raise SystemExit("v41 scale did not close")
PY

echo "v41_ruler_niah_50row_scale_dir: $SCALE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
