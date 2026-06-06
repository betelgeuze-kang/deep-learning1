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

PREFIX="v08_external_benchmark_comparison_gate"
EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion"
PROMOTION_PREFIX="v07_route_memory_promotion_gate"
RESULT_AUTHORITY_PREFIX="v08_external_benchmark_result_authority_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_comparison_gate_smoke"
  EVIDENCE_PREFIX="v08_external_benchmark_evidence_ingestion_smoke"
  PROMOTION_PREFIX="v07_route_memory_promotion_gate_smoke"
  RESULT_AUTHORITY_PREFIX="v08_external_benchmark_result_authority_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

PROMOTION_SUMMARY_CSV="$RESULTS_DIR/${PROMOTION_PREFIX}_summary.csv"
EVIDENCE_SUMMARY_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_summary.csv"
RESULT_AUTHORITY_SUMMARY_CSV="$RESULTS_DIR/${RESULT_AUTHORITY_PREFIX}_summary.csv"
EVIDENCE_CSV="$RESULTS_DIR/${EVIDENCE_PREFIX}_evidence.csv"
if [[ ! -s "$PROMOTION_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v07_route_memory_promotion_gate.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ ! -s "$EVIDENCE_SUMMARY_CSV" ]]; then
  "$ROOT_DIR/experiments/run_v08_external_benchmark_evidence_ingestion.sh" "${RUN_ARGS[@]}" >/dev/null
fi
if [[ -n "${V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV:-}" ]]; then
  EVIDENCE_CSV="$V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV"
fi
"$ROOT_DIR/experiments/run_v08_external_benchmark_result_authority_gate.sh" "${RUN_ARGS[@]}" >/dev/null

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
COMPARISON_CSV="$RESULTS_DIR/${PREFIX}_comparison.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

awk -F, -v promotion_csv="$PROMOTION_SUMMARY_CSV" -v evidence_summary_csv="$EVIDENCE_SUMMARY_CSV" -v final_review_summary_csv="$RESULT_AUTHORITY_SUMMARY_CSV" -v evidence_csv="$EVIDENCE_CSV" -v summary_csv="$SUMMARY_CSV" -v comparison_csv="$COMPARISON_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  FILENAME == promotion_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) pidx[$i] = i
    required_count = split("default_promotion status routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in pidx)) die("missing v08 comparison promotion column: " required[i], 2)
    }
    next
  }
  FILENAME == promotion_csv {
    promotion_rows++
    default_promotion = $pidx["default_promotion"] + 0
    promotion_status = $pidx["status"]
    promotion_routing = $pidx["routing_trigger_rate"] + 0
    promotion_jump = $pidx["active_jump_rate"] + 0
    next
  }
  FILENAME == evidence_summary_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("benchmark_families benchmark_evidence_schema_ready external_benchmark_ready evidence_source routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) die("missing v08 comparison evidence summary column: " required[i], 3)
    }
    next
  }
  FILENAME == evidence_summary_csv {
    evidence_summary_rows++
    benchmark_families = $sidx["benchmark_families"] + 0
    benchmark_evidence_schema_ready = $sidx["benchmark_evidence_schema_ready"] + 0
    external_benchmark_ready = $sidx["external_benchmark_ready"] + 0
    evidence_source = $sidx["evidence_source"]
    evidence_summary_routing = $sidx["routing_trigger_rate"] + 0
    evidence_summary_jump = $sidx["active_jump_rate"] + 0
    next
  }
  FILENAME == final_review_summary_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) fidx[$i] = i
    required_count = split("final_review_verified real_external_benchmark_verified routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in fidx)) die("missing v08 comparison final review summary column: " required[i], 8)
    }
    next
  }
  FILENAME == final_review_summary_csv {
    final_review_rows++
    final_review_verified = $fidx["final_review_verified"] + 0
    real_external_benchmark_verified = $fidx["real_external_benchmark_verified"] + 0
    final_review_routing = $fidx["routing_trigger_rate"] + 0
    final_review_jump = $fidx["active_jump_rate"] + 0
    next
  }
  FILENAME == evidence_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) eidx[$i] = i
    required_count = split("benchmark_family baseline_metric route_memory_metric source_ready result_ready baseline_ready license_ready routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in eidx)) die("missing v08 comparison evidence column: " required[i], 4)
    }
    print "benchmark_family,baseline_metric,route_memory_metric,delta,verdict" > comparison_csv
    next
  }
  FILENAME == evidence_csv {
    evidence_rows++
    family = $eidx["benchmark_family"]
    baseline_raw = $eidx["baseline_metric"]
    route_raw = $eidx["route_memory_metric"]
    row_ready = (($eidx["source_ready"] + 0) == 1 &&
      ($eidx["result_ready"] + 0) == 1 &&
      ($eidx["baseline_ready"] + 0) == 1 &&
      ($eidx["license_ready"] + 0) == 1 &&
      baseline_raw != "pending" &&
      route_raw != "pending")
    if (row_ready) {
      comparable_rows++
      baseline = baseline_raw + 0
      route = route_raw + 0
      delta = route - baseline
      if (delta > 0.0000005) {
        verdict = "route-memory-win"
        wins++
      } else if (delta < -0.0000005) {
        verdict = "route-memory-loss"
        losses++
      } else {
        verdict = "tie"
        ties++
      }
      delta_sum += delta
      printf "%s,%.6f,%.6f,%.6f,%s\n", family, baseline, route, delta, verdict >> comparison_csv
    } else {
      printf "%s,NA,NA,NA,not-comparable\n", family >> comparison_csv
    }
    evidence_routing += $eidx["routing_trigger_rate"] + 0
    evidence_jump += $eidx["active_jump_rate"] + 0
    next
  }
  END {
    if (promotion_rows != 1) die("expected one v08 comparison promotion row", 5)
    if (evidence_summary_rows != 1) die("expected one v08 comparison evidence summary row", 6)
    if (evidence_rows != 4) die("expected four v08 comparison evidence rows", 7)
    if (final_review_rows != 1) die("expected one v08 comparison final review summary row", 9)

    comparison_schema_ready = benchmark_evidence_schema_ready
    comparison_input_ready = 0
    if (external_benchmark_ready == 1 && comparable_rows == benchmark_families && evidence_routing == 0.0 && evidence_jump == 0.0) {
      comparison_input_ready = 1
    }
    benchmark_comparison_ready = comparison_schema_ready && comparison_input_ready
    publishable_comparison_ready = 0
    if (benchmark_comparison_ready &&
        default_promotion == 1 &&
        promotion_status == "promotion-candidate" &&
        real_external_benchmark_verified == 1) {
      publishable_comparison_ready = 1
    }

    mean_delta = 0.0
    if (comparable_rows > 0) mean_delta = delta_sum / comparable_rows

    action = "external-benchmark-source-missing"
    if (!comparison_schema_ready) {
      action = "build-external-benchmark-comparison-schema"
    } else if (benchmark_comparison_ready && publishable_comparison_ready) {
      action = "publish-external-comparison"
    } else if (benchmark_comparison_ready && !publishable_comparison_ready) {
      action = "diagnostic-comparison-only"
    }

    print "benchmark_scope,benchmark_families,comparison_schema_ready,comparison_input_ready,benchmark_comparison_ready,publishable_comparison_ready,default_promotion,final_review_verified,real_external_benchmark_verified,evidence_source,comparable_rows,route_memory_wins,route_memory_losses,route_memory_ties,mean_delta,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "route-memory-v08e,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%d,%d,%.6f,%s,%.6f,%.6f\n",
      benchmark_families,
      comparison_schema_ready,
      comparison_input_ready,
      benchmark_comparison_ready,
      publishable_comparison_ready,
      default_promotion,
      final_review_verified,
      real_external_benchmark_verified,
      evidence_source,
      comparable_rows,
      wins,
      losses,
      ties,
      mean_delta,
      action,
      promotion_routing + evidence_summary_routing + evidence_routing + final_review_routing,
      promotion_jump + evidence_summary_jump + evidence_jump + final_review_jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "comparison-schema,%s,schema_ready=%d\n",
      comparison_schema_ready ? "pass" : "blocked",
      comparison_schema_ready >> decision_csv
    printf "comparison-input,%s,comparable_rows=%d\n",
      comparison_input_ready ? "pass" : "blocked",
      comparable_rows >> decision_csv
    printf "comparison-diagnostic,%s,ready=%d\n",
      benchmark_comparison_ready ? "pass" : "blocked",
      benchmark_comparison_ready >> decision_csv
    printf "comparison-publish,%s,default_promotion=%d\n",
      publishable_comparison_ready ? "pass" : "blocked",
      default_promotion >> decision_csv
    printf "final-review,%s,real_external_benchmark_verified=%d\n",
      real_external_benchmark_verified ? "pass" : "blocked",
      real_external_benchmark_verified >> decision_csv
    printf "external-comparison,%s,action=%s\n",
      publishable_comparison_ready ? "ready" : "deferred",
      action >> decision_csv
  }
' "$PROMOTION_SUMMARY_CSV" "$EVIDENCE_SUMMARY_CSV" "$RESULT_AUTHORITY_SUMMARY_CSV" "$EVIDENCE_CSV"

echo "summary: $SUMMARY_CSV"
echo "comparison: $COMPARISON_CSV"
echo "decision: $DECISION_CSV"
