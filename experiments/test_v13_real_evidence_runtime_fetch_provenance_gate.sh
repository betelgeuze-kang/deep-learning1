#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"

SUMMARY_CSV="$RESULTS_DIR/v13_real_evidence_runtime_fetch_provenance_gate_smoke_summary.csv"
DECISION_CSV="$RESULTS_DIR/v13_real_evidence_runtime_fetch_provenance_gate_smoke_decision.csv"
PACKET_DIR="$RESULTS_DIR/v13_real_evidence_runtime_fetch_provenance_gate_smoke_packet/run_001"
FIXTURE_DIR="$RESULTS_DIR/v13_real_evidence_runtime_fetch_fixture"
INTAKE_CSV="$FIXTURE_DIR/intake.csv"
LIVE_CSV="$FIXTURE_DIR/live_network.csv"
REBIND_CSV="$FIXTURE_DIR/rebind.csv"
BAD_METHOD_CSV="$FIXTURE_DIR/bad_method_live_network.csv"
BAD_TIME_CSV="$FIXTURE_DIR/bad_time_live_network.csv"

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
      if (!(field in idx)) die("missing v13-k summary column: " field, 2)
      next
    }
    {
      rows++
      if ($idx[field] != expected) die(message ": expected " expected " got " $idx[field], 3)
    }
    END {
      if (rows != 1) die("expected one v13-k summary row", 4)
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
      if ($idx["status"] != expected) die("v13-k decision " gate " expected " expected " got " $idx["status"], 5)
    }
    END {
      if (!found) die("missing v13-k decision gate: " gate, 6)
    }
  ' "$decision_csv"
}

write_runtime_style_package() {
  rm -rf "$FIXTURE_DIR"
  mkdir -p "$FIXTURE_DIR/cache" "$FIXTURE_DIR/receipts" "$FIXTURE_DIR/rebound"

  for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
    printf '{"weakness_id":"%s","claim":"local intake cache for v13-k mechanics"}\n' "$weakness" >"$FIXTURE_DIR/cache/${weakness}.json"
    printf '{"weakness_id":"%s","claim":"rebound promotion artifact mechanics"}\n' "$weakness" >"$FIXTURE_DIR/rebound/${weakness}_artifact.json"
    printf '{"weakness_id":"%s","claim_matrix":"rebound claim row mechanics"}\n' "$weakness" >"$FIXTURE_DIR/rebound/${weakness}_claim.json"
  done

  {
    echo "run_id,weakness_id,evidence_family,source_uri,review_uri,authority_uri,cache_uri,cache_hash,nonfixture_declared,independent_declared,runner_owned_declared,official_or_public_declared,source_bound_declared,metric_ready_declared,live_network_verified,real_evidence_declared,routing_trigger_rate,active_jump_rate"
    for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
      case "$weakness" in
        external_benchmark) family="external-benchmark" ;;
        learned_chunk_ranking) family="learned-scorer" ;;
        gpu_speedup) family="resource-speed" ;;
        real_nlg) family="pc-routelm-nlg" ;;
      esac
      cache_hash="$(sha256sum "$FIXTURE_DIR/cache/${weakness}.json" | awk '{print $1}')"
      printf "run_001,%s,%s,https://evidence.example.org/v13k/%s/source,https://evidence.example.org/v13k/%s/review,https://evidence.example.org/v13k/%s/authority,file://%s,sha256:%s,1,1,1,1,1,1,0,1,0,0\n" \
        "$weakness" \
        "$family" \
        "$weakness" \
        "$weakness" \
        "$weakness" \
        "$FIXTURE_DIR/cache/${weakness}.json" \
        "$cache_hash"
    done
  } >"$INTAKE_CSV"

  {
    echo "run_id,weakness_id,source_status,review_status,authority_status,source_final_uri,review_final_uri,authority_final_uri,source_receipt_uri,review_receipt_uri,authority_receipt_uri,source_receipt_hash,review_receipt_hash,authority_receipt_hash,tls_verified,dns_verified,http_verified,runner_owned_live_fetch,nonfixture_declared,fixture_declared,live_network_verified,routing_trigger_rate,active_jump_rate"
    for weakness in external_benchmark learned_chunk_ranking gpu_speedup real_nlg; do
      for kind in source review authority; do
        uri="https://evidence.example.org/v13k/${weakness}/${kind}"
        python3 - "$FIXTURE_DIR/receipts/${weakness}_${kind}.json" "$weakness" "$kind" "$uri" <<'PY'
import json
import sys

path, weakness, kind, uri = sys.argv[1:]
receipt = {
    "artifact_scope": "v13-i-real-evidence-live-network-gate",
    "weakness_id": weakness,
    "kind": kind,
    "uri": uri,
    "method": "HEAD",
    "status": 200,
    "final_uri": uri,
    "started_at_utc": "2026-06-04T00:00:00+00:00",
    "finished_at_utc": "2026-06-04T00:00:01+00:00",
    "headers": {"content-type": "text/html"},
    "error": "",
}
with open(path, "w", encoding="utf-8") as handle:
    json.dump(receipt, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
      done
      source_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_source.json" | awk '{print $1}')"
      review_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_review.json" | awk '{print $1}')"
      authority_hash="$(sha256sum "$FIXTURE_DIR/receipts/${weakness}_authority.json" | awk '{print $1}')"
      printf "run_001,%s,200,200,200,https://evidence.example.org/v13k/%s/source,https://evidence.example.org/v13k/%s/review,https://evidence.example.org/v13k/%s/authority,file://%s,file://%s,file://%s,sha256:%s,sha256:%s,sha256:%s,1,1,1,1,1,0,1,0,0\n" \
        "$weakness" \
        "$weakness" \
        "$weakness" \
        "$weakness" \
        "$FIXTURE_DIR/receipts/${weakness}_source.json" \
        "$FIXTURE_DIR/receipts/${weakness}_review.json" \
        "$FIXTURE_DIR/receipts/${weakness}_authority.json" \
        "$source_hash" \
        "$review_hash" \
        "$authority_hash"
    done
  } >"$LIVE_CSV"

  {
    echo "run_id,weakness_id,source_receipt_hash,review_receipt_hash,authority_receipt_hash,rebuilt_artifact_uri,rebuilt_artifact_hash,claim_matrix_uri,claim_matrix_hash,regenerated_run_declared,receipt_replayed_declared,nonfixture_declared,runtime_live_fetch_bound_declared,promotion_row_ready_declared,routing_trigger_rate,active_jump_rate"
    awk -F, 'NR > 1 {print $2 "," $12 "," $13 "," $14}' "$LIVE_CSV" | while IFS=, read -r weakness source_hash review_hash authority_hash; do
      artifact_hash="$(sha256sum "$FIXTURE_DIR/rebound/${weakness}_artifact.json" | awk '{print $1}')"
      claim_hash="$(sha256sum "$FIXTURE_DIR/rebound/${weakness}_claim.json" | awk '{print $1}')"
      printf "run_001,%s,%s,%s,%s,file://%s,sha256:%s,file://%s,sha256:%s,1,1,1,1,1,0,0\n" \
        "$weakness" \
        "$source_hash" \
        "$review_hash" \
        "$authority_hash" \
        "$FIXTURE_DIR/rebound/${weakness}_artifact.json" \
        "$artifact_hash" \
        "$FIXTURE_DIR/rebound/${weakness}_claim.json" \
        "$claim_hash"
    done
  } >"$REBIND_CSV"
}

rewrite_receipt() {
  local receipt="$1"
  local patch_kind="$2"
  python3 - "$receipt" "$patch_kind" <<'PY'
import json
import sys

path, patch_kind = sys.argv[1:]
with open(path, encoding="utf-8") as handle:
    receipt = json.load(handle)
if patch_kind == "bad-method":
    receipt["method"] = "POST"
elif patch_kind == "bad-time":
    receipt["started_at_utc"] = "2026-06-04T00:00:02+00:00"
    receipt["finished_at_utc"] = "2026-06-04T00:00:01+00:00"
with open(path, "w", encoding="utf-8") as handle:
    json.dump(receipt, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}

mkdir -p "$RESULTS_DIR"

"$ROOT_DIR/experiments/run_v13_real_evidence_runtime_fetch_provenance_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "live_source" "generated-missing-live-network-receipts" "v13-k default live source"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "0" "v13-k default live"
expect_summary_value "$SUMMARY_CSV" "runtime_packet_hash_ready" "1" "v13-k default packet"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_provenance_ready" "0" "v13-k default provenance"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_runtime_ready" "0" "v13-k default candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-k default release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-runtime-fetch-live-network-not-ready" "v13-k default action"

write_runtime_style_package
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$REBIND_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_runtime_fetch_provenance_gate.sh" --smoke >/dev/null

expect_summary_value "$SUMMARY_CSV" "live_source" "provided-live-network-csv" "v13-k fixture live source"
expect_summary_value "$SUMMARY_CSV" "live_network_receipt_contract_ready" "1" "v13-k fixture live contract"
expect_summary_value "$SUMMARY_CSV" "rebind_contract_ready" "1" "v13-k fixture rebind contract"
expect_summary_value "$SUMMARY_CSV" "live_rows" "4" "v13-k fixture rows"
expect_summary_value "$SUMMARY_CSV" "required_weakness_rows" "4" "v13-k fixture required rows"
expect_summary_value "$SUMMARY_CSV" "receipt_hash_verified_rows" "12" "v13-k fixture hashes"
expect_summary_value "$SUMMARY_CSV" "expected_receipt_hash_rows" "12" "v13-k fixture expected hashes"
expect_summary_value "$SUMMARY_CSV" "receipt_json_shape_rows" "12" "v13-k fixture shape"
expect_summary_value "$SUMMARY_CSV" "receipt_kind_match_rows" "12" "v13-k fixture kind"
expect_summary_value "$SUMMARY_CSV" "receipt_https_uri_rows" "12" "v13-k fixture https"
expect_summary_value "$SUMMARY_CSV" "receipt_status_rows" "12" "v13-k fixture status"
expect_summary_value "$SUMMARY_CSV" "receipt_method_rows" "12" "v13-k fixture method"
expect_summary_value "$SUMMARY_CSV" "receipt_headers_rows" "12" "v13-k fixture headers"
expect_summary_value "$SUMMARY_CSV" "receipt_no_error_rows" "12" "v13-k fixture error"
expect_summary_value "$SUMMARY_CSV" "receipt_time_order_rows" "12" "v13-k fixture time"
expect_summary_value "$SUMMARY_CSV" "runtime_source_rows" "0" "v13-k fixture runtime source"
expect_summary_value "$SUMMARY_CSV" "fixture_rows" "0" "v13-k fixture marker"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_provenance_ready" "0" "v13-k fixture provenance"
expect_summary_value "$SUMMARY_CSV" "candidate_real_evidence_runtime_ready" "0" "v13-k fixture candidate"
expect_summary_value "$SUMMARY_CSV" "real_release_package_ready" "0" "v13-k fixture release"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-runtime-fetch-await-runtime-live-fetch" "v13-k fixture action"
expect_summary_value "$SUMMARY_CSV" "routing_trigger_rate" "0.000000" "v13-k fixture routing"
expect_summary_value "$SUMMARY_CSV" "active_jump_rate" "0.000000" "v13-k fixture jump"

expect_decision_status "$DECISION_CSV" "live-network-binding" "pass"
expect_decision_status "$DECISION_CSV" "required-weakness-rows" "pass"
expect_decision_status "$DECISION_CSV" "run-id-binding" "pass"
expect_decision_status "$DECISION_CSV" "receipt-hash-binding" "pass"
expect_decision_status "$DECISION_CSV" "receipt-json-provenance" "pass"
expect_decision_status "$DECISION_CSV" "runtime-live-fetch-source" "blocked"
expect_decision_status "$DECISION_CSV" "rebind-candidate" "blocked"
expect_decision_status "$DECISION_CSV" "runtime-fetch-provenance" "blocked"
expect_decision_status "$DECISION_CSV" "v13-real-evidence-runtime-fetch" "blocked"

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
    if ($idx["receipt_json_shapes_verified"] != "3") die("v13-k row should verify three runtime-style receipt JSONs", 20)
    if ($idx["runtime_source_ready"] != "0") die("v13-k supplied fixture must not become runtime source evidence", 21)
  }
  END {
    if (rows != 4) die("expected four v13-k provenance rows", 22)
  }
' "$PACKET_DIR/runtime_fetch_provenance_rows.csv"

cp "$LIVE_CSV" "$BAD_METHOD_CSV"
rewrite_receipt "$FIXTURE_DIR/receipts/gpu_speedup_source.json" bad-method
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$BAD_METHOD_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$REBIND_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_runtime_fetch_provenance_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "receipt_hash_verified_rows" "11" "v13-k bad method hash detects modified receipt"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_provenance_ready" "0" "v13-k bad method provenance"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-runtime-fetch-receipt-hash-mismatch" "v13-k bad method action"

write_runtime_style_package
cp "$LIVE_CSV" "$BAD_TIME_CSV"
rewrite_receipt "$FIXTURE_DIR/receipts/gpu_speedup_source.json" bad-time
new_hash="$(sha256sum "$FIXTURE_DIR/receipts/gpu_speedup_source.json" | awk '{print $1}')"
awk -F, -v hash="sha256:${new_hash}" 'BEGIN {OFS=","} NR == 1 {print; next} $2 == "gpu_speedup" {$12=hash} {print}' "$BAD_TIME_CSV" >"$BAD_TIME_CSV.tmp"
mv "$BAD_TIME_CSV.tmp" "$BAD_TIME_CSV"
awk -F, -v hash="sha256:${new_hash}" 'BEGIN {OFS=","} NR == 1 {print; next} $2 == "gpu_speedup" {$3=hash} {print}' "$REBIND_CSV" >"$REBIND_CSV.tmp"
mv "$REBIND_CSV.tmp" "$REBIND_CSV"
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$BAD_TIME_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$REBIND_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_runtime_fetch_provenance_gate.sh" --smoke >/dev/null
expect_summary_value "$SUMMARY_CSV" "receipt_hash_verified_rows" "12" "v13-k bad time hash clean"
expect_summary_value "$SUMMARY_CSV" "receipt_time_order_rows" "11" "v13-k bad time rows"
expect_summary_value "$SUMMARY_CSV" "runtime_fetch_provenance_ready" "0" "v13-k bad time provenance"
expect_summary_value "$SUMMARY_CSV" "action" "v13-real-evidence-runtime-fetch-receipt-json-shape-incomplete" "v13-k bad time action"

write_runtime_style_package
V13_REAL_EVIDENCE_INTAKE_CSV="$INTAKE_CSV" \
V13_REAL_EVIDENCE_LIVE_NETWORK_CSV="$LIVE_CSV" \
V13_REAL_EVIDENCE_REBIND_CSV="$REBIND_CSV" \
  "$ROOT_DIR/experiments/run_v13_real_evidence_runtime_fetch_provenance_gate.sh" --smoke >/dev/null

echo "v13 real evidence runtime fetch provenance gate smoke passed"
