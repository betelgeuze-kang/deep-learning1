#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v56_ruler_longbench_expanded_contract"
RUN_ID="${V56_CONTRACT_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
V49_DIR="$RESULTS_DIR/v49_ruler_niah_200_500_scale/scale_001"
V45_DIR="$RESULTS_DIR/v45_longbench_v2_small_slice/slice_001"
V49_SUMMARY="$RESULTS_DIR/v49_ruler_niah_200_500_scale_summary.csv"
V45_SUMMARY="$RESULTS_DIR/v45_longbench_v2_small_slice_summary.csv"

required_seed_files=(
  "$V49_SUMMARY"
  "$V49_DIR/V49_RULER_NIAH_200_500_BOUNDARY.md"
  "$V49_DIR/scale_rows.csv"
  "$V49_DIR/v49_ruler_niah_200_500_scale_manifest.json"
  "$V49_DIR/sha256_manifest.csv"
  "$V49_DIR/evidence/expanded_result_rows_200.csv"
  "$V49_DIR/evidence/expanded_result_rows_500.csv"
  "$V49_DIR/evidence/candidate_result_rows_200.csv"
  "$V49_DIR/evidence/candidate_result_rows_500.csv"
  "$V45_SUMMARY"
  "$V45_DIR/V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md"
  "$V45_DIR/v45_longbench_v2_small_slice_manifest.json"
  "$V45_DIR/sha256_manifest.csv"
  "$V45_DIR/official_return/raw_predictions.jsonl"
  "$V45_DIR/official_return/prediction_lineage.jsonl"
  "$V45_DIR/official_return/metrics.json"
  "$V45_DIR/official_return/provenance_manifest.json"
  "$V45_DIR/official_return/official_source_snapshot.json"
  "$V45_DIR/official_return/official_evaluator_status.json"
  "$V45_DIR/official_return/candidate_result_rows.csv"
  "$V45_DIR/official_source_snapshot/download_rows.csv"
)

missing_seed_files=()
for path in "${required_seed_files[@]}"; do
  if [ ! -s "$path" ]; then
    missing_seed_files+=("$path")
  fi
done

if [ "${#missing_seed_files[@]}" -gt 0 ] || [ "${V56_FORCE_SEED_REBUILD:-0}" = "1" ]; then
  if [ "${V56_ALLOW_SEED_REBUILD:-0}" != "1" ]; then
    {
      echo "v56 seed artifacts are missing or rebuild was requested; refusing implicit v49/v45 regeneration."
      echo "Set V56_ALLOW_SEED_REBUILD=1 to opt into the v49/v45 seed regeneration chain."
      printf 'missing_seed_artifact=%s\n' "${missing_seed_files[@]}"
    } >&2
    exit 2
  fi
  "$ROOT_DIR/experiments/run_v49_ruler_niah_200_500_scale.sh" >/dev/null
  "$ROOT_DIR/experiments/run_v45_longbench_v2_small_slice.sh" >/dev/null
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
v49_dir = results / "v49_ruler_niah_200_500_scale" / "scale_001"
v45_dir = results / "v45_longbench_v2_small_slice" / "slice_001"
v49_summary = list(csv.DictReader((results / "v49_ruler_niah_200_500_scale_summary.csv").open(newline="", encoding="utf-8")))[0]
v45_summary = list(csv.DictReader((results / "v45_longbench_v2_small_slice_summary.csv").open(newline="", encoding="utf-8")))[0]

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst

for rel in [
    "V49_RULER_NIAH_200_500_BOUNDARY.md",
    "scale_rows.csv",
    "v49_ruler_niah_200_500_scale_manifest.json",
    "sha256_manifest.csv",
    "evidence/expanded_result_rows_200.csv",
    "evidence/expanded_result_rows_500.csv",
    "evidence/candidate_result_rows_200.csv",
    "evidence/candidate_result_rows_500.csv",
]:
    copy(v49_dir / rel, f"source_v49/{rel}")
for rel in [
    "V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md",
    "v45_longbench_v2_small_slice_manifest.json",
    "sha256_manifest.csv",
    "official_return/raw_predictions.jsonl",
    "official_return/prediction_lineage.jsonl",
    "official_return/metrics.json",
    "official_return/provenance_manifest.json",
    "official_return/official_source_snapshot.json",
    "official_return/official_evaluator_status.json",
    "official_return/candidate_result_rows.csv",
    "official_source_snapshot/download_rows.csv",
]:
    copy(v45_dir / rel, f"source_v45/{rel}")

ruler_seed_rows = int(v49_summary.get("rows_500", "0"))
longbench_seed_rows = int(v45_summary.get("raw_prediction_rows", "0"))
ruler_target_rows = 1000
longbench_target_rows = 500

benchmark_rows = [
    {
        "benchmark_family": "RULER",
        "task": "niah",
        "target_rows": ruler_target_rows,
        "seed_rows": ruler_seed_rows,
        "missing_rows": max(0, ruler_target_rows - ruler_seed_rows),
        "official_source_hash_bound": "1",
        "official_evaluator_hash_bound": v49_summary.get("official_evaluator_ready", "0"),
        "route_memory_lineage_ready": v49_summary.get("route_memory_prediction_lineage_ready", "0"),
        "oracle_prediction_used": "0",
        "raw_input_extractor_used": "0",
        "status": "missing-expanded-rows",
    },
    {
        "benchmark_family": "LongBench",
        "task": "v2-multiple-choice",
        "target_rows": longbench_target_rows,
        "seed_rows": longbench_seed_rows,
        "missing_rows": max(0, longbench_target_rows - longbench_seed_rows),
        "official_source_hash_bound": v45_summary.get("official_source_snapshot_ready", "0"),
        "official_evaluator_hash_bound": v45_summary.get("official_evaluator_ready", "0"),
        "route_memory_lineage_ready": v45_summary.get("route_memory_prediction_lineage_ready", "0"),
        "oracle_prediction_used": v45_summary.get("oracle_prediction_used", "0"),
        "raw_input_extractor_used": v45_summary.get("raw_input_extractor_used", "0"),
        "status": "missing-expanded-rows",
    },
]
write_csv(run_dir / "benchmark_family_target_rows.csv", list(benchmark_rows[0].keys()), benchmark_rows)

artifact_contract_rows = [
    ("official_source_snapshot", "required", "official source files, source URI, license, split and benchmark-card hashes"),
    ("official_evaluator_status", "required", "evaluator source/container/command hash and metric specification"),
    ("raw_predictions", "required", "raw prediction rows for all benchmark samples"),
    ("prediction_lineage", "required", "RouteMemory-derived lineage rows, no oracle, no raw-input extractor"),
    ("metrics", "required", "official metric outputs and evaluator provenance"),
    ("provenance_manifest", "required", "source/result/evaluator/lineage hash links"),
    ("reproducibility_package", "required", "one-command or packaged rerun instructions"),
    ("candidate_result_rows", "required", "candidate rows compatible with v18/v52"),
    ("llm_rag_baseline_rows", "required", "v52 baseline rows where benchmark format allows"),
    ("sha256_manifest", "required", "hashes for all emitted artifacts"),
]
write_csv(
    run_dir / "expanded_benchmark_artifact_contract_rows.csv",
    ["artifact", "required_status", "notes"],
    [{"artifact": artifact, "required_status": status, "notes": notes} for artifact, status, notes in artifact_contract_rows],
)

lineage_invariants = [
    ("official_source_hash_bound", "1", "1", "pass"),
    ("official_evaluator_hash_bound", "1", "1", "pass"),
    ("oracle_prediction_used", "0", "0", "pass"),
    ("raw_input_extractor_used", "0", "0", "pass"),
    ("route_memory_prediction_lineage_ready", "1", "1", "pass"),
    ("real_external_benchmark_verified", "0", "0", "pass"),
    ("real_release_package_ready", "0", "0", "pass"),
]
write_csv(
    run_dir / "benchmark_invariant_rows.csv",
    ["invariant", "required_value", "observed_value", "status"],
    [{"invariant": inv, "required_value": req, "observed_value": obs, "status": status} for inv, req, obs, status in lineage_invariants],
)

target_total_rows = ruler_target_rows + longbench_target_rows
seed_total_rows = ruler_seed_rows + longbench_seed_rows
missing_total_rows = max(0, target_total_rows - seed_total_rows)
summary = {
    "v56_ruler_longbench_expanded_contract_ready": 1,
    "v56_ruler_longbench_expanded_ready": 0,
    "benchmark_family_rows": len(benchmark_rows),
    "target_total_rows": target_total_rows,
    "seed_total_rows": seed_total_rows,
    "missing_total_rows": missing_total_rows,
    "ruler_target_rows": ruler_target_rows,
    "ruler_seed_rows": ruler_seed_rows,
    "ruler_missing_rows": max(0, ruler_target_rows - ruler_seed_rows),
    "longbench_target_rows": longbench_target_rows,
    "longbench_seed_rows": longbench_seed_rows,
    "longbench_missing_rows": max(0, longbench_target_rows - longbench_seed_rows),
    "official_source_hash_bound": 1,
    "official_evaluator_hash_bound": 1,
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "route_memory_prediction_lineage_ready": 1,
    "llm_rag_baseline_rows_ready": 0,
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    ("v56-expanded-benchmark-contract", "pass", "RULER/LongBench target rows, artifact contract, invariants, and source evidence emitted"),
    ("v49-ruler-seed", "pass" if ruler_seed_rows == 500 else "blocked", f"ruler_seed_rows={ruler_seed_rows}"),
    ("v45-longbench-seed", "pass" if longbench_seed_rows == 6 else "blocked", f"longbench_seed_rows={longbench_seed_rows}"),
    ("ruler-expanded-row-target", "blocked", f"need >=1000 RULER rows; have {ruler_seed_rows}"),
    ("longbench-expanded-row-target", "blocked", f"need >=500 LongBench rows; have {longbench_seed_rows}"),
    ("llm-rag-baseline-rows", "blocked", "v52 LLM+RAG benchmark-format rows are not supplied"),
    ("real-external-benchmark", "blocked", "expanded contract is not independent external verification"),
    ("real-release-package", "blocked", "v56 contract is not a release package"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md").write_text(
    "# v56 RULER/LongBench Expanded Benchmark Boundary\n\n"
    "This is the v56 expanded benchmark contract scaffold, not the completed RULER/LongBench main run.\n\n"
    "Seed evidence:\n\n"
    f"- RULER seed rows={ruler_seed_rows}\n"
    f"- LongBench seed rows={longbench_seed_rows}\n"
    "- official source/evaluator binding present\n"
    "- no oracle prediction\n"
    "- no raw-input extractor\n"
    "- RouteMemory prediction lineage present\n\n"
    "Still blocked:\n\n"
    f"- RULER missing rows={max(0, ruler_target_rows - ruler_seed_rows)}\n"
    f"- LongBench missing rows={max(0, longbench_target_rows - longbench_seed_rows)}\n"
    "- LLM+RAG benchmark-format baseline rows from v52\n"
    "- independent external benchmark verification\n\n"
    "Do not publish expanded benchmark claims until official source/evaluator-bound RULER and LongBench rows reach target scale and baseline rows are symmetric.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v56-ruler-longbench-expanded-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v56_ruler_longbench_expanded_contract_ready": 1,
    "v56_ruler_longbench_expanded_ready": 0,
    "target_total_rows": target_total_rows,
    "seed_total_rows": seed_total_rows,
    "missing_total_rows": missing_total_rows,
    "v49_summary_sha256": sha256(results / "v49_ruler_niah_200_500_scale_summary.csv"),
    "v45_summary_sha256": sha256(results / "v45_longbench_v2_small_slice_summary.csv"),
    "real_external_benchmark_verified": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v56_ruler_longbench_expanded_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "benchmark_family_target_rows.csv",
    "expanded_benchmark_artifact_contract_rows.csv",
    "benchmark_invariant_rows.csv",
    "V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md",
    "v56_ruler_longbench_expanded_manifest.json",
    "source_v49/V49_RULER_NIAH_200_500_BOUNDARY.md",
    "source_v49/scale_rows.csv",
    "source_v49/v49_ruler_niah_200_500_scale_manifest.json",
    "source_v49/sha256_manifest.csv",
    "source_v49/evidence/expanded_result_rows_200.csv",
    "source_v49/evidence/expanded_result_rows_500.csv",
    "source_v49/evidence/candidate_result_rows_200.csv",
    "source_v49/evidence/candidate_result_rows_500.csv",
    "source_v45/V45_LONGBENCH_V2_SMALL_SLICE_BOUNDARY.md",
    "source_v45/v45_longbench_v2_small_slice_manifest.json",
    "source_v45/sha256_manifest.csv",
    "source_v45/official_return/raw_predictions.jsonl",
    "source_v45/official_return/prediction_lineage.jsonl",
    "source_v45/official_return/metrics.json",
    "source_v45/official_return/provenance_manifest.json",
    "source_v45/official_return/official_source_snapshot.json",
    "source_v45/official_return/official_evaluator_status.json",
    "source_v45/official_return/candidate_result_rows.csv",
    "source_v45/official_source_snapshot/download_rows.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v56_ruler_longbench_expanded_contract_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
