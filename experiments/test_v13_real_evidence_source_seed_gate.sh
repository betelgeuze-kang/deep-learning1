#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_evidence_source_seed_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_evidence_source_seed_gate_smoke_decision.csv"
PACKET_DIR="$RESULTS_DIR/v13_real_evidence_source_seed_gate_smoke_packet/run_001"
SEED_CSV="$RESULTS_DIR/v13_real_evidence_source_seed_gate_smoke_seed.csv"
BAD_CACHE_CSV="$RESULTS_DIR/v13_real_evidence_source_seed_bad_cache.csv"
PROMOTED_NO_FETCH_CSV="$RESULTS_DIR/v13_real_evidence_source_seed_promoted_no_fetch.csv"

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
      if (!(field in idx)) die("missing v13-l summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-l summary row", 4)
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
      if ($idx["status"] != expected) die("v13-l decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v13-l decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_real_evidence_source_seed_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "seed_source" "generated-current-source-seed" "v13-l default seed source"
expect_summary_value "$SUMMARY_CSV" "seed_rows" "4" "v13-l default rows"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "4" "v13-l default required rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_or_unknown_rows" "0" "v13-l default duplicate rows"
expect_summary_value "$SUMMARY_CSV" "cache_hash_verified_rows" "4" "v13-l default cache"
expect_summary_value "$SUMMARY_CSV" "https_triad_rows" "4" "v13-l default https"
expect_summary_value "$SUMMARY_CSV" "official_benchmark_seed_rows" "1" "v13-l default external benchmark seed"
expect_summary_value "$SUMMARY_CSV" "project_source_only_rows" "3" "v13-l default project-source blockers"
expect_summary_value "$SUMMARY_CSV" "claim_evidence_class_rows" "0" "v13-l default claim class"
expect_summary_value "$SUMMARY_CSV" "live_fetch_candidate_rows" "4" "v13-l default live candidates"
expect_summary_value "$SUMMARY_CSV" "live_fetch_verified_receipts" "0" "v13-l default no live fetch"
expect_summary_value "$SUMMARY_CSV" "source_seed_contract_ready" "1" "v13-l default contract"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_source_seed_ready" "0" "v13-l default candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-l default release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-source-seed-await-claim-evidence" "v13-l default action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-l default routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-l default jump"

expect_decision_status "$DECISION_CSV" "required-weakness-rows" "pass"
expect_decision_status "$DECISION_CSV" "seed-cache-hashes" "pass"
expect_decision_status "$DECISION_CSV" "https-source-triad" "pass"
expect_decision_status "$DECISION_CSV" "external-benchmark-source-seed" "pass"
expect_decision_status "$DECISION_CSV" "project-source-only-blocker" "blocked"
expect_decision_status "$DECISION_CSV" "claim-evidence-class" "blocked"
expect_decision_status "$DECISION_CSV" "runtime-live-fetch" "blocked"
expect_decision_status "$DECISION_CSV" "candidate-source-seed" "blocked"

awk -F, '
  function die(message, code) {
    print message > "/dev/stderr"
    exit code
  }
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  $idx["weakness_id"] == "external_benchmark" {
    external_seen = 1
    if ($idx["official_benchmark_seed_ready"] != "1") die("external benchmark row should be official source seed", 20)
  }
  $idx["weakness_id"] != "external_benchmark" {
    if ($idx["project_source_only"] != "1") die("non-benchmark rows should stay project-source-only", 21)
  }
  END {
    if (!external_seen) die("missing external benchmark source seed row", 22)
  }
' "$PACKET_DIR/source_seed_rows.csv"

cp "$SEED_CSV" "$BAD_CACHE_CSV"
awk -F, 'BEGIN {OFS=","} NR == 2 {$10="sha256:bad"} {print}' "$BAD_CACHE_CSV" >"$BAD_CACHE_CSV.tmp"
mv "$BAD_CACHE_CSV.tmp" "$BAD_CACHE_CSV"
V13_REAL_EVIDENCE_SOURCE_SEED_CSV="$BAD_CACHE_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_source_seed_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "cache_hash_verified_rows" "3" "v13-l bad cache rows"
expect_summary_value "$SUMMARY_CSV" "source_seed_contract_ready" "0" "v13-l bad cache contract"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-source-seed-cache-hash-mismatch" "v13-l bad cache action"

awk -F, 'BEGIN {OFS=","} NR == 1 {print; next} {$7="official-or-independent-claim-evidence"; $12=1; $13=1; $14=1; $15=1; $16=1; print}' "$SEED_CSV" >"$PROMOTED_NO_FETCH_CSV"
V13_REAL_EVIDENCE_SOURCE_SEED_CSV="$PROMOTED_NO_FETCH_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_source_seed_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "claim_evidence_class_rows" "4" "v13-l promoted no-fetch claim class"
expect_summary_value "$SUMMARY_CSV" "claim_evidence_declared_rows" "4" "v13-l promoted no-fetch claim declaration"
expect_summary_value "$SUMMARY_CSV" "project_source_only_rows" "0" "v13-l promoted no-fetch project blockers"
expect_summary_value "$SUMMARY_CSV" "live_fetch_seed_ready" "0" "v13-l promoted no-fetch live fetch"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_source_seed_ready" "0" "v13-l promoted no-fetch candidate"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-source-seed-await-runtime-fetch" "v13-l promoted no-fetch action"

"$ROOT_DIR/experiments/run_v13_real_evidence_source_seed_gate.sh" --smoke >/dev/null

echo "v13 real evidence source seed gate smoke passed"
