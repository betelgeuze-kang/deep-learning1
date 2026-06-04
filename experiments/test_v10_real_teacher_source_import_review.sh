#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v10_real_teacher_source_import_review_fixture"

REMOTE_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_remote_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_content_fixture.csv"
FETCH_ATTESTATION_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_remote_style_fixture.csv"
LIVE_RUNTIME_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_network_import_gate_live_runtime_fixture.csv"
LOCAL_REVIEW_CSV="$RESULTS_DIR/v10_real_teacher_source_import_review_local_fixture.csv"
PLACEHOLDER_REVIEW_CSV="$RESULTS_DIR/v10_real_teacher_source_import_review_placeholder_fixture.csv"
READY_REVIEW_CSV="$RESULTS_DIR/v10_real_teacher_source_import_review_ready_fixture.csv"
BAD_HASH_REVIEW_CSV="$RESULTS_DIR/v10_real_teacher_source_import_review_bad_hash_fixture.csv"

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
      if (!(field in idx)) die("missing h10-r summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one h10-r summary row", 4)
    }
  ' "$summary_csv"
}

sha_file_uri() {
  local path="$1"
  printf 'sha256:%s\n' "$(sha256sum "$path" | awk '{print $1}')"
}

sha_fixture() {
  local label="$1"
  printf 'sha256:%064x\n' "$label"
}

write_review_header() {
  echo "teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,import_manifest_uri,import_manifest_hash,review_report_uri,review_report_hash,reviewer_identity_uri,reviewer_identity_hash,conflict_disclosure_uri,conflict_disclosure_hash,source_registry_uri,source_registry_hash,source_import_id,live_network_import_observed,independent_review_ready,authoritative_review_ready,registry_entry_ready,real_source_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
}

write_review_csv() {
  local out="$1"
  local import_manifest_uri="$2"
  local import_manifest_hash="$3"
  local review_report_uri="$4"
  local review_report_hash="$5"
  local reviewer_identity_uri="$6"
  local reviewer_identity_hash="$7"
  local conflict_disclosure_uri="$8"
  local conflict_disclosure_hash="$9"
  local source_registry_uri="${10}"
  local source_registry_hash="${11}"

  {
    write_review_header
    printf "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,import-%s-v1,1,1,1,1,1,0,0,0\n" \
      "$teacher_id" \
      "$source_uri" \
      "$source_hash" \
      "$label_export_uri" \
      "$label_export_hash" \
      "$teacher_identity_uri" \
      "$teacher_identity_hash" \
      "$teacher_policy_uri" \
      "$teacher_policy_hash" \
      "$license_uri" \
      "$license_hash" \
      "$import_manifest_uri" \
      "$import_manifest_hash" \
      "$review_report_uri" \
      "$review_report_hash" \
      "$reviewer_identity_uri" \
      "$reviewer_identity_hash" \
      "$conflict_disclosure_uri" \
      "$conflict_disclosure_hash" \
      "$source_registry_uri" \
      "$source_registry_hash" \
      "$teacher_id"
  } >"$out"
}

"$ROOT_DIR/experiments/run_v10_real_teacher_source_import_review.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_real_teacher_source_import_review_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_real_teacher_source_import_review_smoke_decision.csv"

expect_summary_value "$SUMMARY_CSV" "teacher_source_real_import_scope" "route-memory-h10r" "default h10-r scope"
expect_summary_value "$SUMMARY_CSV" "review_source" "pending-fixture" "default h10-r review source"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_network_import_ready" "0" "default h10-r should block before live import"
expect_summary_value "$SUMMARY_CSV" "review_rows" "0" "default h10-r should have no review rows"
expect_summary_value "$SUMMARY_CSV" "teacher_source_import_review_contract_ready" "0" "default h10-r should not pass import-review contract"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_import_review_ready" "0" "default h10-r should not pass real review readiness"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "default h10-r must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "real-teacher-source-live-network-import-missing" "default h10-r should wait for live network import"

"$ROOT_DIR/experiments/test_v10_remote_teacher_source_live_network_import_gate.sh" >/dev/null

mkdir -p "$FIXTURE_DIR"
for name in import_manifest review_report reviewer_identity conflict_disclosure source_registry; do
  printf '%s real teacher source import review fixture\n' "$name" >"$FIXTURE_DIR/${name}.txt"
done

teacher_id="$(awk -F, 'NR == 2 { print $1 }' "$REMOTE_CSV")"
source_uri="$(awk -F, 'NR == 2 { print $2 }' "$REMOTE_CSV")"
source_hash="$(awk -F, 'NR == 2 { print $3 }' "$REMOTE_CSV")"
label_export_uri="$(awk -F, 'NR == 2 { print $4 }' "$REMOTE_CSV")"
label_export_hash="$(awk -F, 'NR == 2 { print $5 }' "$REMOTE_CSV")"
teacher_identity_uri="$(awk -F, 'NR == 2 { print $6 }' "$REMOTE_CSV")"
teacher_identity_hash="$(awk -F, 'NR == 2 { print $7 }' "$REMOTE_CSV")"
teacher_policy_uri="$(awk -F, 'NR == 2 { print $8 }' "$REMOTE_CSV")"
teacher_policy_hash="$(awk -F, 'NR == 2 { print $9 }' "$REMOTE_CSV")"
license_uri="$(awk -F, 'NR == 2 { print $10 }' "$REMOTE_CSV")"
license_hash="$(awk -F, 'NR == 2 { print $11 }' "$REMOTE_CSV")"

manifest_hash="$(sha_file_uri "$FIXTURE_DIR/import_manifest.txt")"
review_report_hash="$(sha_file_uri "$FIXTURE_DIR/review_report.txt")"
reviewer_hash="$(sha_file_uri "$FIXTURE_DIR/reviewer_identity.txt")"
conflict_hash="$(sha_file_uri "$FIXTURE_DIR/conflict_disclosure.txt")"
registry_hash="$(sha_file_uri "$FIXTURE_DIR/source_registry.txt")"

write_review_csv \
  "$LOCAL_REVIEW_CSV" \
  "file://$FIXTURE_DIR/import_manifest.txt" "$manifest_hash" \
  "file://$FIXTURE_DIR/review_report.txt" "$review_report_hash" \
  "file://$FIXTURE_DIR/reviewer_identity.txt" "$reviewer_hash" \
  "file://$FIXTURE_DIR/conflict_disclosure.txt" "$conflict_hash" \
  "file://$FIXTURE_DIR/source_registry.txt" "$registry_hash"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV="$LIVE_RUNTIME_CSV" \
V10_REAL_TEACHER_SOURCE_IMPORT_REVIEW_CSV="$LOCAL_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v10_real_teacher_source_import_review.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_network_import_ready" "1" "local review should still consume live import"
expect_summary_value "$SUMMARY_CSV" "review_rows" "1" "local review should have one row"
expect_summary_value "$SUMMARY_CSV" "matched_teacher_rows" "1" "local review should bind to acquisition teacher/source"
expect_summary_value "$SUMMARY_CSV" "local_review_uri_fields" "5" "local review should expose local import/review URIs"
expect_summary_value "$SUMMARY_CSV" "sha256_review_hash_fields" "10" "local review should still exercise sha256 review hashes"
expect_summary_value "$SUMMARY_CSV" "teacher_source_import_review_contract_ready" "0" "local review must not pass real import-review contract"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "local review must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "real-teacher-source-local-import-artifact" "local review should block as local artifact"

write_review_csv \
  "$PLACEHOLDER_REVIEW_CSV" \
  "https://teacher-source.invalid/import_manifest.json" "$(sha_fixture 101)" \
  "https://teacher-source.invalid/review_report.json" "$(sha_fixture 102)" \
  "https://teacher-source.invalid/reviewer_identity.json" "$(sha_fixture 103)" \
  "https://teacher-source.invalid/conflict_disclosure.json" "$(sha_fixture 104)" \
  "https://teacher-source.invalid/source_registry.json" "$(sha_fixture 105)"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV="$LIVE_RUNTIME_CSV" \
V10_REAL_TEACHER_SOURCE_IMPORT_REVIEW_CSV="$PLACEHOLDER_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v10_real_teacher_source_import_review.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "required_review_uri_fields" "10" "placeholder review should expose ten URI fields"
expect_summary_value "$SUMMARY_CSV" "remote_review_uri_fields" "10" "placeholder review should use HTTPS URI fields"
expect_summary_value "$SUMMARY_CSV" "placeholder_review_uri_fields" "5" "placeholder review should expose reserved placeholder authority"
expect_summary_value "$SUMMARY_CSV" "teacher_source_import_review_contract_ready" "1" "placeholder review should pass syntactic import-review contract"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_import_review_ready" "0" "placeholder review must not become real review readiness"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "placeholder review must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "real-teacher-source-placeholder-import-artifact" "placeholder review should block as placeholder artifact"

write_review_csv \
  "$READY_REVIEW_CSV" \
  "https://teacher-source.registry.net/import_manifest.json" "$(sha_fixture 201)" \
  "https://teacher-source.registry.net/review_report.json" "$(sha_fixture 202)" \
  "https://teacher-source.registry.net/reviewer_identity.json" "$(sha_fixture 203)" \
  "https://teacher-source.registry.net/conflict_disclosure.json" "$(sha_fixture 204)" \
  "https://teacher-source.registry.net/source_registry.json" "$(sha_fixture 205)"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV="$LIVE_RUNTIME_CSV" \
V10_REAL_TEACHER_SOURCE_IMPORT_REVIEW_CSV="$READY_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v10_real_teacher_source_import_review.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "placeholder_review_uri_fields" "0" "ready review should not use placeholder authority"
expect_summary_value "$SUMMARY_CSV" "teacher_source_import_review_contract_ready" "1" "ready review should pass import-review contract"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_import_review_ready" "1" "ready review should pass real review chain readiness"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "ready review must still wait for official authority"
expect_summary_value "$SUMMARY_CSV" "action" "real-teacher-source-official-authority-missing" "ready review should stop at official authority"

write_review_csv \
  "$BAD_HASH_REVIEW_CSV" \
  "https://teacher-source.registry.net/import_manifest.json" "sha256:not-a-real-hash" \
  "https://teacher-source.registry.net/review_report.json" "$(sha_fixture 302)" \
  "https://teacher-source.registry.net/reviewer_identity.json" "$(sha_fixture 303)" \
  "https://teacher-source.registry.net/conflict_disclosure.json" "$(sha_fixture 304)" \
  "https://teacher-source.registry.net/source_registry.json" "$(sha_fixture 305)"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$FETCH_ATTESTATION_CSV" \
V10_REMOTE_TEACHER_SOURCE_RUNTIME_FETCH_CSV="$LIVE_RUNTIME_CSV" \
V10_REAL_TEACHER_SOURCE_IMPORT_REVIEW_CSV="$BAD_HASH_REVIEW_CSV" \
  "$ROOT_DIR/experiments/run_v10_real_teacher_source_import_review.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "sha256_review_hash_fields" "9" "bad hash review should lose one sha256 field"
expect_summary_value "$SUMMARY_CSV" "teacher_source_import_review_contract_ready" "0" "bad hash review must not pass import-review contract"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_import_review_ready" "0" "bad hash review must not pass real review readiness"
expect_summary_value "$SUMMARY_CSV" "action" "real-teacher-source-import-review-hash-mismatch" "bad hash review should block at hash mismatch"

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
    if ($idx["gate"] == "live-network-import" && $idx["status"] != "pass") die("h10-r live network import should pass for ready review fixture", 20)
    if ($idx["gate"] == "import-review-artifacts" && $idx["status"] != "blocked") die("h10-r bad hash should block artifact completeness", 21)
    if ($idx["gate"] == "review-hashes" && $idx["status"] != "blocked") die("h10-r bad hash should block hash manifest", 22)
    if ($idx["gate"] == "real-teacher-source-verification" && $idx["status"] != "blocked") die("h10-r real teacher source verification should still block", 23)
    if ($idx["gate"] == "jump-guardrail" && $idx["status"] != "pass") die("h10-r jump guardrail should pass", 24)
  }
  END {
    if (rows != 8) die("expected eight h10-r decision rows", 25)
  }
' "$DECISION_CSV"

echo "v10 real teacher-source import/review smoke passed"
