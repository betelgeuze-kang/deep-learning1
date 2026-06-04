#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

ACQUISITION_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_content_fixture.csv"
BRIDGE_CSV="$RESULTS_DIR/v08_external_benchmark_family_result_bridge_bridge_fixture.csv"
REPRODUCTION_CSV="$RESULTS_DIR/v08_external_benchmark_independent_reproduction_review_fixture.csv"
RELEASE_CSV="$RESULTS_DIR/v08_external_benchmark_official_release_evidence_fixture.csv"
LIVE_CSV="$RESULTS_DIR/v08_external_benchmark_live_release_verification_fixture.csv"
CONFIRMATION_UPSTREAM_CSV="$RESULTS_DIR/v08_external_benchmark_canonical_online_confirmation_fixture.csv"
REVIEW_CSV="$RESULTS_DIR/v08_external_benchmark_publication_result_review_fixture.csv"
INGESTION_CSV="$RESULTS_DIR/v08_external_benchmark_live_publication_result_ingestion_fixture.csv"
AUTHORITY_CSV="$RESULTS_DIR/v08_external_benchmark_authority_promotion_evidence_fixture.csv"
INDEPENDENT_EVIDENCE_CSV="$RESULTS_DIR/v08_external_benchmark_independent_run_evaluator_evidence_fixture.csv"
REPLAY_CSV="$RESULTS_DIR/v08_external_benchmark_live_replay_final_review_fixture.csv"
VERIFICATION_CSV="$RESULTS_DIR/v08_external_benchmark_public_nonfixture_verification_fixture.csv"
AUDIT_CSV="$RESULTS_DIR/v08_external_benchmark_runner_owned_live_execution_audit_fixture.csv"
RERUN_CSV="$RESULTS_DIR/v08_external_benchmark_independent_live_rerun_confirmation_fixture.csv"
PACKAGE_CSV="$RESULTS_DIR/v08_external_benchmark_real_nonfixture_run_package_fixture.csv"
FETCH_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_fixture.csv"
BAD_COVERAGE_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_coverage_fixture.csv"
BAD_PLACEHOLDER_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_placeholder_fixture.csv"
BAD_STATUS_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_status_fixture.csv"
BAD_DIGEST_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_digest_fixture.csv"
BAD_BINDING_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_binding_fixture.csv"
BAD_RUNNER_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_runner_declaration_fixture.csv"
BAD_NETWORK_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_network_declaration_fixture.csv"
BAD_AUTHORITY_DECLARATION_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_authority_declaration_fixture.csv"
BAD_JUMP_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_bad_jump_fixture.csv"
SUMMARY_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v08_external_benchmark_live_package_artifact_fetch_authority_smoke_decision.csv"
FAMILIES=("RULER" "LongBench" "codebase-retrieval" "real-document-qa")
ARTIFACT_TYPES=(
  run_package_manifest
  raw_query_set
  raw_prediction_output
  evaluator_container_digest
  evaluator_config
  metric_report
  submission_receipt
  public_archive
  official_leaderboard_entry
  license_review
  pii_review
  third_party_repro_report
  package_signature
  timestamp_authority
  package_registry_entry
)

mkdir -p "$RESULTS_DIR"

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
      if (!(field in idx)) die("missing v08-as summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v08-as summary row", 4)
    }
  ' "$summary_csv"
}

hash_for() {
  printf 'sha256:%s\n' "$(printf '%s' "$1" | sha256sum | awk '{print $1}')"
}

write_fetch_header() {
  echo "benchmark_family,real_run_package_id,artifact_type,fetch_authority_verification_id,v08ar_package_intake_bound,runner_owned_live_fetch_declared,network_fetch_transcript_declared,tls_certificate_verified_declared,dns_resolution_verified_declared,http_status_verified_declared,content_digest_match_declared,authority_registry_verified_declared,official_source_authority_verified_declared,fixture_or_replay_declared,fetch_http_status,fetched_artifact_uri,fetched_artifact_hash,fetch_receipt_uri,fetch_receipt_hash,authority_record_uri,authority_record_hash,observed_at_utc,routing_trigger_rate,active_jump_rate"
}

append_fetch_row() {
  local csv="$1"
  local family="$2"
  local artifact_type="$3"
  local host="${4:-fetch.routebench.dev}"
  local fetch_http_status="${5:-200}"
  local v08ar_bound="${6:-1}"
  local runner_declared="${7:-1}"
  local network_declared="${8:-1}"
  local authority_declared="${9:-1}"
  local digest_declared="${10:-1}"
  local active_jump="${11:-0.000000}"
  local package_id="real-nonfixture-run-package-${family}-20260603"
  local verification_id="live-fetch-authority-${family}-${artifact_type}-20260603"
  local base="https://${host}/benchmarks/${family}/${package_id}/${artifact_type}"

  local fields=(
    "$family" \
    "$package_id" \
    "$artifact_type" \
    "$verification_id" \
    "$v08ar_bound" \
    "$runner_declared" \
    "$network_declared" \
    "$network_declared" \
    "$network_declared" \
    "$network_declared" \
    "$digest_declared" \
    "$authority_declared" \
    "$authority_declared" \
    "0" \
    "$fetch_http_status" \
    "$base/artifact.bin" \
    "$(hash_for "$family-$artifact_type-fetched-artifact")" \
    "$base/fetch_receipt.json" \
    "$(hash_for "$family-$artifact_type-fetch-receipt")" \
    "$base/authority_record.json" \
    "$(hash_for "$family-$artifact_type-authority-record")" \
    "2026-06-03T00:00:00Z" \
    "0.000000" \
    "$active_jump"
  )
  (IFS=,; printf '%s\n' "${fields[*]}") >>"$csv"
}

write_good_fetch_csv() {
  local csv="$1"
  local family
  local artifact_type

  write_fetch_header >"$csv"
  for family in "${FAMILIES[@]}"; do
    for artifact_type in "${ARTIFACT_TYPES[@]}"; do
      append_fetch_row "$csv" "$family" "$artifact_type"
    done
  done
}

write_bad_coverage_csv() {
  local csv="$1"
  local family
  local artifact_type

  write_fetch_header >"$csv"
  for family in "${FAMILIES[@]}"; do
    for artifact_type in "${ARTIFACT_TYPES[@]}"; do
      if [[ "$family" == "real-document-qa" && "$artifact_type" == "package_registry_entry" ]]; then
        continue
      fi
      append_fetch_row "$csv" "$family" "$artifact_type"
    done
  done
}

run_v08as_with_upstream() {
  local fetch_csv="$1"

  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CSV="$ACQUISITION_CSV" \
  V08_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_CONTENT_CSV="$CONTENT_CSV" \
  V08_EXTERNAL_BENCHMARK_FAMILY_RESULT_BRIDGE_CSV="$BRIDGE_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_REPRODUCTION_REVIEW_CSV="$REPRODUCTION_CSV" \
  V08_EXTERNAL_BENCHMARK_OFFICIAL_RELEASE_EVIDENCE_CSV="$RELEASE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_RELEASE_VERIFICATION_CSV="$LIVE_CSV" \
  V08_EXTERNAL_BENCHMARK_CANONICAL_ONLINE_CONFIRMATION_CSV="$CONFIRMATION_UPSTREAM_CSV" \
  V08_EXTERNAL_BENCHMARK_PUBLICATION_RESULT_REVIEW_CSV="$REVIEW_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_PUBLICATION_RESULT_INGESTION_CSV="$INGESTION_CSV" \
  V08_EXTERNAL_BENCHMARK_AUTHORITY_PROMOTION_EVIDENCE_CSV="$AUTHORITY_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_RUN_EVALUATOR_EVIDENCE_CSV="$INDEPENDENT_EVIDENCE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_REPLAY_FINAL_REVIEW_CSV="$REPLAY_CSV" \
  V08_EXTERNAL_BENCHMARK_PUBLIC_NONFIXTURE_VERIFICATION_CSV="$VERIFICATION_CSV" \
  V08_EXTERNAL_BENCHMARK_RUNNER_OWNED_LIVE_EXECUTION_AUDIT_CSV="$AUDIT_CSV" \
  V08_EXTERNAL_BENCHMARK_INDEPENDENT_LIVE_RERUN_CONFIRMATION_CSV="$RERUN_CSV" \
  V08_EXTERNAL_BENCHMARK_REAL_NONFIXTURE_RUN_PACKAGE_CSV="$PACKAGE_CSV" \
  V08_EXTERNAL_BENCHMARK_LIVE_PACKAGE_ARTIFACT_FETCH_AUTHORITY_CSV="$fetch_csv" \
    "$ROOT_DIR/experiments/run_v08_external_benchmark_live_package_artifact_fetch_authority.sh" --smoke
}

"$ROOT_DIR/experiments/run_v08_external_benchmark_live_package_artifact_fetch_authority.sh" --smoke
expect_summary_value "$SUMMARY_CSV" "fetch_source" "pending-csv" "default v08-as source"
expect_summary_value "$SUMMARY_CSV" "upstream_real_nonfixture_run_package_intake_ready" "0" "default v08-as upstream should block"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "default v08-as should block"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "default v08-as must not verify external benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-real-nonfixture-run-package-intake-not-ready" "default v08-as action"

"$ROOT_DIR/experiments/test_v08_external_benchmark_real_nonfixture_run_package.sh" >/dev/null
write_good_fetch_csv "$FETCH_CSV"
run_v08as_with_upstream "$FETCH_CSV" >/dev/null

expect_summary_value "$SUMMARY_CSV" "fetch_source" "provided-csv" "v08-as fetch source"
expect_summary_value "$SUMMARY_CSV" "upstream_real_nonfixture_run_package_intake_ready" "1" "v08-as upstream package intake"
expect_summary_value "$SUMMARY_CSV" "fetch_rows" "60" "v08-as fetch rows"
expect_summary_value "$SUMMARY_CSV" "expected_artifact_rows" "60" "v08-as expected artifact rows"
expect_summary_value "$SUMMARY_CSV" "expected_family_rows" "60" "v08-as expected family rows"
expect_summary_value "$SUMMARY_CSV" "unexpected_artifact_type_rows" "0" "v08-as unexpected artifact rows"
expect_summary_value "$SUMMARY_CSV" "duplicate_artifact_rows" "0" "v08-as duplicate artifact rows"
expect_summary_value "$SUMMARY_CSV" "family_coverage" "4" "v08-as family coverage"
expect_summary_value "$SUMMARY_CSV" "artifact_type_coverage" "60" "v08-as artifact coverage"
expect_summary_value "$SUMMARY_CSV" "required_live_fetch_uri_fields" "180" "v08-as required URI fields"
expect_summary_value "$SUMMARY_CSV" "nonlocal_live_fetch_uri_fields" "180" "v08-as nonlocal URI fields"
expect_summary_value "$SUMMARY_CSV" "local_live_fetch_uri_fields" "0" "v08-as local URI fields"
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_live_fetch_uri_fields" "180" "v08-as non-placeholder URI fields"
expect_summary_value "$SUMMARY_CSV" "required_live_fetch_hash_fields" "180" "v08-as required hash fields"
expect_summary_value "$SUMMARY_CSV" "live_fetch_hash_attested_fields" "180" "v08-as hash attestations"
expect_summary_value "$SUMMARY_CSV" "http_status_pass_rows" "60" "v08-as http status rows"
expect_summary_value "$SUMMARY_CSV" "content_digest_match_declared_rows" "60" "v08-as digest rows"
expect_summary_value "$SUMMARY_CSV" "v08ar_package_intake_bound_rows" "60" "v08-as v08-ar binding"
expect_summary_value "$SUMMARY_CSV" "runner_owned_live_fetch_declared_rows" "60" "v08-as runner declaration"
expect_summary_value "$SUMMARY_CSV" "network_fetch_transcript_declared_rows" "60" "v08-as network transcript declaration"
expect_summary_value "$SUMMARY_CSV" "tls_certificate_verified_declared_rows" "60" "v08-as tls declaration"
expect_summary_value "$SUMMARY_CSV" "dns_resolution_verified_declared_rows" "60" "v08-as dns declaration"
expect_summary_value "$SUMMARY_CSV" "http_status_verified_declared_rows" "60" "v08-as http declaration"
expect_summary_value "$SUMMARY_CSV" "authority_registry_verified_declared_rows" "60" "v08-as registry declaration"
expect_summary_value "$SUMMARY_CSV" "official_source_authority_verified_declared_rows" "60" "v08-as official authority declaration"
expect_summary_value "$SUMMARY_CSV" "fixture_free_rows" "60" "v08-as fixture-free rows"
expect_summary_value "$SUMMARY_CSV" "timestamp_rows" "60" "v08-as timestamp rows"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "1" "v08-as ready"
expect_summary_value "$SUMMARY_CSV" "real_external_benchmark_verified" "0" "v08-as supplied fetch must not verify benchmark"
expect_summary_value "$SUMMARY_CSV" "action" "live-package-artifact-fetch-authority-ready-await-official-result-reconciliation" "v08-as good action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v08-as routing should stay zero"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v08-as jump should stay zero"

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
    if ($idx["gate"] == "upstream-real-nonfixture-run-package-intake" && $idx["status"] != "pass") die("v08-as upstream should pass", 20)
    if ($idx["gate"] == "live-package-artifact-fetch-coverage" && $idx["status"] != "pass") die("v08-as coverage should pass", 21)
    if ($idx["gate"] == "live-package-artifact-fetch-artifacts" && $idx["status"] != "pass") die("v08-as artifacts should pass", 22)
    if ($idx["gate"] == "live-package-artifact-fetch-http-status" && $idx["status"] != "pass") die("v08-as http should pass", 23)
    if ($idx["gate"] == "live-package-artifact-fetch-content-digest" && $idx["status"] != "pass") die("v08-as digest should pass", 24)
    if ($idx["gate"] == "live-package-artifact-fetch-bindings" && $idx["status"] != "pass") die("v08-as binding should pass", 25)
    if ($idx["gate"] == "runner-live-fetch-declarations" && $idx["status"] != "pass") die("v08-as runner declaration should pass", 26)
    if ($idx["gate"] == "network-proof-declarations" && $idx["status"] != "pass") die("v08-as network declaration should pass", 27)
    if ($idx["gate"] == "authority-verification-declarations" && $idx["status"] != "pass") die("v08-as authority declaration should pass", 28)
    if ($idx["gate"] == "fixture-declarations" && $idx["status"] != "pass") die("v08-as fixture declaration should pass", 29)
    if ($idx["gate"] == "external-benchmark-live-package-artifact-fetch-authority" && $idx["status"] != "pass") die("v08-as ready should pass", 30)
    if ($idx["gate"] == "real-external-benchmark" && $idx["status"] != "blocked") die("v08-as real benchmark should remain blocked", 31)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("v08-as jump guardrail should pass", 32)
  }
  END {
    if (rows != 13) die("expected v08-as decision rows", 33)
  }
' "$DECISION_CSV"

write_bad_coverage_csv "$BAD_COVERAGE_CSV"
run_v08as_with_upstream "$BAD_COVERAGE_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "fetch_rows" "59" "v08-as bad coverage rows"
expect_summary_value "$SUMMARY_CSV" "artifact_type_coverage" "59" "v08-as bad coverage artifact count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad coverage should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-coverage-incomplete" "v08-as bad coverage action"

write_good_fetch_csv "$BAD_PLACEHOLDER_CSV"
awk -F, 'BEGIN { OFS="," } NR == 2 { $20 = "https://fetch.example.org/authority_record.json" } { print }' \
  "$BAD_PLACEHOLDER_CSV" >"$BAD_PLACEHOLDER_CSV.tmp"
mv "$BAD_PLACEHOLDER_CSV.tmp" "$BAD_PLACEHOLDER_CSV"
run_v08as_with_upstream "$BAD_PLACEHOLDER_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "nonplaceholder_live_fetch_uri_fields" "179" "v08-as bad placeholder count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad placeholder should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-placeholder-artifact-uri" "v08-as bad placeholder action"

write_good_fetch_csv "$BAD_STATUS_CSV"
awk -F, 'BEGIN { OFS="," } NR == 3 { $15 = "500" } { print }' \
  "$BAD_STATUS_CSV" >"$BAD_STATUS_CSV.tmp"
mv "$BAD_STATUS_CSV.tmp" "$BAD_STATUS_CSV"
run_v08as_with_upstream "$BAD_STATUS_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "http_status_pass_rows" "59" "v08-as bad status count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad status should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-http-status-missing" "v08-as bad status action"

write_good_fetch_csv "$BAD_DIGEST_CSV"
awk -F, 'BEGIN { OFS="," } NR == 4 { $11 = "0" } { print }' \
  "$BAD_DIGEST_CSV" >"$BAD_DIGEST_CSV.tmp"
mv "$BAD_DIGEST_CSV.tmp" "$BAD_DIGEST_CSV"
run_v08as_with_upstream "$BAD_DIGEST_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "content_digest_match_declared_rows" "59" "v08-as bad digest count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad digest should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-content-digest-mismatch" "v08-as bad digest action"

write_good_fetch_csv "$BAD_BINDING_CSV"
awk -F, 'BEGIN { OFS="," } NR == 5 { $5 = "0" } { print }' \
  "$BAD_BINDING_CSV" >"$BAD_BINDING_CSV.tmp"
mv "$BAD_BINDING_CSV.tmp" "$BAD_BINDING_CSV"
run_v08as_with_upstream "$BAD_BINDING_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "v08ar_package_intake_bound_rows" "59" "v08-as bad binding count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad binding should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-binding-missing" "v08-as bad binding action"

write_good_fetch_csv "$BAD_RUNNER_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 6 { $6 = "0" } { print }' \
  "$BAD_RUNNER_DECLARATION_CSV" >"$BAD_RUNNER_DECLARATION_CSV.tmp"
mv "$BAD_RUNNER_DECLARATION_CSV.tmp" "$BAD_RUNNER_DECLARATION_CSV"
run_v08as_with_upstream "$BAD_RUNNER_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "runner_owned_live_fetch_declared_rows" "59" "v08-as bad runner declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad runner declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-runner-declaration-missing" "v08-as bad runner declaration action"

write_good_fetch_csv "$BAD_NETWORK_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 7 { $7 = "0" } { print }' \
  "$BAD_NETWORK_DECLARATION_CSV" >"$BAD_NETWORK_DECLARATION_CSV.tmp"
mv "$BAD_NETWORK_DECLARATION_CSV.tmp" "$BAD_NETWORK_DECLARATION_CSV"
run_v08as_with_upstream "$BAD_NETWORK_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "network_fetch_transcript_declared_rows" "59" "v08-as bad network declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad network declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-network-proof-missing" "v08-as bad network declaration action"

write_good_fetch_csv "$BAD_AUTHORITY_DECLARATION_CSV"
awk -F, 'BEGIN { OFS="," } NR == 8 { $12 = "0" } { print }' \
  "$BAD_AUTHORITY_DECLARATION_CSV" >"$BAD_AUTHORITY_DECLARATION_CSV.tmp"
mv "$BAD_AUTHORITY_DECLARATION_CSV.tmp" "$BAD_AUTHORITY_DECLARATION_CSV"
run_v08as_with_upstream "$BAD_AUTHORITY_DECLARATION_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "authority_registry_verified_declared_rows" "59" "v08-as bad authority declaration count"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad authority declaration should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-authority-verification-missing" "v08-as bad authority declaration action"

write_good_fetch_csv "$BAD_JUMP_CSV"
awk -F, 'BEGIN { OFS="," } NR == 9 { $24 = "1.000000" } { print }' \
  "$BAD_JUMP_CSV" >"$BAD_JUMP_CSV.tmp"
mv "$BAD_JUMP_CSV.tmp" "$BAD_JUMP_CSV"
run_v08as_with_upstream "$BAD_JUMP_CSV" >/dev/null
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "1.000000" "v08-as bad jump rate"
expect_summary_value "$SUMMARY_CSV" "external_benchmark_live_package_artifact_fetch_authority_ready" "0" "v08-as bad jump should block"
expect_summary_value "$SUMMARY_CSV" "action" "external-benchmark-live-package-artifact-fetch-jump-guardrail-violated" "v08-as bad jump action"

run_v08as_with_upstream "$FETCH_CSV" >/dev/null

echo "v08 external benchmark live package artifact fetch authority smoke passed"
