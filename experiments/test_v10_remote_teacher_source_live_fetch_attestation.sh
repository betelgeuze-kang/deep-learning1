#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
FIXTURE_DIR="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_fixture"
REMOTE_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_remote_acquisition_fixture.csv"
CONTENT_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_content_fixture.csv"
LOCAL_ATTESTATION_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_local_fixture.csv"
REMOTE_ATTESTATION_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_remote_style_fixture.csv"
BAD_HASH_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_bad_hash_fixture.csv"
MALFORMED_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_malformed_fixture.csv"

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
      if (!(field in idx)) die("missing h10-o summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one h10-o summary row", 4)
    }
  ' "$summary_csv"
}

sha_file_uri() {
  local path="$1"
  printf 'sha256:%s\n' "$(sha256sum "$path" | awk '{print $1}')"
}

set_artifact_values() {
  local kind="$1"

  case "$kind" in
    source)
      remote_uri="https://teacher.example.org/source.json"
      cache_path="$FIXTURE_DIR/source.txt"
      content_hash="$source_hash"
      ;;
    label_export)
      remote_uri="https://teacher.example.org/labels.csv"
      cache_path="$FIXTURE_DIR/labels.txt"
      content_hash="$label_hash"
      ;;
    teacher_identity)
      remote_uri="https://teacher.example.org/identity.json"
      cache_path="$FIXTURE_DIR/identity.txt"
      content_hash="$identity_hash"
      ;;
    teacher_policy)
      remote_uri="https://teacher.example.org/policy.json"
      cache_path="$FIXTURE_DIR/policy.txt"
      content_hash="$policy_hash"
      ;;
    license)
      remote_uri="https://teacher.example.org/license.txt"
      cache_path="$FIXTURE_DIR/license.txt"
      content_hash="$license_hash"
      ;;
    review)
      remote_uri="https://review.example.org/teacher-remote-v3.txt"
      cache_path="$FIXTURE_DIR/review.txt"
      content_hash="$review_hash"
      ;;
    *)
      echo "unknown artifact kind: $kind" >&2
      exit 2
      ;;
  esac
}

write_fetch_attestation_csv() {
  local out="$1"
  local mode="$2"
  local bad_hash_kind="${3:-}"

  {
    echo "teacher_id,artifact_kind,remote_uri,cache_uri,content_hash,fetch_started_at_utc,fetch_completed_at_utc,fetch_tool,fetch_tool_version,http_status,content_length,tls_peer_subject,tls_peer_issuer,tls_sha256_fingerprint,attestation_id,attestation_uri,attestation_cache_uri,attestation_hash,attestor_id,attestor_org,attestor_independent,fetch_manifest_ready,live_fetch_ready,content_hash_attested,independent_attestation_ready,real_remote_fetch_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
    for artifact_kind in source label_export teacher_identity teacher_policy license review; do
      set_artifact_values "$artifact_kind"
      attestation_path="$FIXTURE_DIR/${artifact_kind}_attestation.txt"
      attestation_hash="$(sha_file_uri "$attestation_path")"
      row_hash="$content_hash"
      if [[ "$artifact_kind" == "$bad_hash_kind" ]]; then
        row_hash="sha256:0000000000000000000000000000000000000000000000000000000000000000"
      fi

      if [[ "$mode" == "remote-style" ]]; then
        attestation_uri="https://attest.example.org/teacher-remote-v3/${artifact_kind}.txt"
        attestor_independent=1
        independent_attestation_ready=1
        fixture_or_synthetic_declared=0
      else
        attestation_uri="file://$attestation_path"
        attestor_independent=0
        independent_attestation_ready=0
        fixture_or_synthetic_declared=1
      fi

      printf "teacher-remote-v3,%s,%s,file://%s,%s,2026-05-28T00:00:00Z,2026-05-28T00:00:01Z,curl,8.7.1,200,41,CN=teacher.example.org,O=Example CA,%s,%s,%s,file://%s,%s,attestor-v3,external-review-org,%d,1,1,1,%d,1,%d,0,0\n" \
        "$artifact_kind" \
        "$remote_uri" \
        "$cache_path" \
        "$row_hash" \
        "$source_hash" \
        "attestation-${artifact_kind}-v3" \
        "$attestation_uri" \
        "$attestation_path" \
        "$attestation_hash" \
        "$attestor_independent" \
        "$independent_attestation_ready" \
        "$fixture_or_synthetic_declared"
    done
  } >"$out"
}

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh" --smoke

SUMMARY_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v10_remote_teacher_source_live_fetch_attestation_smoke_decision.csv"

expect_summary_value "$SUMMARY_CSV" "teacher_source_fetch_scope" "route-memory-h10o" "default live-fetch scope"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_content_ready" "0" "default content should block"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_fetch_attestation_ready" "0" "default live-fetch attestation should block"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "default live-fetch must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-content-not-ready" "default live-fetch should block at content"

mkdir -p "$FIXTURE_DIR"
for name in source labels identity policy license review; do
  printf '%s remote live-fetch fixture\n' "$name" >"$FIXTURE_DIR/${name}.txt"
done
for artifact_kind in source label_export teacher_identity teacher_policy license review; do
  printf '%s remote live-fetch attestation fixture\n' "$artifact_kind" >"$FIXTURE_DIR/${artifact_kind}_attestation.txt"
done

source_hash="$(sha_file_uri "$FIXTURE_DIR/source.txt")"
label_hash="$(sha_file_uri "$FIXTURE_DIR/labels.txt")"
identity_hash="$(sha_file_uri "$FIXTURE_DIR/identity.txt")"
policy_hash="$(sha_file_uri "$FIXTURE_DIR/policy.txt")"
license_hash="$(sha_file_uri "$FIXTURE_DIR/license.txt")"
review_hash="$(sha_file_uri "$FIXTURE_DIR/review.txt")"

{
  echo "teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,review_uri,review_hash,acquisition_method,retrieval_tool,content_hash_algorithm,teacher_model_family,provenance_basis,real_remote_source_declared,fixture_or_synthetic_declared,remote_acquisition_ready,review_ready,routing_trigger_rate,active_jump_rate"
  printf "teacher-remote-v3,https://teacher.example.org/source.json,%s,https://teacher.example.org/labels.csv,%s,https://teacher.example.org/identity.json,%s,https://teacher.example.org/policy.json,%s,https://teacher.example.org/license.txt,%s,https://review.example.org/teacher-remote-v3.txt,%s,independent-remote-review,curl-8,sha256,remote-teacher-family,remote-source-chain,1,0,1,1,0,0\n" \
    "$source_hash" \
    "$label_hash" \
    "$identity_hash" \
    "$policy_hash" \
    "$license_hash" \
    "$review_hash"
} >"$REMOTE_CSV"

{
  echo "teacher_id,source_uri,source_cache_uri,source_hash,label_export_uri,label_export_cache_uri,label_export_hash,teacher_identity_uri,teacher_identity_cache_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_cache_uri,teacher_policy_hash,license_uri,license_cache_uri,license_hash,review_uri,review_cache_uri,review_hash,fetch_tool,content_hash_algorithm,fetch_manifest_ready,content_cache_ready,independent_review_ready,real_remote_source_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
  printf "teacher-remote-v3,https://teacher.example.org/source.json,file://%s,%s,https://teacher.example.org/labels.csv,file://%s,%s,https://teacher.example.org/identity.json,file://%s,%s,https://teacher.example.org/policy.json,file://%s,%s,https://teacher.example.org/license.txt,file://%s,%s,https://review.example.org/teacher-remote-v3.txt,file://%s,%s,curl-8,sha256,1,1,1,1,0,0,0\n" \
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
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_content_ready" "1" "content fixture should pass h10-n"
expect_summary_value "$SUMMARY_CSV" "expected_fetch_artifact_rows" "6" "live-fetch should expect six artifacts"
expect_summary_value "$SUMMARY_CSV" "fetch_attestation_rows" "0" "content without attestation should have no fetch rows"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_fetch_attestation_ready" "0" "content without attestation should block live-fetch"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-fetch-attestation-missing" "content should wait for live-fetch attestation"

write_fetch_attestation_csv "$LOCAL_ATTESTATION_CSV" "local"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$LOCAL_ATTESTATION_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "fetch_attestation_rows" "6" "local attestation fixture should have six rows"
expect_summary_value "$SUMMARY_CSV" "matched_artifact_rows" "6" "local attestation fixture should match artifacts"
expect_summary_value "$SUMMARY_CSV" "content_hash_match_rows" "6" "local attestation fixture should match content hashes"
expect_summary_value "$SUMMARY_CSV" "attestation_uri_remote_rows" "0" "local attestation fixture must not count as remote"
expect_summary_value "$SUMMARY_CSV" "independent_attestor_rows" "0" "local attestation fixture must not count as independent"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_fetch_attestation_ready" "0" "local attestation fixture should block live-fetch readiness"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "local attestation fixture must not become real source"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-independent-attestation-missing" "local attestation should block at independent attestation"

write_fetch_attestation_csv "$REMOTE_ATTESTATION_CSV" "remote-style"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$REMOTE_ATTESTATION_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "fetch_attestation_source" "provided-csv" "remote-style attestation should be provided"
expect_summary_value "$SUMMARY_CSV" "fetch_attestation_rows" "6" "remote-style attestation should have six rows"
expect_summary_value "$SUMMARY_CSV" "attestation_uri_remote_rows" "6" "remote-style attestation should expose remote attestation URIs"
expect_summary_value "$SUMMARY_CSV" "attestation_cache_hash_verified_rows" "6" "remote-style attestation caches should hash-match"
expect_summary_value "$SUMMARY_CSV" "independent_attestor_rows" "6" "remote-style attestation should expose independent attestors"
expect_summary_value "$SUMMARY_CSV" "independent_attestation_ready_rows" "6" "remote-style attestation should be marked ready"
expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_fetch_attestation_ready" "1" "remote-style attestation should satisfy h10-o contract"
expect_summary_value "$SUMMARY_CSV" "real_teacher_source_verified" "0" "h10-o contract alone must not claim runtime fetch ownership"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-runtime-fetcher-missing" "remote-style attestation should still wait for runtime fetcher"

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
    if ($idx["gate"] == "remote-content" && $idx["status"] != "pass") die("h10-o remote content should pass", 20)
    if ($idx["gate"] == "fetch-content-hash" && $idx["status"] != "pass") die("h10-o fetch content hash should pass", 21)
    if ($idx["gate"] == "independent-attestation" && $idx["status"] != "pass") die("h10-o independent attestation should pass", 22)
    if ($idx["gate"] == "remote-teacher-source-live-fetch-attestation" && $idx["status"] != "pass") die("h10-o live-fetch attestation should pass", 23)
    if ($idx["gate"] == "real-teacher-source-verification" && $idx["status"] != "blocked") die("h10-o real verification should still block", 24)
  }
  END {
    if (rows != 9) die("expected nine h10-o decision rows", 25)
  }
' "$DECISION_CSV"

write_fetch_attestation_csv "$BAD_HASH_CSV" "remote-style" "source"

V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$BAD_HASH_CSV" \
  "$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh" --smoke

expect_summary_value "$SUMMARY_CSV" "remote_teacher_source_live_fetch_attestation_ready" "0" "bad attested content hash should block live-fetch readiness"
expect_summary_value "$SUMMARY_CSV" "action" "remote-teacher-source-fetch-content-hash-mismatch" "bad attested content hash should block at content hash"

{
  head -n 1 "$REMOTE_ATTESTATION_CSV"
  printf '%s,extra-field\n' "$(sed -n '2p' "$REMOTE_ATTESTATION_CSV")"
} >"$MALFORMED_CSV"

if V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV="$REMOTE_CSV" \
   V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV="$CONTENT_CSV" \
   V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV="$MALFORMED_CSV" \
   "$ROOT_DIR/experiments/run_v10_remote_teacher_source_live_fetch_attestation.sh" --smoke >/dev/null 2>/dev/null; then
  echo "h10-o should reject malformed fetch-attestation CSV row widths" >&2
  exit 40
fi

echo "v10 remote teacher-source live-fetch attestation smoke passed"
