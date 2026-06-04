#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_evidence_live_network_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_evidence_live_network_gate_smoke_decision.csv"
PACKET_DIR="$RESULTS_DIR/v13_real_evidence_live_network_gate_smoke_packet/run_001"
FIXTURE_DIR="$RESULTS_DIR/v13_real_evidence_live_network_fixture"
INTAKE_CSV="$FIXTURE_DIR/intake.csv"
LIVE_CSV="$FIXTURE_DIR/live_network.csv"
BAD_HASH_CSV="$FIXTURE_DIR/bad_hash_live_network.csv"
MISSING_ROW_CSV="$FIXTURE_DIR/missing_row_live_network.csv"

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
      if (!(field in idx)) die("missing v13-i summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-i summary row", 4)
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
      if ($idx["status"] != expected) die("v13-i decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v13-i decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

write_fixture_package() {
  rm -rf "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/artifacts" "$FIXTURE_DIR/receipts"

  for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
    printf '{"weakness_id":"%s","claim":"local evidence cache for v13-i mechanics"}\n' "$weakness" >"$FIXTURE_DIR/artifacts/${weakness}.json"
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
      hash="$(sha256sum "$FIXTURE_DIR/artifacts/${weakness}.json" | awk '{print $1}')"
      printf "run_001,%s,%s,https://evidence.example.org/v13i/%s/source,https://evidence.example.org/v13i/%s/review,https://evidence.example.org/v13i/%s/authority,file://%s,sha256:%s,1,1,1,1,1,1,0,1,0,0\n" \
        "$weakness" \
        "$family" \
        "$weakness" \
        "$weakness" \
        "$weakness" \
        "$FIXTURE_DIR/artifacts/${weakness}.json" \
        "$hash"
    done
  } >"$INTAKE_CSV"

  {
    echo "run_id,weakness_id,source_status,review_status,authority_status,source_final_uri,review_final_uri,authority_final_uri,source_receipt_uri,review_receipt_uri,authority_receipt_uri,source_receipt_hash,review_receipt_hash,authority_receipt_hash,tls_verified,dns_verified,http_verified,runner_owned_live_fetch,nonfixture_declared,fixture_declared,live_network_verified,routing_trigger_rate,active_jump_rate"
    for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
      for kind in source review authority; do
        printf '{"weakness_id":"%s","kind":"%s","status":200,"fixture":"v13-i receipt mechanics only"}\n' "$weakness" "$kind" >"$FIXTURE_DIR/receipts/${weakness}_${kind}.json"
      done
      source_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_source.json" | awk '{print $1}')"
      review_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_review.json" | awk '{print $1}')"
      authority_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_authority.json" | awk '{print $1}')"
      printf "run_001,%s,200,200,200,https://evidence.example.org/v13i/%s/source,https://evidence.example.org/v13i/%s/review,https://evidence.example.org/v13i/%s/authority,file://%s,file://%s,file://%s,sha256:%s,sha256:%s,sha256:%s,1,1,1,1,1,1,1,0,0\n" \
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
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_real_evidence_live_network_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "live_source" "generated-missing-live-network-receipts" "v13-i default source"
expect_summary_value "$SUMMARY_CSV" "intake_contract_ready" "0" "v13-i default intake"
expect_summary_value "$SUMMARY_CSV" "live_packet_hash_ready" "1" "v13-i default packet hash"
expect_summary_value "$SUMMARY_CSV" "live_rows" "4" "v13-i default rows"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "4" "v13-i default required rows"
expect_summary_value "$SUMMARY_CSV" "receipt_hash_verified_rows" "0" "v13-i default receipt hashes"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "0" "v13-i default contract"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_live_network_ready" "0" "v13-i default candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-i default release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-live-network-intake-not-ready" "v13-i default action"

write_fixture_package
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_live_network_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "live_source" "generated-missing-live-network-receipts" "v13-i missing live source"
expect_summary_value "$SUMMARY_CSV" "intake_contract_ready" "1" "v13-i fixture intake"
expect_summary_value "$SUMMARY_CSV" "receipt_hash_verified_rows" "0" "v13-i missing receipts"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "0" "v13-i missing live contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-live-network-receipt-hash-mismatch" "v13-i missing live action"

V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_live_network_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "live_source" "provided-live-network-csv" "v13-i fixture live source"
expect_summary_value "$SUMMARY_CSV" "intake_contract_ready" "1" "v13-i fixture intake contract"
expect_summary_value "$SUMMARY_CSV" "live_rows" "4" "v13-i fixture live rows"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "4" "v13-i fixture required rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_or_unknown_rows" "0" "v13-i fixture duplicate rows"
expect_summary_value "$SUMMARY_CSV" "run_id_match_rows" "4" "v13-i fixture run binding"
expect_summary_value "$SUMMARY_CSV" "receipt_hash_verified_rows" "12" "v13-i fixture receipt hashes"
expect_summary_value "$SUMMARY_CSV" "expected_receipt_hash_rows" "12" "v13-i fixture expected receipt hashes"
expect_summary_value "$SUMMARY_CSV" "https_final_uri_rows" "4" "v13-i fixture final uris"
expect_summary_value "$SUMMARY_CSV" "status_ready_rows" "4" "v13-i fixture statuses"
expect_summary_value "$SUMMARY_CSV" "network_flag_ready_rows" "4" "v13-i fixture flags"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_rows" "0" "v13-i fixture runtime"
expect_summary_value "$SUMMARY_CSV" "fixture_rows" "4" "v13-i fixture marker"
expect_summary_value "$SUMMARY_CSV" "live_network_verified_rows" "4" "v13-i fixture live declarations"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "1" "v13-i fixture receipt contract"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_live_network_ready" "0" "v13-i fixture candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-i fixture release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-live-network-await-runtime-fetch" "v13-i fixture action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-i fixture routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-i fixture jump"

expect_decision_status "$DECISION_CSV" "intake-contract" "pass"
expect_decision_status "$DECISION_CSV" "required-weakness-rows" "pass"
expect_decision_status "$DECISION_CSV" "run-id-binding" "pass"
expect_decision_status "$DECISION_CSV" "receipt-hash-binding" "pass"
expect_decision_status "$DECISION_CSV" "live-http-status" "pass"
expect_decision_status "$DECISION_CSV" "network-declarations" "pass"
expect_decision_status "$DECISION_CSV" "runtime-live-fetch" "blocked"
expect_decision_status "$DECISION_CSV" "candidate-live-network" "blocked"
expect_decision_status "$DECISION_CSV" "v13-real-evidence-live-network" "blocked"

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
    if ($idx["receipt_hashes_verified"] != "3") die("v13-i fixture row should verify three receipts", 20)
    if ($idx["runtime_fetch_ready"] != "0") die("v13-i supplied fixture must not become runtime fetch evidence", 21)
  }
  END {
    if (rows != 4) die("expected four v13-i live network rows", 22)
  }
' "$PACKET_DIR/live_network_rows.csv"

cp "$LIVE_CSV" "$BAD_HASH_CSV"
printf '\n' >>"$FIXTURE_DIR/receipts/gpu_speedup_source.json"
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_live_network_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "receipt_hash_verified_rows" "11" "v13-i bad hash rows"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "0" "v13-i bad hash contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-live-network-receipt-hash-mismatch" "v13-i bad hash action"

awk -F, 'NR == 1 || $2 != "real_nlg"' "$LIVE_CSV" >"$MISSING_ROW_CSV"
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$MISSING_ROW_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_live_network_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "live_rows" "3" "v13-i missing row count"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "3" "v13-i missing required rows"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "0" "v13-i missing contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-live-network-required-weakness-rows-missing" "v13-i missing action"

write_fixture_package
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_live_network_gate.sh" --smoke >/dev/null

echo "v13 real evidence live network gate smoke passed"
