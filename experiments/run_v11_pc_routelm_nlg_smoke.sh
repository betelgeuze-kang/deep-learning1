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

PREFIX="v11_pc_routelm_nlg_smoke"
STORE_PREFIX="v11_nvme_route_memory_store"
ARTIFACT_PREFIX="v11_pc_routelm_prototype_artifact_verifier"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v11_pc_routelm_nlg_smoke_smoke"
  STORE_PREFIX="v11_nvme_route_memory_store_smoke"
  ARTIFACT_PREFIX="v11_pc_routelm_prototype_artifact_verifier_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  STORE_PREFIX="v11_nvme_route_memory_store_full"
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v11_nvme_route_memory_store.sh" "${RUN_ARGS[@]}" >/dev/null
"$ROOT_DIR/experiments/run_v11_pc_routelm_prototype_artifact_verifier.sh" "${RUN_ARGS[@]}" >/dev/null

STORE_SUMMARY_CSV="$RESULTS_DIR/${STORE_PREFIX}_summary.csv"
ARTIFACT_SUMMARY_CSV="$RESULTS_DIR/${ARTIFACT_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
ARTIFACT_DIR="$RESULTS_DIR/${PREFIX}_artifacts/routelm/nlg"
TRANSCRIPT_JSONL="$ARTIFACT_DIR/smoke_transcript.jsonl"
RESULT_JSON="$ARTIFACT_DIR/result_summary.json"
NLG_CSV="${V11_PC_ROUTELM_NLG_SMOKE_CSV:-$RESULTS_DIR/${PREFIX}_nlg.csv}"
NLG_SOURCE="generated-fixture"

if [[ -n "${V11_PC_ROUTELM_NLG_SMOKE_CSV:-}" ]]; then
  NLG_SOURCE="provided-csv"
  if [[ ! -s "$NLG_CSV" ]]; then
    echo "V11_PC_ROUTELM_NLG_SMOKE_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  rm -rf "$ARTIFACT_DIR"
  mkdir -p "$ARTIFACT_DIR"
  cat >"$TRANSCRIPT_JSONL" <<'JSONL'
{"query_id":"q_symbol_alpha","route_key":"alpha_route","retrieved_chunk_id":"chunk-alpha","evidence_span":"alpha_route","answer":"alpha_route","citation":"alpha_route","teacher_off_inference":true}
{"query_id":"q_config_timeout","route_key":"timeout_ms","retrieved_chunk_id":"chunk-config","evidence_span":"timeout_ms=2500","answer":"timeout_ms=2500","citation":"timeout_ms=2500","teacher_off_inference":true}
{"query_id":"q_missing_symbol","route_key":"missing_widget","retrieved_chunk_id":"ABSTAIN","evidence_span":"ABSTAIN","answer":"ABSTAIN","citation":"ABSTAIN","teacher_off_inference":true}
JSONL
  cat >"$RESULT_JSON" <<'JSON'
{
  "artifact_scope": "h11d-pc-routelm-nlg-smoke",
  "claim": "diagnostic PC RouteLM NLG smoke, not a real product claim",
  "teacher_off_inference": true,
  "retrieved_evidence_used": true,
  "answer_grounded_rate": 1.0,
  "span_citation_accuracy": 1.0,
  "routing_trigger_rate": 0.0,
  "active_jump_rate": 0.0
}
JSON
  cat >"$NLG_CSV" <<'CSV'
query_id,route_key,retrieved_chunk_id,evidence_span,answer,citation,generator_model_id,generator_runtime,teacher_off_inference,retrieved_evidence_used,answer_grounded,span_citation_correct,span_exact,chunk_exact,missing_query,missing_abstain,wrong_answer,answer_token_count,retrieval_latency_ms,query_to_first_token_ms,tokens_per_second_after_retrieval,ssd_bytes_per_query,ram_used_gb,vram_used_gb,real_generator_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate
q_symbol_alpha,alpha_route,chunk-alpha,alpha_route,alpha_route,alpha_route,diagnostic-small-generator-v1,fixture-local-generator,1,1,1,1,1,1,0,0,0,1,0.420000,4.000000,48.000000,64.000000,0.031250,0.000000,0,1,0,0
q_config_timeout,timeout_ms,chunk-config,timeout_ms=2500,timeout_ms=2500,timeout_ms=2500,diagnostic-small-generator-v1,fixture-local-generator,1,1,1,1,1,1,0,0,0,1,0.420000,4.500000,46.000000,64.000000,0.031250,0.000000,0,1,0,0
q_missing_symbol,missing_widget,ABSTAIN,ABSTAIN,ABSTAIN,ABSTAIN,diagnostic-small-generator-v1,fixture-local-generator,1,1,1,1,1,1,1,1,0,1,0.420000,3.500000,52.000000,64.000000,0.031250,0.000000,0,1,0,0
CSV
fi

awk -F, \
  -v store_csv="$STORE_SUMMARY_CSV" \
  -v artifact_csv="$ARTIFACT_SUMMARY_CSV" \
  -v nlg_csv="$NLG_CSV" \
  -v nlg_source="$NLG_SOURCE" \
  -v transcript_jsonl="$TRANSCRIPT_JSONL" \
  -v result_json="$RESULT_JSON" \
  -v summary_csv="$SUMMARY_CSV" \
  -v decision_csv="$DECISION_CSV" '
  function die(message, code) {
    print message > "/dev/stderr"
    fatal_code = code
    exit code
  }
  FILENAME == store_csv && FNR == 1 {
    store_header_fields = NF
    for (i = 1; i <= NF; i++) sidx[$i] = i
    required_count = split("route_memory_artifact_chain_verified query_to_evidence_ms span_exact chunk_exact missing_abstain wrong_answer_rate ssd_bytes_per_query route_lookup_latency_ms candidate_scoring_latency_ms real_pc_routelm_artifact_verified real_external_benchmark_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in sidx)) die("missing h11-d store summary column: " required[i], 2)
    }
    next
  }
  FILENAME == store_csv {
    if (NF != store_header_fields) die("h11-d store summary row has wrong column count", 3)
    store_rows++
    route_memory_artifact_chain_verified = $sidx["route_memory_artifact_chain_verified"] + 0
    store_query_to_evidence_ms = $sidx["query_to_evidence_ms"] + 0
    store_span_exact = $sidx["span_exact"] + 0
    store_chunk_exact = $sidx["chunk_exact"] + 0
    store_missing_abstain = $sidx["missing_abstain"] + 0
    store_wrong_answer_rate = $sidx["wrong_answer_rate"] + 0
    store_ssd_bytes_per_query = $sidx["ssd_bytes_per_query"] + 0
    route_lookup_latency_ms = $sidx["route_lookup_latency_ms"] + 0
    candidate_scoring_latency_ms = $sidx["candidate_scoring_latency_ms"] + 0
    store_real_pc_routelm_artifact_verified = $sidx["real_pc_routelm_artifact_verified"] + 0
    store_real_external_benchmark_verified = $sidx["real_external_benchmark_verified"] + 0
    store_action = $sidx["action"]
    store_routing = $sidx["routing_trigger_rate"] + 0
    store_jump = $sidx["active_jump_rate"] + 0
    next
  }
  FILENAME == artifact_csv && FNR == 1 {
    artifact_header_fields = NF
    for (i = 1; i <= NF; i++) aidx[$i] = i
    required_count = split("prototype_artifact_chain_verified real_pc_routelm_artifact_verified action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in aidx)) die("missing h11-d artifact summary column: " required[i], 4)
    }
    next
  }
  FILENAME == artifact_csv {
    if (NF != artifact_header_fields) die("h11-d artifact summary row has wrong column count", 5)
    artifact_rows++
    prototype_artifact_chain_verified = $aidx["prototype_artifact_chain_verified"] + 0
    artifact_real_pc_routelm_artifact_verified = $aidx["real_pc_routelm_artifact_verified"] + 0
    artifact_action = $aidx["action"]
    artifact_routing = $aidx["routing_trigger_rate"] + 0
    artifact_jump = $aidx["active_jump_rate"] + 0
    next
  }
  FILENAME == nlg_csv && FNR == 1 {
    nlg_header_fields = NF
    for (i = 1; i <= NF; i++) nidx[$i] = i
    required_count = split("query_id route_key retrieved_chunk_id evidence_span answer citation generator_model_id generator_runtime teacher_off_inference retrieved_evidence_used answer_grounded span_citation_correct span_exact chunk_exact missing_query missing_abstain wrong_answer answer_token_count retrieval_latency_ms query_to_first_token_ms tokens_per_second_after_retrieval ssd_bytes_per_query ram_used_gb vram_used_gb real_generator_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in nidx)) die("missing h11-d NLG smoke column: " required[i], 6)
    }
    next
  }
  FILENAME == nlg_csv {
    if (NF != nlg_header_fields) die("h11-d NLG smoke row has wrong column count", 7)
    nlg_rows++
    if ($nidx["query_id"] == "" || $nidx["route_key"] == "") die("h11-d NLG rows need query_id and route_key", 8)
    if (($nidx["teacher_off_inference"] + 0) == 1) teacher_off_rows++
    if (($nidx["retrieved_evidence_used"] + 0) == 1) retrieved_rows++
    if (($nidx["answer_grounded"] + 0) == 1) grounded_rows++
    if (($nidx["span_citation_correct"] + 0) == 1) citation_correct_rows++
    if (($nidx["missing_query"] + 0) == 1) {
      missing_rows++
      if (($nidx["missing_abstain"] + 0) == 1) missing_abstain_hits++
    }
    if (($nidx["real_generator_declared"] + 0) == 1) real_generator_declared_rows++
    if (($nidx["fixture_or_synthetic_declared"] + 0) == 0) non_fixture_rows++
    if ($nidx["evidence_span"] != "" && $nidx["answer"] != "" && $nidx["citation"] != "") evidence_bound_rows++
    span_exact_sum += $nidx["span_exact"] + 0
    chunk_exact_sum += $nidx["chunk_exact"] + 0
    wrong_answer_sum += $nidx["wrong_answer"] + 0
    retrieval_latency_sum += $nidx["retrieval_latency_ms"] + 0
    query_to_first_token_sum += $nidx["query_to_first_token_ms"] + 0
    tokens_per_second_sum += $nidx["tokens_per_second_after_retrieval"] + 0
    ssd_bytes_sum += $nidx["ssd_bytes_per_query"] + 0
    ram_used_sum += $nidx["ram_used_gb"] + 0
    vram_used_sum += $nidx["vram_used_gb"] + 0
    nlg_routing += $nidx["routing_trigger_rate"] + 0
    nlg_jump += $nidx["active_jump_rate"] + 0
    next
  }
  END {
    if (fatal_code) exit fatal_code

    if (store_rows != 1) die("expected one h11-d store summary row", 9)
    if (artifact_rows != 1) die("expected one h11-d artifact summary row", 10)

    diagnostic_artifact_ready = 0
    if (route_memory_artifact_chain_verified &&
        store_span_exact == 1.0 &&
        store_chunk_exact == 1.0 &&
        store_missing_abstain == 1.0 &&
        store_wrong_answer_rate == 0.0 &&
        store_routing == 0.0 &&
        store_jump == 0.0) {
      diagnostic_artifact_ready = 1
    }

    real_pc_routelm_artifact_verified = 0
    if (store_real_pc_routelm_artifact_verified || artifact_real_pc_routelm_artifact_verified) {
      real_pc_routelm_artifact_verified = 1
    }

    teacher_off_inference = 0
    retrieved_evidence_used = 0
    answer_grounded_rate = 0.0
    span_citation_accuracy = 0.0
    span_exact = 0.0
    chunk_exact = 0.0
    missing_abstain = 0.0
    wrong_answer_rate = 1.0
    retrieval_latency_ms = store_query_to_evidence_ms
    query_to_first_token_ms = 0.0
    tokens_per_second_after_retrieval = 0.0
    ssd_bytes_per_query = store_ssd_bytes_per_query
    ram_used_gb = 0.0
    vram_used_gb = 0.0

    if (nlg_rows > 0) {
      teacher_off_inference = teacher_off_rows == nlg_rows ? 1 : 0
      retrieved_evidence_used = retrieved_rows == nlg_rows ? 1 : 0
      answer_grounded_rate = grounded_rows / nlg_rows
      span_citation_accuracy = citation_correct_rows / nlg_rows
      span_exact = span_exact_sum / nlg_rows
      chunk_exact = chunk_exact_sum / nlg_rows
      missing_abstain = missing_rows > 0 ? missing_abstain_hits / missing_rows : 1.0
      wrong_answer_rate = wrong_answer_sum / nlg_rows
      retrieval_latency_ms = retrieval_latency_sum / nlg_rows
      query_to_first_token_ms = query_to_first_token_sum / nlg_rows
      tokens_per_second_after_retrieval = tokens_per_second_sum / nlg_rows
      ssd_bytes_per_query = ssd_bytes_sum / nlg_rows
      ram_used_gb = ram_used_sum / nlg_rows
      vram_used_gb = vram_used_sum / nlg_rows
    }

    evidence_binding_ready = 0
    if (nlg_rows > 0 && evidence_bound_rows == nlg_rows) {
      evidence_binding_ready = 1
    }

    nlg_quality_ready = 0
    if (answer_grounded_rate >= 0.8 &&
        span_citation_accuracy >= 0.8 &&
        span_exact >= 0.8 &&
        chunk_exact >= 0.8 &&
        missing_abstain >= 0.8 &&
        wrong_answer_rate == 0.0) {
      nlg_quality_ready = 1
    }

    total_routing = store_routing + artifact_routing + nlg_routing
    total_jump = store_jump + artifact_jump + nlg_jump

    pc_routelm_nlg_smoke_ready = 0
    if ((real_pc_routelm_artifact_verified || diagnostic_artifact_ready) &&
        nlg_rows > 0 &&
        teacher_off_inference &&
        retrieved_evidence_used &&
        evidence_binding_ready &&
        nlg_quality_ready &&
        total_routing == 0.0 &&
        total_jump == 0.0) {
      pc_routelm_nlg_smoke_ready = 1
    }

    real_pc_routelm_nlg_verified = 0
    if (pc_routelm_nlg_smoke_ready &&
        real_pc_routelm_artifact_verified &&
        real_generator_declared_rows == nlg_rows &&
        non_fixture_rows == nlg_rows) {
      real_pc_routelm_nlg_verified = 1
    }

    status = pc_routelm_nlg_smoke_ready ? "diagnostic-nlg-smoke" : "blocked"
    action = "diagnostic-nlg-smoke-ready"
    if (!diagnostic_artifact_ready && !real_pc_routelm_artifact_verified) {
      action = "route-memory-diagnostic-artifact-missing"
    } else if (nlg_rows <= 0) {
      action = "nlg-smoke-transcript-missing"
    } else if (!teacher_off_inference) {
      action = "teacher-off-inference-missing"
    } else if (!retrieved_evidence_used) {
      action = "retrieved-evidence-unused"
    } else if (!evidence_binding_ready) {
      action = "retrieved-evidence-binding-missing"
    } else if (answer_grounded_rate < 0.8) {
      action = "answer-grounding-insufficient"
    } else if (span_citation_accuracy < 0.8) {
      action = "span-citation-insufficient"
    } else if (wrong_answer_rate > 0.0) {
      action = "wrong-answer-rate-nonzero"
    } else if (total_routing != 0.0 || total_jump != 0.0) {
      action = "jump-guardrail-active"
    } else if (real_pc_routelm_nlg_verified) {
      status = "real-nlg-smoke"
      action = "real-pc-routelm-nlg-verified"
    }

    summary_header = "pc_routelm_nlg_scope,nlg_source,transcript_jsonl,result_json,store_action,artifact_action,nlg_rows,diagnostic_artifact_ready,prototype_artifact_chain_verified,real_pc_routelm_artifact_verified,teacher_off_inference,retrieved_evidence_used,evidence_binding_ready,nlg_quality_ready,answer_grounded_rate,span_citation_accuracy,span_exact,chunk_exact,missing_abstain,wrong_answer_rate,retrieval_latency_ms,route_lookup_latency_ms,candidate_scoring_latency_ms,query_to_first_token_ms,tokens_per_second_after_retrieval,ssd_bytes_per_query,ram_used_gb,vram_used_gb,real_generator_declared_rows,non_fixture_rows,pc_routelm_nlg_smoke_ready,real_pc_routelm_nlg_verified,status,action,routing_trigger_rate,active_jump_rate"
    summary_row = sprintf("h11d-pc-routelm-nlg,%s,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%d,%d,%d,%d,%s,%s,%.6f,%.6f", nlg_source, transcript_jsonl, result_json, store_action, artifact_action, nlg_rows, diagnostic_artifact_ready, prototype_artifact_chain_verified, real_pc_routelm_artifact_verified, teacher_off_inference, retrieved_evidence_used, evidence_binding_ready, nlg_quality_ready, answer_grounded_rate, span_citation_accuracy, span_exact, chunk_exact, missing_abstain, wrong_answer_rate, retrieval_latency_ms, route_lookup_latency_ms, candidate_scoring_latency_ms, query_to_first_token_ms, tokens_per_second_after_retrieval, ssd_bytes_per_query, ram_used_gb, vram_used_gb, real_generator_declared_rows, non_fixture_rows, pc_routelm_nlg_smoke_ready, real_pc_routelm_nlg_verified, status, action, total_routing, total_jump)
    print summary_header > summary_csv
    print summary_row >> summary_csv

    print "gate,status,reason" > decision_csv
    print sprintf("route-memory-artifact,%s,diagnostic_artifact_ready=%d store_action=%s", (diagnostic_artifact_ready || real_pc_routelm_artifact_verified) ? "pass" : "blocked", diagnostic_artifact_ready, store_action) >> decision_csv
    print sprintf("nlg-transcript,%s,rows=%d source=%s", nlg_rows > 0 ? "pass" : "blocked", nlg_rows, nlg_source) >> decision_csv
    print sprintf("teacher-off-inference,%s,teacher_off=%d", teacher_off_inference ? "pass" : "blocked", teacher_off_inference) >> decision_csv
    print sprintf("retrieved-evidence,%s,retrieved=%d evidence_binding=%d", (retrieved_evidence_used && evidence_binding_ready) ? "pass" : "blocked", retrieved_evidence_used, evidence_binding_ready) >> decision_csv
    print sprintf("grounded-answer,%s,rate=%.6f", answer_grounded_rate >= 0.8 ? "pass" : "blocked", answer_grounded_rate) >> decision_csv
    print sprintf("span-citation,%s,accuracy=%.6f", span_citation_accuracy >= 0.8 ? "pass" : "blocked", span_citation_accuracy) >> decision_csv
    print sprintf("wrong-answer,%s,wrong_rate=%.6f", wrong_answer_rate == 0.0 ? "pass" : "blocked", wrong_answer_rate) >> decision_csv
    print sprintf("pc-routelm-nlg-smoke,%s,ready=%d action=%s", pc_routelm_nlg_smoke_ready ? "pass" : "blocked", pc_routelm_nlg_smoke_ready, action) >> decision_csv
    print sprintf("real-pc-routelm-nlg,%s,real_verified=%d", real_pc_routelm_nlg_verified ? "pass" : "blocked", real_pc_routelm_nlg_verified) >> decision_csv
    print sprintf("jump-guardrail,%s,routing=%.6f active_jump=%.6f", total_routing == 0.0 && total_jump == 0.0 ? "pass" : "blocked", total_routing, total_jump) >> decision_csv
  }
' "$STORE_SUMMARY_CSV" "$ARTIFACT_SUMMARY_CSV" "$NLG_CSV"

echo "transcript: $TRANSCRIPT_JSONL"
echo "result: $RESULT_JSON"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
