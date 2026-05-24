#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

"$ROOT_DIR/experiments/run_v11_pc_routelm_prototype_readiness.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v11_pc_routelm_prototype_readiness_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v11_pc_routelm_prototype_readiness_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("prototype_scope prototype_contract_schema_ready prototype_rows small_generator_adapter_ready route_memory_residency_ready candidate_scoring_ready decoder_binding_ready nlg_smoke_ready component_evidence_ready diagnostic_prototype_ready default_promotion teacher_external_label_source_ready teacher_external_labels_ready teacher_distillation_ready comparison_input_ready benchmark_comparison_ready publishable_comparison_ready speed_schema_ready speed_evidence_ready gpu_speedup_claim pc_routelm_prototype_ready publishable_pc_routelm_ready action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h11 readiness summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h11 readiness summary row has wrong column count", 3)
    if ($idx["prototype_scope"] != "h11-pc-routelm" ||
        ($idx["prototype_contract_schema_ready"] + 0) != 1 ||
        ($idx["prototype_rows"] + 0) != 0 ||
        ($idx["small_generator_adapter_ready"] + 0) != 0 ||
        ($idx["route_memory_residency_ready"] + 0) != 0 ||
        ($idx["candidate_scoring_ready"] + 0) != 0 ||
        ($idx["decoder_binding_ready"] + 0) != 0 ||
        ($idx["nlg_smoke_ready"] + 0) != 0 ||
        ($idx["component_evidence_ready"] + 0) != 0 ||
        ($idx["diagnostic_prototype_ready"] + 0) != 0 ||
        ($idx["default_promotion"] + 0) != 0 ||
        ($idx["teacher_external_label_source_ready"] + 0) != 0 ||
        ($idx["teacher_external_labels_ready"] + 0) != 0 ||
        ($idx["teacher_distillation_ready"] + 0) != 0 ||
        ($idx["comparison_input_ready"] + 0) != 0 ||
        ($idx["benchmark_comparison_ready"] + 0) != 0 ||
        ($idx["publishable_comparison_ready"] + 0) != 0 ||
        ($idx["speed_schema_ready"] + 0) != 1 ||
        ($idx["speed_evidence_ready"] + 0) != 0 ||
        $idx["gpu_speedup_claim"] != "deferred" ||
        ($idx["pc_routelm_prototype_ready"] + 0) != 0 ||
        ($idx["publishable_pc_routelm_ready"] + 0) != 0 ||
        $idx["action"] != "pc-routelm-components-missing") {
      die("default h11 PC RouteLM readiness should be schema-ready but component/evidence blocked", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h11 readiness", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h11 readiness summary row", 6)
  }
' "$SUMMARY_CSV"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    if (!("gate" in idx) || !("status" in idx) || !("reason" in idx)) {
      die("missing h11 readiness decision columns", 20)
    }
    next
  }
  {
    rows++
    if ($idx["gate"] == "prototype-contract" && $idx["status"] != "pass") die("h11 contract should pass", 21)
    if ($idx["gate"] == "component-evidence" && $idx["status"] != "blocked") die("h11 components should block by default", 22)
    if ($idx["gate"] == "nlg-smoke" && $idx["status"] != "blocked") die("h11 NLG smoke should block by default", 23)
    if ($idx["gate"] == "pc-routelm-prototype" && $idx["status"] != "blocked") die("h11 prototype should block by default", 24)
    if ($idx["gate"] == "publishable-prototype" && $idx["status"] != "blocked") die("h11 publish should block by default", 25)
  }
  END {
    if (rows < 8) die("expected h11 readiness decision rows", 26)
  }
' "$DECISION_CSV"

echo "v11 PC RouteLM prototype readiness smoke passed"
