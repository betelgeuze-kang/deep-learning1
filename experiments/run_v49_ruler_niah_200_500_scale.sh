#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v49_ruler_niah_200_500_scale"
SCALE_ID="${V49_SCALE_ID:-scale_001}"
SCALE_DIR="${V49_SCALE_DIR:-$RESULTS_DIR/${PREFIX}/$SCALE_ID}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
CONTEXT_LENGTH="${V49_CONTEXT_LENGTH:-4096}"
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

mkdir -p "$SCALE_DIR/evidence"

for rows in 200 500; do
  ENGINE_DIR="$SCALE_DIR/v34_engine_${rows}row_packet"
  V34_PACKET_DIR="$ENGINE_DIR" \
  V34_EXPANDED_QUERY_COUNT="$rows" \
  V34_CONTEXT_LENGTH="$CONTEXT_LENGTH" \
  "$ROOT_DIR/experiments/run_v34_official_benchmark_expansion_packet.sh" >/dev/null
  cp "$V34_SUMMARY" "$SCALE_DIR/evidence/v34_engine_${rows}row_summary.csv"
  cp "$V34_DECISION" "$SCALE_DIR/evidence/v34_engine_${rows}row_decision.csv"
done

python3 - "$ROOT_DIR" "$SCALE_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$CONTEXT_LENGTH" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
scale_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
context_length = int(sys.argv[5])
targets = [200, 500]

if context_length != 4096:
    raise SystemExit("v49 must keep context length fixed at 4096")

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
        raise SystemExit(f"missing source artifact: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)

scale_rows = []
per_target = {}
for target_rows in targets:
    engine_dir = scale_dir / f"v34_engine_{target_rows}row_packet"
    official_dir = engine_dir / "official_expansion_return"
    evidence_dir = scale_dir / "evidence"
    v34_summary = read_csv(evidence_dir / f"v34_engine_{target_rows}row_summary.csv")[0]
    v34_decisions = {row["gate"]: row for row in read_csv(evidence_dir / f"v34_engine_{target_rows}row_decision.csv")}
    manifest = read_json(engine_dir / "benchmark_expansion_manifest.json")
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
    target_ready = int(row_count_ready and same_context and official_ready and lineage_ready and no_oracle_ready and v18_ready and one_axis_ready and release_blocked)

    copy_file(engine_dir / "benchmark_expansion_manifest.json", evidence_dir / f"v34_engine_{target_rows}row_manifest.json")
    copy_file(official_dir / "candidate_result_rows.csv", evidence_dir / f"candidate_result_rows_{target_rows}.csv")
    copy_file(engine_dir / "expansion" / "expanded_result_rows.csv", evidence_dir / f"expanded_result_rows_{target_rows}.csv")

    scale_rows.append(
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
            "scale_target_ready": target_ready,
            "success_message": f"official-evaluator no-oracle RouteMemory lineage preserved through {target_rows} rows at 4096 context length",
        }
    )
    per_target[target_rows] = {
        "target_ready": target_ready,
        "row_count_ready": row_count_ready,
        "same_context": same_context,
        "official_ready": official_ready,
        "lineage_ready": lineage_ready,
        "no_oracle_ready": no_oracle_ready,
        "v18_ready": v18_ready,
        "one_axis_ready": one_axis_ready,
        "release_blocked": release_blocked,
        "raw_rows": len(raw_rows),
        "lineage_rows": len(lineage_rows),
        "artifact_manifest_rows": int(manifest.get("artifact_rows", 0)),
        "v34_decisions": v34_decisions,
    }

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
        "scale_target_ready",
        "success_message",
    ],
    scale_rows,
)

v49_ready = int(all(per_target[target]["target_ready"] for target in targets))

(scale_dir / "V49_RULER_NIAH_200_500_BOUNDARY.md").write_text(
    "\n".join(
        [
            "# v49 RULER NIAH 200/500-row Scale Boundary",
            "",
            "Goal:",
            "",
            "- Expand RULER NIAH from 50 rows to 200 and 500 rows.",
            "",
            "Held constant:",
            "",
            "- Benchmark family: RULER.",
            "- Task family: NIAH single-needle lite candidate.",
            "- Context length: 4096.",
            "- Architecture and evaluator path: v34 official benchmark expansion engine.",
            "- No oracle, no raw-input extractor, no post-hoc answer repair.",
            "",
            "Success message:",
            "",
            "- Official-evaluator, no-oracle RouteMemory lineage is preserved through both 200 and 500 rows at the same 4096 context length.",
            "",
            "Blocked claims:",
            "",
            "- Not a public leaderboard result.",
            "- Not long-context solved.",
            "- Not Transformer replacement.",
            "- Not release-ready product.",
            "",
        ]
    ),
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v49-ruler-niah-200-500-scale",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "scale_id": scale_dir.name,
    "target_rows": targets,
    "context_length": context_length,
    "engine": "v34_official_benchmark_expansion_packet",
    "architecture_fixed": 1,
    "context_length_fixed": 1,
    "target_200_ready": per_target[200]["target_ready"],
    "target_500_ready": per_target[500]["target_ready"],
    "v49_ruler_niah_200_500_scale_ready": v49_ready,
    "human_review_completed": 0,
    "real_release_package_ready": 0,
}
write_json(scale_dir / "v49_ruler_niah_200_500_scale_manifest.json", manifest)

sha_rows = []
for path in sorted(scale_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(scale_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(scale_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "scale_id": scale_dir.name,
        "v49_ruler_niah_200_500_scale_ready": v49_ready,
        "target_200_ready": per_target[200]["target_ready"],
        "target_500_ready": per_target[500]["target_ready"],
        "rows_200": per_target[200]["raw_rows"],
        "rows_500": per_target[500]["raw_rows"],
        "lineage_rows_200": per_target[200]["lineage_rows"],
        "lineage_rows_500": per_target[500]["lineage_rows"],
        "context_length": context_length,
        "context_length_fixed": int(per_target[200]["same_context"] and per_target[500]["same_context"]),
        "architecture_fixed": 1,
        "official_evaluator_ready": int(per_target[200]["official_ready"] and per_target[500]["official_ready"]),
        "route_memory_prediction_lineage_ready": int(per_target[200]["lineage_ready"] and per_target[500]["lineage_ready"]),
        "no_oracle_no_extractor_ready": int(per_target[200]["no_oracle_ready"] and per_target[500]["no_oracle_ready"]),
        "v18_verified": int(per_target[200]["v18_ready"] and per_target[500]["v18_ready"]),
        "human_review_completed": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v49-ruler-niah-200-500-scale", "status": status(v49_ready), "reason": "200/500-row RULER NIAH scale is ready" if v49_ready else "v49 scale incomplete"},
    {"gate": "row-count-200", "status": status(per_target[200]["row_count_ready"]), "reason": f"{per_target[200]['raw_rows']} raw rows"},
    {"gate": "row-count-500", "status": status(per_target[500]["row_count_ready"]), "reason": f"{per_target[500]['raw_rows']} raw rows"},
    {"gate": "fixed-context", "status": status(per_target[200]["same_context"] and per_target[500]["same_context"]), "reason": f"context_length={context_length}"},
    {"gate": "fixed-architecture", "status": "pass", "reason": "both targets use v34 official benchmark expansion engine"},
    {"gate": "official-source-evaluator", "status": status(per_target[200]["official_ready"] and per_target[500]["official_ready"]), "reason": "official source/evaluator reused"},
    {"gate": "route-memory-lineage", "status": status(per_target[200]["lineage_ready"] and per_target[500]["lineage_ready"]), "reason": "all rows lineage-bound"},
    {"gate": "no-oracle-no-extractor", "status": status(per_target[200]["no_oracle_ready"] and per_target[500]["no_oracle_ready"]), "reason": "oracle_prediction_used=0 and raw_input_extractor_used=0"},
    {"gate": "v18-intake", "status": status(per_target[200]["v18_ready"] and per_target[500]["v18_ready"]), "reason": "v18 verifies both expanded official returns"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release-ready wording remains blocked"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

if not v49_ready:
    raise SystemExit("v49 scale did not close")
PY

echo "v49_ruler_niah_200_500_scale_dir: $SCALE_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
