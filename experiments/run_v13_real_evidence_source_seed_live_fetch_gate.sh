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

PREFIX="v13_real_evidence_source_seed_live_fetch_gate"
SEED_PREFIX="v13_real_evidence_source_seed_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_evidence_source_seed_live_fetch_gate_smoke"
  SEED_PREFIX="v13_real_evidence_source_seed_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_evidence_source_seed_live_fetch_gate_full"
  SEED_PREFIX="v13_real_evidence_source_seed_gate_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SEED_SUMMARY_CSV="${V13_REAL_EVIDENCE_SOURCE_SEED_LIVE_SUMMARY_CSV:-$RESULTS_DIR/${SEED_PREFIX}_summary.csv}"
SEED_PACKET_DIR="${V13_REAL_EVIDENCE_SOURCE_SEED_LIVE_PACKET_DIR:-$RESULTS_DIR/${SEED_PREFIX}_packet/$RUN_ID}"

"$ROOT_DIR/experiments/run_v13_real_evidence_source_seed_gate.sh" "${RUN_ARGS[@]}" >/dev/null

python3 - \
  "$PACKET_DIR" \
  "$SUMMARY_CSV" \
  "$DECISION_CSV" \
  "$SEED_SUMMARY_CSV" \
  "$SEED_PACKET_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

packet_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
seed_summary_csv = Path(sys.argv[4])
seed_packet_dir = Path(sys.argv[5])

required_weaknesses = [
    "external_benchmark",
    "learned_chunk_ranking",
    "gpu_speedup",
    "real_nlg",
]
receipt_kinds = [
    ("source", "source_uri"),
    ("review", "review_uri"),
    ("authority", "authority_uri"),
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

def https_real_uri(uri):
    if not uri.startswith("https://"):
        return 0
    lowered = uri.lower()
    bad_markers = ["placeholder", "fixture", "example.invalid", "localhost"]
    return int(not any(marker in lowered for marker in bad_markers))

def status(condition):
    return "pass" if condition else "blocked"

seed_summary = first_row(seed_summary_csv)
seed_packet_hash_entries, seed_packet_hash_verified = verify_manifest(seed_packet_dir)
seed_packet_hash_ready = int(
    seed_packet_hash_entries > 0 and seed_packet_hash_entries == seed_packet_hash_verified
)
seed_contract_ready = as_int(seed_summary, "source_seed_contract_ready")
live_fetch_seed_ready = as_int(seed_summary, "live_fetch_seed_ready")
candidate_real_evidence_source_seed_ready = as_int(seed_summary, "candidate_real_evidence_source_seed_ready")
seed_live_fetch_requested = as_int(seed_summary, "live_fetch_requested")
expected_receipts = 3 * len(required_weaknesses)

seed_manifest = {}
seed_manifest_path = seed_packet_dir / "source_seed_manifest.json"
if seed_manifest_path.is_file():
    seed_manifest = json.loads(seed_manifest_path.read_text(encoding="utf-8"))
seed_csv = Path(seed_manifest.get("seed_csv", ""))
seed_rows = read_rows(seed_csv)
seed_by_weakness = {row.get("weakness_id", ""): row for row in seed_rows}

receipt_dir = seed_packet_dir / "runtime_receipts"
packet_rows = []
weakness_counts = {weakness: 0 for weakness in required_weaknesses}
receipt_file_rows = 0
receipt_json_shape_rows = 0
receipt_kind_match_rows = 0
receipt_https_rows = 0
receipt_status_rows = 0
receipt_method_rows = 0
receipt_headers_rows = 0
receipt_no_error_rows = 0
receipt_time_order_rows = 0
routing_sum = 0.0
jump_sum = 0.0

for weakness in required_weaknesses:
    seed = seed_by_weakness.get(weakness, {})
    if seed:
        weakness_counts[weakness] += 1
    routing = as_float(seed, "routing_trigger_rate")
    jump = as_float(seed, "active_jump_rate")
    row_files = 0
    row_shapes = 0
    row_kinds = 0
    row_https = 0
    row_statuses = 0
    row_methods = 0
    row_headers = 0
    row_no_errors = 0
    row_times = 0

    for kind, uri_field in receipt_kinds:
        path = receipt_dir / f"{weakness}_{kind}_receipt.json"
        data = {}
        if path.is_file():
            row_files += 1
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                data = {}
        started = parse_time(data.get("started_at_utc", ""))
        finished = parse_time(data.get("finished_at_utc", ""))
        kind_ok = int(
            data.get("artifact_scope") == "v13-l-real-evidence-source-seed-gate"
            and data.get("weakness_id") == weakness
            and data.get("kind") == kind
        )
        https_ok = int(
            https_real_uri(data.get("uri", ""))
            and https_real_uri(data.get("final_uri", ""))
            and data.get("uri") == seed.get(uri_field, "")
        )
        status_ok = int(isinstance(data.get("status"), int) and 200 <= data.get("status") < 400)
        method_ok = int(data.get("method") in {"HEAD", "GET"})
        headers_ok = int(isinstance(data.get("headers"), dict))
        no_error_ok = int(data.get("error") == "")
        time_ok = int(started is not None and finished is not None and started <= finished)
        shape_ok = int(
            kind_ok
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

    receipt_file_rows += row_files
    receipt_json_shape_rows += row_shapes
    receipt_kind_match_rows += row_kinds
    receipt_https_rows += row_https
    receipt_status_rows += row_statuses
    receipt_method_rows += row_methods
    receipt_headers_rows += row_headers
    receipt_no_error_rows += row_no_errors
    receipt_time_order_rows += row_times
    routing_sum += routing
    jump_sum += jump

    packet_rows.append({
        "weakness_id": weakness,
        "receipt_files": row_files,
        "receipt_json_shapes_verified": row_shapes,
        "receipt_kind_matches": row_kinds,
        "receipt_https_ready": row_https,
        "receipt_status_ready": row_statuses,
        "receipt_method_ready": row_methods,
        "receipt_headers_ready": row_headers,
        "receipt_no_error_ready": row_no_errors,
        "receipt_time_order_ready": row_times,
        "routing_trigger_rate": f"{routing:.6f}",
        "active_jump_rate": f"{jump:.6f}",
    })

required_weakness_rows = sum(1 for weakness in required_weaknesses if weakness_counts[weakness] == 1)
source_seed_live_fetch_receipt_ready = int(
    seed_contract_ready == 1
    and seed_packet_hash_ready == 1
    and seed_live_fetch_requested == 1
    and live_fetch_seed_ready == 1
    and required_weakness_rows == len(required_weaknesses)
    and receipt_file_rows == expected_receipts
    and receipt_json_shape_rows == expected_receipts
    and receipt_kind_match_rows == expected_receipts
    and receipt_https_rows == expected_receipts
    and receipt_status_rows == expected_receipts
    and receipt_method_rows == expected_receipts
    and receipt_headers_rows == expected_receipts
    and receipt_no_error_rows == expected_receipts
    and receipt_time_order_rows == expected_receipts
    and abs(routing_sum) < 0.000001
    and abs(jump_sum) < 0.000001
)
candidate_real_evidence_source_live_fetch_ready = int(
    source_seed_live_fetch_receipt_ready == 1
    and candidate_real_evidence_source_seed_ready == 1
)
real_release_package_ready = 0

action = "v13-real-evidence-source-seed-live-fetch-not-requested"
if seed_contract_ready != 1 or seed_packet_hash_ready != 1:
    action = "v13-real-evidence-source-seed-live-fetch-seed-not-ready"
elif seed_live_fetch_requested != 1:
    action = "v13-real-evidence-source-seed-live-fetch-not-requested"
elif live_fetch_seed_ready != 1:
    action = "v13-real-evidence-source-seed-live-fetch-incomplete"
elif required_weakness_rows != len(required_weaknesses):
    action = "v13-real-evidence-source-seed-live-fetch-required-rows-missing"
elif receipt_file_rows != expected_receipts:
    action = "v13-real-evidence-source-seed-live-fetch-receipts-missing"
elif receipt_json_shape_rows != expected_receipts:
    action = "v13-real-evidence-source-seed-live-fetch-receipt-json-incomplete"
elif abs(routing_sum) >= 0.000001 or abs(jump_sum) >= 0.000001:
    action = "v13-real-evidence-source-seed-live-fetch-jump-guardrail-active"
elif candidate_real_evidence_source_seed_ready != 1:
    action = "v13-real-evidence-source-seed-live-fetch-await-claim-evidence"
elif candidate_real_evidence_source_live_fetch_ready == 1:
    action = "v13-real-evidence-source-seed-live-fetch-ready-await-rebind"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

rows_csv = packet_dir / "source_seed_live_fetch_rows.csv"
with rows_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(packet_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(packet_rows)

manifest = {
    "artifact_scope": "v13-m-real-evidence-source-seed-live-fetch-gate",
    "seed_summary_csv": str(seed_summary_csv),
    "seed_packet_dir": str(seed_packet_dir),
    "seed_csv": str(seed_csv),
    "required_weaknesses": required_weaknesses,
    "claim": "verifies runner-owned source-seed live fetch receipts without converting source seeds into claim evidence",
}
(packet_dir / "source_seed_live_fetch_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

packet_hash_entries, packet_hash_verified = verify_manifest(packet_dir)
packet_hash_ready = int(packet_hash_entries > 0 and packet_hash_entries == packet_hash_verified)
source_seed_live_fetch_receipt_ready = int(
    source_seed_live_fetch_receipt_ready == 1 and packet_hash_ready == 1
)
candidate_real_evidence_source_live_fetch_ready = int(
    candidate_real_evidence_source_live_fetch_ready == 1 and packet_hash_ready == 1
)

summary_fields = [
    "source_seed_live_fetch_scope",
    "run_id",
    "source_seed_live_fetch_packet_dir",
    "seed_contract_ready",
    "seed_packet_hash_ready",
    "seed_live_fetch_requested",
    "live_fetch_seed_ready",
    "candidate_real_evidence_source_seed_ready",
    "packet_hash_entries",
    "packet_hash_verified",
    "packet_hash_ready",
    "required_weakness_rows",
    "receipt_file_rows",
    "expected_receipt_rows",
    "receipt_json_shape_rows",
    "receipt_kind_match_rows",
    "receipt_https_rows",
    "receipt_status_rows",
    "receipt_method_rows",
    "receipt_headers_rows",
    "receipt_no_error_rows",
    "receipt_time_order_rows",
    "source_seed_live_fetch_receipt_ready",
    "candidate_real_evidence_source_live_fetch_ready",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "source_seed_live_fetch_scope": "v13-m-real-evidence-source-seed-live-fetch-gate",
    "run_id": seed_summary.get("run_id", seed_packet_dir.name),
    "source_seed_live_fetch_packet_dir": str(packet_dir),
    "seed_contract_ready": seed_contract_ready,
    "seed_packet_hash_ready": seed_packet_hash_ready,
    "seed_live_fetch_requested": seed_live_fetch_requested,
    "live_fetch_seed_ready": live_fetch_seed_ready,
    "candidate_real_evidence_source_seed_ready": candidate_real_evidence_source_seed_ready,
    "packet_hash_entries": packet_hash_entries,
    "packet_hash_verified": packet_hash_verified,
    "packet_hash_ready": packet_hash_ready,
    "required_weakness_rows": required_weakness_rows,
    "receipt_file_rows": receipt_file_rows,
    "expected_receipt_rows": expected_receipts,
    "receipt_json_shape_rows": receipt_json_shape_rows,
    "receipt_kind_match_rows": receipt_kind_match_rows,
    "receipt_https_rows": receipt_https_rows,
    "receipt_status_rows": receipt_status_rows,
    "receipt_method_rows": receipt_method_rows,
    "receipt_headers_rows": receipt_headers_rows,
    "receipt_no_error_rows": receipt_no_error_rows,
    "receipt_time_order_rows": receipt_time_order_rows,
    "source_seed_live_fetch_receipt_ready": source_seed_live_fetch_receipt_ready,
    "candidate_real_evidence_source_live_fetch_ready": candidate_real_evidence_source_live_fetch_ready,
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
    ("source-seed-contract", status(seed_contract_ready == 1 and seed_packet_hash_ready == 1), f"seed_contract={seed_contract_ready} seed_hash={seed_packet_hash_ready}"),
    ("runtime-live-fetch-requested", status(seed_live_fetch_requested == 1), f"requested={seed_live_fetch_requested}"),
    ("runtime-live-fetch-complete", status(live_fetch_seed_ready == 1), f"live_fetch_seed_ready={live_fetch_seed_ready}"),
    ("receipt-files", status(receipt_file_rows == expected_receipts), f"receipt_files={receipt_file_rows}/{expected_receipts}"),
    ("receipt-json-provenance", status(receipt_json_shape_rows == expected_receipts), f"shape={receipt_json_shape_rows}/{expected_receipts}"),
    ("source-live-fetch-receipts", status(source_seed_live_fetch_receipt_ready == 1), f"ready={source_seed_live_fetch_receipt_ready} action={action}"),
    ("claim-evidence-bound", status(candidate_real_evidence_source_seed_ready == 1), f"candidate_source_seed={candidate_real_evidence_source_seed_ready}"),
    ("candidate-source-live-fetch", status(candidate_real_evidence_source_live_fetch_ready == 1), f"candidate={candidate_real_evidence_source_live_fetch_ready}"),
    ("v13-real-evidence-source-live-fetch", status(real_release_package_ready == 1), f"release={real_release_package_ready}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "source_seed_live_fetch_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
