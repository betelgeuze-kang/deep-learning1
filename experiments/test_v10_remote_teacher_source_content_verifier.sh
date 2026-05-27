#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v10_remote_teacher_source_content_fixture"
REMOTE_CSV="$RESULTS_DIR/v10_remote_teacher_source_content_remote_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v10_remote_teacher_source_content_cache_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v10_remote_teacher_source_content_bad_hash_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v10_remote_teacher_source_content_malformed_fixture.csv"

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
      if (!(field in idx)) die("missing h10-n summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one h10-n summary row", 4)
    }
  ' "$summary_csv"
}

sha_file_uri() {
  local path="$1"
  printf 'sha256:%s\n' "$(sha256sum "$path" | awk '{print $1}')"
}

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_content_verifier.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_remote_teacher_source_content_verifier_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_remote_teacher_source_content_verifier_smoke_decision.csv"

expect_summary_value "$SUMMARY_CSV" "teacher_source_content_scope" "route-memory-h10n" "default content verifier scope"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_acquisition_ready" "0" "default acquisition should block"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_content_ready" "0" "default content verifier should block"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "default content verifier must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-acquisition-not-ready" "default content verifier should block at acquisition"

mkdir -p "$FIXTURE_DIR"
for name in source labels identity policy license review; do
  printf '%s remote content verifier fixture\n' "$name" >"$FIXTURE_DIR/${name}.txt"
done

source_hash="$(sha_file_uri "$FIXTURE_DIR/source.txt")"
label_hash="$(sha_file_uri "$FIXTURE_DIR/labels.txt")"
identity_hash="$(sha_file_uri "$FIXTURE_DIR/identity.txt")"
policy_hash="$(sha_file_uri "$FIXTURE_DIR/policy.txt")"
license_hash="$(sha_file_uri "$FIXTURE_DIR/license.txt")"
review_hash="$(sha_file_uri "$FIXTURE_DIR/review.txt")"

{
  echo "teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,review_uri,review_hash,acquisition_method,retrieval_tool,content_hash_algorithm,teacher_model_family,provenance_basis,real_remote_source_declared,fixture_or_synthetic_declared,remote_acquisition_ready,review_ready,routing_trigger_rate,active_jump_rate"
  printf "teacher-remote-v2,https://teacher.example.org/source.json,%s,https://teacher.example.org/labels.csv,%s,https://teacher.example.org/identity.json,%s,https://teacher.example.org/policy.json,%s,https://teacher.example.org/license.txt,%s,https://review.example.org/teacher-remote-v2.txt,%s,independent-remote-review,curl-8,sha256,remote-teacher-family,remote-source-chain,1,0,1,1,0,0\n" \
    "$source_hash" \
    "$label_hash" \
    "$identity_hash" \
    "$policy_hash" \
    "$license_hash" \
    "$review_hash"
} >"$REMOTE_CSV"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_content_verifier.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_acquisition_ready" "1" "remote acquisition fixture should pass acquisition"
expect_summary_value "$SUMMARY_CSV" "content_rows" "0" "remote acquisition without content should have no content rows"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_content_ready" "0" "remote acquisition without content should block content verifier"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-content-missing" "remote acquisition should wait for content cache"

{
  echo "teacher_id,source_uri,source_cache_uri,source_hash,label_export_uri,label_export_cache_uri,label_export_hash,teacher_identity_uri,teacher_identity_cache_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_cache_uri,teacher_policy_hash,license_uri,license_cache_uri,license_hash,review_uri,review_cache_uri,review_hash,fetch_tool,content_hash_algorithm,fetch_manifest_ready,content_cache_ready,independent_review_ready,real_remote_source_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
  printf "teacher-remote-v2,https://teacher.example.org/source.json,file://%s,%s,https://teacher.example.org/labels.csv,file://%s,%s,https://teacher.example.org/identity.json,file://%s,%s,https://teacher.example.org/policy.json,file://%s,%s,https://teacher.example.org/license.txt,file://%s,%s,https://review.example.org/teacher-remote-v2.txt,file://%s,%s,curl-8,sha256,1,1,1,1,0,0,0\n" \
    "$FIXTURE_DIR/source.txt" \
    "$source_hash" \
    "$FIXTURE_DIR/labels.txt" \
    "$label_hash" \
    "$FIXTURE_DIR/identity.txt" \
    "$identity_hash" \
    "$FIXTURE_DIR/policy.txt" \
    "$policy_hash" \
    "$FIXTURE_DIR/license.txt" \
    "$license_hash" \
    "$FIXTURE_DIR/review.txt" \
    "$review_hash"
} >"$CONTENT_CSV"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_content_verifier.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "content_source" "provided-csv" "content cache fixture should be provided"
expect_summary_value "$SUMMARY_CSV" "content_rows" "1" "content cache fixture should have one row"
expect_summary_value "$SUMMARY_CSV" "matched_teacher_rows" "1" "content cache fixture should match teacher id"
expect_summary_value "$SUMMARY_CSV" "remote_uri_match_rows" "1" "content cache fixture should match remote URI manifest"
expect_summary_value "$SUMMARY_CSV" "hash_manifest_match_rows" "1" "content cache fixture should match acquisition hashes"
expect_summary_value "$SUMMARY_CSV" "required_content_fields" "6" "content cache fixture should expose six cache fields"
expect_summary_value "$SUMMARY_CSV" "cache_uri_fields" "6" "content cache fixture should use file cache URIs"
expect_summary_value "$SUMMARY_CSV" "content_hash_verified_fields" "6" "content cache fixture should verify all cache hashes"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_content_ready" "1" "content verifier should pass cache contract"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "content cache contract alone must not claim live remote source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-live-fetch-missing" "content cache fixture should block at live fetch verification"

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
    if ($idx["gate"] == "remote-acquisition" && $idx["status"] != "pass") die("h10-n remote acquisition should pass", 20)
    if ($idx["gate"] == "content-cache-hash" && $idx["status"] != "pass") die("h10-n content cache hash should pass", 21)
    if ($idx["gate"] == "remote-teacher-source-content" && $idx["status"] != "pass") die("h10-n content contract should pass", 22)
    if ($idx["gate"] == "real-teacher-source-verification" && $idx["status"] != "blocked") die("h10-n real verification should still block", 23)
  }
  END {
    if (rows != 8) die("expected eight h10-n decision rows", 24)
  }
' "$DECISION_CSV"

{
  head -n 1 "$CONTENT_CSV"
  sed -n '2p' "$CONTENT_CSV" | awk -F, 'BEGIN { OFS="," } { $4 = "sha256:0000000000000000000000000000000000000000000000000000000000000000"; print }'
} >"$BAD_HASH_CSV"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_content_verifier.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_content_ready" "0" "bad content hash should block content readiness"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-content-hash-manifest-mismatch" "bad content hash should block at manifest mismatch"

{
  head -n 1 "$CONTENT_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$CONTENT_CSV")"
} >"$MALFORMED_CSV"

if V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
   V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v10_remote_teacher_source_content_verifier.sh" --smoke >/dev/null 2>/dev/null; then
  echo "h10-n should reject malformed content CSV row widths" >&2
  exit 40
fi

echo "v10 remote teacher-source content verifier smoke passed"
