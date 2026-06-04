#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_evidence_promotion_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_evidence_promotion_gate_smoke_decision.csv"
PACKET_DIR="$RESULTS_DIR/v13_real_evidence_promotion_gate_smoke_packet/run_001"
RUN_DIR="$RESULTS_DIR/v13_real_run_binder_manifest_smoke_runs/run_001"
BAD_HASH_RUN_DIR="$RESULTS_DIR/v13_real_evidence_promotion_bad_hash_run"

expect_summary_value() {
  local summary_csv="$1"
  local field="$2"
  local expected="$3"
  local message="$4"

  awk -F, -v field="$field" -v expected="$expected" -v message="$message" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!(field in idx)) die("missing v13-g summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-g summary row", 4)
    }
  ' "$summary_csv"
}

expect_decision_status() {
  local decision_csv="$1"
  local gate="$2"
  local expected="$3"

  awk -F, -v gate="$gate" -v expected="$expected" '
    function die(text, code) {
      print text > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      next
    }
    $idx["gate"] == gate {
      found = 1
      if ($idx["status"] != expected) die("v13-g decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v13-g decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

expect_file() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "missing expected v13-g file: $path" >&2
    exit 10
  fi
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_real_evidence_promotion_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "run_source" "generated-diagnostic-run" "v13-g source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "1" "v13-g run hash"
expect_summary_value "$SUMMARY_CSV" "evidence_packet_hash_ready" "1" "v13-g evidence packet hash"
expect_summary_value "$SUMMARY_CSV" "transcript_packet_hash_ready" "1" "v13-g transcript packet hash"
expect_summary_value "$SUMMARY_CSV" "routeqa_packet_hash_ready" "1" "v13-g routeqa packet hash"
expect_summary_value "$SUMMARY_CSV" "resource_packet_hash_ready" "1" "v13-g resource packet hash"
expect_summary_value "$SUMMARY_CSV" "promotion_packet_hash_ready" "1" "v13-g packet hash"
expect_summary_value "$SUMMARY_CSV" "evidence_packet_abi_ready" "1" "v13-g evidence packet"
expect_summary_value "$SUMMARY_CSV" "v13_real_nlg_transcript_ready" "1" "v13-g transcript"
expect_summary_value "$SUMMARY_CSV" "public_codebase_routeqa_ready" "1" "v13-g routeqa"
expect_summary_value "$SUMMARY_CSV" "resource_envelope_ready" "1" "v13-g resource"
expect_summary_value "$SUMMARY_CSV" "diagnostic_binding_ready" "1" "v13-g diagnostic binding"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v13-g external real"
expect_summary_value "$SUMMARY_CSV" "independent_external_routeqa_verified" "0" "v13-g independent routeqa"
expect_summary_value "$SUMMARY_CSV" "source_verified_learned_chunk_scorer_eval_ready" "0" "v13-g learned eval"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "v13-g teacher source"
expect_summary_value "$SUMMARY_CSV" "metric_improvement_ready" "0" "v13-g metric improvement"
expect_summary_value "$SUMMARY_CSV" "learned_chunk_ranking_real_ready" "0" "v13-g learned real"
expect_summary_value "$SUMMARY_CSV" "real_pc_routelm_nlg_verified" "0" "v13-g real NLG"
expect_summary_value "$SUMMARY_CSV" "real_nlg_transcript_ready" "0" "v13-g real transcript"
expect_summary_value "$SUMMARY_CSV" "real_workload_speed_evidence_ready" "0" "v13-g real speed"
expect_summary_value "$SUMMARY_CSV" "gpu_speedup_claim" "deferred" "v13-g speed claim"
expect_summary_value "$SUMMARY_CSV" "actual_nonfixture_run_verified" "0" "v13-g nonfixture"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_blocker" "1" "v13-g external blocker"
expect_summary_value "$SUMMARY_CSV" "learned_chunk_ranking_blocker" "1" "v13-g learned blocker"
expect_summary_value "$SUMMARY_CSV" "gpu_speedup_blocker" "1" "v13-g GPU blocker"
expect_summary_value "$SUMMARY_CSV" "real_nlg_blocker" "1" "v13-g NLG blocker"
expect_summary_value "$SUMMARY_CSV" "nonfixture_run_blocker" "1" "v13-g nonfixture blocker"
expect_summary_value "$SUMMARY_CSV" "real_evidence_promotion_ready" "0" "v13-g promotion"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-g release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-promotion-external-benchmark-missing" "v13-g action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-g routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-g jump"

expect_file "$PACKET_DIR/promotion_rows.csv"
expect_file "$PACKET_DIR/promotion_manifest.json"
expect_file "$PACKET_DIR/sha256sums.txt"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    blockers += $idx["blocker"] + 0
    if ($idx["diagnostic_binding_ready"] != "1") die("v13-g weakness row should inherit diagnostic binding", 20)
    if ($idx["real_evidence_verified"] != "0") die("v13-g default weakness should not be real verified", 21)
  }
  END {
    if (rows != 4) die("expected four v13-g weakness rows", 22)
    if (blockers != 4) die("expected four v13-g real-evidence blockers", 23)
  }
' "$PACKET_DIR/promotion_rows.csv"

expect_decision_status "$DECISION_CSV" "diagnostic-binding" "pass"
expect_decision_status "$DECISION_CSV" "external-benchmark" "blocked"
expect_decision_status "$DECISION_CSV" "learned-chunk-ranking" "blocked"
expect_decision_status "$DECISION_CSV" "real-nlg" "blocked"
expect_decision_status "$DECISION_CSV" "gpu-speedup" "blocked"
expect_decision_status "$DECISION_CSV" "nonfixture-run" "blocked"
expect_decision_status "$DECISION_CSV" "promotion-packet-hash" "pass"
expect_decision_status "$DECISION_CSV" "v13-real-evidence-promotion" "blocked"

rm -rf "$BAD_HASH_RUN_DIR"
cp -a "$RUN_DIR" "$BAD_HASH_RUN_DIR"
printf '\n' >>"$BAD_HASH_RUN_DIR/evidence/h10s.csv"
V13_REAL_EVIDENCE_PROMOTION_RUN_DIR="$BAD_HASH_RUN_DIR" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_promotion_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "run_source" "provided-run-dir" "v13-g bad-hash source"
expect_summary_value "$SUMMARY_CSV" "run_hash_manifest_ready" "0" "v13-g bad run hash"
expect_summary_value "$SUMMARY_CSV" "diagnostic_binding_ready" "0" "v13-g bad diagnostic"
expect_summary_value "$SUMMARY_CSV" "real_evidence_promotion_ready" "0" "v13-g bad promotion"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-promotion-run-hash-mismatch" "v13-g bad hash action"

"$ROOT_DIR/experiments/run_v13_real_evidence_promotion_gate.sh" --smoke >/dev/null

echo "v13 real evidence promotion gate smoke passed"
