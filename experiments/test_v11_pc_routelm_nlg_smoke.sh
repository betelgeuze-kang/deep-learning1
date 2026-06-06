#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

BAD_NLG_CSV="$RESULTS_DIR/v11_pc_routelm_nlg_smoke_bad_fixture.csv"
MALFORMED_NLG_CSV="$RESULTS_DIR/v11_pc_routelm_nlg_smoke_malformed_fixture.csv"

"$ROOT_DIR/experiments/run_v11_pc_routelm_nlg_smoke.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v11_pc_routelm_nlg_smoke_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v11_pc_routelm_nlg_smoke_smoke_decision.csv"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    header_fields = NF
    for (i = 1; i <= NF; i++) idx[$i] = i
    required_count = split("nlg_source nlg_rows diagnostic_artifact_ready real_pc_routelm_artifact_verified teacher_off_inference retrieved_evidence_used evidence_binding_ready nlg_quality_ready answer_grounded_rate span_citation_accuracy span_exact chunk_exact missing_abstain wrong_answer_rate retrieval_latency_ms query_to_first_token_ms tokens_per_second_after_retrieval ssd_bytes_per_query ram_used_gb vram_used_gb pc_routelm_nlg_smoke_ready real_pc_routelm_nlg_verified status action routing_trigger_rate active_jump_rate", required, " ")
    for (i = 1; i <= required_count; i++) {
      if (!(required[i] in idx)) die("missing h11-d summary column: " required[i], 2)
    }
    next
  }
  {
    rows++
    if (NF != header_fields) die("h11-d summary row has wrong column count", 3)
    if ($idx["nlg_source"] != "generated-fixture" ||
        ($idx["nlg_rows"] + 0) != 3 ||
        ($idx["diagnostic_artifact_ready"] + 0) != 1 ||
        ($idx["real_pc_routelm_artifact_verified"] + 0) != 0 ||
        ($idx["teacher_off_inference"] + 0) != 1 ||
        ($idx["retrieved_evidence_used"] + 0) != 1 ||
        ($idx["evidence_binding_ready"] + 0) != 1 ||
        ($idx["nlg_quality_ready"] + 0) != 1 ||
        ($idx["answer_grounded_rate"] + 0) != 1.0 ||
        ($idx["span_citation_accuracy"] + 0) != 1.0 ||
        ($idx["span_exact"] + 0) != 1.0 ||
        ($idx["chunk_exact"] + 0) != 1.0 ||
        ($idx["missing_abstain"] + 0) != 1.0 ||
        ($idx["wrong_answer_rate"] + 0) != 0.0 ||
        ($idx["retrieval_latency_ms"] + 0) <= 0.0 ||
        ($idx["query_to_first_token_ms"] + 0) <= 0.0 ||
        ($idx["tokens_per_second_after_retrieval"] + 0) <= 0.0 ||
        ($idx["ssd_bytes_per_query"] + 0) <= 0.0 ||
        ($idx["ram_used_gb"] + 0) <= 0.0 ||
        ($idx["vram_used_gb"] + 0) != 0.0 ||
        ($idx["pc_routelm_nlg_smoke_ready"] + 0) != 1 ||
        ($idx["real_pc_routelm_nlg_verified"] + 0) != 0 ||
        $idx["status"] != "diagnostic-nlg-smoke" ||
        $idx["action"] != "diagnostic-nlg-smoke-ready") {
      die("h11-d generated fixture should pass diagnostic NLG smoke without real product claim", 4)
    }
    if (($idx["routing_trigger_rate"] + 0) != 0.0 ||
        ($idx["active_jump_rate"] + 0) != 0.0) {
      die("jump-neighbor path must stay inactive for h11-d", 5)
    }
  }
  END {
    if (rows != 1) die("expected one h11-d summary row", 6)
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
    if ($idx["gate"] == "route-memory-artifact" && $idx["status"] != "pass") die("route-memory artifact should pass", 20)
    if ($idx["gate"] == "nlg-transcript" && $idx["status"] != "pass") die("NLG transcript should pass", 21)
    if ($idx["gate"] == "teacher-off-inference" && $idx["status"] != "pass") die("teacher-off inference should pass", 22)
    if ($idx["gate"] == "retrieved-evidence" && $idx["status"] != "pass") die("retrieved evidence should pass", 23)
    if ($idx["gate"] == "grounded-answer" && $idx["status"] != "pass") die("grounded answer should pass", 24)
    if ($idx["gate"] == "span-citation" && $idx["status"] != "pass") die("span citation should pass", 25)
    if ($idx["gate"] == "wrong-answer" && $idx["status"] != "pass") die("wrong-answer guard should pass", 26)
    if ($idx["gate"] == "pc-routelm-nlg-smoke" && $idx["status"] != "pass") die("diagnostic NLG smoke should pass", 27)
    if ($idx["gate"] == "real-pc-routelm-nlg" && $idx["status"] != "blocked") die("real PC RouteLM NLG should stay blocked", 28)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("jump guardrail should pass", 29)
  }
  END {
    if (rows != 10) die("expected h11-d decision rows", 30)
  }
' "$DECISION_CSV"

cat >"$BAD_NLG_CSV" <<'CSV'
query_id,route_key,retrieved_chunk_id,evidence_span,answer,citation,generator_model_id,generator_runtime,teacher_off_inference,retrieved_evidence_used,answer_grounded,span_citation_correct,span_exact,chunk_exact,missing_query,missing_abstain,wrong_answer,answer_token_count,retrieval_latency_ms,query_to_first_token_ms,tokens_per_second_after_retrieval,ssd_bytes_per_query,ram_used_gb,vram_used_gb,real_generator_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate
q_symbol_alpha,alpha_route,chunk-alpha,alpha_route,wrong_answer,alpha_route,diagnostic-small-generator-v1,fixture-local-generator,1,1,0,1,0,0,0,0,1,1,0.420000,4.000000,48.000000,64.000000,0.031250,0.000000,0,1,0,0
q_config_timeout,timeout_ms,chunk-config,timeout_ms=2500,timeout_ms=2500,timeout_ms=2500,diagnostic-small-generator-v1,fixture-local-generator,1,1,1,1,1,1,0,0,0,1,0.420000,4.500000,46.000000,64.000000,0.031250,0.000000,0,1,0,0
q_missing_symbol,missing_widget,ABSTAIN,ABSTAIN,ABSTAIN,ABSTAIN,diagnostic-small-generator-v1,fixture-local-generator,1,1,1,1,1,1,1,1,0,1,0.420000,3.500000,52.000000,64.000000,0.031250,0.000000,0,1,0,0
CSV

V11_PC_ROUTELM_NLG_SMOKE_CSV="$BAD_NLG_CSV" \
  "$ROOT_DIR/experiments/run_v11_pc_routelm_nlg_smoke.sh" --smoke

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
    if (($idx["pc_routelm_nlg_smoke_ready"] + 0) != 0 ||
        ($idx["nlg_quality_ready"] + 0) != 0 ||
        ($idx["answer_grounded_rate"] + 0) >= 0.8 ||
        ($idx["wrong_answer_rate"] + 0) <= 0.0 ||
        $idx["action"] != "answer-grounding-insufficient") {
      die("bad h11-d NLG fixture should block on grounding/wrong answer", 40)
    }
  }
  END {
    if (rows != 1) die("expected one bad h11-d summary row", 41)
  }
' "$SUMMARY_CSV"

{
  head -n 1 "$BAD_NLG_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$BAD_NLG_CSV")"
} >"$MALFORMED_NLG_CSV"

if V11_PC_ROUTELM_NLG_SMOKE_CSV="$MALFORMED_NLG_CSV" \
     "$ROOT_DIR/experiments/run_v11_pc_routelm_nlg_smoke.sh" --smoke >/dev/null 2>/dev/null; then
  echo "h11-d should reject malformed NLG smoke CSV row widths" >&2
  exit 50
fi

"$ROOT_DIR/experiments/run_v11_pc_routelm_nlg_smoke.sh" --smoke >/dev/null

echo "v11 PC RouteLM NLG smoke passed"
