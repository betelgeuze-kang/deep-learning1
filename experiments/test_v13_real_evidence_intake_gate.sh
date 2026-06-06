#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_evidence_intake_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_evidence_intake_gate_smoke_decision.csv"
PACKET_DIR="$RESULTS_DIR/v13_real_evidence_intake_gate_smoke_packet/run_001"
FIXTURE_DIR="$RESULTS_DIR/v13_real_evidence_intake_fixture"
FIXTURE_CSV="$FIXTURE_DIR/intake.csv"
BAD_HASH_CSV="$FIXTURE_DIR/bad_hash_intake.csv"
MISSING_ROW_CSV="$FIXTURE_DIR/missing_row_intake.csv"

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
      if (!(field in idx)) die("missing v13-h summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-h summary row", 4)
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
      if ($idx["status"] != expected) die("v13-h decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v13-h decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

write_fixture_package() {
  rm -rf "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/artifacts"

  for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
    printf '{"weakness_id":"%s","claim":"local cache for v13-h mechanics only"}\n' "$weakness" >"$FIXTURE_DIR/artifacts/${weakness}.json"
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
      printf "run_001,%s,%s,https://evidence.example.org/v13h/%s/source,https://evidence.example.org/v13h/%s/review,https://evidence.example.org/v13h/%s/authority,file://%s,sha256:%s,1,1,1,1,1,1,0,1,0,0\n" \
        "$weakness" \
        "$family" \
        "$weakness" \
        "$weakness" \
        "$weakness" \
        "$FIXTURE_DIR/artifacts/${weakness}.json" \
        "$hash"
    done
  } >"$FIXTURE_CSV"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_real_evidence_intake_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "intake_source" "generated-missing-intake" "v13-h default source"
expect_summary_value "$SUMMARY_CSV" "diagnostic_binding_ready" "1" "v13-h diagnostic binding"
expect_summary_value "$SUMMARY_CSV" "promotion_packet_hash_ready" "1" "v13-h promotion packet"
expect_summary_value "$SUMMARY_CSV" "intake_packet_hash_ready" "1" "v13-h packet hash"
expect_summary_value "$SUMMARY_CSV" "intake_rows" "4" "v13-h default rows"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "4" "v13-h required rows"
expect_summary_value "$SUMMARY_CSV" "cache_hash_verified_rows" "0" "v13-h default cache"
expect_summary_value "$SUMMARY_CSV" "contract_ready_rows" "0" "v13-h default contract"
expect_summary_value "$SUMMARY_CSV" "live_network_verified_rows" "0" "v13-h default live"
expect_summary_value "$SUMMARY_CSV" "real_evidence_declared_rows" "0" "v13-h default real declarations"
expect_summary_value "$SUMMARY_CSV" "real_evidence_ready_rows" "0" "v13-h default real rows"
expect_summary_value "$SUMMARY_CSV" "real_evidence_intake_contract_ready" "0" "v13-h default contract ready"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_intake_ready" "0" "v13-h default candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-h default release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-intake-cache-hash-mismatch" "v13-h default action"

write_fixture_package
V13_REAL_EVIDENCE_INTAKE_CSV="$FIXTURE_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_intake_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "intake_source" "provided-intake-csv" "v13-h fixture source"
expect_summary_value "$SUMMARY_CSV" "intake_rows" "4" "v13-h fixture rows"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "4" "v13-h fixture required rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_or_unknown_rows" "0" "v13-h fixture duplicate rows"
expect_summary_value "$SUMMARY_CSV" "run_id_match_rows" "4" "v13-h fixture run binding"
expect_summary_value "$SUMMARY_CSV" "cache_hash_verified_rows" "4" "v13-h fixture cache hash"
expect_summary_value "$SUMMARY_CSV" "https_source_rows" "4" "v13-h fixture source URI"
expect_summary_value "$SUMMARY_CSV" "https_review_rows" "4" "v13-h fixture review URI"
expect_summary_value "$SUMMARY_CSV" "https_authority_rows" "4" "v13-h fixture authority URI"
expect_summary_value "$SUMMARY_CSV" "contract_ready_rows" "4" "v13-h fixture contract"
expect_summary_value "$SUMMARY_CSV" "live_network_verified_rows" "0" "v13-h fixture live"
expect_summary_value "$SUMMARY_CSV" "real_evidence_declared_rows" "4" "v13-h fixture declarations"
expect_summary_value "$SUMMARY_CSV" "real_evidence_ready_rows" "0" "v13-h fixture real ready"
expect_summary_value "$SUMMARY_CSV" "real_evidence_intake_contract_ready" "1" "v13-h fixture contract ready"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_intake_ready" "0" "v13-h fixture candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-h fixture release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-intake-await-live-network-verification" "v13-h fixture action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-h fixture routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-h fixture jump"

expect_decision_status "$DECISION_CSV" "promotion-gate-binding" "pass"
expect_decision_status "$DECISION_CSV" "required-weakness-rows" "pass"
expect_decision_status "$DECISION_CSV" "run-id-binding" "pass"
expect_decision_status "$DECISION_CSV" "cache-hash-binding" "pass"
expect_decision_status "$DECISION_CSV" "contract-flags" "pass"
expect_decision_status "$DECISION_CSV" "https-authority-chain" "pass"
expect_decision_status "$DECISION_CSV" "live-network-verification" "blocked"
expect_decision_status "$DECISION_CSV" "candidate-real-intake" "blocked"
expect_decision_status "$DECISION_CSV" "v13-real-evidence-intake" "blocked"

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
    if ($idx["contract_ready"] != "1") die("v13-h fixture row should be contract ready", 20)
    if ($idx["real_evidence_ready"] != "0") die("v13-h fixture row should not become real without live verification", 21)
  }
  END {
    if (rows != 4) die("expected four v13-h intake rows", 22)
  }
' "$PACKET_DIR/intake_rows.csv"

cp "$FIXTURE_CSV" "$BAD_HASH_CSV"
printf '\n' >>"$FIXTURE_DIR/artifacts/gpu_speedup.json"
V13_REAL_EVIDENCE_INTAKE_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_intake_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "cache_hash_verified_rows" "3" "v13-h bad hash rows"
expect_summary_value "$SUMMARY_CSV" "real_evidence_intake_contract_ready" "0" "v13-h bad hash contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-intake-cache-hash-mismatch" "v13-h bad hash action"

awk -F, 'NR == 1 || $2 != "real_nlg"' "$FIXTURE_CSV" >"$MISSING_ROW_CSV"
V13_REAL_EVIDENCE_INTAKE_CSV="$MISSING_ROW_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_intake_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "intake_rows" "3" "v13-h missing row count"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "3" "v13-h missing required rows"
expect_summary_value "$SUMMARY_CSV" "real_evidence_intake_contract_ready" "0" "v13-h missing contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-intake-required-weakness-rows-missing" "v13-h missing action"

write_fixture_package
V13_REAL_EVIDENCE_INTAKE_CSV="$FIXTURE_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_intake_gate.sh" --smoke >/dev/null

echo "v13 real evidence intake gate smoke passed"
