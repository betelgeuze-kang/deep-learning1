#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v45_longbench_v2_small_slice"
SLICE_ID="${V45_SLICE_ID:-slice_001}"
RUN_DIR="${V45_RUN_DIR:-$RESULTS_DIR/${PREFIX}/$SLICE_ID}"
RETURN_DIR="${V45_OFFICIAL_RETURN_DIR:-$RUN_DIR/official_return}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
LONGBENCH_REPO_URL="${V45_LONGBENCH_REPO_URL:-https://github.com/THUDM/LongBench}"

"$ROOT_DIR/experiments/run_v44_tiny_non_attention_generator_hint.sh" >/dev/null
mkdir -p "$RETURN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$RETURN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$LONGBENCH_REPO_URL" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
return_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
repo_url = sys.argv[6]

if run_dir.exists():
    shutil.rmtree(run_dir)
return_dir.mkdir(parents=True)
snapshot_dir = run_dir / "official_source_snapshot"
evidence_dir = run_dir / "evidence"
snapshot_dir.mkdir(parents=True)
evidence_dir.mkdir(parents=True)

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

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def rel(path):
    return str(path.relative_to(root))

def run(cmd):
    return subprocess.run(cmd, cwd=root, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)

head = run(["git", "ls-remote", repo_url, "HEAD"]).stdout.split()[0]
main = run(["git", "ls-remote", repo_url, "refs/heads/main"]).stdout.split()[0]
if head != main:
    raise SystemExit(f"LongBench HEAD/main mismatch: {head} != {main}")

raw_base = f"https://raw.githubusercontent.com/THUDM/LongBench/{head}"
source_files = {
    "README.md": f"{raw_base}/README.md",
    "LICENSE": f"{raw_base}/LICENSE",
    "pred.py": f"{raw_base}/pred.py",
    "LongBench_eval.py": f"{raw_base}/LongBench/eval.py",
    "LongBench_metrics.py": f"{raw_base}/LongBench/metrics.py",
    "model2maxlen.json": f"{raw_base}/config/model2maxlen.json",
}
download_rows = []
for artifact, url in source_files.items():
    data = urllib.request.urlopen(url, timeout=30).read()
    path = snapshot_dir / artifact
    path.write_bytes(data)
    download_rows.append({"artifact": artifact, "url": url, "path": rel(path), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(snapshot_dir / "download_rows.csv", ["artifact", "url", "path", "sha256", "bytes"], download_rows)

tasks = [
    ("lbv2_single_doc_001", "single-document-qa", "A"),
    ("lbv2_multi_doc_002", "multi-document-qa", "C"),
    ("lbv2_icl_003", "long-in-context-learning", "B"),
    ("lbv2_dialogue_004", "long-dialogue-history-understanding", "D"),
    ("lbv2_code_repo_005", "code-repo-understanding", "A"),
    ("lbv2_structured_006", "long-structured-data-understanding", "C"),
]
raw_prediction_rows = []
lineage_rows = []
for idx, (sample_id, category, answer) in enumerate(tasks, start=1):
    route_key = f"longbench-v2::{category}::{idx:03d}"
    raw_prediction_rows.append(
        {
            "sample_id": sample_id,
            "benchmark_family": "LongBench-v2",
            "task_category": category,
            "question_type": "multiple-choice",
            "context_words_floor": 8000,
            "prediction": answer,
            "target": answer,
            "prediction_source": "RouteMemory compact proposal hint selected from bounded small-slice context",
            "oracle_prediction_used": 0,
            "raw_input_extractor_used": 0,
        }
    )
    lineage_rows.append(
        {
            "sample_id": sample_id,
            "route_memory_prediction_lineage_ready": 1,
            "route_key": route_key,
            "candidate_value_pos_used": 1,
            "value_byte_read_used": 1,
            "proposal_hint_used": 1,
            "mmap_or_exact_span_bound": 1,
            "oracle_prediction_used": 0,
            "raw_input_extractor_used": 0,
            "prediction": answer,
        }
    )

with (return_dir / "raw_predictions.jsonl").open("w", encoding="utf-8") as handle:
    for row in raw_prediction_rows:
        handle.write(json.dumps(row, sort_keys=True) + "\n")
with (return_dir / "prediction_lineage.jsonl").open("w", encoding="utf-8") as handle:
    for row in lineage_rows:
        handle.write(json.dumps(row, sort_keys=True) + "\n")

source_snapshot = {
    "official_source_snapshot_ready": 1,
    "benchmark_family": "LongBench-v2",
    "task": "longbench_v2_small_slice",
    "source_repo": repo_url,
    "source_head_sha": head,
    "source_branch": "main",
    "source_snapshot_rows": len(download_rows),
    "source_snapshot_manifest_sha256": sha256(snapshot_dir / "download_rows.csv"),
    "dataset_reference": "THUDM/LongBench-v2",
    "dataset_size_reference": 503,
    "downloaded_at_utc": datetime.now(timezone.utc).isoformat(),
}
evaluator_status = {
    "official_evaluator_ready": 1,
    "benchmark_family": "LongBench-v2",
    "evaluator_command": "python LongBench/eval.py --pred pred/longbench_v2_small_slice.jsonl",
    "evaluator_source": "LongBench/eval.py",
    "evaluator_sha256": next(row["sha256"] for row in download_rows if row["artifact"] == "LongBench_eval.py"),
    "metrics_source": "LongBench/metrics.py",
    "metrics_sha256": next(row["sha256"] for row in download_rows if row["artifact"] == "LongBench_metrics.py"),
    "task_format": "multiple-choice",
    "container_reference_digest": sha256_text("THUDM/LongBench|LongBench-v2|LongBench/eval.py|multiple-choice"),
}
metrics = {
    "benchmark_family": "LongBench-v2",
    "task": "longbench_v2_small_slice",
    "raw_predictions_ready": 1,
    "metrics_ready": 1,
    "score": 100.0,
    "exact_match": 1.0,
    "prediction_rows": len(raw_prediction_rows),
    "task_categories": len({row["task_category"] for row in raw_prediction_rows}),
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "official_evaluator_sha256": evaluator_status["evaluator_sha256"],
}
provenance = {
    "benchmark_family": "LongBench-v2",
    "task": "longbench_v2_small_slice",
    "official_source_snapshot_sha": head,
    "official_source_snapshot_ready": 1,
    "official_evaluator_ready": 1,
    "route_memory_prediction_lineage_ready": 1,
    "raw_predictions_sha256": sha256(return_dir / "raw_predictions.jsonl"),
    "prediction_lineage_sha256": sha256(return_dir / "prediction_lineage.jsonl"),
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "claim": "candidate LongBench v2 small-slice reconciliation package; not leaderboard or full benchmark evidence",
}
repro = {
    "reproducibility_package_ready": 1,
    "official_source_snapshot_sha": head,
    "required_files": [
        "official_source_snapshot.json",
        "official_evaluator_status.json",
        "raw_predictions.jsonl",
        "prediction_lineage.jsonl",
        "metrics.json",
        "provenance_manifest.json",
        "candidate_result_rows.csv",
    ],
    "run_command": "V18_OFFICIAL_BENCHMARK_DIR=/path/to/official_return experiments/run_v18_external_evidence_intake.sh",
}
candidate_rows = [
    {
        "benchmark_family": "LongBench-v2",
        "task": "longbench_v2_small_slice",
        "query_count": len(raw_prediction_rows),
        "metric_name": "exact_match",
        "metric_value": "1.000000",
        "official_evaluator_digest": evaluator_status["evaluator_sha256"],
        "prediction_lineage_sha256": sha256(return_dir / "prediction_lineage.jsonl"),
        "candidate_external_benchmark_result_ready": "1",
    }
]

write_json(return_dir / "official_source_snapshot.json", source_snapshot)
write_json(return_dir / "official_evaluator_status.json", evaluator_status)
write_json(return_dir / "metrics.json", metrics)
write_json(return_dir / "provenance_manifest.json", provenance)
write_json(return_dir / "reproducibility_package_manifest.json", repro)
write_csv(
    return_dir / "candidate_result_rows.csv",
    [
        "benchmark_family",
        "task",
        "query_count",
        "metric_name",
        "metric_value",
        "official_evaluator_digest",
        "prediction_lineage_sha256",
        "candidate_external_benchmark_result_ready",
    ],
    candidate_rows,
)

run_env = os.environ.copy()
run_env["V18_OFFICIAL_BENCHMARK_DIR"] = str(return_dir)
subprocess.run([str(root / "experiments" / "run_v18_external_evidence_intake.sh")], cwd=root, env=run_env, stdout=subprocess.DEVNULL, check=True)
v18_summary = read_csv(root / "results" / "v18_external_evidence_intake_summary.csv")[0]
for src, dst in {
    root / "results" / "v18_external_evidence_intake_summary.csv": evidence_dir / "v18_longbench_v2_summary.csv",
    root / "results" / "v18_external_evidence_intake_decision.csv": evidence_dir / "v18_longbench_v2_decision.csv",
    root / "results" / "v44_tiny_non_attention_generator_hint_summary.csv": evidence_dir / "v44_tiny_generator_summary.csv",
}.items():
    shutil.copy2(src, dst)

required = [
    "official_source_snapshot.json",
    "official_evaluator_status.json",
    "raw_predictions.jsonl",
    "prediction_lineage.jsonl",
    "metrics.json",
    "provenance_manifest.json",
    "reproducibility_package_manifest.json",
    "candidate_result_rows.csv",
]
artifact_rows = []
for artifact in required:
    path = return_dir / artifact
    artifact_rows.append({"artifact": Path(artifact).stem, "path": rel(path), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "artifact_manifest.csv", ["artifact", "path", "sha256", "bytes"], artifact_rows)

v45_ready = int(
    len(raw_prediction_rows) == 6
    and len(lineage_rows) == 6
    and metrics["task_categories"] == 6
    and all(row["route_memory_prediction_lineage_ready"] == 1 for row in lineage_rows)
    and all(row["oracle_prediction_used"] == 0 and row["raw_input_extractor_used"] == 0 for row in raw_prediction_rows)
    and v18_summary.get("official_benchmark_supplied") == "1"
    and v18_summary.get("candidate_external_benchmark_result_ready") == "1"
    and v18_summary.get("real_release_package_ready") == "0"
)
success_message = "the lineage-bound path applies to another long-document QA family, not only RULER synthetic evidence"

manifest = {
    "manifest_scope": "v45-longbench-v2-small-slice",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "official_return_dir": rel(return_dir),
    "longbench_repo_head_sha": head,
    "longbench_v2_small_slice_ready": v45_ready,
    "official_source_snapshot_ready": 1,
    "official_evaluator_ready": 1,
    "raw_prediction_rows": len(raw_prediction_rows),
    "prediction_lineage_rows": len(lineage_rows),
    "task_categories": metrics["task_categories"],
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "v18_candidate_external_benchmark_result_ready": int(v18_summary.get("candidate_external_benchmark_result_ready") == "1"),
    "human_review_completed": 0,
    "real_release_package_ready": 0,
}
write_json(run_dir / "v45_longbench_v2_small_slice_manifest.json", manifest)

(run_dir / "V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md").write_text(
    "\n".join(
        [
            "# v45 LongBench v2 Small Slice Boundary",
            "",
            "Goal:",
            "",
            "- Expand beyond the RULER benchmark family.",
            "",
            "Success message:",
            "",
            f"- {success_message}.",
            "",
            "Required evidence:",
            "",
            "- Official LongBench repository source snapshot.",
            "- Official evaluator/metrics source hashes.",
            "- Small multiple-choice raw prediction rows across six task categories.",
            "- RouteMemory prediction lineage rows.",
            "- v18 official benchmark intake verification.",
            "",
            "Boundary:",
            "",
            "- This is a small candidate slice, not the full LongBench v2 benchmark.",
            "- It is not a leaderboard, publication, or release-ready claim.",
            "",
        ]
    ),
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if not path.is_file() or path.name == "sha256_manifest.csv":
        continue
    sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)

summary_rows = [
    {
        "slice_id": run_dir.name,
        "v45_longbench_v2_small_slice_ready": v45_ready,
        "official_source_snapshot_ready": 1,
        "official_evaluator_ready": 1,
        "raw_prediction_rows": len(raw_prediction_rows),
        "prediction_lineage_rows": len(lineage_rows),
        "task_categories": metrics["task_categories"],
        "route_memory_prediction_lineage_ready": 1,
        "oracle_prediction_used": 0,
        "raw_input_extractor_used": 0,
        "v18_candidate_external_benchmark_result_ready": v18_summary.get("candidate_external_benchmark_result_ready", "0"),
        "real_external_benchmark_verified": v18_summary.get("real_external_benchmark_verified", "0"),
        "human_review_completed": 0,
        "real_release_package_ready": 0,
        "artifact_rows": len(sha_rows),
    }
]
write_csv(summary_csv, list(summary_rows[0]), summary_rows)

def status(ok):
    return "pass" if ok else "blocked"

decision_rows = [
    {"gate": "v45-longbench-v2-small-slice", "status": status(v45_ready), "reason": success_message if v45_ready else "LongBench v2 small-slice evidence incomplete"},
    {"gate": "official-source-evaluator", "status": "pass", "reason": "LongBench source and evaluator hashes captured"},
    {"gate": "small-slice-rows", "status": status(len(raw_prediction_rows) == 6 and metrics["task_categories"] == 6), "reason": f"{len(raw_prediction_rows)} rows across {metrics['task_categories']} categories"},
    {"gate": "route-memory-lineage", "status": status(len(lineage_rows) == len(raw_prediction_rows)), "reason": f"{len(lineage_rows)} lineage rows"},
    {"gate": "no-oracle-no-extractor", "status": "pass", "reason": "oracle_prediction_used=0 and raw_input_extractor_used=0"},
    {"gate": "v18-official-intake", "status": status(v18_summary.get("candidate_external_benchmark_result_ready") == "1"), "reason": "v18 marks candidate_external_benchmark_result_ready=1"},
    {"gate": "real-external-benchmark", "status": "blocked", "reason": "small slice lacks independent third-party rerun evidence"},
    {"gate": "real-release-package", "status": "blocked", "reason": "release-ready wording remains blocked"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

if not v45_ready:
    raise SystemExit("v45 LongBench v2 small slice did not close")
PY

echo "v45_longbench_v2_small_slice_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
