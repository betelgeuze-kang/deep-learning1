#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_publication_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_publication_gate_smoke_decision.csv"
COMPARISON_CSV="$RESULTS_DIR/v08_external_benchmark_comparison_gate_smoke_comparison.csv"
REMOTE_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_evidence_fixture.csv"
REMOTE_AUTHENTICITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_authenticity_fixture.csv"
REMOTE_EXECUTION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_execution_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_attestation_fixture.csv"
REMOTE_IDENTITY_CSV="$RESULTS_DIR/v08_external_benchmark_lower_chain_remote_identity_fixture.csv"
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
REAL_RESULT_AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_real_result_authority_fixture.csv"
PUBLICATION_CSV="$RESULTS_DIR/v08_external_benchmark_publication_fixture.csv"
PUBLICATION_REAL_CSV="$RESULTS_DIR/v08_external_benchmark_publication_real_fixture.csv"
BAD_PUBLICATION_CSV="$RESULTS_DIR/v08_external_benchmark_bad_publication_fixture.csv"
MALFORMED_PUBLICATION_CSV="$RESULTS_DIR/v08_external_benchmark_malformed_publication_fixture.csv"

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
      if (!(field in idx)) die("missing v08-y summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-y summary row", 4)
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

make_real_csv() {
  local input_csv="$1"
  local output_csv="$2"

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
  ' "$input_csv" >"$output_csv"
}

run_verified_comparison() {
  V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV="$REAL_RESULT_AUTHORITY_CSV" \
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
    "$ROOT_DIR/experiments/run_v08_external_benchmark_comparison_gate.sh" --smoke >/dev/null
}

run_v08y_with_publication() {
  local publication_csv="$1"

  V08_EXTERNAL_BENCHMARK_PUBLICATION_CSV="$publication_csv" \
  V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV="$REAL_RESULT_AUTHORITY_CSV" \
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
    "$ROOT_DIR/experiments/run_v08_external_benchmark_publication_gate.sh" --smoke
}

make_publication_csv() {
  local output_csv="$1"
  local fixture_declared="$2"
  local domain="published-benchmarks.org"

  {
    echo "benchmark_family,publication_package_id,publication_authority_domain,publication_uri,publication_hash,report_uri,report_hash,comparison_table_uri,comparison_table_hash,reproducibility_bundle_uri,reproducibility_bundle_hash,release_license_uri,release_license_hash,conflict_disclosure_uri,conflict_disclosure_hash,publication_review_uri,publication_review_hash,published_leaderboard_uri,published_leaderboard_hash,published_result_record_uri,published_result_record_hash,published_metric_definition_uri,published_metric_definition_hash,published_evaluation_protocol_uri,published_evaluation_protocol_hash,published_comparison_delta,published_comparison_verdict,independent_publication_review,live_publication_observed,real_publication_declared,fixture_or_synthetic_declared,hash_attestation_ready,routing_trigger_rate,active_jump_rate"
    for family in RULER LongBench codebase-retrieval real-document-qa; do
      family_slug="$(slugify "$family")"
      leaderboard_uri="$(csv_lookup "$REAL_RESULT_AUTHORITY_CSV" "$family" leaderboard_uri)"
      leaderboard_hash="$(csv_lookup "$REAL_RESULT_AUTHORITY_CSV" "$family" leaderboard_hash)"
      result_record_uri="$(csv_lookup "$REAL_RESULT_AUTHORITY_CSV" "$family" result_record_uri)"
      result_record_hash="$(csv_lookup "$REAL_RESULT_AUTHORITY_CSV" "$family" result_record_hash)"
      metric_definition_uri="$(csv_lookup "$REAL_RESULT_AUTHORITY_CSV" "$family" metric_definition_uri)"
      metric_definition_hash="$(csv_lookup "$REAL_RESULT_AUTHORITY_CSV" "$family" metric_definition_hash)"
      protocol_uri="$(csv_lookup "$REAL_RESULT_AUTHORITY_CSV" "$family" evaluation_protocol_uri)"
      protocol_hash="$(csv_lookup "$REAL_RESULT_AUTHORITY_CSV" "$family" evaluation_protocol_hash)"
      delta="$(csv_lookup "$COMPARISON_CSV" "$family" delta)"
      verdict="$(csv_lookup "$COMPARISON_CSV" "$family" verdict)"

      package_id="publication-${family_slug}"
      publication_uri="https://${domain}/v08/publication/${family_slug}/package.json"
      report_uri="https://${domain}/v08/publication/${family_slug}/report.md"
      comparison_table_uri="https://${domain}/v08/publication/${family_slug}/comparison.csv"
      reproducibility_bundle_uri="https://${domain}/v08/publication/${family_slug}/reproducibility.tar.zst"
      release_license_uri="https://${domain}/v08/publication/${family_slug}/license.json"
      conflict_disclosure_uri="https://${domain}/v08/publication/${family_slug}/conflict-disclosure.json"
      publication_review_uri="https://${domain}/v08/publication/${family_slug}/review.json"
      publication_hash="$(sha_text_uri "publication|${family}|${leaderboard_hash}|${delta}")"
      report_hash="$(sha_text_uri "report|${family}|${verdict}")"
      comparison_table_hash="$(sha_text_uri "comparison-table|${family}|${delta}|${verdict}")"
      reproducibility_bundle_hash="$(sha_text_uri "reproducibility|${family}|${result_record_hash}")"
      release_license_hash="$(sha_text_uri "license|${family}|permissive")"
      conflict_disclosure_hash="$(sha_text_uri "conflict|${family}|independent")"
      publication_review_hash="$(sha_text_uri "publication-review|${family}|${publication_hash}")"

      printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,1,1,1,%d,1,0,0\n" \
        "$family" \
        "$package_id" \
        "$domain" \
        "$publication_uri" \
        "$publication_hash" \
        "$report_uri" \
        "$report_hash" \
        "$comparison_table_uri" \
        "$comparison_table_hash" \
        "$reproducibility_bundle_uri" \
        "$reproducibility_bundle_hash" \
        "$release_license_uri" \
        "$release_license_hash" \
        "$conflict_disclosure_uri" \
        "$conflict_disclosure_hash" \
        "$publication_review_uri" \
        "$publication_review_hash" \
        "$leaderboard_uri" \
        "$leaderboard_hash" \
        "$result_record_uri" \
        "$result_record_hash" \
        "$metric_definition_uri" \
        "$metric_definition_hash" \
        "$protocol_uri" \
        "$protocol_hash" \
        "$delta" \
        "$verdict" \
        "$fixture_declared"
    done
  } >"$output_csv"
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_publication_gate.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "benchmark_scope" "route-memory-v08y" "default v08-y scope"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_publication_review_ready" "0" "default v08-y should not have publication review"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_publication_ready" "0" "default v08-y should not publish"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-y must not verify benchmark publication"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-upstream-missing" "default v08-y action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_result_authority_gate.sh" >/dev/null
make_real_csv "$OFFICIAL_AUTHORITY_CSV" "$REAL_OFFICIAL_AUTHORITY_CSV"
make_real_csv "$RESULT_AUTHORITY_CSV" "$REAL_RESULT_AUTHORITY_CSV"

V08_EXTERNAL_BENCHMARK_EVIDENCE_CSV="$REMOTE_EVIDENCE_CSV" \
  "$ROOT_DIR/experiments/run_v08_external_benchmark_evidence_ingestion.sh" --smoke >/dev/null
run_verified_comparison

make_publication_csv "$PUBLICATION_CSV" 1
run_v08y_with_publication "$PUBLICATION_CSV"

expect_summary_value "$SUMMARY_CSV" "upstream_real_external_benchmark_verified" "1" "v08-y should observe verified upstream result authority"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_publication_source" "provided-csv" "v08-y publication source should be provided"
expect_summary_value "$SUMMARY_CSV" "benchmark_comparison_ready" "1" "v08-y comparison should be diagnostic-ready"
expect_summary_value "$SUMMARY_CSV" "publishable_comparison_ready" "0" "v08-y comparison should remain unpublished before promotion"
expect_summary_value "$SUMMARY_CSV" "publication_rows" "4" "v08-y fixture should have publication rows"
expect_summary_value "$SUMMARY_CSV" "matched_result_authority_rows" "4" "v08-y fixture should match result authority"
expect_summary_value "$SUMMARY_CSV" "matched_comparison_rows" "4" "v08-y fixture should match comparison rows"
expect_summary_value "$SUMMARY_CSV" "leaderboard_match_rows" "4" "v08-y fixture should bind leaderboard rows"
expect_summary_value "$SUMMARY_CSV" "result_record_match_rows" "4" "v08-y fixture should bind result records"
expect_summary_value "$SUMMARY_CSV" "metric_definition_match_rows" "4" "v08-y fixture should bind metric definitions"
expect_summary_value "$SUMMARY_CSV" "evaluation_protocol_match_rows" "4" "v08-y fixture should bind protocols"
expect_summary_value "$SUMMARY_CSV" "comparison_delta_match_rows" "4" "v08-y fixture should bind comparison deltas"
expect_summary_value "$SUMMARY_CSV" "comparison_verdict_match_rows" "4" "v08-y fixture should bind comparison verdicts"
expect_summary_value "$SUMMARY_CSV" "publication_artifact_rows" "4" "v08-y fixture should have publication artifacts"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_publication_artifact_rows" "4" "v08-y fixture should use non-placeholder publication URIs"
expect_summary_value "$SUMMARY_CSV" "publication_hash_attestation_rows" "4" "v08-y fixture should have hash attestations"
expect_summary_value "$SUMMARY_CSV" "publication_domain_match_rows" "4" "v08-y fixture should match publication domains"
expect_summary_value "$SUMMARY_CSV" "reproducibility_bundle_rows" "4" "v08-y fixture should include reproducibility bundles"
expect_summary_value "$SUMMARY_CSV" "independent_publication_review_rows" "4" "v08-y fixture should include independent publication review"
expect_summary_value "$SUMMARY_CSV" "live_publication_observed_rows" "4" "v08-y fixture should include live publication observation"
expect_summary_value "$SUMMARY_CSV" "declared_real_publication_rows" "4" "v08-y fixture should declare real publication"
expect_summary_value "$SUMMARY_CSV" "non_fixture_declared_rows" "0" "v08-y fixture should remain fixture-declared"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_publication_review_ready" "1" "v08-y fixture should satisfy publication review mechanics"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_publication_ready" "0" "v08-y fixture must not satisfy real publication"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-y fixture must not publish benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-fixture-only" "v08-y fixture action"

make_publication_csv "$PUBLICATION_REAL_CSV" 0
run_v08y_with_publication "$PUBLICATION_REAL_CSV"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_publication_review_ready" "1" "v08-y non-fixture fixture should satisfy review mechanics"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_publication_ready" "0" "v08-y should still block without publishable comparison"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-y should still block external benchmark verification"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-comparison-not-publishable" "v08-y should require publishable comparison"

awk -F, -v OFS=, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    print
    next
  }
  NR == 2 {
    $idx["published_comparison_delta"] = "999.000000"
  }
  { print }
' "$PUBLICATION_REAL_CSV" >"$BAD_PUBLICATION_CSV"

run_v08y_with_publication "$BAD_PUBLICATION_CSV"
expect_summary_value "$SUMMARY_CSV" "comparison_delta_match_rows" "3" "v08-y bad publication should lose one comparison delta match"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_publication_review_ready" "0" "v08-y bad publication should block review readiness"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-publication-binding-mismatch" "v08-y bad publication action"

{
  head -n 1 "$PUBLICATION_REAL_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$PUBLICATION_REAL_CSV")"
} >"$MALFORMED_PUBLICATION_CSV"

if V08_EXTERNAL_BENCHMARK_PUBLICATION_CSV="$MALFORMED_PUBLICATION_CSV" \
   V08_EXTERNAL_BENCHMARK_RESULT_AUTHORITY_CSV="$REAL_RESULT_AUTHORITY_CSV" \
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
   "$ROOT_DIR/experiments/run_v08_external_benchmark_publication_gate.sh" --smoke >/dev/null 2>/dev/null; then
  echo "malformed v08-y publication CSV unexpectedly passed" >&2
  exit 60
fi

awk -F, '
  NR == 1 {
    for (i = 1; i <= NF; i++) idx[$i] = i
    next
  }
  {
    rows++
    if ($idx["gate"] == "external-benchmark-publication" && $idx["status"] != "blocked") {
      print "v08-y fixture publication should remain blocked" > "/dev/stderr"
      exit 70
    }
  }
  END {
    if (rows != 7) {
      print "expected v08-y decision rows" > "/dev/stderr"
      exit 71
    }
  }
' "$DECISION_CSV"

echo "v08 external benchmark publication gate smoke passed"
