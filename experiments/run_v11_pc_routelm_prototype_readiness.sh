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

PREFIX="v11_pc_routelm_prototype_readiness"
PROMOTION_PREFIX="v07_route_memory_promotion_gate"
DISTILLATION_PREFIX="v10_chunk_credit_distillation_gate"
COMPARISON_PREFIX="v08_external_benchmark_comparison_gate"
SPEED_PREFIX="v09_gpu_backend_speed_evidence"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v11_pc_routelm_prototype_readiness_smoke"
  PROMOTION_PREFIX="v07_route_memory_promotion_gate_smoke"
  DISTILLATION_PREFIX="v10_chunk_credit_distillation_gate_smoke"
  COMPARISON_PREFIX="v08_external_benchmark_comparison_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

PROMOTION_SUMMARY_CSV="$RESULTS_DIR/${PROMOTION_PREFIX}_summary.csv"
DISTILLATION_SUMMARY_CSV="$RESULTS_DIR/${DISTILLATION_PREFIX}_summary.csv"
COMPARISON_SUMMARY_CSV="$RESULTS_DIR/${COMPARISON_PREFIX}_summary.csv"
SPEED_SUMMARY_CSV="$RESULTS_DIR/${SPEED_PREFIX}_summary.csv"
MANIFEST_CSV="$RESULTS_DIR/${PREFIX}_manifest.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PROTOTYPE_CSV="${V11_PC_ROUTELM_PROTOTYPE_CSV:-}"

"$ROOT_DIR/experiments/run_v07_route_memory_promotion_gate.sh" "${RUN_ARGS[@]}" >/dev/null
env -u V10_TEACHER_EXTERNAL_LABEL_CSV \
  "$ROOT_DIR/experiments/run_v10_chunk_credit_distillation_gate.sh" "${RUN_ARGS[@]}" >/dev/null
env -u V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_evidence_ingestion.sh" "${RUN_ARGS[@]}" >/dev/null
env -u V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_comparison_gate.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/test_v09_gpu_backend_speed_evidence.sh" >/dev/null

if [[ -n "$PROTOTYPE_CSV" && ! -s "$PROTOTYPE_CSV" ]]; then
  echo "V11_PC_ROUTELM_PROTOTYPE_CSV is set but not readable/non-empty: $PROTOTYPE_CSV" >&2
  exit 2
fi

cat >"$MANIFEST_CSV" <<'CSV'
field,required,source_mapping
prototype_id,1,prototype-manifest
generator_model_uri,1,small-generator-adapter
parameter_class,1,small-generator-adapter
quantization,1,small-generator-adapter
route_memory_store_uri,1,o-n-route-memory
route_memory_residency,1,o-n-route-memory
route_memory_index_policy,1,o-n-route-memory
candidate_scoring_device,1,candidate-scoring
decoder_device,1,small-decoder
nlg_smoke_uri,1,nlg-smoke
nlg_smoke_ready,1,nlg-smoke
benchmark_result_uri,1,external-benchmark
license,1,prototype-manifest
provenance_hash,1,prototype-manifest
routing_trigger_rate,1,guardrail
active_jump_rate,1,guardrail
CSV

AWK_INPUTS=(
  "$MANIFEST_CSV"
  "$PROMOTION_SUMMARY_CSV"
  "$DISTILLATION_SUMMARY_CSV"
  "$COMPARISON_SUMMARY_CSV"
  "$SPEED_SUMMARY_CSV"
)
if [[ -n "$PROTOTYPE_CSV" ]]; then
  AWK_INPUTS+=("$PROTOTYPE_CSV")
fi

awk -F, -v manifest_csv="$MANIFEST_CSV" -v promotion_csv="$PROMOTION_SUMMARY_CSV" -v distillation_csv="$DISTILLATION_SUMMARY_CSV" -v comparison_csv="$COMPARISON_SUMMARY_CSV" -v speed_csv="$SPEED_SUMMARY_CSV" -v prototype_csv="$PROTOTYPE_CSV" -v summary_csv="$SUMMARY_CSV" -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  FILENAME == manifest_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) midx[$i] = i
    required_count = split("field required source_mapping", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in midx)) die("missing h11 prototype manifest column: " required[i], 2)
    }
    next
  }
  FILENAME == manifest_csv {
    manifest_rows++
    if ($midx["required"] + 0 == 1) required_fields++
    mapping = $midx["source_mapping"]
    if (mapping == "small-generator-adapter") generator_fields++
    if (mapping == "o-n-route-memory") route_memory_fields++
    if (mapping == "candidate-scoring") candidate_scoring_fields++
    if (mapping == "small-decoder") decoder_fields++
    if (mapping == "nlg-smoke") nlg_fields++
    next
  }
  FILENAME == promotion_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) pidx[$i] = i
    required_count = split("default_promotion status routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in pidx)) die("missing h11 promotion column: " required[i], 3)
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
  FILENAME == distillation_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) didx[$i] = i
    required_count = split("teacher_external_label_source_ready teacher_external_labels_ready distillation_ready status routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in didx)) die("missing h11 distillation column: " required[i], 4)
    }
    next
  }
  FILENAME == distillation_csv {
    distillation_rows++
    teacher_external_label_source_ready = $didx["teacher_external_label_source_ready"] + 0
    teacher_external_labels_ready = $didx["teacher_external_labels_ready"] + 0
    teacher_distillation_ready = $didx["distillation_ready"] + 0
    teacher_distillation_status = $didx["status"]
    distillation_routing = $didx["routing_trigger_rate"] + 0
    distillation_jump = $didx["active_jump_rate"] + 0
    next
  }
  FILENAME == comparison_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) cidx[$i] = i
    required_count = split("comparison_input_ready benchmark_comparison_ready publishable_comparison_ready action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in cidx)) die("missing h11 benchmark comparison column: " required[i], 5)
    }
    next
  }
  FILENAME == comparison_csv {
    comparison_rows++
    comparison_input_ready = $cidx["comparison_input_ready"] + 0
    benchmark_comparison_ready = $cidx["benchmark_comparison_ready"] + 0
    publishable_comparison_ready = $cidx["publishable_comparison_ready"] + 0
    benchmark_action = $cidx["action"]
    comparison_routing = $cidx["routing_trigger_rate"] + 0
    comparison_jump = $cidx["active_jump_rate"] + 0
    next
  }
  FILENAME == speed_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("speed_schema_ready speed_evidence_ready gpu_speedup_claim routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) die("missing h11 speed evidence column: " required[i], 6)
    }
    next
  }
  FILENAME == speed_csv {
    speed_rows++
    speed_schema_ready = $sidx["speed_schema_ready"] + 0
    speed_evidence_ready = $sidx["speed_evidence_ready"] + 0
    gpu_speedup_claim = $sidx["gpu_speedup_claim"]
    speed_routing = $sidx["routing_trigger_rate"] + 0
    speed_jump = $sidx["active_jump_rate"] + 0
    next
  }
  prototype_csv != "" && FILENAME == prototype_csv && FNR == 1 {
    for (i = 1; i <= NF; i++) vidx[$i] = i
    required_count = split("prototype_id generator_model_uri parameter_class quantization route_memory_store_uri route_memory_residency route_memory_index_policy candidate_scoring_device decoder_device nlg_smoke_uri nlg_smoke_ready benchmark_result_uri license provenance_hash routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in vidx)) die("missing h11 prototype evidence column: " required[i], 7)
    }
    next
  }
  prototype_csv != "" && FILENAME == prototype_csv {
    prototype_rows++
    parameter_class = $vidx["parameter_class"]
    residency = $vidx["route_memory_residency"]
    index_policy = $vidx["route_memory_index_policy"]
    candidate_device = $vidx["candidate_scoring_device"]
    decoder_device = $vidx["decoder_device"]
    if ($vidx["generator_model_uri"] != "" &&
        (parameter_class == "3b-14b" || parameter_class == "3b" ||
         parameter_class == "7b" || parameter_class == "14b") &&
        $vidx["quantization"] != "") {
      generator_rows++
    }
    if ($vidx["route_memory_store_uri"] != "" &&
        (residency == "cpu-ram" || residency == "nvme") &&
        index_policy == "o-n-scan") {
      route_memory_rows++
    }
    if (candidate_device == "gpu") candidate_scoring_rows++
    if (decoder_device == "gpu") decoder_rows++
    if (($vidx["nlg_smoke_ready"] + 0) == 1 && $vidx["nlg_smoke_uri"] != "") nlg_rows++
    if ($vidx["benchmark_result_uri"] != "") benchmark_result_rows++
    if ($vidx["license"] != "") license_rows++
    if ($vidx["provenance_hash"] != "") provenance_rows++
    prototype_routing += $vidx["routing_trigger_rate"] + 0
    prototype_jump += $vidx["active_jump_rate"] + 0
    next
  }
  END {
    if (manifest_rows < 16 || required_fields != manifest_rows) die("expected h11 prototype manifest fields", 8)
    if (promotion_rows != 1) die("expected one h11 promotion row", 9)
    if (distillation_rows != 1) die("expected one h11 distillation row", 10)
    if (comparison_rows != 1) die("expected one h11 comparison row", 11)
    if (speed_rows != 1) die("expected one h11 speed row", 12)

    prototype_contract_schema_ready = 0
    if (generator_fields >= 3 &&
        route_memory_fields >= 3 &&
        candidate_scoring_fields >= 1 &&
        decoder_fields >= 1 &&
        nlg_fields >= 2) {
      prototype_contract_schema_ready = 1
    }

    small_generator_adapter_ready = 0
    route_memory_residency_ready = 0
    candidate_scoring_ready = 0
    decoder_binding_ready = 0
    nlg_smoke_ready = 0
    component_evidence_ready = 0
    diagnostic_prototype_ready = 0

    if (prototype_rows > 0) {
      small_generator_adapter_ready = generator_rows == prototype_rows
      route_memory_residency_ready = route_memory_rows == prototype_rows
      candidate_scoring_ready = candidate_scoring_rows == prototype_rows
      decoder_binding_ready = decoder_rows == prototype_rows
      nlg_smoke_ready = nlg_rows == prototype_rows
      if (small_generator_adapter_ready &&
          route_memory_residency_ready &&
          candidate_scoring_ready &&
          decoder_binding_ready &&
          nlg_smoke_ready &&
          benchmark_result_rows == prototype_rows &&
          license_rows == prototype_rows &&
          provenance_rows == prototype_rows &&
          prototype_routing == 0.0 &&
          prototype_jump == 0.0) {
        component_evidence_ready = 1
      }
      diagnostic_prototype_ready = component_evidence_ready && nlg_smoke_ready
    }

    pc_routelm_prototype_ready = 0
    if (component_evidence_ready &&
        default_promotion == 1 &&
        teacher_distillation_ready == 1 &&
        benchmark_comparison_ready == 1 &&
        speed_evidence_ready == 1 &&
        promotion_status == "promotion-candidate") {
      pc_routelm_prototype_ready = 1
    }
    publishable_pc_routelm_ready = 0
    if (pc_routelm_prototype_ready &&
        publishable_comparison_ready == 1 &&
        gpu_speedup_claim != "deferred") {
      publishable_pc_routelm_ready = 1
    }

    action = "pc-routelm-components-missing"
    if (!prototype_contract_schema_ready) {
      action = "build-pc-routelm-contract"
    } else if (component_evidence_ready && !default_promotion) {
      action = "diagnostic-prototype-only"
    } else if (component_evidence_ready && !teacher_distillation_ready) {
      action = "teacher-distillation-missing"
    } else if (component_evidence_ready && !benchmark_comparison_ready) {
      action = "external-benchmark-comparison-missing"
    } else if (component_evidence_ready && !speed_evidence_ready) {
      action = "gpu-speed-evidence-missing"
    } else if (publishable_pc_routelm_ready) {
      action = "publish-pc-routelm-prototype"
    }

    routing = promotion_routing + distillation_routing + comparison_routing + speed_routing + prototype_routing
    jump = promotion_jump + distillation_jump + comparison_jump + speed_jump + prototype_jump

    print "prototype_scope,prototype_contract_schema_ready,prototype_rows,small_generator_adapter_ready,route_memory_residency_ready,candidate_scoring_ready,decoder_binding_ready,nlg_smoke_ready,component_evidence_ready,diagnostic_prototype_ready,default_promotion,teacher_external_label_source_ready,teacher_external_labels_ready,teacher_distillation_ready,comparison_input_ready,benchmark_comparison_ready,publishable_comparison_ready,speed_schema_ready,speed_evidence_ready,gpu_speedup_claim,pc_routelm_prototype_ready,publishable_pc_routelm_ready,action,routing_trigger_rate,active_jump_rate" > summary_csv
    printf "h11-pc-routelm,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%d,%d,%s,%.6f,%.6f\n",
      prototype_contract_schema_ready,
      prototype_rows,
      small_generator_adapter_ready,
      route_memory_residency_ready,
      candidate_scoring_ready,
      decoder_binding_ready,
      nlg_smoke_ready,
      component_evidence_ready,
      diagnostic_prototype_ready,
      default_promotion,
      teacher_external_label_source_ready,
      teacher_external_labels_ready,
      teacher_distillation_ready,
      comparison_input_ready,
      benchmark_comparison_ready,
      publishable_comparison_ready,
      speed_schema_ready,
      speed_evidence_ready,
      gpu_speedup_claim,
      pc_routelm_prototype_ready,
      publishable_pc_routelm_ready,
      action,
      routing,
      jump >> summary_csv

    print "gate,status,reason" > decision_csv
    printf "prototype-contract,%s,manifest_fields=%d\n",
      prototype_contract_schema_ready ? "pass" : "blocked",
      manifest_rows >> decision_csv
    printf "component-evidence,%s,prototype_rows=%d\n",
      component_evidence_ready ? "pass" : "blocked",
      prototype_rows >> decision_csv
    printf "nlg-smoke,%s,nlg_smoke_ready=%d\n",
      nlg_smoke_ready ? "pass" : "blocked",
      nlg_smoke_ready >> decision_csv
    printf "teacher-distillation,%s,status=%s\n",
      teacher_distillation_ready ? "pass" : "blocked",
      teacher_distillation_status >> decision_csv
    printf "external-comparison,%s,action=%s\n",
      benchmark_comparison_ready ? "pass" : "blocked",
      benchmark_action >> decision_csv
    printf "speed-evidence,%s,gpu_speedup_claim=%s\n",
      speed_evidence_ready ? "pass" : "blocked",
      gpu_speedup_claim >> decision_csv
    printf "pc-routelm-prototype,%s,action=%s\n",
      pc_routelm_prototype_ready ? "pass" : "blocked",
      action >> decision_csv
    printf "publishable-prototype,%s,default_promotion=%d\n",
      publishable_pc_routelm_ready ? "pass" : "blocked",
      default_promotion >> decision_csv
  }
' "${AWK_INPUTS[@]}"

echo "manifest: $MANIFEST_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
