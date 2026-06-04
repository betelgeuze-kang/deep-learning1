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

PREFIX="v13_real_evidence_runtime_fetch_provenance_gate"
LIVE_PREFIX="v13_real_evidence_live_network_gate"
REBIND_PREFIX="v13_real_evidence_rebind_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_evidence_runtime_fetch_provenance_gate_smoke"
  LIVE_PREFIX="v13_real_evidence_live_network_gate_smoke"
  REBIND_PREFIX="v13_real_evidence_rebind_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_evidence_runtime_fetch_provenance_gate_full"
  LIVE_PREFIX="v13_real_evidence_live_network_gate_full"
  REBIND_PREFIX="v13_real_evidence_rebind_gate_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
LIVE_SUMMARY_CSV="${V13_REAL_EVIDENCE_RUNTIME_LIVE_SUMMARY_CSV:-$RESULTS_DIR/${LIVE_PREFIX}_summary.csv}"
LIVE_PACKET_DIR="${V13_REAL_EVIDENCE_RUNTIME_LIVE_PACKET_DIR:-$RESULTS_DIR/${LIVE_PREFIX}_packet/$RUN_ID}"
REBIND_SUMMARY_CSV="${V13_REAL_EVIDENCE_RUNTIME_REBIND_SUMMARY_CSV:-$RESULTS_DIR/${REBIND_PREFIX}_summary.csv}"
REBIND_PACKET_DIR="${V13_REAL_EVIDENCE_RUNTIME_REBIND_PACKET_DIR:-$RESULTS_DIR/${REBIND_PREFIX}_packet/$RUN_ID}"

"$ROOT_DIR/experiments/run_v13_real_evidence_rebind_gate.sh" "${RUN_ARGS[@]}" >/dev/null

python3 - \
  "$PACKET_DIR" \
  "$SUMMARY_CSV" \
  "$DECISION_CSV" \
  "$LIVE_SUMMARY_CSV" \
  "$LIVE_PACKET_DIR" \
  "$REBIND_SUMMARY_CSV" \
  "$REBIND_PACKET_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path
from urllib.parse import unquote

packet_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
live_summary_csv = Path(sys.argv[4])
live_packet_dir = Path(sys.argv[5])
rebind_summary_csv = Path(sys.argv[6])
rebind_packet_dir = Path(sys.argv[7])

required_weaknesses = [
    "external_benchmark",
    "learned_chunk_ranking",
    "gpu_speedup",
    "real_nlg",
]
receipt_kinds = [
    ("source", "source_status", "source_final_uri", "source_receipt_uri", "source_receipt_hash"),
    ("review", "review_status", "review_final_uri", "review_receipt_uri", "review_receipt_hash"),
    ("authority", "authority_status", "authority_final_uri", "authority_receipt_uri", "authority_receipt_hash"),
]

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()

def verify_manifest(base_dir):
    manifest = base_dir / "sha256sums.txt"
    entries = 0
    verified = 0
    if not manifest.is_file():
        return entries, verified
    with manifest.open(encoding="utf-8") as handle:
        for line in handle:
            if "  " not in line:
                continue
            expected, rel = line.rstrip("\n").split("  ", 1)
            entries += 1
            path = base_dir / rel
            if path.is_file() and sha256(path) == expected:
                verified += 1
    return entries, verified

def first_row(path):
    if not path.is_file():
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return rows[0] if rows else {}

def read_rows(path):
    if not path.is_file():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def as_int(row, field, default=0):
    try:
        return int(float(row.get(field, default) or default))
    except ValueError:
        return default

def as_float(row, field, default=0.0):
    try:
        return float(row.get(field, default) or default)
    except ValueError:
        return default

def local_uri_path(uri):
    if not uri.startswith("file://"):
        return None
    return Path(unquote(uri[7:]))

def hash_matches(uri, expected):
    path = local_uri_path(uri)
    if path is None or not path.is_file() or not expected.startswith("sha256:"):
        return 0
    return int("sha256:" + sha256(path) == expected)

def https_real_uri(uri):
    if not uri.startswith("https://"):
        return 0
    lowered = uri.lower()
    bad_markers = ["placeholder", "fixture", "example.invalid", "localhost"]
    return int(not any(marker in lowered for marker in bad_markers))

def parse_time(value):
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        return None
    return parsed

def status(condition):
    return "pass" if condition else "blocked"

live_summary = first_row(live_summary_csv)
rebind_summary = first_row(rebind_summary_csv)
live_packet_hash_entries, live_packet_hash_verified = verify_manifest(live_packet_dir)
live_packet_hash_ready = int(
    live_packet_hash_entries > 0 and live_packet_hash_entries == live_packet_hash_verified
)
rebind_packet_hash_entries, rebind_packet_hash_verified = verify_manifest(rebind_packet_dir)
rebind_packet_hash_ready = int(
    rebind_packet_hash_entries > 0 and rebind_packet_hash_entries == rebind_packet_hash_verified
)

live_source = live_summary.get("live_source", "missing-live-summary")
run_id = live_summary.get("run_id", live_packet_dir.name)
live_network_receipt_contract_ready = as_int(live_summary, "live_network_receipt_contract_ready")
candidate_real_evidence_live_network_ready = as_int(live_summary, "candidate_real_evidence_live_network_ready")
v13_real_evidence_promotion_ready = as_int(live_summary, "v13_real_evidence_promotion_ready")
rebind_contract_ready = as_int(rebind_summary, "rebind_contract_ready")
candidate_real_evidence_rebind_ready = as_int(rebind_summary, "candidate_real_evidence_rebind_ready")

live_manifest = {}
live_manifest_path = live_packet_dir / "live_network_manifest.json"
if live_manifest_path.is_file():
    live_manifest = json.loads(live_manifest_path.read_text(encoding="utf-8"))
live_csv = Path(live_manifest.get("live_csv", ""))
live_rows = read_rows(live_csv) if live_csv.is_file() else []

weakness_counts = {weakness: 0 for weakness in required_weaknesses}
packet_rows = []
run_id_match_rows = 0
receipt_hash_verified_rows = 0
receipt_json_shape_rows = 0
receipt_kind_match_rows = 0
receipt_https_uri_rows = 0
receipt_status_rows = 0
receipt_method_rows = 0
receipt_headers_rows = 0
receipt_no_error_rows = 0
receipt_time_order_rows = 0
runtime_source_rows = 0
fixture_rows = 0
routing_sum = 0.0
jump_sum = 0.0

for row in live_rows:
    weakness = row.get("weakness_id", "")
    if weakness in weakness_counts:
        weakness_counts[weakness] += 1
    run_id_match = int(row.get("run_id") == run_id)
    runtime_source = int(live_source == "runtime-live-fetch" and as_int(row, "runner_owned_live_fetch") == 1)
    fixture = as_int(row, "fixture_declared")
    routing = as_float(row, "routing_trigger_rate")
    jump = as_float(row, "active_jump_rate")

    row_hashes = 0
    row_shapes = 0
    row_kinds = 0
    row_https = 0
    row_statuses = 0
    row_methods = 0
    row_headers = 0
    row_no_errors = 0
    row_times = 0

    for kind, status_field, final_field, uri_field, hash_field in receipt_kinds:
        receipt_hash_ok = hash_matches(row.get(uri_field, ""), row.get(hash_field, ""))
        row_hashes += receipt_hash_ok
        path = local_uri_path(row.get(uri_field, ""))
        data = {}
        if path is not None and path.is_file():
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                data = {}

        started = parse_time(data.get("started_at_utc", ""))
        finished = parse_time(data.get("finished_at_utc", ""))
        kind_ok = int(
            data.get("artifact_scope") == "v13-i-real-evidence-live-network-gate"
            and data.get("weakness_id") == weakness
            and data.get("kind") == kind
        )
        https_ok = int(
            https_real_uri(data.get("uri", ""))
            and https_real_uri(data.get("final_uri", ""))
            and data.get("final_uri") == row.get(final_field)
        )
        status_ok = int(
            isinstance(data.get("status"), int)
            and 200 <= data.get("status") < 400
            and data.get("status") == as_int(row, status_field)
        )
        method_ok = int(data.get("method") in {"HEAD", "GET"})
        headers_ok = int(isinstance(data.get("headers"), dict))
        no_error_ok = int(data.get("error") == "")
        time_ok = int(started is not None and finished is not None and started <= finished)
        shape_ok = int(
            receipt_hash_ok
            and kind_ok
            and https_ok
            and status_ok
            and method_ok
            and headers_ok
            and no_error_ok
            and time_ok
        )

        row_shapes += shape_ok
        row_kinds += kind_ok
        row_https += https_ok
        row_statuses += status_ok
        row_methods += method_ok
        row_headers += headers_ok
        row_no_errors += no_error_ok
        row_times += time_ok

    run_id_match_rows += run_id_match
    receipt_hash_verified_rows += row_hashes
    receipt_json_shape_rows += row_shapes
    receipt_kind_match_rows += row_kinds
    receipt_https_uri_rows += row_https
    receipt_status_rows += row_statuses
    receipt_method_rows += row_methods
    receipt_headers_rows += row_headers
    receipt_no_error_rows += row_no_errors
    receipt_time_order_rows += row_times
    runtime_source_rows += runtime_source
    fixture_rows += fixture
    routing_sum += routing
    jump_sum += jump

    packet_rows.append({
        "weakness_id": weakness,
        "run_id_match": run_id_match,
        "receipt_hashes_verified": row_hashes,
        "receipt_json_shapes_verified": row_shapes,
        "receipt_kind_matches": row_kinds,
        "receipt_https_uri_ready": row_https,
        "receipt_status_ready": row_statuses,
        "receipt_method_ready": row_methods,
        "receipt_headers_ready": row_headers,
        "receipt_no_error_ready": row_no_errors,
        "receipt_time_order_ready": row_times,
        "runtime_source_ready": runtime_source,
        "fixture_declared": fixture,
        "routing_trigger_rate": f"{routing:.6f}",
        "active_jump_rate": f"{jump:.6f}",
    })

required_weakness_rows = sum(1 for weakness in required_weaknesses if weakness_counts[weakness] == 1)
duplicate_or_unknown_rows = len(live_rows) - sum(weakness_counts.values()) + sum(
    max(0, count - 1) for count in weakness_counts.values()
)
expected_receipts = 3 * len(required_weaknesses)
runtime_fetch_provenance_ready = int(
    live_network_receipt_contract_ready == 1
    and live_packet_hash_ready == 1
    and len(live_rows) == len(required_weaknesses)
    and required_weakness_rows == len(required_weaknesses)
    and duplicate_or_unknown_rows == 0
    and run_id_match_rows == len(required_weaknesses)
    and receipt_hash_verified_rows == expected_receipts
    and receipt_json_shape_rows == expected_receipts
    and receipt_kind_match_rows == expected_receipts
    and receipt_https_uri_rows == expected_receipts
    and receipt_status_rows == expected_receipts
    and receipt_method_rows == expected_receipts
    and receipt_headers_rows == expected_receipts
    and receipt_no_error_rows == expected_receipts
    and receipt_time_order_rows == expected_receipts
    and runtime_source_rows == len(required_weaknesses)
    and fixture_rows == 0
    and live_source == "runtime-live-fetch"
    and candidate_real_evidence_live_network_ready == 1
    and abs(routing_sum) < 0.000001
    and abs(jump_sum) < 0.000001
)
candidate_real_evidence_runtime_ready = int(
    runtime_fetch_provenance_ready == 1
    and rebind_contract_ready == 1
    and rebind_packet_hash_ready == 1
    and candidate_real_evidence_rebind_ready == 1
)
real_release_package_ready = int(
    candidate_real_evidence_runtime_ready == 1
    and v13_real_evidence_promotion_ready == 1
)

action = "v13-real-evidence-runtime-fetch-live-network-not-ready"
if live_source == "generated-missing-live-network-receipts" or not live_rows:
    action = "v13-real-evidence-runtime-fetch-live-network-not-ready"
elif live_packet_hash_ready != 1:
    action = "v13-real-evidence-runtime-fetch-live-packet-hash-mismatch"
elif len(live_rows) != len(required_weaknesses) or required_weakness_rows != len(required_weaknesses) or duplicate_or_unknown_rows != 0:
    action = "v13-real-evidence-runtime-fetch-required-weakness-rows-missing"
elif run_id_match_rows != len(required_weaknesses):
    action = "v13-real-evidence-runtime-fetch-run-id-mismatch"
elif receipt_hash_verified_rows != expected_receipts:
    action = "v13-real-evidence-runtime-fetch-receipt-hash-mismatch"
elif receipt_kind_match_rows != expected_receipts or receipt_json_shape_rows != expected_receipts:
    action = "v13-real-evidence-runtime-fetch-receipt-json-shape-incomplete"
elif receipt_https_uri_rows != expected_receipts:
    action = "v13-real-evidence-runtime-fetch-https-uri-incomplete"
elif receipt_status_rows != expected_receipts:
    action = "v13-real-evidence-runtime-fetch-http-status-incomplete"
elif receipt_method_rows != expected_receipts:
    action = "v13-real-evidence-runtime-fetch-method-incomplete"
elif receipt_headers_rows != expected_receipts:
    action = "v13-real-evidence-runtime-fetch-headers-incomplete"
elif receipt_no_error_rows != expected_receipts:
    action = "v13-real-evidence-runtime-fetch-error-present"
elif receipt_time_order_rows != expected_receipts:
    action = "v13-real-evidence-runtime-fetch-time-order-incomplete"
elif abs(routing_sum) >= 0.000001 or abs(jump_sum) >= 0.000001:
    action = "v13-real-evidence-runtime-fetch-jump-guardrail-active"
elif live_network_receipt_contract_ready != 1:
    action = "v13-real-evidence-runtime-fetch-live-network-not-ready"
elif runtime_source_rows != len(required_weaknesses) or fixture_rows != 0 or live_source != "runtime-live-fetch":
    action = "v13-real-evidence-runtime-fetch-await-runtime-live-fetch"
elif candidate_real_evidence_live_network_ready != 1:
    action = "v13-real-evidence-runtime-fetch-live-candidate-not-ready"
elif rebind_contract_ready != 1 or rebind_packet_hash_ready != 1:
    action = "v13-real-evidence-runtime-fetch-rebind-not-ready"
elif candidate_real_evidence_rebind_ready != 1:
    action = "v13-real-evidence-runtime-fetch-await-rebind-candidate"
elif v13_real_evidence_promotion_ready != 1:
    action = "v13-real-evidence-runtime-fetch-ready-await-promotion-regeneration"
elif real_release_package_ready == 1:
    action = "v13-real-evidence-runtime-fetch-release-ready"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

rows_csv = packet_dir / "runtime_fetch_provenance_rows.csv"
fieldnames = list(packet_rows[0].keys()) if packet_rows else [
    "weakness_id",
    "run_id_match",
    "receipt_hashes_verified",
    "receipt_json_shapes_verified",
    "receipt_kind_matches",
    "receipt_https_uri_ready",
    "receipt_status_ready",
    "receipt_method_ready",
    "receipt_headers_ready",
    "receipt_no_error_ready",
    "receipt_time_order_ready",
    "runtime_source_ready",
    "fixture_declared",
    "routing_trigger_rate",
    "active_jump_rate",
]
with rows_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(packet_rows)

manifest = {
    "artifact_scope": "v13-k-real-evidence-runtime-fetch-provenance-gate",
    "live_summary_csv": str(live_summary_csv),
    "live_packet_dir": str(live_packet_dir),
    "rebind_summary_csv": str(rebind_summary_csv),
    "rebind_packet_dir": str(rebind_packet_dir),
    "live_csv": str(live_csv),
    "required_weaknesses": required_weaknesses,
    "claim": "verifies that v13-i receipt JSONs were produced by runner-owned runtime live fetch before rebind evidence can be promoted",
}
(packet_dir / "runtime_fetch_provenance_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

runtime_packet_hash_entries, runtime_packet_hash_verified = verify_manifest(packet_dir)
runtime_packet_hash_ready = int(
    runtime_packet_hash_entries > 0 and runtime_packet_hash_entries == runtime_packet_hash_verified
)
runtime_fetch_provenance_ready = int(runtime_fetch_provenance_ready == 1 and runtime_packet_hash_ready == 1)
candidate_real_evidence_runtime_ready = int(
    candidate_real_evidence_runtime_ready == 1 and runtime_packet_hash_ready == 1
)
real_release_package_ready = int(real_release_package_ready == 1 and runtime_packet_hash_ready == 1)

summary_fields = [
    "runtime_scope",
    "live_source",
    "run_id",
    "runtime_packet_dir",
    "live_network_receipt_contract_ready",
    "candidate_real_evidence_live_network_ready",
    "v13_real_evidence_promotion_ready",
    "rebind_contract_ready",
    "candidate_real_evidence_rebind_ready",
    "live_packet_hash_entries",
    "live_packet_hash_verified",
    "live_packet_hash_ready",
    "rebind_packet_hash_entries",
    "rebind_packet_hash_verified",
    "rebind_packet_hash_ready",
    "runtime_packet_hash_entries",
    "runtime_packet_hash_verified",
    "runtime_packet_hash_ready",
    "live_rows",
    "required_weakness_rows",
    "duplicate_or_unknown_rows",
    "run_id_match_rows",
    "receipt_hash_verified_rows",
    "expected_receipt_hash_rows",
    "receipt_json_shape_rows",
    "receipt_kind_match_rows",
    "receipt_https_uri_rows",
    "receipt_status_rows",
    "receipt_method_rows",
    "receipt_headers_rows",
    "receipt_no_error_rows",
    "receipt_time_order_rows",
    "runtime_source_rows",
    "fixture_rows",
    "runtime_fetch_provenance_ready",
    "candidate_real_evidence_runtime_ready",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "runtime_scope": "v13-k-real-evidence-runtime-fetch-provenance-gate",
    "live_source": live_source,
    "run_id": run_id,
    "runtime_packet_dir": str(packet_dir),
    "live_network_receipt_contract_ready": live_network_receipt_contract_ready,
    "candidate_real_evidence_live_network_ready": candidate_real_evidence_live_network_ready,
    "v13_real_evidence_promotion_ready": v13_real_evidence_promotion_ready,
    "rebind_contract_ready": rebind_contract_ready,
    "candidate_real_evidence_rebind_ready": candidate_real_evidence_rebind_ready,
    "live_packet_hash_entries": live_packet_hash_entries,
    "live_packet_hash_verified": live_packet_hash_verified,
    "live_packet_hash_ready": live_packet_hash_ready,
    "rebind_packet_hash_entries": rebind_packet_hash_entries,
    "rebind_packet_hash_verified": rebind_packet_hash_verified,
    "rebind_packet_hash_ready": rebind_packet_hash_ready,
    "runtime_packet_hash_entries": runtime_packet_hash_entries,
    "runtime_packet_hash_verified": runtime_packet_hash_verified,
    "runtime_packet_hash_ready": runtime_packet_hash_ready,
    "live_rows": len(live_rows),
    "required_weakness_rows": required_weakness_rows,
    "duplicate_or_unknown_rows": duplicate_or_unknown_rows,
    "run_id_match_rows": run_id_match_rows,
    "receipt_hash_verified_rows": receipt_hash_verified_rows,
    "expected_receipt_hash_rows": expected_receipts,
    "receipt_json_shape_rows": receipt_json_shape_rows,
    "receipt_kind_match_rows": receipt_kind_match_rows,
    "receipt_https_uri_rows": receipt_https_uri_rows,
    "receipt_status_rows": receipt_status_rows,
    "receipt_method_rows": receipt_method_rows,
    "receipt_headers_rows": receipt_headers_rows,
    "receipt_no_error_rows": receipt_no_error_rows,
    "receipt_time_order_rows": receipt_time_order_rows,
    "runtime_source_rows": runtime_source_rows,
    "fixture_rows": fixture_rows,
    "runtime_fetch_provenance_ready": runtime_fetch_provenance_ready,
    "candidate_real_evidence_runtime_ready": candidate_real_evidence_runtime_ready,
    "real_release_package_ready": real_release_package_ready,
    "action": action,
    "routing_trigger_rate": f"{routing_sum:.6f}",
    "active_jump_rate": f"{jump_sum:.6f}",
}
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=summary_fields, lineterminator="\n")
    writer.writeheader()
    writer.writerow(summary_row)

decision_rows = [
    ("live-network-binding", status(live_network_receipt_contract_ready == 1 and live_packet_hash_ready == 1), f"live_contract={live_network_receipt_contract_ready} live_hash={live_packet_hash_ready}"),
    ("required-weakness-rows", status(required_weakness_rows == len(required_weaknesses) and duplicate_or_unknown_rows == 0), f"required={required_weakness_rows}/{len(required_weaknesses)} duplicate_or_unknown={duplicate_or_unknown_rows}"),
    ("run-id-binding", status(run_id_match_rows == len(required_weaknesses)), f"run_id_match={run_id_match_rows}/{len(required_weaknesses)}"),
    ("receipt-hash-binding", status(receipt_hash_verified_rows == expected_receipts), f"receipt_hashes={receipt_hash_verified_rows}/{expected_receipts}"),
    ("receipt-json-provenance", status(receipt_json_shape_rows == expected_receipts), f"shape={receipt_json_shape_rows}/{expected_receipts}"),
    ("runtime-live-fetch-source", status(runtime_source_rows == len(required_weaknesses) and fixture_rows == 0 and live_source == "runtime-live-fetch"), f"source={live_source} runtime={runtime_source_rows}/{len(required_weaknesses)} fixture_rows={fixture_rows}"),
    ("rebind-candidate", status(rebind_contract_ready == 1 and rebind_packet_hash_ready == 1 and candidate_real_evidence_rebind_ready == 1), f"rebind_contract={rebind_contract_ready} rebind_candidate={candidate_real_evidence_rebind_ready}"),
    ("runtime-fetch-provenance", status(runtime_fetch_provenance_ready == 1), f"runtime_provenance={runtime_fetch_provenance_ready} action={action}"),
    ("v13-real-evidence-runtime-fetch", status(real_release_package_ready == 1), f"release={real_release_package_ready} promotion={v13_real_evidence_promotion_ready}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "runtime_fetch_provenance_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
