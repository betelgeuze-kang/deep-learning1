#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_result_authority_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_result_authority_gate_smoke_decision.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
LOCAL_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_final_review_fixture.csv"
REMOTE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_result_authority_final_review_fixture.csv"
SOURCE_IMPORT_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_remote_contract_fixture.csv"
LIVE_VERIFIER_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_verifier_fixture.csv"
LIVE_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_review_fixture.csv"
AUTHORITY_REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_authoritative_review_fixture.csv"
PUBLIC_REGISTRY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_public_registry_fixture.csv"
LIVE_REGISTRY_QUERY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_query_fixture.csv"
LIVE_REGISTRY_FETCH_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_fetcher_fetch_fixture.csv"
NETWORK_PROOF_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_live_registry_network_proof_fixture.csv"
REAL_VERIFICATION_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_official_authority_real_verification_fixture.csv"
OFFICIAL_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_official_authority_fixture.csv"
REAL_OFFICIAL_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_source_import_real_official_authority_fixture.csv"
RESULT_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_result_authority_fixture.csv"
BAD_RESULT_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_bad_result_authority_fixture.csv"
MALFORMED_RESULT_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_malformed_result_authority_fixture.csv"

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
      if (!(field in idx)) die("missing v08-x summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-x summary row", 4)
    }
  ' "$summary_csv"
}

csv_lookup() {
  local csv="$1"
  local family="$2"
  local column="$3"

  awk -F, -v family="$family" -v column="$column" '
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      if (!("benchmark_family" in idx)) exit 2
      if (!(column in idx)) exit 3
      next
    }
    $idx["benchmark_family"] == family {
      print $idx[column]
      found = 1
      exit
    }
    END {
      if (!found) exit 4
    }
  ' "$csv"
}

sha_text_uri() {
  local text="$1"
  printf 'sha256:%s\n' "$(printf '%s' "$text" | sha256sum | awk '{print $1}')"
}

slugify() {
  local value="$1"
  printf '%s\n' "$value" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-//; s/-$//'
}

make_remote_review_csv() {
  awk -F, -v OFS=, '
    function slugify(value, out) {
      out = tolower(value)
      gsub(/[^a-z0-9]+/, "-", out)
      gsub(/^-|-$/, "", out)
      return out
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("benchmark_family review_report_uri reviewer_identity_uri reviewer_conflict_disclosure_uri real_benchmark_source_declared fixture_or_synthetic_declared", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) {
          print "missing v08-x final review fixture column: " required[i] > "/dev/stderr"
          exit 2
        }
      }
      print $0, "review_report_hash_attested", "reviewer_identity_hash_attested", "reviewer_conflict_disclosure_hash_attested"
      next
    }
    {
      family_slug = slugify($idx["benchmark_family"])
      $idx["review_report_uri"] = "https://benchmarks.example.invalid/v08/final-review/" family_slug ".json"
      $idx["reviewer_identity_uri"] = "https://benchmarks.example.invalid/v08/reviewer/" family_slug "-identity.json"
      $idx["reviewer_conflict_disclosure_uri"] = "https://benchmarks.example.invalid/v08/reviewer/" family_slug "-conflict.json"
      $idx["real_benchmark_source_declared"] = 1
      $idx["fixture_or_synthetic_declared"] = 0
      print $0, 1, 1, 1
    }
  ' "$LOCAL_REVIEW_CSV" >"$REMOTE_REVIEW_CSV"
}

make_result_authority_csv() {
  local authority_csv="$1"
  local fixture_declared="$2"
  local domain="result-authority-benchmarks.org"

  {
    echo "benchmark_family,benchmark_result_id,official_result_authority_id,official_result_authority_domain,leaderboard_uri,leaderboard_hash,result_record_uri,result_record_hash,result_artifact_uri,result_artifact_hash,metric_definition_uri,metric_definition_hash,evaluation_protocol_uri,evaluation_protocol_hash,submitter_identity_uri,submitter_identity_hash,authority_review_uri,authority_review_hash,reviewed_result_uri,reviewed_provenance_hash,reviewed_evaluator_output_hash,reviewed_run_log_hash,reviewed_metric_value,official_leaderboard_declared,official_metric_declared,independent_result_review,live_result_observed,real_result_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
    for family in RULER LongBench codebase-retrieval real-document-qa; do
      family_slug="$(slugify "$family")"
      result_uri="$(csv_lookup "$REMOTE_EVIDENCE_CSV" "$family" result_uri)"
      provenance_hash="$(csv_lookup "$REMOTE_EVIDENCE_CSV" "$family" provenance_hash)"
      output_hash="$(csv_lookup "$REMOTE_EXECUTION_CSV" "$family" evaluator_output_hash)"
      run_log_hash="$(csv_lookup "$REMOTE_EXECUTION_CSV" "$family" run_log_hash)"
      metric_value="$(csv_lookup "$REMOTE_EXECUTION_CSV" "$family" metric_value)"

      benchmark_result_id="official-result-${family_slug}"
      official_result_authority_id="official-result-authority-${family_slug}"
      leaderboard_uri="https://${domain}/v08/results/leaderboard/${family_slug}.json"
      result_record_uri="https://${domain}/v08/results/record/${family_slug}.json"
      result_artifact_uri="https://${domain}/v08/results/artifact/${family_slug}.json"
      metric_definition_uri="https://${domain}/v08/results/metric/${family_slug}.json"
      evaluation_protocol_uri="https://${domain}/v08/results/protocol/${family_slug}.json"
      submitter_identity_uri="https://${domain}/v08/results/submitter/${family_slug}-identity.json"
      authority_review_uri="https://${domain}/v08/results/review/${family_slug}.json"
      leaderboard_hash="$(sha_text_uri "leaderboard|${family}|${metric_value}")"
      result_record_hash="$(sha_text_uri "result-record|${family}|${result_uri}|${metric_value}")"
      result_artifact_hash="$(sha_text_uri "result-artifact|${family}|${provenance_hash}")"
      metric_definition_hash="$(sha_text_uri "metric-definition|${family}")"
      evaluation_protocol_hash="$(sha_text_uri "evaluation-protocol|${family}")"
      submitter_identity_hash="$(sha_text_uri "submitter|${family}|route-memory")"
      authority_review_hash="$(sha_text_uri "result-authority-review|${family}|${run_log_hash}")"

      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,1,1,1,1,1,%d,1,0,0\n" \
        "$family" \
        "$benchmark_result_id" \
        "$official_result_authority_id" \
        "$domain" \
        "$leaderboard_uri" \
        "$leaderboard_hash" \
        "$result_record_uri" \
        "$result_record_hash" \
        "$result_artifact_uri" \
        "$result_artifact_hash" \
        "$metric_definition_uri" \
        "$metric_definition_hash" \
        "$evaluation_protocol_uri" \
        "$evaluation_protocol_hash" \
        "$submitter_identity_uri" \
        "$submitter_identity_hash" \
        "$authority_review_uri" \
        "$authority_review_hash" \
        "$result_uri" \
        "$provenance_hash" \
        "$output_hash" \
        "$run_log_hash" \
        "$metric_value" \
        "$fixture_declared"
    done
  } >"$authority_csv"
}

run_v08x_with_verified_upstream() {
  local result_authority_csv="${1:-}"

  if [[ -n "$result_authority_csv" ]]; then
    V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV="$result_authority_csv" \
    V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
    V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
    V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
    V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
    V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
    V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV="$REMOTE_REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV="$LIVE_REGISTRY_QUERY_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV="$NETWORK_PROOF_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV="$REAL_VERIFICATION_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_OFFICIAL_AUTHORITY_CSV="$REAL_OFFICIAL_AUTHORITY_CSV" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_result_authority_gate.sh" --smoke
  else
    V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
    V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
    V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
    V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
    V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
    V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV="$REMOTE_REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV="$LIVE_REGISTRY_QUERY_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV="$NETWORK_PROOF_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV="$REAL_VERIFICATION_CSV" \
    V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_OFFICIAL_AUTHORITY_CSV="$REAL_OFFICIAL_AUTHORITY_CSV" \
      "$ROOT_DIR/experiments/run_v08_external_benchmark_result_authority_gate.sh" --smoke
  fi
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_result_authority_gate.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08x" "default v08-x scope"
expect_summary_value "$SUMMARY_CSV" "final_review_verified" "0" "default v08-x should block before final review"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_review_ready" "0" "default v08-x should not have result-authority review"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_ready" "0" "default v08-x should not verify result authority"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-x must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-attestor-identity-missing" "default v08-x action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_source_import_official_authority_gate.sh" >/dev/null
"$ROOT_DIR/experiments/test_v08_external_benchmark_final_review_import.sh" >/dev/null

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["fixture_or_synthetic_declared"] = 0
    print
  }
' "$OFFICIAL_AUTHORITY_CSV" >"$REAL_OFFICIAL_AUTHORITY_CSV"

make_remote_review_csv
run_v08x_with_verified_upstream ""

expect_summary_value "$SUMMARY_CSV" "final_review_verified" "1" "v08-x upstream final review should pass with verified source import"
expect_summary_value "$SUMMARY_CSV" "upstream_real_external_benchmark_verified" "1" "v08-x should observe upstream benchmark verification before result-authority layer"
expect_summary_value "$SUMMARY_CSV" "result_authority_rows" "0" "v08-x should have no result authority rows before evidence"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_review_ready" "0" "v08-x should block before result authority review"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_ready" "0" "v08-x should block before official result authority"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-x must downgrade benchmark verification until result authority exists"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-result-authority-missing" "v08-x should ask for official result authority evidence"

make_result_authority_csv "$RESULT_AUTHORITY_CSV" 1
run_v08x_with_verified_upstream "$RESULT_AUTHORITY_CSV"

expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_source" "provided-csv" "v08-x result authority should be provided"
expect_summary_value "$SUMMARY_CSV" "result_authority_rows" "4" "v08-x result authority fixture should have rows"
expect_summary_value "$SUMMARY_CSV" "matched_evidence_rows" "4" "v08-x result authority should match evidence rows"
expect_summary_value "$SUMMARY_CSV" "matched_execution_rows" "4" "v08-x result authority should match execution rows"
expect_summary_value "$SUMMARY_CSV" "result_uri_match_rows" "4" "v08-x result authority should bind result URIs"
expect_summary_value "$SUMMARY_CSV" "provenance_hash_match_rows" "4" "v08-x result authority should bind provenance hashes"
expect_summary_value "$SUMMARY_CSV" "evaluator_output_hash_match_rows" "4" "v08-x result authority should bind evaluator output hashes"
expect_summary_value "$SUMMARY_CSV" "run_log_hash_match_rows" "4" "v08-x result authority should bind run log hashes"
expect_summary_value "$SUMMARY_CSV" "metric_value_match_rows" "4" "v08-x result authority should bind metric values"
expect_summary_value "$SUMMARY_CSV" "result_authority_artifact_rows" "4" "v08-x result authority fixture should have metadata"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_result_authority_artifact_rows" "4" "v08-x result authority fixture should use non-placeholder authority URIs"
expect_summary_value "$SUMMARY_CSV" "result_authority_hash_attestation_rows" "4" "v08-x result authority fixture should have hash attestations"
expect_summary_value "$SUMMARY_CSV" "result_authority_domain_match_rows" "4" "v08-x result authority fixture should match authority domains"
expect_summary_value "$SUMMARY_CSV" "official_leaderboard_rows" "4" "v08-x fixture can exercise official leaderboard flags"
expect_summary_value "$SUMMARY_CSV" "official_metric_rows" "4" "v08-x fixture can exercise official metric flags"
expect_summary_value "$SUMMARY_CSV" "independent_result_review_rows" "4" "v08-x fixture can exercise independent review flags"
expect_summary_value "$SUMMARY_CSV" "live_result_observed_rows" "4" "v08-x fixture can exercise live-observed flags"
expect_summary_value "$SUMMARY_CSV" "declared_real_result_rows" "4" "v08-x fixture can exercise real declaration flags"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "0" "v08-x fixture must not count as non-fixture"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_review_ready" "1" "v08-x fixture should satisfy review mechanics"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_ready" "0" "v08-x fixture must not satisfy real result authority"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-x fixture must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-result-authority-fixture-only" "v08-x fixture should block at fixture-only"

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
    if ($idx["gate"] == "final-review" && $idx["status"] != "pass") die("v08-x final review should pass", 20)
    if ($idx["gate"] == "result-authority-rows" && $idx["status"] != "pass") die("v08-x result authority rows should pass", 21)
    if ($idx["gate"] == "result-authority-result-binding" && $idx["status"] != "pass") die("v08-x result binding should pass", 22)
    if ($idx["gate"] == "result-authority-artifacts" && $idx["status"] != "pass") die("v08-x result authority artifacts should pass", 23)
    if ($idx["gate"] == "result-authority-trust-root" && $idx["status"] != "blocked") die("v08-x fixture trust-root should block at non-fixture", 24)
    if ($idx["gate"] == "external-benchmark-result-authority" && $idx["status"] != "blocked") die("v08-x result authority should block", 25)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-x real benchmark should block", 26)
  }
  END {
    if (rows != 7) die("expected seven v08-x decision rows", 27)
  }
' "$DECISION_CSV"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  {
    $idx["reviewed_metric_value"] = "0.000000"
    print
  }
' "$RESULT_AUTHORITY_CSV" >"$BAD_RESULT_AUTHORITY_CSV"

run_v08x_with_verified_upstream "$BAD_RESULT_AUTHORITY_CSV"

expect_summary_value "$SUMMARY_CSV" "final_review_verified" "1" "v08-x bad result authority should preserve final review readiness"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_review_ready" "0" "v08-x bad result authority should block review readiness"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_result_authority_ready" "0" "v08-x bad result authority should block result authority"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-result-authority-result-mismatch" "v08-x bad result authority should block at result mismatch"

{
  head -n 1 "$RESULT_AUTHORITY_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$RESULT_AUTHORITY_CSV")"
} >"$MALFORMED_RESULT_AUTHORITY_CSV"

if V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV="$MALFORMED_RESULT_AUTHORITY_CSV" \
   V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
   V08_EXTERNAL_BENCHMARK_AUTHENTICITY_CSV="$REMOTE_AUTHENTICITY_CSV" \
   V08_EXTERNAL_BENCHMARK_EXECUTION_CSV="$REMOTE_EXECUTION_CSV" \
   V08_EXTERNAL_BENCHMARK_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
   V08_EXTERNAL_BENCHMARK_ATTESTOR_IDENTITY_CSV="$REMOTE_IDENTITY_CSV" \
   V08_EXTERNAL_BENCHMARK_FINAL_REVIEW_CSV="$REMOTE_REVIEW_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_CSV="$SOURCE_IMPORT_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_VERIFIER_CSV="$LIVE_VERIFIER_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REVIEW_CSV="$LIVE_REVIEW_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_AUTHORITY_REVIEW_CSV="$AUTHORITY_REVIEW_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_PUBLIC_REGISTRY_CSV="$PUBLIC_REGISTRY_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_QUERY_CSV="$LIVE_REGISTRY_QUERY_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_FETCH_CSV="$LIVE_REGISTRY_FETCH_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_LIVE_REGISTRY_NETWORK_PROOF_CSV="$NETWORK_PROOF_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_REAL_VERIFICATION_CSV="$REAL_VERIFICATION_CSV" \
   V08_EXTERNAL_BENCHMARK_SOURCE_IMPORT_OFFICIAL_AUTHORITY_CSV="$REAL_OFFICIAL_AUTHORITY_CSV" \
   "$ROOT_DIR/experiments/run_v08_external_benchmark_result_authority_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "v08-x should reject malformed result authority CSV row widths" >&2
  exit 40
fi

echo "v08 external benchmark result authority smoke passed"
