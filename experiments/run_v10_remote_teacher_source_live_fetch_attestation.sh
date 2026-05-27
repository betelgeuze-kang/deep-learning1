#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

MODE="standard"
if [[ "${1:-}" == "--smoke" ]]; then
  MODE="smoke"
elif [[ "${1:-}" == "--full" ]]; then
  MODE="full"
elif [[ "${1:-}" != "" ]]; then
  echo "usage: $0 [--smoke|--full]" >&2
  exit 2
fi

mkdir -p "$RESULTS_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PREFIX="v10_remote_teacher_source_live_fetch_attestation"
CONTENT_PREFIX="v10_remote_teacher_source_content_verifier"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_remote_teacher_source_live_fetch_attestation_smoke"
  CONTENT_PREFIX="v10_remote_teacher_source_content_verifier_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_content_verifier.sh" "${RUN_ARGS[@]}" >/dev/null

CONTENT_CSV="${V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV:-$RESULTS_DIR/${CONTENT_PREFIX}_content.csv}"
CONTENT_SUMMARY_CSV="$RESULTS_DIR/${CONTENT_PREFIX}_summary.csv"
FETCH_CSV="$RESULTS_DIR/${PREFIX}_fetch_attestation.csv"
FETCH_SOURCE="pending-fixture"
if [[ -n "${V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV:-}" ]]; then
  FETCH_CSV="$V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV"
  FETCH_SOURCE="provided-csv"
  if [[ ! -s "$FETCH_CSV" ]]; then
    echo "V10_REMOTE_TEACHER_SOURCE_FETCH_ATTESTATION_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  {
    echo "teacher_id,artifact_kind,remote_uri,cache_uri,content_hash,fetch_started_at_utc,fetch_completed_at_utc,fetch_tool,fetch_tool_version,http_status,content_length,tls_peer_subject,tls_peer_issuer,tls_sha256_fingerprint,attestation_id,attestation_uri,attestation_cache_uri,attestation_hash,attestor_id,attestor_org,attestor_independent,fetch_manifest_ready,live_fetch_ready,content_hash_attested,independent_attestation_ready,real_remote_fetch_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
  } >"$FETCH_CSV"
fi

SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

is_sha256() {
  local value="$1"
  local hex

  [[ "$value" == sha256:* ]] || return 1
  hex="${value#sha256:}"
  [[ ${#hex} -eq 64 && ! "$hex" =~ [^0-9a-fA-F] ]]
}

is_present() {
  local value="$1"
  [[ "$value" != "" && "$value" != "pending" ]]
}

uri_to_local_path() {
  local uri="$1"
  if [[ "$uri" == file://* ]]; then
    printf '%s\n' "${uri#file://}"
    return 0
  fi
  return 1
}

hash_matches_uri() {
  local uri="$1"
  local expected="$2"
  local path
  local expected_hex
  local actual_hex

  if ! is_sha256 "$expected"; then
    return 1
  fi
  if ! path="$(uri_to_local_path "$uri")"; then
    return 1
  fi
  if [[ ! -f "$path" ]]; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

uri_is_remote_https() {
  local uri="$1"
  local lowered

  lowered="${uri,,}"
  [[ "$lowered" =~ ^https:// ]] || return 1
  [[ "$lowered" =~ ^https://(localhost|127\.0\.0\.1|0\.0\.0\.0|\[::1\])([:/]|$) ]] && return 1
  return 0
}

CONTENT_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("content_source content_rows required_content_fields content_hash_verified_fields remote_teacher_source_content_ready real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-o content summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%s,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["content_source"],
        $idx["content_rows"] + 0,
        $idx["required_content_fields"] + 0,
        $idx["content_hash_verified_fields"] + 0,
        $idx["remote_teacher_source_content_ready"] + 0,
        $idx["real_teacher_source_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one h10-o content summary row", 3)
    }
  ' "$CONTENT_SUMMARY_CSV"
)"

IFS=, read -r content_source content_rows content_required_fields content_hash_verified_fields remote_content_ready content_real_verified content_action content_routing content_jump <<<"$CONTENT_VALUES"

declare -A expected_remote_uri
declare -A expected_cache_uri
declare -A expected_content_hash
expected_artifact_rows=0
CONTENT_TSV="$TMP_DIR/content.tsv"

awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("teacher_id source_uri source_cache_uri source_hash label_export_uri label_export_cache_uri label_export_hash teacher_identity_uri teacher_identity_cache_uri teacher_identity_hash teacher_policy_uri teacher_policy_cache_uri teacher_policy_hash license_uri license_cache_uri license_hash review_uri review_cache_uri review_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-o content column: " required[i], 4)
      }
      next
    }
    {
      if (NF != header_fields) die("h10-o content row has wrong column count", 5)
      printf "%s\tsource\t%s\t%s\t%s\n", $idx["teacher_id"], $idx["source_uri"], $idx["source_cache_uri"], $idx["source_hash"]
      printf "%s\tlabel_export\t%s\t%s\t%s\n", $idx["teacher_id"], $idx["label_export_uri"], $idx["label_export_cache_uri"], $idx["label_export_hash"]
      printf "%s\tteacher_identity\t%s\t%s\t%s\n", $idx["teacher_id"], $idx["teacher_identity_uri"], $idx["teacher_identity_cache_uri"], $idx["teacher_identity_hash"]
      printf "%s\tteacher_policy\t%s\t%s\t%s\n", $idx["teacher_id"], $idx["teacher_policy_uri"], $idx["teacher_policy_cache_uri"], $idx["teacher_policy_hash"]
      printf "%s\tlicense\t%s\t%s\t%s\n", $idx["teacher_id"], $idx["license_uri"], $idx["license_cache_uri"], $idx["license_hash"]
      printf "%s\treview\t%s\t%s\t%s\n", $idx["teacher_id"], $idx["review_uri"], $idx["review_cache_uri"], $idx["review_hash"]
    }
  ' "$CONTENT_CSV" >"$CONTENT_TSV"

while IFS=$'\t' read -r teacher_id artifact_kind remote_uri cache_uri content_hash; do
  key="${teacher_id}|${artifact_kind}"
  if [[ -n "${expected_remote_uri[$key]:-}" ]]; then
    echo "duplicate h10-o content artifact: $key" >&2
    exit 6
  fi
  expected_remote_uri["$key"]="$remote_uri"
  expected_cache_uri["$key"]="$cache_uri"
  expected_content_hash["$key"]="$content_hash"
  ((expected_artifact_rows += 1))
done <"$CONTENT_TSV"

fetch_rows=0
matched_artifact_rows=0
remote_uri_match_rows=0
cache_uri_match_rows=0
content_hash_match_rows=0
content_cache_hash_verified_rows=0
live_fetch_metadata_rows=0
fetch_manifest_ready_rows=0
live_fetch_ready_rows=0
content_hash_attested_rows=0
attestation_uri_remote_rows=0
attestation_cache_hash_verified_rows=0
independent_attestor_rows=0
independent_attestation_ready_rows=0
declared_real_rows=0
non_fixture_declared_rows=0
fetch_routing="0.000000"
fetch_jump="0.000000"
declare -A fetch_seen
FETCH_TSV="$TMP_DIR/fetch.tsv"

awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("teacher_id artifact_kind remote_uri cache_uri content_hash fetch_started_at_utc fetch_completed_at_utc fetch_tool fetch_tool_version http_status content_length tls_peer_subject tls_peer_issuer tls_sha256_fingerprint attestation_id attestation_uri attestation_cache_uri attestation_hash attestor_id attestor_org attestor_independent fetch_manifest_ready live_fetch_ready content_hash_attested independent_attestation_ready real_remote_fetch_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-o fetch attestation column: " required[i], 7)
      }
      next
    }
    {
      if (NF != header_fields) die("h10-o fetch attestation row has wrong column count", 8)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["teacher_id"],
        $idx["artifact_kind"],
        $idx["remote_uri"],
        $idx["cache_uri"],
        $idx["content_hash"],
        $idx["fetch_started_at_utc"],
        $idx["fetch_completed_at_utc"],
        $idx["fetch_tool"],
        $idx["fetch_tool_version"],
        $idx["http_status"] + 0,
        $idx["content_length"] + 0,
        $idx["tls_peer_subject"],
        $idx["tls_peer_issuer"],
        $idx["tls_sha256_fingerprint"],
        $idx["attestation_id"],
        $idx["attestation_uri"],
        $idx["attestation_cache_uri"],
        $idx["attestation_hash"],
        $idx["attestor_id"],
        $idx["attestor_org"],
        $idx["attestor_independent"] + 0,
        $idx["fetch_manifest_ready"] + 0,
        $idx["live_fetch_ready"] + 0,
        $idx["content_hash_attested"] + 0,
        $idx["independent_attestation_ready"] + 0,
        $idx["real_remote_fetch_declared"] + 0,
        $idx["fixture_or_synthetic_declared"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$FETCH_CSV" >"$FETCH_TSV"

while IFS=$'\t' read -r teacher_id artifact_kind remote_uri cache_uri content_hash fetch_started fetch_completed fetch_tool fetch_tool_version http_status content_length tls_peer_subject tls_peer_issuer tls_fingerprint attestation_id attestation_uri attestation_cache_uri attestation_hash attestor_id attestor_org attestor_independent fetch_manifest_ready live_fetch_ready content_hash_attested independent_attestation_ready real_remote_fetch_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((fetch_rows += 1))
  key="${teacher_id}|${artifact_kind}"
  if [[ -n "${fetch_seen[$key]:-}" ]]; then
    echo "duplicate h10-o fetch attestation artifact: $key" >&2
    exit 10
  fi
  fetch_seen["$key"]=1

  if [[ -n "${expected_remote_uri[$key]:-}" ]]; then
    ((matched_artifact_rows += 1))
  fi
  if [[ "${expected_remote_uri[$key]:-}" == "$remote_uri" && -n "$remote_uri" ]]; then
    ((remote_uri_match_rows += 1))
  fi
  if [[ "${expected_cache_uri[$key]:-}" == "$cache_uri" && -n "$cache_uri" ]]; then
    ((cache_uri_match_rows += 1))
  fi
  if [[ "${expected_content_hash[$key]:-}" == "$content_hash" && -n "$content_hash" ]]; then
    ((content_hash_match_rows += 1))
  fi
  if hash_matches_uri "$cache_uri" "$content_hash"; then
    ((content_cache_hash_verified_rows += 1))
  fi

  if is_present "$fetch_started" &&
      is_present "$fetch_completed" &&
      is_present "$fetch_tool" &&
      is_present "$fetch_tool_version" &&
      [[ "$http_status" -eq 200 ]] &&
      [[ "$content_length" -gt 0 ]] &&
      is_present "$tls_peer_subject" &&
      is_present "$tls_peer_issuer" &&
      is_sha256 "$tls_fingerprint"; then
    ((live_fetch_metadata_rows += 1))
  fi

  if [[ "$fetch_manifest_ready" == "1" ]]; then
    ((fetch_manifest_ready_rows += 1))
  fi
  if [[ "$live_fetch_ready" == "1" ]]; then
    ((live_fetch_ready_rows += 1))
  fi
  if [[ "$content_hash_attested" == "1" && "${expected_content_hash[$key]:-}" == "$content_hash" ]]; then
    ((content_hash_attested_rows += 1))
  fi
  if uri_is_remote_https "$attestation_uri"; then
    ((attestation_uri_remote_rows += 1))
  fi
  if hash_matches_uri "$attestation_cache_uri" "$attestation_hash"; then
    ((attestation_cache_hash_verified_rows += 1))
  fi
  if [[ "$attestor_independent" == "1" ]] &&
      is_present "$attestor_id" &&
      is_present "$attestor_org" &&
      uri_is_remote_https "$attestation_uri"; then
    ((independent_attestor_rows += 1))
  fi
  if [[ "$independent_attestation_ready" == "1" ]]; then
    ((independent_attestation_ready_rows += 1))
  fi
  if [[ "$real_remote_fetch_declared" == "1" ]]; then
    ((declared_real_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  fetch_routing="$(awk -v a="$fetch_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  fetch_jump="$(awk -v a="$fetch_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$FETCH_TSV"

live_fetch_attestation_ready=0
if [[ "$remote_content_ready" == "1" &&
      "$expected_artifact_rows" -gt 0 &&
      "$fetch_rows" -eq "$expected_artifact_rows" &&
      "$matched_artifact_rows" -eq "$expected_artifact_rows" &&
      "$remote_uri_match_rows" -eq "$expected_artifact_rows" &&
      "$cache_uri_match_rows" -eq "$expected_artifact_rows" &&
      "$content_hash_match_rows" -eq "$expected_artifact_rows" &&
      "$content_cache_hash_verified_rows" -eq "$expected_artifact_rows" &&
      "$live_fetch_metadata_rows" -eq "$expected_artifact_rows" &&
      "$fetch_manifest_ready_rows" -eq "$expected_artifact_rows" &&
      "$live_fetch_ready_rows" -eq "$expected_artifact_rows" &&
      "$content_hash_attested_rows" -eq "$expected_artifact_rows" &&
      "$attestation_uri_remote_rows" -eq "$expected_artifact_rows" &&
      "$attestation_cache_hash_verified_rows" -eq "$expected_artifact_rows" &&
      "$independent_attestor_rows" -eq "$expected_artifact_rows" &&
      "$independent_attestation_ready_rows" -eq "$expected_artifact_rows" &&
      "$declared_real_rows" -eq "$expected_artifact_rows" &&
      "$non_fixture_declared_rows" -eq "$expected_artifact_rows" &&
      "$content_routing" == "0.000000" &&
      "$content_jump" == "0.000000" &&
      "$fetch_routing" == "0.000000" &&
      "$fetch_jump" == "0.000000" ]]; then
  live_fetch_attestation_ready=1
fi

real_teacher_source_verified=0
action="remote-teacher-source-content-not-ready"
if [[ "$remote_content_ready" == "1" ]]; then
  if [[ "$fetch_rows" -eq 0 ]]; then
    action="remote-teacher-source-fetch-attestation-missing"
  elif [[ "$fetch_rows" -ne "$expected_artifact_rows" ||
          "$matched_artifact_rows" -ne "$expected_artifact_rows" ||
          "$remote_uri_match_rows" -ne "$expected_artifact_rows" ||
          "$cache_uri_match_rows" -ne "$expected_artifact_rows" ]]; then
    action="remote-teacher-source-fetch-artifact-mismatch"
  elif [[ "$content_hash_match_rows" -ne "$expected_artifact_rows" ||
          "$content_cache_hash_verified_rows" -ne "$expected_artifact_rows" ||
          "$content_hash_attested_rows" -ne "$expected_artifact_rows" ]]; then
    action="remote-teacher-source-fetch-content-hash-mismatch"
  elif [[ "$live_fetch_metadata_rows" -ne "$expected_artifact_rows" ||
          "$fetch_manifest_ready_rows" -ne "$expected_artifact_rows" ||
          "$live_fetch_ready_rows" -ne "$expected_artifact_rows" ]]; then
    action="remote-teacher-source-fetch-metadata-incomplete"
  elif [[ "$attestation_uri_remote_rows" -ne "$expected_artifact_rows" ||
          "$attestation_cache_hash_verified_rows" -ne "$expected_artifact_rows" ||
          "$independent_attestor_rows" -ne "$expected_artifact_rows" ||
          "$independent_attestation_ready_rows" -ne "$expected_artifact_rows" ]]; then
    action="remote-teacher-source-independent-attestation-missing"
  elif [[ "$declared_real_rows" -ne "$expected_artifact_rows" ||
          "$non_fixture_declared_rows" -ne "$expected_artifact_rows" ]]; then
    action="remote-teacher-source-live-fetch-contract-incomplete"
  elif [[ "$live_fetch_attestation_ready" == "1" ]]; then
    action="remote-teacher-source-runtime-fetcher-missing"
  fi
fi

total_routing="$(awk -v a="$content_routing" -v b="$fetch_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$content_jump" -v b="$fetch_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "teacher_source_fetch_scope,content_source,fetch_attestation_source,h10n_action,content_rows,expected_fetch_artifact_rows,fetch_attestation_rows,matched_artifact_rows,remote_uri_match_rows,cache_uri_match_rows,content_hash_match_rows,content_cache_hash_verified_rows,live_fetch_metadata_rows,fetch_manifest_ready_rows,live_fetch_ready_rows,content_hash_attested_rows,attestation_uri_remote_rows,attestation_cache_hash_verified_rows,independent_attestor_rows,independent_attestation_ready_rows,declared_real_rows,non_fixture_declared_rows,remote_teacher_source_content_ready,remote_teacher_source_live_fetch_attestation_ready,real_teacher_source_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-h10o,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$content_source" \
    "$FETCH_SOURCE" \
    "$content_action" \
    "$content_rows" \
    "$expected_artifact_rows" \
    "$fetch_rows" \
    "$matched_artifact_rows" \
    "$remote_uri_match_rows" \
    "$cache_uri_match_rows" \
    "$content_hash_match_rows" \
    "$content_cache_hash_verified_rows" \
    "$live_fetch_metadata_rows" \
    "$fetch_manifest_ready_rows" \
    "$live_fetch_ready_rows" \
    "$content_hash_attested_rows" \
    "$attestation_uri_remote_rows" \
    "$attestation_cache_hash_verified_rows" \
    "$independent_attestor_rows" \
    "$independent_attestation_ready_rows" \
    "$declared_real_rows" \
    "$non_fixture_declared_rows" \
    "$remote_content_ready" \
    "$live_fetch_attestation_ready" \
    "$real_teacher_source_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "remote-content,%s,ready=%d h10n_action=%s\n" \
    "$([[ "$remote_content_ready" == "1" ]] && echo pass || echo blocked)" \
    "$remote_content_ready" \
    "$content_action"
  printf "fetch-attestation-rows,%s,rows=%d expected=%d\n" \
    "$([[ "$fetch_rows" -gt 0 && "$fetch_rows" -eq "$expected_artifact_rows" ]] && echo pass || echo blocked)" \
    "$fetch_rows" \
    "$expected_artifact_rows"
  printf "fetch-artifact-match,%s,matched=%d/%d remote=%d cache=%d\n" \
    "$([[ "$matched_artifact_rows" -eq "$expected_artifact_rows" && "$remote_uri_match_rows" -eq "$expected_artifact_rows" && "$cache_uri_match_rows" -eq "$expected_artifact_rows" && "$expected_artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$matched_artifact_rows" \
    "$expected_artifact_rows" \
    "$remote_uri_match_rows" \
    "$cache_uri_match_rows"
  printf "fetch-content-hash,%s,hash=%d/%d cache_verified=%d attested=%d\n" \
    "$([[ "$content_hash_match_rows" -eq "$expected_artifact_rows" && "$content_cache_hash_verified_rows" -eq "$expected_artifact_rows" && "$content_hash_attested_rows" -eq "$expected_artifact_rows" && "$expected_artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$content_hash_match_rows" \
    "$expected_artifact_rows" \
    "$content_cache_hash_verified_rows" \
    "$content_hash_attested_rows"
  printf "live-fetch-metadata,%s,metadata=%d/%d manifest=%d live=%d\n" \
    "$([[ "$live_fetch_metadata_rows" -eq "$expected_artifact_rows" && "$fetch_manifest_ready_rows" -eq "$expected_artifact_rows" && "$live_fetch_ready_rows" -eq "$expected_artifact_rows" && "$expected_artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$live_fetch_metadata_rows" \
    "$expected_artifact_rows" \
    "$fetch_manifest_ready_rows" \
    "$live_fetch_ready_rows"
  printf "independent-attestation,%s,remote_uri=%d/%d attestation_hash=%d independent_attestor=%d ready=%d\n" \
    "$([[ "$attestation_uri_remote_rows" -eq "$expected_artifact_rows" && "$attestation_cache_hash_verified_rows" -eq "$expected_artifact_rows" && "$independent_attestor_rows" -eq "$expected_artifact_rows" && "$independent_attestation_ready_rows" -eq "$expected_artifact_rows" && "$expected_artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$attestation_uri_remote_rows" \
    "$expected_artifact_rows" \
    "$attestation_cache_hash_verified_rows" \
    "$independent_attestor_rows" \
    "$independent_attestation_ready_rows"
  printf "live-fetch-contract,%s,declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$declared_real_rows" -eq "$expected_artifact_rows" && "$non_fixture_declared_rows" -eq "$expected_artifact_rows" && "$expected_artifact_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$declared_real_rows" \
    "$expected_artifact_rows" \
    "$non_fixture_declared_rows" \
    "$expected_artifact_rows"
  printf "remote-teacher-source-live-fetch-attestation,%s,ready=%d action=%s\n" \
    "$([[ "$live_fetch_attestation_ready" == "1" ]] && echo pass || echo blocked)" \
    "$live_fetch_attestation_ready" \
    "$action"
  printf "real-teacher-source-verification,%s,real_verified=%d action=%s\n" \
    "$([[ "$real_teacher_source_verified" == "1" ]] && echo pass || echo blocked)" \
    "$real_teacher_source_verified" \
    "$action"
} >"$DECISION_CSV"

echo "fetch_attestation: $FETCH_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
