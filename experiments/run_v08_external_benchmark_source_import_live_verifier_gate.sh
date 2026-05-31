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

PREFIX="v08_external_benchmark_source_import_live_verifier_gate"
VERIFIER_PREFIX="v08_external_benchmark_source_import_verifier_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v08_external_benchmark_source_import_live_verifier_gate_smoke"
  VERIFIER_PREFIX="v08_external_benchmark_source_import_verifier_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v08_external_benchmark_source_import_verifier_gate.sh" "${RUN_ARGS[@]}" >/dev/null

VERIFIER_SUMMARY_CSV="$RESULTS_DIR/${VERIFIER_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

VERIFIER_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_families source_import_source source_import_action source_import_contract_ready upstream_source_import_verified source_import_verifier_source expected_verifier_rows source_import_verifier_rows live_network_verifier_rows offline_replay_rows declared_real_verifier_rows non_fixture_declared_rows source_import_verifier_ready source_import_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing v08-o verifier summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["benchmark_families"] + 0,
        $idx["source_import_source"],
        $idx["source_import_action"],
        $idx["source_import_contract_ready"] + 0,
        $idx["upstream_source_import_verified"] + 0,
        $idx["source_import_verifier_source"],
        $idx["expected_verifier_rows"] + 0,
        $idx["source_import_verifier_rows"] + 0,
        $idx["live_network_verifier_rows"] + 0,
        $idx["offline_replay_rows"] + 0,
        $idx["declared_real_verifier_rows"] + 0,
        $idx["non_fixture_declared_rows"] + 0,
        $idx["source_import_verifier_ready"] + 0,
        $idx["source_import_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one v08-o verifier summary row", 3)
    }
  ' "$VERIFIER_SUMMARY_CSV"
)"

IFS=, read -r benchmark_families source_import_source source_import_action source_import_contract_ready upstream_source_import_verified source_import_verifier_source expected_verifier_rows source_import_verifier_rows live_network_verifier_rows offline_replay_rows declared_real_verifier_rows non_fixture_declared_rows source_import_verifier_ready upstream_source_import_verified_after_verifier verifier_action routing_trigger_rate active_jump_rate <<<"$VERIFIER_VALUES"

source_import_live_verifier_ready=0
if [[ "$source_import_verifier_ready" == "1" &&
      "$expected_verifier_rows" -gt 0 &&
      "$source_import_verifier_rows" -eq "$expected_verifier_rows" &&
      "$live_network_verifier_rows" -eq "$expected_verifier_rows" &&
      "$offline_replay_rows" -eq 0 &&
      "$declared_real_verifier_rows" -eq "$expected_verifier_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_verifier_rows" &&
      "$routing_trigger_rate" == "0.000000" &&
      "$active_jump_rate" == "0.000000" ]]; then
  source_import_live_verifier_ready=1
fi

source_import_verified=0
real_external_benchmark_verified=0
action="$verifier_action"
if [[ "$source_import_verifier_ready" == "1" && "$source_import_live_verifier_ready" == "0" ]]; then
  action="external-benchmark-source-import-live-verifier-missing"
elif [[ "$source_import_live_verifier_ready" == "1" ]]; then
  action="external-benchmark-source-import-independent-live-review-missing"
fi

{
  echo "benchmark_scope,benchmark_families,source_import_source,source_import_action,source_import_contract_ready,upstream_source_import_verified,source_import_verifier_source,expected_verifier_rows,source_import_verifier_rows,live_network_verifier_rows,offline_replay_rows,declared_real_verifier_rows,non_fixture_declared_rows,source_import_verifier_ready,source_import_live_verifier_ready,source_import_verified,real_external_benchmark_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-v08o,%d,%s,%s,%d,%d,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$benchmark_families" \
    "$source_import_source" \
    "$source_import_action" \
    "$source_import_contract_ready" \
    "$upstream_source_import_verified" \
    "$source_import_verifier_source" \
    "$expected_verifier_rows" \
    "$source_import_verifier_rows" \
    "$live_network_verifier_rows" \
    "$offline_replay_rows" \
    "$declared_real_verifier_rows" \
    "$non_fixture_declared_rows" \
    "$source_import_verifier_ready" \
    "$source_import_live_verifier_ready" \
    "$source_import_verified" \
    "$real_external_benchmark_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "source-import-verifier-contract,%s,ready=%d source=%s verifier_action=%s\n" \
    "$([[ "$source_import_verifier_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verifier_ready" \
    "$source_import_verifier_source" \
    "$verifier_action"
  printf "live-network-verifier-evidence,%s,live=%d/%d replay=%d declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$source_import_live_verifier_ready" == "1" ]] && echo pass || echo blocked)" \
    "$live_network_verifier_rows" \
    "$expected_verifier_rows" \
    "$offline_replay_rows" \
    "$declared_real_verifier_rows" \
    "$expected_verifier_rows" \
    "$non_fixture_declared_rows" \
    "$expected_verifier_rows"
  printf "source-import-live-verifier,%s,ready=%d action=%s\n" \
    "$([[ "$source_import_live_verifier_ready" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_live_verifier_ready" \
    "$action"
  printf "source-import-verification,%s,verified=%d action=%s\n" \
    "$([[ "$source_import_verified" == "1" ]] && echo pass || echo blocked)" \
    "$source_import_verified" \
    "$action"
  printf "real-external-benchmark,%s,verified=%d action=%s\n" \
    "$([[ "$real_external_benchmark_verified" == "1" ]] && echo ready || echo blocked)" \
    "$real_external_benchmark_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
