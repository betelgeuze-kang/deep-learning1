#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

mkdir -p "$RESULTS_DIR"

PREFIX="v14b_lite_prediction_lineage"
SOURCE_PREFIX="v13_external_benchmark_official_source_acquisition_gate_smoke"
SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate_smoke"
RUNTIME_PREFIX="${V14_RUNTIME_FETCH_PROVENANCE_PREFIX:-v13_real_evidence_runtime_fetch_provenance_gate_smoke}"
RUN_ID="${V14B_LITE_RUN_ID:-lite_001}"
RUN_DIR="${V14B_LITE_RUN_DIR:-$RESULTS_DIR/${PREFIX}_runs/$RUN_ID}"
TARGET_ROWS="${V14B_ROUTEQA_MINI_TARGET_ROWS:-50}"
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
  --emit-resource-envelope >/dev/null

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

def status(condition):
    return "pass" if condition else "blocked"

decision_rows = [
    ("stage-8-l-prediction-lineage", status(as_int("prediction_lineage_ready") == 1 and as_int("no_extractor_prediction_ready") == 1), f"lineage={summary.get('prediction_lineage_ready', '')} no_extractor={summary.get('no_extractor_prediction_ready', '')}"),
    ("stage-8-l-route-memory-prediction", status(as_int("promoted_prediction_rows") == as_int("promoted_route_memory_prediction_rows") and as_int("route_memory_prediction_rows_ready") == 1), f"promoted={summary.get('promoted_prediction_rows', '')} route_memory={summary.get('promoted_route_memory_prediction_rows', '')}"),
    ("stage-8-5-l-lightweight-benchmark", status(as_int("routeqa_mini_ready") == 1 and 50 <= as_int("dataset_rows") <= 200), f"rows={summary.get('dataset_rows', '')} target={summary.get('routeqa_mini_target_rows', '')}"),
    ("stage-9-l-generator-hint-nlg", status(as_int("generator_hint_nlg_ready") == 1 and as_int("proposal_hint_nlg_used_rows") == as_int("dataset_rows")), f"generator={summary.get('generator_hint_nlg_ready', '')} hint_rows={summary.get('proposal_hint_nlg_used_rows', '')}"),
    ("stage-8-2-l-shortcut-negative-suite", status(as_int("shortcut_negative_suite_ready") == 1 and as_int("hash_clean_wrong_span_block") == 1 and as_int("corrupted_route_index_block") == 1 and as_int("corrupted_chunk_offsets_block") == 1), f"negative={summary.get('shortcut_negative_suite_ready', '')} rows={summary.get('negative_case_rows', '')}"),
    ("stage-9-5-l-resource-envelope", status(as_int("resource_envelope_ready") == 1 and as_int("cpu_canonical") == 1 and as_int("hip_optional_parity") == 1), f"resource={summary.get('resource_envelope_ready', '')} cpu={summary.get('cpu_canonical', '')} hip={summary.get('hip_optional_parity', '')}"),
    ("stage-10-lite-evidence-bound-runtime", status(as_int("run_layout_ready") == 1 and as_int("objective_requirements_ready") == 1 and as_int("execution_chain_manifest_ready") == 1 and as_int("requested_outputs_ready") == 1), f"layout={summary.get('run_layout_ready', '')} objective={summary.get('objective_requirements_ready', '')} chain={summary.get('execution_chain_manifest_ready', '')}"),
    ("candidate-external-benchmark-result", status(as_int("candidate_external_benchmark_result_ready") == 1), f"candidate={summary.get('candidate_external_benchmark_result_ready', '')}"),
    ("real-release-package", status(as_int("real_release_package_ready") == 1), f"release={summary.get('real_release_package_ready', '')}"),
]

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v14b_lite_run_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
