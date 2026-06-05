#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

mkdir -p "$RESULTS_DIR"

PREFIX="v14d_routeqa_mini_scale"
SOURCE_PREFIX="v13_external_benchmark_official_source_acquisition_gate_smoke"
SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate_smoke"
RUNTIME_PREFIX="${V14_RUNTIME_FETCH_PROVENANCE_PREFIX:-v13_real_evidence_runtime_fetch_provenance_gate_smoke}"
TARGET_ROWS_LIST="${V14D_ROUTEQA_MINI_TARGET_ROWS_LIST:-100 150}"
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

summary_written=0
: > "$SUMMARY_CSV"

for target_rows in $TARGET_ROWS_LIST; do
  case "$target_rows" in
    ''|*[!0-9]*)
      echo "invalid v14-d target row count: $target_rows" >&2
      exit 2
      ;;
  esac

  run_id="scale_${target_rows}"
  run_dir="$RESULTS_DIR/${PREFIX}_runs/$run_id"

  "$ROOT_DIR/tools/routelm_benchmark_run" \
    --source-acquisition "$SOURCE_ACQUISITION_ROWS" \
    --source-seed-live-fetch "$SOURCE_SEED_LIVE_FETCH_ROWS" \
    --runtime-fetch-provenance "$RUNTIME_FETCH_PROVENANCE_ROWS" \
    --source-snapshot-mode manifest \
    --task public-codebase-routeqa-v1 \
    --repo "$ROOT_DIR" \
    --out "$run_dir" \
    --backend cpu \
    --store-mode mmap \
    --no-jump-neighbor \
    --routeqa-mini-target-rows "$target_rows" \
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
    --emit-resource-envelope >/dev/null

  if [[ "$summary_written" -eq 0 ]]; then
    cat "$run_dir/run_summary.csv" > "$SUMMARY_CSV"
    summary_written=1
  else
    tail -n +2 "$run_dir/run_summary.csv" >> "$SUMMARY_CSV"
  fi
done

python3 - "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import sys
from pathlib import Path

summary_csv = Path(sys.argv[1])
decision_csv = Path(sys.argv[2])
with summary_csv.open(newline="", encoding="utf-8") as handle:
    rows = list(csv.DictReader(handle))

def as_int(row, field):
    try:
        return int(float(row.get(field, "0") or 0))
    except ValueError:
        return 0

def as_float(row, field):
    try:
        return float(row.get(field, "0") or 0)
    except ValueError:
        return 0.0

def status(condition):
    return "pass" if condition else "blocked"

decision_rows = []
for row in rows:
    target = as_int(row, "routeqa_mini_target_rows")
    label = f"v14-d-scale-{target}"
    decision_rows.extend(
        [
            (
                f"{label}-routeqa-mini",
                status(as_int(row, "dataset_rows") == target and target in {100, 150} and as_int(row, "routeqa_mini_ready") == 1),
                f"rows={row.get('dataset_rows', '')} target={row.get('routeqa_mini_target_rows', '')} ready={row.get('routeqa_mini_ready', '')}",
            ),
            (
                f"{label}-lineage-contracts",
                status(
                    as_int(row, "prediction_lineage_ready") == 1
                    and as_int(row, "prediction_lineage_rows") == target
                    and as_int(row, "no_extractor_prediction_ready") == 1
                    and as_int(row, "promoted_prediction_rows") == target
                    and as_int(row, "promoted_route_memory_prediction_rows") == target
                ),
                f"lineage={row.get('prediction_lineage_ready', '')} lineage_rows={row.get('prediction_lineage_rows', '')} promoted={row.get('promoted_prediction_rows', '')}",
            ),
            (
                f"{label}-negative-nlg-resource",
                status(
                    as_int(row, "shortcut_negative_suite_ready") == 1
                    and as_int(row, "generator_hint_nlg_ready") == 1
                    and as_int(row, "generator_hint_nlg_rows") == target
                    and as_int(row, "resource_envelope_ready") == 1
                    and as_int(row, "run_dir_under_5gb") == 1
                    and as_int(row, "cpu_canonical") == 1
                    and as_int(row, "hip_optional_parity") == 1
                ),
                f"negative={row.get('shortcut_negative_suite_ready', '')} nlg_rows={row.get('generator_hint_nlg_rows', '')} resource={row.get('resource_envelope_ready', '')}",
            ),
            (
                f"{label}-baseline-comparison",
                status(
                    as_int(row, "baseline_comparison_ready") == 1
                    and as_int(row, "baseline_rows") == 6
                    and as_int(row, "baseline_negative_case_rows") == 66
                    and as_int(row, "route_memory_safety_dominates_baselines") == 1
                    and as_int(row, "input_extractor_baseline_only") == 1
                    and as_int(row, "baseline_promotion_guard_ready") == 1
                ),
                f"baseline={row.get('baseline_comparison_ready', '')} rows={row.get('baseline_rows', '')} negative={row.get('baseline_negative_case_rows', '')}",
            ),
            (
                f"{label}-runtime-binding",
                status(
                    as_int(row, "run_layout_ready") == 1
                    and as_int(row, "objective_requirements_ready") == 1
                    and as_int(row, "execution_chain_manifest_ready") == 1
                    and as_int(row, "requested_outputs_ready") == 1
                    and as_float(row, "routing_trigger_rate") == 0.0
                    and as_float(row, "active_jump_rate") == 0.0
                ),
                f"layout={row.get('run_layout_ready', '')} objective={row.get('objective_requirements_ready', '')} chain={row.get('execution_chain_manifest_ready', '')}",
            ),
        ]
    )

all_targets_ready = {as_int(row, "routeqa_mini_target_rows") for row in rows} == {100, 150}
all_candidate_blocked = rows and all(as_int(row, "candidate_external_benchmark_result_ready") == 0 for row in rows)
all_release_blocked = rows and all(as_int(row, "real_release_package_ready") == 0 for row in rows)
decision_rows.extend(
    [
        ("v14-d-routeqa-mini-scale-set", status(len(rows) == 2 and all_targets_ready), f"rows={len(rows)} targets={sorted(as_int(row, 'routeqa_mini_target_rows') for row in rows)}"),
        ("candidate-external-benchmark-result", status(not all_candidate_blocked), "candidate remains blocked across v14-d scale runs"),
        ("real-release-package", status(not all_release_blocked), "release remains blocked across v14-d scale runs"),
    ]
)

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "v14d_scale_runs_dir: $RESULTS_DIR/${PREFIX}_runs"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
