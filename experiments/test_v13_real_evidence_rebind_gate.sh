#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_evidence_rebind_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_evidence_rebind_gate_smoke_decision.csv"
PACKET_DIR="$RESULTS_DIR/v13_real_evidence_rebind_gate_smoke_packet/run_001"
FIXTURE_DIR="$RESULTS_DIR/v13_real_evidence_rebind_fixture"
INTAKE_CSV="$FIXTURE_DIR/intake.csv"
LIVE_CSV="$FIXTURE_DIR/live_network.csv"
REBIND_CSV="$FIXTURE_DIR/rebind.csv"
BAD_RECEIPT_CSV="$FIXTURE_DIR/bad_receipt_rebind.csv"
BAD_ARTIFACT_CSV="$FIXTURE_DIR/bad_artifact_rebind.csv"
MISSING_ROW_CSV="$FIXTURE_DIR/missing_row_rebind.csv"

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
      if (!(field in idx)) die("missing v13-j summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-j summary row", 4)
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
      if ($idx["status"] != expected) die("v13-j decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v13-j decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

write_fixture_package() {
  rm -rf "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/cache" "$FIXTURE_DIR/receipts" "$FIXTURE_DIR/rebound"

  for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
    printf '{"weakness_id":"%s","claim":"local intake cache for v13-j mechanics"}\n' "$weakness" >"$FIXTURE_DIR/cache/${weakness}.json"
    printf '{"weakness_id":"%s","claim":"rebound promotion artifact mechanics"}\n' "$weakness" >"$FIXTURE_DIR/rebound/${weakness}_artifact.json"
    printf '{"weakness_id":"%s","claim_matrix":"rebound claim row mechanics"}\n' "$weakness" >"$FIXTURE_DIR/rebound/${weakness}_claim.json"
  done

  {
    echo "run_id,weakness_id,evidence_family,source_uri,review_uri,authority_uri,cache_uri,cache_hash,nonfixture_declared,independent_declared,runner_owned_declared,official_or_public_declared,source_bound_declared,metric_ready_declared,live_network_verified,real_evidence_declared,routing_trigger_rate,active_jump_rate"
    for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
      case "$weakness" in
        external_benchmark) family="external-benchmark" ;;
        learned_chunk_ranking) family="learned-scorer" ;;
        gpu_speedup) family="resource-speed" ;;
        real_nlg) family="pc-routelm-nlg" ;;
      esac
      cache_hash="$(sha256sum "$FIXTURE_DIR/cache/${weakness}.json" | awk '{print $1}')"
      printf "run_001,%s,%s,https://evidence.example.org/v13j/%s/source,https://evidence.example.org/v13j/%s/review,https://evidence.example.org/v13j/%s/authority,file://%s,sha256:%s,1,1,1,1,1,1,0,1,0,0\n" \
        "$weakness" \
        "$family" \
        "$weakness" \
        "$weakness" \
        "$weakness" \
        "$FIXTURE_DIR/cache/${weakness}.json" \
        "$cache_hash"
    done
  } >"$INTAKE_CSV"

  {
    echo "run_id,weakness_id,source_status,review_status,authority_status,source_final_uri,review_final_uri,authority_final_uri,source_receipt_uri,review_receipt_uri,authority_receipt_uri,source_receipt_hash,review_receipt_hash,authority_receipt_hash,tls_verified,dns_verified,http_verified,runner_owned_live_fetch,nonfixture_declared,fixture_declared,live_network_verified,routing_trigger_rate,active_jump_rate"
    for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
      for kind in source review authority; do
        printf '{"weakness_id":"%s","kind":"%s","status":200,"fixture":"v13-j receipt mechanics only"}\n' "$weakness" "$kind" >"$FIXTURE_DIR/receipts/${weakness}_${kind}.json"
      done
      source_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_source.json" | awk '{print $1}')"
      review_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_review.json" | awk '{print $1}')"
      authority_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_authority.json" | awk '{print $1}')"
      printf "run_001,%s,200,200,200,https://evidence.example.org/v13j/%s/source,https://evidence.example.org/v13j/%s/review,https://evidence.example.org/v13j/%s/authority,file://%s,file://%s,file://%s,sha256:%s,sha256:%s,sha256:%s,1,1,1,1,1,1,1,0,0\n" \
        "$weakness" \
        "$weakness" \
        "$weakness" \
        "$weakness" \
        "$FIXTURE_DIR/receipts/${weakness}_source.json" \
        "$FIXTURE_DIR/receipts/${weakness}_review.json" \
        "$FIXTURE_DIR/receipts/${weakness}_authority.json" \
        "$source_hash" \
        "$review_hash" \
        "$authority_hash"
    done
  } >"$LIVE_CSV"

  {
    echo "run_id,weakness_id,source_receipt_hash,review_receipt_hash,authority_receipt_hash,rebuilt_artifact_uri,rebuilt_artifact_hash,claim_matrix_uri,claim_matrix_hash,regenerated_run_declared,receipt_replayed_declared,nonfixture_declared,runtime_live_fetch_bound_declared,promotion_row_ready_declared,routing_trigger_rate,active_jump_rate"
    awk -F, 'NR > 1 {print $2 "," $12 "," $13 "," $14}' "$LIVE_CSV" | while IFS=, read -r weakness source_hash review_hash authority_hash; do
      artifact_hash="$(sha256sum "$FIXTURE_DIR/rebound/${weakness}_artifact.json" | awk '{print $1}')"
      claim_hash="$(sha256sum "$FIXTURE_DIR/rebound/${weakness}_claim.json" | awk '{print $1}')"
      printf "run_001,%s,%s,%s,%s,file://%s,sha256:%s,file://%s,sha256:%s,1,1,1,1,1,0,0\n" \
        "$weakness" \
        "$source_hash" \
        "$review_hash" \
        "$authority_hash" \
        "$FIXTURE_DIR/rebound/${weakness}_artifact.json" \
        "$artifact_hash" \
        "$FIXTURE_DIR/rebound/${weakness}_claim.json" \
        "$claim_hash"
    done
  } >"$REBIND_CSV"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_real_evidence_rebind_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "rebind_source" "generated-missing-rebind" "v13-j default source"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "0" "v13-j default live"
expect_summary_value "$SUMMARY_CSV" "rebind_packet_hash_ready" "1" "v13-j default packet"
expect_summary_value "$SUMMARY_CSV" "rebind_contract_ready" "0" "v13-j default contract"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_rebind_ready" "0" "v13-j default candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-j default release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-rebind-live-network-not-ready" "v13-j default action"

write_fixture_package
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$REBIND_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_rebind_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "rebind_source" "provided-rebind-csv" "v13-j fixture source"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "1" "v13-j fixture live contract"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_live_network_ready" "0" "v13-j fixture live candidate"
expect_summary_value "$SUMMARY_CSV" "rebind_rows" "4" "v13-j fixture rows"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "4" "v13-j fixture required rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_or_unknown_rows" "0" "v13-j fixture duplicates"
expect_summary_value "$SUMMARY_CSV" "run_id_match_rows" "4" "v13-j fixture run binding"
expect_summary_value "$SUMMARY_CSV" "receipt_hash_match_rows" "12" "v13-j fixture receipt hashes"
expect_summary_value "$SUMMARY_CSV" "expected_receipt_hash_rows" "12" "v13-j fixture expected receipt hashes"
expect_summary_value "$SUMMARY_CSV" "artifact_hash_verified_rows" "8" "v13-j fixture artifacts"
expect_summary_value "$SUMMARY_CSV" "expected_artifact_hash_rows" "8" "v13-j fixture expected artifacts"
expect_summary_value "$SUMMARY_CSV" "contract_flag_ready_rows" "4" "v13-j fixture flags"
expect_summary_value "$SUMMARY_CSV" "rebind_contract_ready" "1" "v13-j fixture contract"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_rebind_ready" "0" "v13-j fixture candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-j fixture release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-rebind-await-runtime-live-fetch" "v13-j fixture action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-j fixture routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-j fixture jump"

expect_decision_status "$DECISION_CSV" "live-network-binding" "pass"
expect_decision_status "$DECISION_CSV" "required-weakness-rows" "pass"
expect_decision_status "$DECISION_CSV" "run-id-binding" "pass"
expect_decision_status "$DECISION_CSV" "receipt-hash-replay" "pass"
expect_decision_status "$DECISION_CSV" "artifact-hash-binding" "pass"
expect_decision_status "$DECISION_CSV" "rebind-contract-flags" "pass"
expect_decision_status "$DECISION_CSV" "runtime-live-fetch" "blocked"
expect_decision_status "$DECISION_CSV" "candidate-rebind" "blocked"
expect_decision_status "$DECISION_CSV" "v13-real-evidence-rebind" "blocked"

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
    if ($idx["receipt_hashes_match"] != "3") die("v13-j row should match three receipt hashes", 20)
    if ($idx["artifact_hashes_verified"] != "2") die("v13-j row should verify two rebound artifacts", 21)
  }
  END {
    if (rows != 4) die("expected four v13-j rebind rows", 22)
  }
' "$PACKET_DIR/rebind_rows.csv"

cp "$REBIND_CSV" "$BAD_RECEIPT_CSV"
awk -F, 'BEGIN {OFS=","} NR == 2 {$3="sha256:bad"} {print}' "$BAD_RECEIPT_CSV" >"$BAD_RECEIPT_CSV.tmp"
mv "$BAD_RECEIPT_CSV.tmp" "$BAD_RECEIPT_CSV"
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$BAD_RECEIPT_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_rebind_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "receipt_hash_match_rows" "9" "v13-j bad receipt rows"
expect_summary_value "$SUMMARY_CSV" "rebind_contract_ready" "0" "v13-j bad receipt contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-rebind-receipt-hash-mismatch" "v13-j bad receipt action"

cp "$REBIND_CSV" "$BAD_ARTIFACT_CSV"
printf '\n' >>"$FIXTURE_DIR/rebound/gpu_speedup_artifact.json"
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$BAD_ARTIFACT_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_rebind_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "artifact_hash_verified_rows" "7" "v13-j bad artifact rows"
expect_summary_value "$SUMMARY_CSV" "rebind_contract_ready" "0" "v13-j bad artifact contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-rebind-artifact-hash-mismatch" "v13-j bad artifact action"

awk -F, 'NR == 1 || $2 != "real_nlg"' "$REBIND_CSV" >"$MISSING_ROW_CSV"
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$MISSING_ROW_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_rebind_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "rebind_rows" "3" "v13-j missing row count"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "3" "v13-j missing required rows"
expect_summary_value "$SUMMARY_CSV" "rebind_contract_ready" "0" "v13-j missing contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-rebind-required-weakness-rows-missing" "v13-j missing action"

write_fixture_package
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$REBIND_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_rebind_gate.sh" --smoke >/dev/null

echo "v13 real evidence rebind gate smoke passed"
