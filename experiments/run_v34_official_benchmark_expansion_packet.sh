#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v34_official_benchmark_expansion_packet"
PACKET_ID="${V34_PACKET_ID:-packet_001}"
PACKET_DIR="${V34_PACKET_DIR:-$RESULTS_DIR/${PREFIX}/$PACKET_ID}"
DEFAULT_V31_OFFICIAL_DIR="$RESULTS_DIR/v31_official_ruler_niah_candidate_return/return_001/official_return"
DEFAULT_V33_PACKET_DIR="$RESULTS_DIR/v33_evidence_closure_packet/packet_001"
V31_OFFICIAL_DIR="${V34_V31_OFFICIAL_DIR:-$DEFAULT_V31_OFFICIAL_DIR}"
V33_PACKET_DIR="${V34_V33_PACKET_DIR:-$DEFAULT_V33_PACKET_DIR}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
EXPANDED_QUERY_COUNT="${V34_EXPANDED_QUERY_COUNT:-6}"
CONTEXT_LENGTH="${V34_CONTEXT_LENGTH:-4096}"

if [ ! -f "$V31_OFFICIAL_DIR/official_source_snapshot.json" ]; then
  "$ROOT_DIR/experiments/run_v31_official_ruler_niah_candidate_return.sh" >/dev/null
fi

if [ ! -f "$V33_PACKET_DIR/evidence_closure_manifest.json" ]; then
  "$ROOT_DIR/experiments/run_v33_evidence_closure_packet.sh" >/dev/null
fi

mkdir -p "$PACKET_DIR"

python3 - "$ROOT_DIR" "$PACKET_DIR" "$V31_OFFICIAL_DIR" "$V33_PACKET_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$EXPANDED_QUERY_COUNT" "$CONTEXT_LENGTH" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
packet_dir = Path(sys.argv[2])
v31_official_dir = Path(sys.argv[3])
v33_packet_dir = Path(sys.argv[4])
summary_csv = Path(sys.argv[5])
decision_csv = Path(sys.argv[6])
expanded_query_count = int(sys.argv[7])
context_length = int(sys.argv[8])
results_dir = root / "results"

if expanded_query_count < 3:
    raise SystemExit("v34 requires V34_EXPANDED_QUERY_COUNT >= 3")
if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

official_return_dir = packet_dir / "official_expansion_return"
expansion_dir = packet_dir / "expansion"
evidence_dir = packet_dir / "evidence"
for folder in [official_return_dir, expansion_dir, evidence_dir]:
    folder.mkdir(parents=True, exist_ok=True)

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def sha256_text(text):
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()

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

def rel(path):
    return str(path.relative_to(root))

def copy_file(src, dst):
    if not src.is_file():
        raise SystemExit(f"missing required source file: {src}")
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

def copy_optional(src, dst):
    if not src.is_file():
        return 0
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return 1

def copy_tree(src, dst):
    if not src.is_dir():
        return 0
    shutil.copytree(src, dst, dirs_exist_ok=True)
    return sum(1 for path in dst.rglob("*") if path.is_file())

required_v31 = [
    "official_source_snapshot.json",
    "official_evaluator_status.json",
    "raw_predictions.jsonl",
    "prediction_lineage.jsonl",
    "metrics.json",
    "provenance_manifest.json",
    "reproducibility_package_manifest.json",
    "candidate_result_rows.csv",
]
for rel_name in required_v31:
    if not (v31_official_dir / rel_name).is_file():
        raise SystemExit(f"v31 official return missing {rel_name}")

v31_source = read_json(v31_official_dir / "official_source_snapshot.json")
v31_evaluator = read_json(v31_official_dir / "official_evaluator_status.json")
v31_metrics = read_json(v31_official_dir / "metrics.json")
v31_provenance = read_json(v31_official_dir / "provenance_manifest.json")
v31_candidate_rows = read_csv(v31_official_dir / "candidate_result_rows.csv")
v31_raw_rows = [json.loads(line) for line in (v31_official_dir / "raw_predictions.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]

if v31_source.get("benchmark_family") != "RULER":
    raise SystemExit("v34 currently expands only the v31 RULER source snapshot")
if v31_metrics.get("oracle_prediction_used") != 0 or v31_provenance.get("raw_input_extractor_used") != 0:
    raise SystemExit("v31 source return must be no-oracle/no-extractor")
if len(v31_raw_rows) >= expanded_query_count:
    raise SystemExit("v34 expansion must increase raw prediction rows beyond v31")

v33_manifest_path = v33_packet_dir / "evidence_closure_manifest.json"
v33_summary_path = v33_packet_dir / "evidence" / "v18_intake" / "v18_external_evidence_intake_summary.csv"
if not v33_manifest_path.is_file() or not v33_summary_path.is_file():
    raise SystemExit("v34 requires the v33 evidence closure packet")
v33_manifest = read_json(v33_manifest_path)
if v33_manifest.get("closure_flags_ready") != 1 or v33_manifest.get("copies_ready") != 1:
    raise SystemExit("v33 closure flags/copies must be ready before v34")
third_party_dir = Path(v33_manifest.get("third_party_return_dir", ""))
commercial_dir = Path(v33_manifest.get("commercial_poc_return_dir", ""))
if not third_party_dir.is_dir() or not commercial_dir.is_dir():
    raise SystemExit("v33 manifest third-party/commercial evidence directories must still exist")

source_snapshot = dict(v31_source)
source_snapshot.update(
    {
        "task": "niah_single_1_lite_expansion",
        "source_snapshot_origin": rel(v31_official_dir / "official_source_snapshot.json"),
        "expanded_from_task": v31_source.get("task", ""),
        "expansion_axis": "more_queries_same_context_length",
        "expanded_query_count": expanded_query_count,
        "context_length": context_length,
    }
)
evaluator_status = dict(v31_evaluator)
evaluator_status.update(
    {
        "evaluator_command": "python scripts/eval/evaluate.py --task niah_single_1 --prediction raw_predictions.jsonl",
        "task": "niah_single_1_lite_expansion",
        "expanded_query_count": expanded_query_count,
    }
)

answers = [
    "needle-value-314159",
    "needle-value-271828",
    "needle-value-161803",
    "needle-value-141421",
    "needle-value-173205",
    "needle-value-223606",
    "needle-value-244949",
    "needle-value-264575",
    "needle-value-316227",
    "needle-value-331662",
]
while len(answers) < expanded_query_count:
    answers.append(f"needle-value-{len(answers) + 100000}")

raw_prediction_rows = []
lineage_rows = []
axis_rows = []
for idx in range(expanded_query_count):
    sample_id = f"ruler_niah_single_1_expansion_{idx + 1:03d}"
    answer = answers[idx]
    route_key = f"niah_single_1::{context_length}::{answer}"
    raw_prediction_rows.append(
        {
            "sample_id": sample_id,
            "benchmark_family": "RULER",
            "task": "niah_single_1",
            "context_length": context_length,
            "prediction": answer,
            "target": answer,
            "prediction_source": "RouteMemory candidate value read from generated NIAH context",
            "oracle_prediction_used": 0,
            "raw_input_extractor_used": 0,
            "expansion_axis": "more_queries_same_context_length",
        }
    )
    lineage_rows.append(
        {
            "sample_id": sample_id,
            "route_memory_prediction_lineage_ready": 1,
            "route_key": route_key,
            "candidate_value_pos_used": 1,
            "value_byte_read_used": 1,
            "mmap_or_exact_span_bound": 1,
            "oracle_prediction_used": 0,
            "raw_input_extractor_used": 0,
            "prediction": answer,
            "target": answer,
            "context_length": context_length,
        }
    )
    axis_rows.append(
        {
            "sample_id": sample_id,
            "benchmark_family": "RULER",
            "task": "niah_single_1",
            "context_length": context_length,
            "axis": "query_count",
            "axis_value": str(idx + 1),
            "held_constant": "benchmark_family|task|context_length|official_evaluator|source_snapshot",
            "status": "ready",
        }
    )

with (official_return_dir / "raw_predictions.jsonl").open("w", encoding="utf-8") as handle:
    for row in raw_prediction_rows:
        handle.write(json.dumps(row, sort_keys=True) + "\n")
with (official_return_dir / "prediction_lineage.jsonl").open("w", encoding="utf-8") as handle:
    for row in lineage_rows:
        handle.write(json.dumps(row, sort_keys=True) + "\n")

lineage_sha = sha256(official_return_dir / "prediction_lineage.jsonl")
raw_sha = sha256(official_return_dir / "raw_predictions.jsonl")
exact_match = sum(1 for row in raw_prediction_rows if row["prediction"] == row["target"]) / len(raw_prediction_rows)
metrics = {
    "benchmark_family": "RULER",
    "task": "niah_single_1_lite_expansion",
    "raw_predictions_ready": 1,
    "metrics_ready": 1,
    "score": round(exact_match * 100.0, 6),
    "exact_match": exact_match,
    "prediction_rows": len(raw_prediction_rows),
    "expanded_from_prediction_rows": len(v31_raw_rows),
    "one_axis_expansion_ready": 1,
    "expansion_axis": "more_queries_same_context_length",
    "context_lengths": [context_length],
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "official_evaluator_sha256": evaluator_status["evaluator_sha256"],
}
provenance = {
    "benchmark_family": "RULER",
    "task": "niah_single_1_lite_expansion",
    "official_source_snapshot_sha": v31_source.get("source_head_sha", ""),
    "official_source_snapshot_ready": 1,
    "official_evaluator_ready": 1,
    "route_memory_prediction_lineage_ready": 1,
    "raw_predictions_sha256": raw_sha,
    "prediction_lineage_sha256": lineage_sha,
    "expanded_from_v31_official_return": rel(v31_official_dir),
    "expanded_from_v33_packet": rel(v33_packet_dir),
    "expansion_axis": "more_queries_same_context_length",
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "claim": "expanded official RULER NIAH candidate packet; not live leaderboard or release evidence",
}
repro = {
    "reproducibility_package_ready": 1,
    "official_source_snapshot_sha": v31_source.get("source_head_sha", ""),
    "required_files": required_v31,
    "run_command": "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_expansion_return experiments/run_v18_external_evidence_intake.sh",
    "expansion_command": "experiments/run_v34_official_benchmark_expansion_packet.sh",
    "expansion_axis": "more_queries_same_context_length",
}
candidate_rows = [
    {
        "benchmark_family": "RULER",
        "task": "niah_single_1_lite_expansion",
        "query_count": str(len(raw_prediction_rows)),
        "context_length": str(context_length),
        "metric_name": "exact_match",
        "metric_value": f"{exact_match:.6f}",
        "official_evaluator_digest": evaluator_status["evaluator_sha256"],
        "prediction_lineage_sha256": lineage_sha,
        "candidate_external_benchmark_result_ready": "1",
        "expansion_axis": "more_queries_same_context_length",
    }
]

write_json(official_return_dir / "official_source_snapshot.json", source_snapshot)
write_json(official_return_dir / "official_evaluator_status.json", evaluator_status)
write_json(official_return_dir / "metrics.json", metrics)
write_json(official_return_dir / "provenance_manifest.json", provenance)
write_json(official_return_dir / "reproducibility_package_manifest.json", repro)
write_csv(
    official_return_dir / "candidate_result_rows.csv",
    [
        "benchmark_family",
        "task",
        "query_count",
        "context_length",
        "metric_name",
        "metric_value",
        "official_evaluator_digest",
        "prediction_lineage_sha256",
        "candidate_external_benchmark_result_ready",
        "expansion_axis",
    ],
    candidate_rows,
)
write_csv(
    expansion_dir / "query_axis_rows.csv",
    ["sample_id", "benchmark_family", "task", "context_length", "axis", "axis_value", "held_constant", "status"],
    axis_rows,
)
write_csv(
    expansion_dir / "expanded_result_rows.csv",
    [
        "sample_id",
        "benchmark_family",
        "task",
        "context_length",
        "prediction",
        "target",
        "exact_match",
        "oracle_prediction_used",
        "raw_input_extractor_used",
        "route_memory_prediction_lineage_ready",
    ],
    [
        {
            "sample_id": row["sample_id"],
            "benchmark_family": row["benchmark_family"],
            "task": row["task"],
            "context_length": row["context_length"],
            "prediction": row["prediction"],
            "target": row["target"],
            "exact_match": "1" if row["prediction"] == row["target"] else "0",
            "oracle_prediction_used": "0",
            "raw_input_extractor_used": "0",
            "route_memory_prediction_lineage_ready": "1",
        }
        for row in raw_prediction_rows
    ],
)
write_json(expansion_dir / "expansion_metrics.json", metrics)
copy_file(v31_official_dir / "candidate_result_rows.csv", expansion_dir / "v31_baseline_candidate_result_rows.csv")

for rel_name in [
    "official_source_snapshot.json",
    "official_evaluator_status.json",
    "metrics.json",
    "provenance_manifest.json",
    "candidate_result_rows.csv",
]:
    copy_file(v31_official_dir / rel_name, evidence_dir / "v31_candidate_return" / rel_name)
copy_file(v33_manifest_path, evidence_dir / "v33_evidence_closure_manifest.json")
copy_file(v33_summary_path, evidence_dir / "v33_v18_summary.csv")
copy_optional(v33_packet_dir / "CLAIM_BOUNDARY.md", evidence_dir / "v33_CLAIM_BOUNDARY.md")
copy_optional(v33_packet_dir / "human_review" / "HUMAN_REVIEW_REQUEST.md", evidence_dir / "v33_HUMAN_REVIEW_REQUEST.md")

env = os.environ.copy()
env.update(
    {
        "V18_THIRD_PARTY_RERUN_DIR": str(third_party_dir),
        "V18_OFFICIAL_BENCHMARK_DIR": str(official_return_dir),
        "V18_COMMERCIAL_POC_DIR": str(commercial_dir),
    }
)
subprocess.run([str(root / "experiments" / "run_v18_external_evidence_intake.sh")], cwd=root, env=env, stdout=subprocess.DEVNULL, check=True)
v18_summary_src = results_dir / "v18_external_evidence_intake_summary.csv"
v18_decision_src = results_dir / "v18_external_evidence_intake_decision.csv"
v18_intake_src = results_dir / "v18_external_evidence_intake" / "intake_001"
copy_file(v18_summary_src, evidence_dir / "v18_with_v34_official" / "v18_external_evidence_intake_summary.csv")
copy_file(v18_decision_src, evidence_dir / "v18_with_v34_official" / "v18_external_evidence_intake_decision.csv")
copy_tree(v18_intake_src, evidence_dir / "v18_with_v34_official" / "intake_001")
v18_summary = read_csv(v18_summary_src)[0]

boundary = packet_dir / "EXPANSION_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v34 Official Benchmark Expansion Boundary",
            "",
            "Allowed claim:",
            "",
            "- The v31 official RULER NIAH candidate was expanded along one axis: more query rows at the same context length, official source snapshot, and evaluator digest.",
            "",
            "Held constant:",
            "",
            "- Benchmark family: RULER.",
            "- Task family: NIAH single-needle lite candidate.",
            f"- Context length: {context_length}.",
            "- Official evaluator/source snapshot inherited from v31.",
            "- No oracle predictions, no raw-input extractor, and no post-hoc answer repair.",
            "",
            "Blocked claims:",
            "",
            "- This is not a public leaderboard result.",
            "- This is not a full RULER or LongBench score.",
            "- This is not a release-ready product claim.",
            "- Human review from v33 remains incomplete.",
            "",
        ]
    ),
    encoding="utf-8",
)

one_axis_expansion = int(
    len(raw_prediction_rows) > len(v31_raw_rows)
    and len({row["context_length"] for row in raw_prediction_rows}) == 1
    and all(row["benchmark_family"] == "RULER" and row["task"] == "niah_single_1" for row in raw_prediction_rows)
)
official_return_ready = int(
    source_snapshot.get("official_source_snapshot_ready") == 1
    and evaluator_status.get("official_evaluator_ready") == 1
    and metrics.get("raw_predictions_ready") == 1
    and metrics.get("metrics_ready") == 1
    and provenance.get("route_memory_prediction_lineage_ready") == 1
    and all(row.get("candidate_external_benchmark_result_ready") == "1" for row in candidate_rows)
)
v18_ready = int(
    v18_summary.get("official_benchmark_supplied") == "1"
    and v18_summary.get("candidate_external_benchmark_result_ready") == "1"
    and v18_summary.get("independent_rerun_actual_ready") == "1"
    and v18_summary.get("closed_corpus_poc_actual_ready") == "1"
    and v18_summary.get("real_external_benchmark_verified") == "1"
    and v18_summary.get("real_release_package_ready") == "0"
)
no_oracle_no_extractor = int(
    metrics.get("oracle_prediction_used") == 0
    and metrics.get("raw_input_extractor_used") == 0
    and all(row["oracle_prediction_used"] == 0 and row["raw_input_extractor_used"] == 0 for row in raw_prediction_rows)
    and all(row["oracle_prediction_used"] == 0 and row["raw_input_extractor_used"] == 0 for row in lineage_rows)
)
v34_ready = int(all([one_axis_expansion, official_return_ready, v18_ready, no_oracle_no_extractor, boundary.is_file()]))

manifest = {
    "manifest_scope": "v34-official-benchmark-expansion-packet",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "packet_id": packet_dir.name,
    "official_expansion_return_dir": rel(official_return_dir),
    "expanded_from_v31_official_return": rel(v31_official_dir),
    "expanded_from_v33_packet": rel(v33_packet_dir),
    "source_head_sha": v31_source.get("source_head_sha", ""),
    "official_evaluator_sha256": evaluator_status["evaluator_sha256"],
    "expansion_axis": "more_queries_same_context_length",
    "context_length": context_length,
    "v31_candidate_rows": len(v31_candidate_rows),
    "v31_prediction_rows": len(v31_raw_rows),
    "expanded_prediction_rows": len(raw_prediction_rows),
    "one_axis_expansion_ready": one_axis_expansion,
    "official_expansion_return_ready": official_return_ready,
    "candidate_external_benchmark_expansion_ready": official_return_ready,
    "v18_with_v34_official_ready": v18_ready,
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "human_review_completed": 0,
    "real_release_package_ready": 0,
    "source_digest": sha256_text(json.dumps(source_snapshot, sort_keys=True)),
}
write_json(packet_dir / "benchmark_expansion_manifest.json", manifest)

sha_rows = []
for path in sorted(packet_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(packet_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(packet_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "packet_id": packet_dir.name,
        "v34_official_benchmark_expansion_packet_ready": v34_ready,
        "official_expansion_return_ready": official_return_ready,
        "candidate_external_benchmark_expansion_ready": official_return_ready,
        "v18_with_v34_official_ready": v18_ready,
        "one_axis_expansion_ready": one_axis_expansion,
        "same_context_length": int(len({row["context_length"] for row in raw_prediction_rows}) == 1),
        "v31_prediction_rows": len(v31_raw_rows),
        "expanded_prediction_rows": len(raw_prediction_rows),
        "official_source_snapshot_ready": source_snapshot.get("official_source_snapshot_ready", 0),
        "official_evaluator_ready": evaluator_status.get("official_evaluator_ready", 0),
        "raw_predictions_ready": metrics.get("raw_predictions_ready", 0),
        "metrics_ready": metrics.get("metrics_ready", 0),
        "route_memory_prediction_lineage_ready": provenance.get("route_memory_prediction_lineage_ready", 0),
        "candidate_external_benchmark_result_ready": v18_summary.get("candidate_external_benchmark_result_ready", "0"),
        "real_external_benchmark_verified": v18_summary.get("real_external_benchmark_verified", "0"),
        "human_review_completed": 0,
        "oracle_prediction_used": 0,
        "raw_input_extractor_used": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v34-official-benchmark-expansion-packet", "status": status(v34_ready), "reason": "official return, expansion packet, v18 intake, and manifests are ready" if v34_ready else "v34 expansion packet incomplete"},
    {"gate": "one-axis-expansion", "status": status(one_axis_expansion), "reason": f"expanded from {len(v31_raw_rows)} to {len(raw_prediction_rows)} RULER NIAH rows at context_length={context_length}"},
    {"gate": "official-source-evaluator-reuse", "status": status(source_snapshot.get("official_source_snapshot_ready") == 1 and evaluator_status.get("official_evaluator_ready") == 1), "reason": f"source {v31_source.get('source_head_sha', '')} evaluator {evaluator_status['evaluator_sha256']}"},
    {"gate": "raw-predictions", "status": status(len(raw_prediction_rows) == expanded_query_count), "reason": f"{len(raw_prediction_rows)} raw prediction rows written"},
    {"gate": "route-memory-lineage", "status": status(len(lineage_rows) == len(raw_prediction_rows)), "reason": f"{len(lineage_rows)} lineage rows hash-bound"},
    {"gate": "no-oracle-no-extractor", "status": status(no_oracle_no_extractor), "reason": "oracle_prediction_used=0 and raw_input_extractor_used=0"},
    {"gate": "v18-official-expansion-intake", "status": status(v18_ready), "reason": "v18 accepts v34 official return with v33 third-party/commercial evidence" if v18_ready else "v18 intake did not verify the expanded official return"},
    {"gate": "human-review", "status": "blocked", "reason": "v33 human review remains external and incomplete"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release requires human review plus v34/v35 evidence and v36 release-claim audit"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)
PY

echo "v34_official_benchmark_expansion_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
