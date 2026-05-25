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

PREFIX="v10_teacher_external_label_source_verifier"
INGESTION_PREFIX="v10_teacher_external_label_ingestion"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v10_teacher_external_label_source_verifier_smoke"
  INGESTION_PREFIX="v10_teacher_external_label_ingestion_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  RUN_ARGS=(--full)
fi

"$ROOT_DIR/experiments/run_v10_teacher_external_label_ingestion.sh" "${RUN_ARGS[@]}" >/dev/null

LABEL_CSV="${V10_TEACHER_EXTERNAL_LABEL_CSV:-}"
SOURCE_CSV="$RESULTS_DIR/${PREFIX}_source.csv"
SOURCE_SOURCE="pending-fixture"
if [[ -n "${V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV:-}" ]]; then
  SOURCE_CSV="$V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV"
  SOURCE_SOURCE="provided-csv"
  if [[ ! -s "$SOURCE_CSV" ]]; then
    echo "V10_TEACHER_EXTERNAL_LABEL_SOURCE_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  {
    echo "teacher_id,source_uri,source_hash,label_export_uri,label_export_hash,teacher_identity_uri,teacher_identity_hash,teacher_model_family,teacher_policy_uri,teacher_policy_hash,license_uri,license_hash,provenance_basis,real_teacher_source_declared,fixture_or_synthetic_declared,source_artifact_ready,label_export_ready,teacher_identity_ready,teacher_policy_ready,license_ready,routing_trigger_rate,active_jump_rate"
    if [[ -n "$LABEL_CSV" ]]; then
      awk -F, '
        NR == 1 {
          for (i = 1; i <= NF; i++) idx[$i] = i
          if (!("teacher_id" in idx) || !("source_uri" in idx)) {
            print "missing h10 pending teacher source label column" > "/dev/stderr"
            exit 2
          }
          next
        }
        {
          key = $idx["teacher_id"] SUBSEP $idx["source_uri"]
          if (!(key in seen)) {
            seen[key] = 1
            printf "%s,%s,pending,pending,pending,pending,pending,pending,pending,pending,pending,pending,pending,0,1,0,0,0,0,0,0,0\n",
              $idx["teacher_id"],
              $idx["source_uri"]
          }
        }
      ' "$LABEL_CSV"
    fi
  } >"$SOURCE_CSV"
fi

INGESTION_SUMMARY_CSV="$RESULTS_DIR/${INGESTION_PREFIX}_summary.csv"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

is_present() {
  local value="$1"
  [[ "$value" != "" && "$value" != "pending" ]]
}

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

hash_matches() {
  local path="$1"
  local expected="$2"
  local expected_hex
  local actual_hex

  if [[ ! -f "$path" ]] || ! is_sha256 "$expected"; then
    return 1
  fi
  expected_hex="${expected#sha256:}"
  actual_hex="$(sha256sum "$path" | awk '{print $1}')"
  [[ "$actual_hex" == "$expected_hex" ]]
}

is_local_fixture_path() {
  local path="$1"
  [[ "$path" == "$RESULTS_DIR"/* ]]
}

INGESTION_VALUES="$(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("external_schema_ready external_label_source_ready teacher_external_labels_ready label_source routing_trigger_rate active_jump_rate external_label_rows", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10 teacher source ingestion column: " required[i], 2)
      }
      next
    }
    {
      rows++
      printf "%d,%d,%d,%s,%.6f,%.6f,%d\n",
        $idx["external_schema_ready"] + 0,
        $idx["external_label_source_ready"] + 0,
        $idx["teacher_external_labels_ready"] + 0,
        $idx["label_source"],
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0,
        $idx["external_label_rows"] + 0
    }
    END {
      if (rows != 1) die("expected one h10 teacher source ingestion row", 3)
    }
  ' "$INGESTION_SUMMARY_CSV"
)"

IFS=, read -r external_schema_ready external_label_source_ready teacher_external_labels_ready label_source ingestion_routing ingestion_jump external_label_rows <<<"$INGESTION_VALUES"

declare -A label_source_uri_by_teacher
declare -A label_teacher_seen
label_teacher_rows=0
label_provenance_hash_rows=0
if [[ -n "$LABEL_CSV" ]]; then
  while IFS=$'\t' read -r teacher_id source_uri provenance_hash; do
    if [[ -z "${label_teacher_seen[$teacher_id]:-}" ]]; then
      ((label_teacher_rows += 1))
      label_teacher_seen["$teacher_id"]=1
      label_source_uri_by_teacher["$teacher_id"]="$source_uri"
    fi
    if is_sha256 "$provenance_hash"; then
      ((label_provenance_hash_rows += 1))
    fi
  done < <(
    awk -F, '
      function die(message, code) {
        print message > "/dev/stderr"
        exit code
      }
      NR == 1 {
        for (i = 1; i <= NF; i++) idx[$i] = i
        required_count = split("teacher_id source_uri provenance_hash", required, " ")
        for (i = 1; i <= required_count; i++) {
          if (!(required[i] in idx)) die("missing h10 teacher source label column: " required[i], 4)
        }
        next
      }
      {
        printf "%s\t%s\t%s\n",
          $idx["teacher_id"],
          $idx["source_uri"],
          $idx["provenance_hash"]
      }
    ' "$LABEL_CSV"
  )
fi

source_rows=0
matched_teacher_rows=0
source_artifact_rows=0
source_hash_verified_rows=0
label_export_rows=0
label_export_hash_verified_rows=0
teacher_identity_rows=0
teacher_identity_hash_verified_rows=0
teacher_policy_rows=0
teacher_policy_hash_verified_rows=0
license_rows=0
license_hash_verified_rows=0
provenance_basis_rows=0
ready_rows=0
local_fixture_uri_rows=0
real_source_declared_rows=0
non_fixture_declared_rows=0
source_routing="0.000000"
source_jump="0.000000"
declare -A source_seen

while IFS=$'\t' read -r teacher_id source_uri source_hash label_export_uri label_export_hash teacher_identity_uri teacher_identity_hash teacher_model_family teacher_policy_uri teacher_policy_hash license_uri license_hash provenance_basis real_teacher_source_declared fixture_or_synthetic_declared source_artifact_ready label_export_ready teacher_identity_ready teacher_policy_ready license_ready routing_trigger_rate active_jump_rate; do
  ((source_rows += 1))
  row_local_fixture=0
  if [[ -n "${source_seen[$teacher_id]:-}" ]]; then
    echo "duplicate h10 teacher source id: $teacher_id" >&2
    exit 5
  fi
  source_seen["$teacher_id"]=1

  if [[ -n "${label_source_uri_by_teacher[$teacher_id]:-}" &&
        "${label_source_uri_by_teacher[$teacher_id]}" == "$source_uri" ]] &&
      is_present "$teacher_id" &&
      is_present "$source_uri"; then
    ((matched_teacher_rows += 1))
  fi

  if source_path="$(uri_to_local_path "$source_uri")"; then
    if is_local_fixture_path "$source_path"; then
      row_local_fixture=1
    fi
    ((source_artifact_rows += 1))
    if hash_matches "$source_path" "$source_hash"; then
      ((source_hash_verified_rows += 1))
    fi
  fi

  if export_path="$(uri_to_local_path "$label_export_uri")"; then
    if is_local_fixture_path "$export_path"; then
      row_local_fixture=1
    fi
    ((label_export_rows += 1))
    if hash_matches "$export_path" "$label_export_hash"; then
      ((label_export_hash_verified_rows += 1))
    fi
  fi

  if identity_path="$(uri_to_local_path "$teacher_identity_uri")"; then
    if is_local_fixture_path "$identity_path"; then
      row_local_fixture=1
    fi
    ((teacher_identity_rows += 1))
    if hash_matches "$identity_path" "$teacher_identity_hash"; then
      ((teacher_identity_hash_verified_rows += 1))
    fi
  fi

  if policy_path="$(uri_to_local_path "$teacher_policy_uri")"; then
    if is_local_fixture_path "$policy_path"; then
      row_local_fixture=1
    fi
    ((teacher_policy_rows += 1))
    if hash_matches "$policy_path" "$teacher_policy_hash"; then
      ((teacher_policy_hash_verified_rows += 1))
    fi
  fi

  if license_path="$(uri_to_local_path "$license_uri")"; then
    if is_local_fixture_path "$license_path"; then
      row_local_fixture=1
    fi
    ((license_rows += 1))
    if hash_matches "$license_path" "$license_hash"; then
      ((license_hash_verified_rows += 1))
    fi
  fi

  if is_present "$provenance_basis" &&
      is_present "$teacher_model_family"; then
    ((provenance_basis_rows += 1))
  fi

  if [[ "$source_artifact_ready" == "1" &&
        "$label_export_ready" == "1" &&
        "$teacher_identity_ready" == "1" &&
        "$teacher_policy_ready" == "1" &&
        "$license_ready" == "1" ]] &&
      is_present "$teacher_id" &&
      is_present "$source_uri" &&
      is_present "$label_export_uri" &&
      is_present "$teacher_identity_uri" &&
      is_present "$teacher_policy_uri" &&
      is_present "$license_uri"; then
    ((ready_rows += 1))
  fi

  if [[ "$row_local_fixture" == "1" ]]; then
    ((local_fixture_uri_rows += 1))
  fi

  if [[ "$real_teacher_source_declared" == "1" ]]; then
    ((real_source_declared_rows += 1))
  fi

  if [[ "$fixture_or_synthetic_declared" == "0" ]]; then
    ((non_fixture_declared_rows += 1))
  fi

  source_routing="$(awk -v a="$source_routing" -v b="$routing_trigger_rate" 'BEGIN { printf "%.6f", a + b }')"
  source_jump="$(awk -v a="$source_jump" -v b="$active_jump_rate" 'BEGIN { printf "%.6f", a + b }')"
done < <(
  awk -F, '
    function die(message, code) {
      print message > "/dev/stderr"
      exit code
    }
    NR == 1 {
      for (i = 1; i <= NF; i++) idx[$i] = i
      required_count = split("teacher_id source_uri source_hash label_export_uri label_export_hash teacher_identity_uri teacher_identity_hash teacher_model_family teacher_policy_uri teacher_policy_hash license_uri license_hash provenance_basis real_teacher_source_declared fixture_or_synthetic_declared source_artifact_ready label_export_ready teacher_identity_ready teacher_policy_ready license_ready routing_trigger_rate active_jump_rate", required, " ")
      for (i = 1; i <= required_count; i++) {
        if (!(required[i] in idx)) die("missing h10 teacher source verifier column: " required[i], 6)
      }
      next
    }
    {
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\n",
        $idx["teacher_id"],
        $idx["source_uri"],
        $idx["source_hash"],
        $idx["label_export_uri"],
        $idx["label_export_hash"],
        $idx["teacher_identity_uri"],
        $idx["teacher_identity_hash"],
        $idx["teacher_model_family"],
        $idx["teacher_policy_uri"],
        $idx["teacher_policy_hash"],
        $idx["license_uri"],
        $idx["license_hash"],
        $idx["provenance_basis"],
        $idx["real_teacher_source_declared"] + 0,
        $idx["fixture_or_synthetic_declared"] + 0,
        $idx["source_artifact_ready"] + 0,
        $idx["label_export_ready"] + 0,
        $idx["teacher_identity_ready"] + 0,
        $idx["teacher_policy_ready"] + 0,
        $idx["license_ready"] + 0,
        $idx["routing_trigger_rate"] + 0,
        $idx["active_jump_rate"] + 0
    }
  ' "$SOURCE_CSV"
)

teacher_source_chain_verified=0
if [[ "$teacher_external_labels_ready" == "1" &&
      "$source_rows" -gt 0 &&
      "$source_rows" -eq "$label_teacher_rows" &&
      "$matched_teacher_rows" -eq "$source_rows" &&
      "$source_artifact_rows" -eq "$source_rows" &&
      "$source_hash_verified_rows" -eq "$source_rows" &&
      "$label_export_rows" -eq "$source_rows" &&
      "$label_export_hash_verified_rows" -eq "$source_rows" &&
      "$teacher_identity_rows" -eq "$source_rows" &&
      "$teacher_identity_hash_verified_rows" -eq "$source_rows" &&
      "$teacher_policy_rows" -eq "$source_rows" &&
      "$teacher_policy_hash_verified_rows" -eq "$source_rows" &&
      "$license_rows" -eq "$source_rows" &&
      "$license_hash_verified_rows" -eq "$source_rows" &&
      "$provenance_basis_rows" -eq "$source_rows" &&
      "$ready_rows" -eq "$source_rows" &&
      "$label_provenance_hash_rows" -eq "$external_label_rows" &&
      "$source_routing" == "0.000000" &&
      "$source_jump" == "0.000000" ]]; then
  teacher_source_chain_verified=1
fi

real_teacher_source_verified=0
action="teacher-external-label-source-missing"
if [[ "$teacher_external_labels_ready" == "1" ]]; then
  if [[ "$source_rows" -eq 0 ||
        "$matched_teacher_rows" -ne "$source_rows" ||
        "$ready_rows" -ne "$source_rows" ]]; then
    action="teacher-external-source-evidence-missing"
  elif [[ "$source_hash_verified_rows" -ne "$source_rows" ||
          "$label_export_hash_verified_rows" -ne "$source_rows" ]]; then
    action="teacher-external-source-hash-mismatch"
  elif [[ "$teacher_identity_hash_verified_rows" -ne "$source_rows" ||
          "$teacher_policy_hash_verified_rows" -ne "$source_rows" ||
          "$license_hash_verified_rows" -ne "$source_rows" ]]; then
    action="teacher-external-source-provenance-missing"
  elif [[ "$label_provenance_hash_rows" -ne "$external_label_rows" ]]; then
    action="teacher-external-label-provenance-missing"
  elif [[ "$real_source_declared_rows" -ne "$source_rows" ||
          "$non_fixture_declared_rows" -ne "$source_rows" ||
          "$local_fixture_uri_rows" -ne 0 ]]; then
    action="teacher-real-source-review-missing"
  elif [[ "$teacher_source_chain_verified" == "1" ]]; then
    real_teacher_source_verified=1
    action="teacher-real-source-verified"
  fi
fi

total_routing="$(awk -v a="$ingestion_routing" -v b="$source_routing" 'BEGIN { printf "%.6f", a + b }')"
total_jump="$(awk -v a="$ingestion_jump" -v b="$source_jump" 'BEGIN { printf "%.6f", a + b }')"

{
  echo "teacher_source_scope,external_schema_ready,external_label_source_ready,teacher_external_labels_ready,label_source,teacher_source_source,external_label_rows,label_teacher_rows,label_provenance_hash_rows,source_rows,matched_teacher_rows,source_artifact_rows,source_hash_verified_rows,label_export_rows,label_export_hash_verified_rows,teacher_identity_rows,teacher_identity_hash_verified_rows,teacher_policy_rows,teacher_policy_hash_verified_rows,license_rows,license_hash_verified_rows,provenance_basis_rows,ready_rows,local_fixture_uri_rows,real_source_declared_rows,non_fixture_declared_rows,teacher_source_chain_verified,real_teacher_source_verified,action,routing_trigger_rate,active_jump_rate"
  printf "route-memory-h10j,%d,%d,%d,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%s,%.6f,%.6f\n" \
    "$external_schema_ready" \
    "$external_label_source_ready" \
    "$teacher_external_labels_ready" \
    "$label_source" \
    "$SOURCE_SOURCE" \
    "$external_label_rows" \
    "$label_teacher_rows" \
    "$label_provenance_hash_rows" \
    "$source_rows" \
    "$matched_teacher_rows" \
    "$source_artifact_rows" \
    "$source_hash_verified_rows" \
    "$label_export_rows" \
    "$label_export_hash_verified_rows" \
    "$teacher_identity_rows" \
    "$teacher_identity_hash_verified_rows" \
    "$teacher_policy_rows" \
    "$teacher_policy_hash_verified_rows" \
    "$license_rows" \
    "$license_hash_verified_rows" \
    "$provenance_basis_rows" \
    "$ready_rows" \
    "$local_fixture_uri_rows" \
    "$real_source_declared_rows" \
    "$non_fixture_declared_rows" \
    "$teacher_source_chain_verified" \
    "$real_teacher_source_verified" \
    "$action" \
    "$total_routing" \
    "$total_jump"
} >"$SUMMARY_CSV"

{
  echo "gate,status,reason"
  printf "external-label-ingestion,%s,external_ready=%d\n" \
    "$([[ "$teacher_external_labels_ready" == "1" ]] && echo pass || echo blocked)" \
    "$teacher_external_labels_ready"
  printf "teacher-source-rows,%s,source_rows=%d matched_rows=%d\n" \
    "$([[ "$source_rows" -gt 0 && "$matched_teacher_rows" -eq "$source_rows" ]] && echo pass || echo blocked)" \
    "$source_rows" \
    "$matched_teacher_rows"
  printf "source-artifact-hash,%s,artifact_rows=%d hash_rows=%d\n" \
    "$([[ "$source_artifact_rows" -eq "$source_rows" && "$source_hash_verified_rows" -eq "$source_rows" && "$source_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$source_artifact_rows" \
    "$source_hash_verified_rows"
  printf "label-export-hash,%s,export_rows=%d hash_rows=%d\n" \
    "$([[ "$label_export_rows" -eq "$source_rows" && "$label_export_hash_verified_rows" -eq "$source_rows" && "$source_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$label_export_rows" \
    "$label_export_hash_verified_rows"
  printf "teacher-identity,%s,identity_rows=%d hash_rows=%d\n" \
    "$([[ "$teacher_identity_rows" -eq "$source_rows" && "$teacher_identity_hash_verified_rows" -eq "$source_rows" && "$source_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$teacher_identity_rows" \
    "$teacher_identity_hash_verified_rows"
  printf "teacher-policy,%s,policy_rows=%d hash_rows=%d\n" \
    "$([[ "$teacher_policy_rows" -eq "$source_rows" && "$teacher_policy_hash_verified_rows" -eq "$source_rows" && "$source_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$teacher_policy_rows" \
    "$teacher_policy_hash_verified_rows"
  printf "teacher-license,%s,license_rows=%d hash_rows=%d\n" \
    "$([[ "$license_rows" -eq "$source_rows" && "$license_hash_verified_rows" -eq "$source_rows" && "$source_rows" -gt 0 ]] && echo pass || echo blocked)" \
    "$license_rows" \
    "$license_hash_verified_rows"
  printf "teacher-source-chain,%s,verified=%d\n" \
    "$([[ "$teacher_source_chain_verified" == "1" ]] && echo pass || echo blocked)" \
    "$teacher_source_chain_verified"
  printf "real-teacher-source,%s,action=%s\n" \
    "$([[ "$real_teacher_source_verified" == "1" ]] && echo pass || echo blocked)" \
    "$action"
} >"$DECISION_CSV"

echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
