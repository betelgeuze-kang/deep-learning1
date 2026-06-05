#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

mkdir -p "$RESULTS_DIR"

PREFIX="v14e_ruler_niah_lite"
SOURCE_PREFIX="v13_external_benchmark_official_source_acquisition_gate_smoke"
SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate_smoke"
RUNTIME_PREFIX="${V14_RUNTIME_FETCH_PROVENANCE_PREFIX:-v13_real_evidence_runtime_fetch_provenance_gate_smoke}"
RUN_ID="${V14E_RULER_NIAH_LITE_RUN_ID:-niah_lite_001}"
RUN_DIR="${V14E_RULER_NIAH_LITE_RUN_DIR:-$RESULTS_DIR/${PREFIX}_runs/$RUN_ID}"
TARGET_ROWS="${V14E_ROUTEQA_MINI_TARGET_ROWS:-100}"
SOURCE_PACKET_DIR="$RESULTS_DIR/${SOURCE_PREFIX}_packet/run_001"
SOURCE_LIVE_PACKET_DIR="$RESULTS_DIR/${SOURCE_LIVE_PREFIX}_packet/run_001"
RUNTIME_PACKET_DIR="$RESULTS_DIR/${RUNTIME_PREFIX}_packet/run_001"
SOURCE_ACQUISITION_ROWS="${V14_SOURCE_ACQUISITION_ROWS:-$SOURCE_PACKET_DIR/official_source_acquisition_rows.csv}"
SOURCE_SEED_LIVE_FETCH_ROWS="${V14_SOURCE_SEED_LIVE_FETCH_ROWS:-$SOURCE_LIVE_PACKET_DIR/source_seed_live_fetch_rows.csv}"
RUNTIME_FETCH_PROVENANCE_ROWS="${V14_RUNTIME_FETCH_PROVENANCE_ROWS:-$RUNTIME_PACKET_DIR/runtime_fetch_provenance_rows.csv}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

"$ROOT_DIR/experiments/run_v13_real_evidence_source_seed_live_fetch_gate.sh" --smoke >/dev/null
"$ROOT_DIR/experiments/run_v13_real_evidence_runtime_fetch_provenance_gate.sh" --smoke >/dev/null
"$ROOT_DIR/experiments/run_v13_external_benchmark_official_source_acquisition_gate.sh" --smoke >/dev/null

"$ROOT_DIR/tools/routelm_benchmark_run" \
  --source-acquisition "$SOURCE_ACQUISITION_ROWS" \
  --source-seed-live-fetch "$SOURCE_SEED_LIVE_FETCH_ROWS" \
  --runtime-fetch-provenance "$RUNTIME_FETCH_PROVENANCE_ROWS" \
  --source-snapshot-mode manifest \
  --task public-codebase-routeqa-v1 \
  --repo "$ROOT_DIR" \
  --out "$RUN_DIR" \
  --backend cpu \
  --store-mode mmap \
  --no-jump-neighbor \
  --routeqa-mini-target-rows "$TARGET_ROWS" \
  --emit-raw-predictions \
  --emit-evaluator-output \
  --emit-routeqa-rows \
  --emit-resource-rows \
  --emit-evidence-packet \
  --emit-promotion-rows \
  --emit-prediction-lineage \
  --emit-generator-hint-nlg \
  --emit-shortcut-negative-suite \
  --emit-baseline-comparison \
  --emit-resource-envelope \
  --emit-ruler-synthetic-smoke >/dev/null

cp "$RUN_DIR/run_summary.csv" "$SUMMARY_CSV"

python3 - "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))
summary = rows[0] if rows else {}

def as_int(field):
    try:
        return int(float(summary.get(field, "0") or 0))
    except ValueError:
        return 0

def as_float(field):
    try:
        return float(summary.get(field, "0") or 0)
    except ValueError:
        return 0.0

def status(condition):
    return "pass" if condition else "blocked"

target = as_int("routeqa_mini_target_rows")
decision_rows = [
    (
        "v14-d-scale-contract-inherited",
        status(
            target == 100
            and as_int("dataset_rows") == target
            and as_int("routeqa_mini_ready") == 1
            and as_int("prediction_lineage_rows") == target
            and as_int("baseline_comparison_ready") == 1
            and as_int("resource_envelope_ready") == 1
        ),
        f"target={summary.get('routeqa_mini_target_rows', '')} rows={summary.get('dataset_rows', '')}",
    ),
    (
        "v14-e-ruler-compatible-niah-lite",
        status(
            as_int("ruler_compatible_ready") == 1
            and as_int("ruler_compatible_benchmark_ready") == 1
            and as_int("ruler_compatible_benchmark_rows") == 1
            and as_float("ruler_compatible_score") == 100.0
        ),
        f"ready={summary.get('ruler_compatible_ready', '')} benchmark={summary.get('ruler_compatible_benchmark_ready', '')}",
    ),
    (
        "v14-e-mmap-provenance",
        status(
            as_int("ruler_compatible_prediction_provenance_rows") == 1
            and as_int("ruler_compatible_extracted_prediction_rows") == 1
            and as_int("ruler_compatible_mmap_read_rows") == 1
            and as_int("ruler_compatible_mmap_prediction_match_rows") == 1
            and as_int("ruler_compatible_mmap_verification_ready") == 1
        ),
        f"provenance={summary.get('ruler_compatible_prediction_provenance_rows', '')} mmap={summary.get('ruler_compatible_mmap_verification_ready', '')}",
    ),
    (
        "v14-e-runner-owned-external-smoke",
        status(
            as_int("runner_owned_external_benchmark_result_ready") == 1
            and as_int("external_benchmark_rows") == 1
            and as_int("external_benchmark_ready_rows") == 1
            and as_int("external_benchmark_execution_chain_ready") == 1
        ),
        f"external_rows={summary.get('external_benchmark_rows', '')} runner_owned={summary.get('runner_owned_external_benchmark_result_ready', '')}",
    ),
    (
        "v14-e-no-route-jump",
        status(as_float("routing_trigger_rate") == 0.0 and as_float("active_jump_rate") == 0.0),
        f"route={summary.get('routing_trigger_rate', '')} jump={summary.get('active_jump_rate', '')}",
    ),
    ("candidate-external-benchmark-result", status(as_int("candidate_external_benchmark_result_ready") == 1), f"candidate={summary.get('candidate_external_benchmark_result_ready', '')}"),
    ("real-external-benchmark", status(as_int("real_external_benchmark_verified") == 1), f"real={summary.get('real_external_benchmark_verified', '')}"),
    ("real-release-package", status(as_int("real_release_package_ready") == 1), f"release={summary.get('real_release_package_ready', '')}"),
]

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v14e_ruler_niah_lite_run_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
