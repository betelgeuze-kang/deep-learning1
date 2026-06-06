#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"

PREFIX="v14_real_query_result_evaluator_runner"
SOURCE_PREFIX="v13_external_benchmark_official_source_acquisition_gate"
SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate"
RUNTIME_PREFIX="${V14_RUNTIME_FETCH_PROVENANCE_PREFIX:-v13_real_evidence_runtime_fetch_provenance_gate_smoke}"
RUN_ID="${V14_REAL_QUERY_RESULT_RUN_ID:-live_001}"
RUN_ARGS=()
RUNTIME_RUN_ARGS=(--smoke)
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v14_real_query_result_evaluator_runner_smoke"
  SOURCE_PREFIX="v13_external_benchmark_official_source_acquisition_gate_smoke"
  SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v14_real_query_result_evaluator_runner_full"
  SOURCE_PREFIX="v13_external_benchmark_official_source_acquisition_gate_full"
  SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate_full"
  RUN_ARGS=(--full)
fi

RUN_DIR="${V14_REAL_QUERY_RESULT_RUN_DIR:-$RESULTS_DIR/${PREFIX}_runs/$RUN_ID}"
SOURCE_PACKET_DIR="$RESULTS_DIR/${SOURCE_PREFIX}_packet/run_001"
SOURCE_LIVE_PACKET_DIR="$RESULTS_DIR/${SOURCE_LIVE_PREFIX}_packet/run_001"
RUNTIME_PACKET_DIR="$RESULTS_DIR/${RUNTIME_PREFIX}_packet/run_001"
SOURCE_ACQUISITION_ROWS="${V14_SOURCE_ACQUISITION_ROWS:-$SOURCE_PACKET_DIR/official_source_acquisition_rows.csv}"
SOURCE_SEED_LIVE_FETCH_ROWS="${V14_SOURCE_SEED_LIVE_FETCH_ROWS:-$SOURCE_LIVE_PACKET_DIR/source_seed_live_fetch_rows.csv}"
RUNTIME_FETCH_PROVENANCE_ROWS="${V14_RUNTIME_FETCH_PROVENANCE_ROWS:-$RUNTIME_PACKET_DIR/runtime_fetch_provenance_rows.csv}"
SOURCE_SNAPSHOT_MODE="${V14_SOURCE_SNAPSHOT_MODE:-manifest}"
QUERY_FILE="${V14_QUERIES:-}"
REPO_FROM_SOURCE_SNAPSHOT="${V14_REPO_FROM_SOURCE_SNAPSHOT:-}"
RULER_SYNTHETIC_SMOKE="${V14_RULER_SYNTHETIC_SMOKE:-0}"
LONGBENCH_V2_SMOKE="${V14_LONGBENCH_V2_SMOKE:-0}"
LONGBENCH_V2_OFFICIAL_SAMPLE="${V14_LONGBENCH_V2_OFFICIAL_SAMPLE:-0}"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
OPTIONAL_RUNNER_ARGS=()
if [[ -n "$QUERY_FILE" ]]; then
  OPTIONAL_RUNNER_ARGS+=(--queries "$QUERY_FILE")
fi
if [[ -n "$REPO_FROM_SOURCE_SNAPSHOT" ]]; then
  OPTIONAL_RUNNER_ARGS+=(--repo-from-source-snapshot "$REPO_FROM_SOURCE_SNAPSHOT")
fi
if [[ "$RULER_SYNTHETIC_SMOKE" == "1" ]]; then
  OPTIONAL_RUNNER_ARGS+=(--emit-ruler-synthetic-smoke)
fi
if [[ "$LONGBENCH_V2_SMOKE" == "1" ]]; then
  OPTIONAL_RUNNER_ARGS+=(--emit-longbench-v2-smoke)
fi
if [[ "$LONGBENCH_V2_OFFICIAL_SAMPLE" == "1" ]]; then
  OPTIONAL_RUNNER_ARGS+=(--emit-longbench-v2-official-sample)
fi

"$ROOT_DIR/experiments/run_v13_real_evidence_runtime_fetch_provenance_gate.sh" "${RUNTIME_RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v13_external_benchmark_official_source_acquisition_gate.sh" "${RUN_ARGS[@]}" >/dev/null

"$ROOT_DIR/tools/routelm_benchmark_run" \
  --source-acquisition "$SOURCE_ACQUISITION_ROWS" \
  --source-seed-live-fetch "$SOURCE_SEED_LIVE_FETCH_ROWS" \
  --runtime-fetch-provenance "$RUNTIME_FETCH_PROVENANCE_ROWS" \
  --source-snapshot-mode "$SOURCE_SNAPSHOT_MODE" \
  --task public-codebase-routeqa-v1 \
  --repo "$ROOT_DIR" \
  --out "$RUN_DIR" \
  --backend cpu \
  --store-mode mmap \
  --no-jump-neighbor \
  "${OPTIONAL_RUNNER_ARGS[@]}" \
  --emit-raw-predictions \
  --emit-evaluator-output \
  --emit-routeqa-rows \
  --emit-resource-rows \
  --emit-evidence-packet \
  --emit-promotion-rows >/dev/null

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
    ("source-chain", status(as_int("source_acquisition_copied") == 1 and as_int("source_seed_live_fetch_copied") == 1 and as_int("runtime_fetch_provenance_copied") == 1), f"acquisition={summary.get('source_acquisition_copied', '')} seed_live={summary.get('source_seed_live_fetch_copied', '')} runtime={summary.get('runtime_fetch_provenance_copied', '')}"),
    ("source-snapshot", status(as_int("source_snapshot_rows") >= 2), f"mode={summary.get('source_snapshot_mode', '')} rows={summary.get('source_snapshot_rows', '')} ready={summary.get('source_snapshot_ready_rows', '')} live={summary.get('runner_owned_live_source_snapshot_rows', '')}"),
    ("dataset-materialization", status(as_int("dataset_rows") == 7), f"rows={summary.get('dataset_rows', '')}"),
    ("store-mmap-read", status(as_int("store_route_rows") == 7 and as_int("route_memory_store_ready") == 1 and as_int("mmap_read_ready_rows") >= 5), f"routes={summary.get('store_route_rows', '')} route_memory={summary.get('route_memory_store_ready', '')} mmap={summary.get('mmap_read_ready_rows', '')}"),
    ("raw-predictions", status(as_int("raw_prediction_rows") == 7), f"rows={summary.get('raw_prediction_rows', '')}"),
    ("evaluator-output", status(as_int("evaluator_output_rows") == 7 and as_int("routeqa_bound_rows") == 7), f"eval={summary.get('evaluator_output_rows', '')} bound={summary.get('routeqa_bound_rows', '')}"),
    ("metrics", status(as_int("metrics_ready") == 1), f"ready={summary.get('metrics_ready', '')}"),
    ("benchmark-rows", status(as_int("benchmark_rows") == 7 and as_int("benchmark_bound_rows") == 7), f"rows={summary.get('benchmark_rows', '')} bound={summary.get('benchmark_bound_rows', '')}"),
    ("runner-owned-external-benchmark-result", status(as_int("runner_owned_external_benchmark_result_ready") == 1), f"rows={summary.get('external_benchmark_rows', '')} ready={summary.get('external_benchmark_ready_rows', '')} runner_owned={summary.get('runner_owned_external_benchmark_result_ready', '')}"),
    ("evidence-packet", status(as_int("evidence_packet_rows") >= 15), f"rows={summary.get('evidence_packet_rows', '')}"),
    ("promotion-rows", status(as_int("promotion_rows") == 4), f"rows={summary.get('promotion_rows', '')}"),
    ("runner-owned-query-result-evaluator", status(as_int("runner_owned_query_result_evaluator_ready") == 1), f"ready={summary.get('runner_owned_query_result_evaluator_ready', '')}"),
    ("candidate-external-benchmark-result", status(as_int("candidate_external_benchmark_result_ready") == 1), f"candidate={summary.get('candidate_external_benchmark_result_ready', '')}"),
    ("real-release-package", status(as_int("real_release_package_ready") == 1), f"release={summary.get('real_release_package_ready', '')}"),
]

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v14_runner_run_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
