#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_CSV="$RESULTS_DIR/v11_pc_routelm_prototype_import_fixture.csv"

mkdir -p "$RESULTS_DIR"

cat >"$FIXTURE_CSV" <<'CSV'
prototype_id,generator_model_uri,parameter_class,quantization,route_memory_store_uri,route_memory_residency,route_memory_index_policy,candidate_scoring_device,decoder_device,nlg_smoke_uri,nlg_smoke_ready,benchmark_result_uri,license,provenance_hash,routing_trigger_rate,active_jump_rate
h11-fixture,model://local/quantized-7b,7b,int4,store://cpu-ram/route-memory,cpu-ram,o-n-scan,gpu,gpu,results://h11/nlg-smoke,1,results://h11/external-benchmark-pending,permissive,prov-h11-fixture,0,0
CSV

V11_PC_ROUTELM_PROTOTYPE_CSV="$FIXTURE_CSV" \
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
    required_count = split("prototype_contract_schema_ready prototype_rows small_generator_adapter_ready route_memory_residency_ready candidate_scoring_ready decoder_binding_ready nlg_smoke_ready component_evidence_ready diagnostic_prototype_ready prototype_artifact_chain_verified real_pc_routelm_artifact_verified prototype_artifact_action default_promotion teacher_distillation_ready benchmark_comparison_ready speed_evidence_ready gpu_speedup_claim pc_routelm_prototype_ready publishable_pc_routelm_ready action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h11 import summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h11 import summary row has wrong column count", 3)
    if (($idx["prototype_contract_schema_ready"] + 0) != 1 ||
        ($idx["prototype_rows"] + 0) != 1 ||
        ($idx["small_generator_adapter_ready"] + 0) != 1 ||
        ($idx["route_memory_residency_ready"] + 0) != 1 ||
        ($idx["candidate_scoring_ready"] + 0) != 1 ||
        ($idx["decoder_binding_ready"] + 0) != 1 ||
        ($idx["nlg_smoke_ready"] + 0) != 1 ||
        ($idx["component_evidence_ready"] + 0) != 1 ||
        ($idx["diagnostic_prototype_ready"] + 0) != 1 ||
        ($idx["prototype_artifact_chain_verified"] + 0) != 0 ||
        ($idx["real_pc_routelm_artifact_verified"] + 0) != 0 ||
        $idx["prototype_artifact_action"] != "pc-routelm-artifact-evidence-missing" ||
        ($idx["default_promotion"] + 0) != 0 ||
        ($idx["teacher_distillation_ready"] + 0) != 0 ||
        ($idx["benchmark_comparison_ready"] + 0) != 0 ||
        ($idx["speed_evidence_ready"] + 0) != 0 ||
        $idx["gpu_speedup_claim"] != "deferred" ||
        ($idx["pc_routelm_prototype_ready"] + 0) != 0 ||
        ($idx["publishable_pc_routelm_ready"] + 0) != 0 ||
        $idx["action"] != "diagnostic-prototype-only") {
      die("supplied h11 prototype fixture should be diagnostic-only before promotion/benchmark/speed evidence", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h11 prototype import", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h11 prototype import summary row", 6)
  }
' "$SUMMARY_CSV"

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
    if ($idx["gate"] == "prototype-contract" && $idx["status"] != "pass") die("h11 contract should pass", 20)
    if ($idx["gate"] == "component-evidence" && $idx["status"] != "pass") die("h11 supplied components should pass", 21)
    if ($idx["gate"] == "nlg-smoke" && $idx["status"] != "pass") die("h11 supplied NLG smoke should pass", 22)
    if ($idx["gate"] == "teacher-distillation" && $idx["status"] != "blocked") die("h11 teacher distillation should remain default-blocked", 23)
    if ($idx["gate"] == "external-comparison" && $idx["status"] != "blocked") die("h11 external comparison should remain default-blocked", 24)
    if ($idx["gate"] == "speed-evidence" && $idx["status"] != "blocked") die("h11 speed evidence should remain blocked", 25)
    if ($idx["gate"] == "real-prototype-artifacts" && $idx["status"] != "blocked") die("h11 real artifacts should remain blocked", 26)
    if ($idx["gate"] == "pc-routelm-prototype" && $idx["status"] != "blocked") die("h11 prototype should remain blocked", 27)
  }
  END {
    if (rows < 9) die("expected h11 import decision rows", 28)
  }
' "$DECISION_CSV"

echo "v11 PC RouteLM prototype import smoke passed"
