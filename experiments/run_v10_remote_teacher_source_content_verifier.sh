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

PREFIX="v10_remote_teacher_source_content_verifier"
ACQUISITION_PREFIX="v10_remote_teacher_source_acquisition_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_remote_teacher_source_content_verifier_smoke"
  ACQUISITION_PREFIX="v10_remote_teacher_source_acquisition_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v10_remote_teacher_source_acquisition_gate.sh" "${RUN_ARGS[@]}" >/dev/null

ACQUISITION_CSV="${V10_REMOTE_TEACHER_SOURCE_ACQUISITION_CSV:-$RESULTS_DIR/${ACQUISITION_PREFIX}_acquisition.csv}"
ACQUISITION_SUMMARY_CSV="$RESULTS_DIR/${ACQUISITION_PREFIX}_summary.csv"
CONTENT_CSV="$RESULTS_DIR/${PREFIX}_content.csv"
CONTENT_SOURCE="pending-fixture"
if [[ -n "${V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV:-}" ]]; then
  CONTENT_CSV="$V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV"
  CONTENT_SOURCE="provided-csv"
  if [[ ! -s "$CONTENT_CSV" ]]; then
    echo "V10_REMOTE_TEACHER_SOURCE_CONTENT_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  {
    echo "teacher_id,source_uri,source_cache_uri,source_hash,label_export_uri,label_export_cache_uri,label_export_hash,teacher_identity_uri,teacher_identity_cache_uri,teacher_identity_hash,teacher_policy_uri,teacher_policy_cache_uri,teacher_policy_hash,license_uri,license_cache_uri,license_hash,review_uri,review_cache_uri,review_hash,fetch_tool,content_hash_algorithm,fetch_manifest_ready,content_cache_ready,independent_review_ready,real_remote_source_declared,fixture_or_synthetic_declared,routing_trigger_rate,active_jump_rate"
  } >"$CONTENT_CSV"
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

is_present() {
  local value="$1"
  [[ "$value" != "" && "$value" != "pending" ]]
}

ACQUISITION_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("acquisition_source acquisition_rows remote_teacher_source_acquisition_ready real_teacher_source_verified action routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-n acquisition summary column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%s,%d,%d,%d,%s,%.6f,%.6f\n",
        $idx["acquisition_source"],
        $idx["acquisition_rows"] + 0,
        $idx["remote_teacher_source_acquisition_ready"] + 0,
        $idx["real_teacher_source_verified"] + 0,
        $idx["action"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
    END {
      if (rows != 1) die("expected one h10-n acquisition summary row", 3)
    }
  ' "$ACQUISITION_SUMMARY_CSV"
)"

IFS=, read -r acquisition_source acquisition_rows remote_acquisition_ready acquisition_real_verified acquisition_action acquisition_routing acquisition_jump <<<"$ACQUISITION_VALUES"

declare -A acq_source_uri
declare -A acq_source_hash
declare -A acq_label_export_uri
declare -A acq_label_export_hash
declare -A acq_identity_uri
declare -A acq_identity_hash
declare -A acq_policy_uri
declare -A acq_policy_hash
declare -A acq_license_uri
declare -A acq_license_hash
declare -A acq_review_uri
declare -A acq_review_hash
declare -A acq_seen
acq_rows_seen=0
ACQUISITION_TSV="$TMP_DIR/acquisition.tsv"

awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("teacher_id source_uri source_hash label_export_uri label_export_hash teacher_identity_uri teacher_identity_hash teacher_policy_uri teacher_policy_hash license_uri license_hash review_uri review_hash", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-n acquisition column: " required[i], 4)
      }
      next
    }
    {
      if (NF != header_fields) die("h10-n acquisition row has wrong column count", 6)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
        $idx["teacher_id"],
        $idx["source_uri"],
        $idx["source_hash"],
        $idx["label_export_uri"],
        $idx["label_export_hash"],
        $idx["teacher_identity_uri"],
        $idx["teacher_identity_hash"],
        $idx["teacher_policy_uri"],
        $idx["teacher_policy_hash"],
        $idx["license_uri"],
        $idx["license_hash"],
        $idx["review_uri"],
        $idx["review_hash"]
    }
  ' "$ACQUISITION_CSV" >"$ACQUISITION_TSV"

while IFS=$'\t' read -r teacher_id source_uri source_hash label_export_uri label_export_hash teacher_identity_uri teacher_identity_hash teacher_policy_uri teacher_policy_hash license_uri license_hash review_uri review_hash; do
  ((acq_rows_seen += 1))
  if [[ -n "${acq_seen[$teacher_id]:-}" ]]; then
    echo "duplicate h10-n acquisition teacher id: $teacher_id" >&2
    exit 5
  fi
  acq_seen["$teacher_id"]=1
  acq_source_uri["$teacher_id"]="$source_uri"
  acq_source_hash["$teacher_id"]="$source_hash"
  acq_label_export_uri["$teacher_id"]="$label_export_uri"
  acq_label_export_hash["$teacher_id"]="$label_export_hash"
  acq_identity_uri["$teacher_id"]="$teacher_identity_uri"
  acq_identity_hash["$teacher_id"]="$teacher_identity_hash"
  acq_policy_uri["$teacher_id"]="$teacher_policy_uri"
  acq_policy_hash["$teacher_id"]="$teacher_policy_hash"
  acq_license_uri["$teacher_id"]="$license_uri"
  acq_license_hash["$teacher_id"]="$license_hash"
  acq_review_uri["$teacher_id"]="$review_uri"
  acq_review_hash["$teacher_id"]="$review_hash"
done <"$ACQUISITION_TSV"

content_rows=0
matched_teacher_rows=0
remote_uri_match_rows=0
hash_manifest_match_rows=0
required_content_fields=0
cache_uri_fields=0
content_hash_verified_fields=0
fetch_manifest_ready_rows=0
content_cache_ready_rows=0
independent_review_ready_rows=0
declared_real_rows=0
non_fixture_declared_rows=0
content_metadata_rows=0
content_routing="0.000000"
content_jump="0.000000"
CONTENT_TSV="$TMP_DIR/content.tsv"

awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      header_fields = NF
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("teacher_id source_uri source_cache_uri source_hash label_export_uri label_export_cache_uri label_export_hash teacher_identity_uri teacher_identity_cache_uri teacher_identity_hash teacher_policy_uri teacher_policy_cache_uri teacher_policy_hash license_uri license_cache_uri license_hash review_uri review_cache_uri review_hash fetch_tool content_hash_algorithm fetch_manifest_ready content_cache_ready independent_review_ready real_remote_source_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10-n content verifier column: " required[i], 7)
      }
      next
    }
    {
      if (NF != header_fields) die("h10-n content verifier row has wrong column count", 8)
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["teacher_id"],
        $idx["source_uri"],
        $idx["source_cache_uri"],
        $idx["source_hash"],
        $idx["label_export_uri"],
        $idx["label_export_cache_uri"],
        $idx["label_export_hash"],
        $idx["teacher_identity_uri"],
        $idx["teacher_identity_cache_uri"],
        $idx["teacher_identity_hash"],
        $idx["teacher_policy_uri"],
        $idx["teacher_policy_cache_uri"],
        $idx["teacher_policy_hash"],
        $idx["license_uri"],
        $idx["license_cache_uri"],
        $idx["license_hash"],
        $idx["review_uri"],
        $idx["review_cache_uri"],
        $idx["review_hash"],
        $idx["fetch_tool"],
        $idx["content_hash_algorithm"],
        $idx["fetch_manifest_ready"] + 0,
        $idx["content_cache_ready"] + 0,
        $idx["independent_review_ready"] + 0,
        $idx["real_remote_source_declared"] + 0,
        $idx["fixture_or_synthetic_declared"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$CONTENT_CSV" >"$CONTENT_TSV"

while IFS=$'\t' read -r teacher_id source_uri source_cache_uri source_hash label_export_uri label_export_cache_uri label_export_hash teacher_identity_uri teacher_identity_cache_uri teacher_identity_hash teacher_policy_uri teacher_policy_cache_uri teacher_policy_hash license_uri license_cache_uri license_hash review_uri review_cache_uri review_hash fetch_tool content_hash_algorithm fetch_manifest_ready content_cache_ready independent_review_ready real_remote_source_declared fixture_or_synthetic_declared routing_trigger_rate active_jump_rate; do
  ((content_rows += 1))
  row_remote_match=0
  row_hash_match=0
  row_cache_uri_fields=0
  row_content_hash_verified_fields=0

  if [[ -n "${acq_seen[$teacher_id]:-}" ]]; then
    ((matched_teacher_rows += 1))
  fi

  if [[ "${acq_source_uri[$teacher_id]:-}" == "$source_uri" &&
        "${acq_label_export_uri[$teacher_id]:-}" == "$label_export_uri" &&
        "${acq_identity_uri[$teacher_id]:-}" == "$teacher_identity_uri" &&
        "${acq_policy_uri[$teacher_id]:-}" == "$teacher_policy_uri" &&
        "${acq_license_uri[$teacher_id]:-}" == "$license_uri" &&
        "${acq_review_uri[$teacher_id]:-}" == "$review_uri" ]]; then
    row_remote_match=1
    ((remote_uri_match_rows += 1))
  fi

  if [[ "${acq_source_hash[$teacher_id]:-}" == "$source_hash" &&
        "${acq_label_export_hash[$teacher_id]:-}" == "$label_export_hash" &&
        "${acq_identity_hash[$teacher_id]:-}" == "$teacher_identity_hash" &&
        "${acq_policy_hash[$teacher_id]:-}" == "$teacher_policy_hash" &&
        "${acq_license_hash[$teacher_id]:-}" == "$license_hash" &&
        "${acq_review_hash[$teacher_id]:-}" == "$review_hash" ]]; then
    row_hash_match=1
    ((hash_manifest_match_rows += 1))
  fi

  for uri in "$source_cache_uri" "$label_export_cache_uri" "$teacher_identity_cache_uri" "$teacher_policy_cache_uri" "$license_cache_uri" "$review_cache_uri"; do
    ((required_content_fields += 1))
    if uri_to_local_path "$uri" >/dev/null; then
      ((cache_uri_fields += 1))
      ((row_cache_uri_fields += 1))
    fi
  done

  if hash_matches_uri "$source_cache_uri" "$source_hash"; then
    ((content_hash_verified_fields += 1))
    ((row_content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$label_export_cache_uri" "$label_export_hash"; then
    ((content_hash_verified_fields += 1))
    ((row_content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$teacher_identity_cache_uri" "$teacher_identity_hash"; then
    ((content_hash_verified_fields += 1))
    ((row_content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$teacher_policy_cache_uri" "$teacher_policy_hash"; then
    ((content_hash_verified_fields += 1))
    ((row_content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$license_cache_uri" "$license_hash"; then
    ((content_hash_verified_fields += 1))
    ((row_content_hash_verified_fields += 1))
  fi
  if hash_matches_uri "$review_cache_uri" "$review_hash"; then
    ((content_hash_verified_fields += 1))
    ((row_content_hash_verified_fields += 1))
  fi

  if [[ "$fetch_manifest_ready" == "1" ]]; then
    ((fetch_manifest_ready_rows += 1))
  fi
  if [[ "$content_cache_ready" == "1" ]]; then
    ((content_cache_ready_rows += 1))
  fi
  if [[ "$independent_review_ready" == "1" ]]; then
    ((independent_review_ready_rows += 1))
  fi
  if [[ "$real_remote_source_declared" == "1" ]]; then
    ((declared_real_rows += 1))
  fi
  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi
  if is_present "$fetch_tool" && [[ "${content_hash_algorithm,,}" == "sha256" ]]; then
    ((content_metadata_rows += 1))
  fi
  if [[ "$row_remote_match" == "1" && "$row_hash_match" == "1" &&
        "$row_cache_uri_fields" -eq 6 && "$row_content_hash_verified_fields" -eq 6 ]]; then
    :
  fi

  content_routing="$(awk -v a="$content_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  content_jump="$(awk -v a="$content_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done <"$CONTENT_TSV"

remote_content_ready=0
if [[ "$remote_acquisition_ready" == "1" &&
      "$content_rows" -gt 0 &&
      "$content_rows" -eq "$acquisition_rows" &&
      "$acq_rows_seen" -eq "$acquisition_rows" &&
      "$matched_teacher_rows" -eq "$content_rows" &&
      "$remote_uri_match_rows" -eq "$content_rows" &&
      "$hash_manifest_match_rows" -eq "$content_rows" &&
      "$required_content_fields" -gt 0 &&
      "$cache_uri_fields" -eq "$required_content_fields" &&
      "$content_hash_verified_fields" -eq "$required_content_fields" &&
      "$fetch_manifest_ready_rows" -eq "$content_rows" &&
      "$content_cache_ready_rows" -eq "$content_rows" &&
      "$independent_review_ready_rows" -eq "$content_rows" &&
      "$declared_real_rows" -eq "$content_rows" &&
      "$non_fixture_declared_rows" -eq "$content_rows" &&
      "$content_metadata_rows" -eq "$content_rows" &&
      "$acquisition_routing" == "0.000000" &&
      "$acquisition_jump" == "0.000000" &&
      "$content_routing" == "0.000000" &&
      "$content_jump" == "0.000000" ]]; then
  remote_content_ready=1
fi

real_teacher_source_verified=0
action="remote-teacher-source-acquisition-not-ready"
if [[ "$remote_acquisition_ready" == "1" ]]; then
  if [[ "$content_rows" -eq 0 ]]; then
    action="remote-teacher-source-content-missing"
  elif [[ "$matched_teacher_rows" -ne "$content_rows" ||
          "$remote_uri_match_rows" -ne "$content_rows" ]]; then
    action="remote-teacher-source-content-uri-mismatch"
  elif [[ "$hash_manifest_match_rows" -ne "$content_rows" ]]; then
    action="remote-teacher-source-content-hash-manifest-mismatch"
  elif [[ "$cache_uri_fields" -ne "$required_content_fields" ||
          "$content_hash_verified_fields" -ne "$required_content_fields" ]]; then
    action="remote-teacher-source-content-hash-mismatch"
  elif [[ "$fetch_manifest_ready_rows" -ne "$content_rows" ||
          "$content_cache_ready_rows" -ne "$content_rows" ||
          "$independent_review_ready_rows" -ne "$content_rows" ||
          "$declared_real_rows" -ne "$content_rows" ||
          "$non_fixture_declared_rows" -ne "$content_rows" ||
          "$content_metadata_rows" -ne "$content_rows" ]]; then
    action="remote-teacher-source-content-contract-incomplete"
  elif [[ "$remote_content_ready" == "1" ]]; then
    action="remote-teacher-source-live-fetch-missing"
  fi
fi

total_routing="$(awk -v a="$acquisition_routing" -v b="$content_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$acquisition_jump" -v b="$content_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "teacher_source_content_scope,acquisition_source,content_source,h10m_action,acquisition_rows,content_rows,matched_teacher_rows,remote_uri_match_rows,hash_manifest_match_rows,required_content_fields,cache_uri_fields,content_hash_verified_fields,fetch_manifest_ready_rows,content_cache_ready_rows,independent_review_ready_rows,declared_real_rows,non_fixture_declared_rows,remote_teacher_source_acquisition_ready,remote_teacher_source_content_ready,real_teacher_source_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-h10n,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$acquisition_source" \
    "$CONTENT_SOURCE" \
    "$acquisition_action" \
    "$acquisition_rows" \
    "$content_rows" \
    "$matched_teacher_rows" \
    "$remote_uri_match_rows" \
    "$hash_manifest_match_rows" \
    "$required_content_fields" \
    "$cache_uri_fields" \
    "$content_hash_verified_fields" \
    "$fetch_manifest_ready_rows" \
    "$content_cache_ready_rows" \
    "$independent_review_ready_rows" \
    "$declared_real_rows" \
    "$non_fixture_declared_rows" \
    "$remote_acquisition_ready" \
    "$remote_content_ready" \
    "$real_teacher_source_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "remote-acquisition,%s,ready=%d h10m_action=%s\n" \
    "$([[ "$remote_acquisition_ready" == "1" ]] && echo pass || echo blocked)" \
    "$remote_acquisition_ready" \
    "$acquisition_action"
  printf "content-rows,%s,content_rows=%d acquisition_rows=%d\n" \
    "$([[ "$content_rows" -gt 0 && "$content_rows" -eq "$acquisition_rows" ]] && echo pass || echo blocked)" \
    "$content_rows" \
    "$acquisition_rows"
  printf "remote-uri-match,%s,matched=%d/%d\n" \
    "$([[ "$remote_uri_match_rows" -eq "$content_rows" && "$content_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$remote_uri_match_rows" \
    "$content_rows"
  printf "hash-manifest-match,%s,matched=%d/%d\n" \
    "$([[ "$hash_manifest_match_rows" -eq "$content_rows" && "$content_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$hash_manifest_match_rows" \
    "$content_rows"
  printf "content-cache-hash,%s,verified=%d/%d cache_uri_fields=%d\n" \
    "$([[ "$required_content_fields" -gt 0 && "$content_hash_verified_fields" -eq "$required_content_fields" && "$cache_uri_fields" -eq "$required_content_fields" ]] && echo pass || echo blocked)" \
    "$content_hash_verified_fields" \
    "$required_content_fields" \
    "$cache_uri_fields"
  printf "content-contract,%s,fetch=%d/%d cache=%d/%d review=%d/%d declared_real=%d/%d non_fixture=%d/%d\n" \
    "$([[ "$fetch_manifest_ready_rows" -eq "$content_rows" && "$content_cache_ready_rows" -eq "$content_rows" && "$independent_review_ready_rows" -eq "$content_rows" && "$declared_real_rows" -eq "$content_rows" && "$non_fixture_declared_rows" -eq "$content_rows" && "$content_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$fetch_manifest_ready_rows" \
    "$content_rows" \
    "$content_cache_ready_rows" \
    "$content_rows" \
    "$independent_review_ready_rows" \
    "$content_rows" \
    "$declared_real_rows" \
    "$content_rows" \
    "$non_fixture_declared_rows" \
    "$content_rows"
  printf "remote-teacher-source-content,%s,ready=%d action=%s\n" \
    "$([[ "$remote_content_ready" == "1" ]] && echo pass || echo blocked)" \
    "$remote_content_ready" \
    "$action"
  printf "real-teacher-source-verification,%s,real_verified=%d action=%s\n" \
    "$([[ "$real_teacher_source_verified" == "1" ]] && echo pass || echo blocked)" \
    "$real_teacher_source_verified" \
    "$action"
} >"$DECISION_CSV"

echo "content: $CONTENT_CSV"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
