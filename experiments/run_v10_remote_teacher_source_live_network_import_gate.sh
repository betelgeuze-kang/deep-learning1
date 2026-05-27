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

PREFIX="v10_remote_teacher_source_live_network_import_gate"
RUNTIME_PREFIX="v10_remote_teacher_source_runtime_fetcher"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_remote_teacher_source_live_network_import_gate_smoke"
  RUNTIME_PREFIX="v10_remote_teacher_source_runtime_fetcher_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_runtime_fetcher.sh" "${RUN_ARGS[@]}" >/dev/null

RUNTIME_SUMMARY_CSV="$RESULTS_DIR/${RUNTIME_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

RUNTIME_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("runtime_fetch_source h10o_action expected_runtime_artifact_rows runtime_fetch_rows network_fetch_rows offline_replay_rows declared_real_rows non_fixture_declared_rows runner_owned_runtime_fetcher_ready live_network_fetch_ready real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-q runtime summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["runtime_fetch_source"],
        $idx["h10o_action"],
        $idx["expected_runtime_artifact_rows"] + 0,
        $idx["runtime_fetch_rows"] + 0,
        $idx["network_fetch_rows"] + 0,
        $idx["offline_replay_rows"] + 0,
        $idx["declared_real_rows"] + 0,
        $idx["non_fixture_declared_rows"] + 0,
        $idx["runner_owned_runtime_fetcher_ready"] + 0,
        $idx["live_network_fetch_ready"] + 0,
        $idx["real_teacher_source_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one h10-q runtime summary row", 3)
    }
  ' "$RUNTIME_SUMMARY_CSV"
)"

IFS=, read -r runtime_fetch_source h10p_h10o_action expected_artifact_rows runtime_fetch_rows network_fetch_rows offline_replay_rows declared_real_rows non_fixture_declared_rows runner_owned_runtime_fetcher_ready live_network_fetch_ready h10p_real_verified h10p_action routing_trigger_rate active_jump_rate <<<"$RUNTIME_VALUES"

remote_teacher_source_live_network_import_ready=0
if [[ "$runner_owned_runtime_fetcher_ready" == "1" &&
      "$live_network_fetch_ready" == "1" &&
      "$expected_artifact_rows" -gt 0 &&
      "$runtime_fetch_rows" -eq "$expected_artifact_rows" &&
      "$network_fetch_rows" -eq "$expected_artifact_rows" &&
      "$offline_replay_rows" -eq 0 &&
      "$declared_real_rows" -eq "$expected_artifact_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_artifact_rows" &&
      "$routing_trigger_rate" == "0.000000" &&
      "$active_jump_rate" == "0.000000" ]]; then
  remote_teacher_source_live_network_import_ready=1
fi

real_teacher_source_verified=0
action="$h10p_action"
if [[ "$runner_owned_runtime_fetcher_ready" == "0" ]]; then
  action="$h10p_action"
elif [[ "$live_network_fetch_ready" == "0" ]]; then
  action="remote-teacher-source-live-network-fetch-missing"
elif [[ "$remote_teacher_source_live_network_import_ready" == "1" ]]; then
  action="remote-teacher-source-real-source-import-missing"
fi

{
  echo "teacher_source_live_network_scope,runtime_fetch_source,h10p_h10o_action,h10p_action,expected_runtime_artifact_rows,runtime_fetch_rows,network_fetch_rows,offline_replay_rows,declared_real_rows,non_fixture_declared_rows,runner_owned_runtime_fetcher_ready,live_network_fetch_ready,remote_teacher_source_live_network_import_ready,real_teacher_source_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-h10q,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$runtime_fetch_source" \
    "$h10p_h10o_action" \
    "$h10p_action" \
    "$expected_artifact_rows" \
    "$runtime_fetch_rows" \
    "$network_fetch_rows" \
    "$offline_replay_rows" \
    "$declared_real_rows" \
    "$non_fixture_declared_rows" \
    "$runner_owned_runtime_fetcher_ready" \
    "$live_network_fetch_ready" \
    "$remote_teacher_source_live_network_import_ready" \
    "$real_teacher_source_verified" \
    "$action" \
    "$routing_trigger_rate" \
    "$active_jump_rate"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "runner-owned-runtime-fetcher,%s,ready=%d h10p_action=%s\n" \
    "$([[ "$runner_owned_runtime_fetcher_ready" == "1" ]] && echo pass || echo blocked)" \
    "$runner_owned_runtime_fetcher_ready" \
    "$h10p_action"
  printf "live-network-fetch,%s,live=%d network=%d/%d replay=%d declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$live_network_fetch_ready" == "1" ]] && echo pass || echo blocked)" \
    "$live_network_fetch_ready" \
    "$network_fetch_rows" \
    "$expected_artifact_rows" \
    "$offline_replay_rows" \
    "$declared_real_rows" \
    "$expected_artifact_rows" \
    "$non_fixture_declared_rows" \
    "$expected_artifact_rows"
  printf "live-network-import,%s,ready=%d source=%s\n" \
    "$([[ "$remote_teacher_source_live_network_import_ready" == "1" ]] && echo pass || echo blocked)" \
    "$remote_teacher_source_live_network_import_ready" \
    "$runtime_fetch_source"
  printf "real-teacher-source-verification,%s,real_verified=%d action=%s\n" \
    "$([[ "$real_teacher_source_verified" == "1" ]] && echo pass || echo blocked)" \
    "$real_teacher_source_verified" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
