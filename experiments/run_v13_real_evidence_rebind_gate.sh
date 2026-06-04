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

PREFIX="v13_real_evidence_rebind_gate"
LIVE_PREFIX="v13_real_evidence_live_network_gate"
BINDER_PREFIX="v13_real_run_binder_manifest"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_evidence_rebind_gate_smoke"
  LIVE_PREFIX="v13_real_evidence_live_network_gate_smoke"
  BINDER_PREFIX="v13_real_run_binder_manifest_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_evidence_rebind_gate_full"
  LIVE_PREFIX="v13_real_evidence_live_network_gate_full"
  BINDER_PREFIX="v13_real_run_binder_manifest_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_REAL_EVIDENCE_REBIND_RUN_DIR:-$RESULTS_DIR/${BINDER_PREFIX}_runs/$RUN_ID}"
PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
LIVE_SUMMARY_CSV="$RESULTS_DIR/${LIVE_PREFIX}_summary.csv"
LIVE_PACKET_DIR="$RESULTS_DIR/${LIVE_PREFIX}_packet/$RUN_ID"
REBIND_CSV="${V13_REAL_EVIDENCE_REBIND_CSV:-$RESULTS_DIR/${PREFIX}_rebind.csv}"
REBIND_SOURCE="generated-missing-rebind"

"$ROOT_DIR/experiments/run_v13_real_evidence_live_network_gate.sh" "${RUN_ARGS[@]}" >/dev/null

if [[ -n "${V13_REAL_EVIDENCE_REBIND_CSV:-}" ]]; then
  REBIND_SOURCE="provided-rebind-csv"
  if [[ ! -s "$REBIND_CSV" ]]; then
    echo "V13_REAL_EVIDENCE_REBIND_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  cat >"$REBIND_CSV" <<CSV
run_id,weakness_id,source_receipt_hash,review_receipt_hash,authority_receipt_hash,rebuilt_artifact_uri,rebuilt_artifact_hash,claim_matrix_uri,claim_matrix_hash,regenerated_run_declared,receipt_replayed_declared,nonfixture_declared,runtime_live_fetch_bound_declared,promotion_row_ready_declared,routing_trigger_rate,active_jump_rate
$RUN_ID,external_benchmark,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,0,0
$RUN_ID,learned_chunk_ranking,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,0,0
$RUN_ID,gpu_speedup,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,0,0
$RUN_ID,real_nlg,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,0,0
CSV
fi

python3 - \
  "$RUN_DIR" \
  "$PACKET_DIR" \
  "$SUMMARY_CSV" \
  "$DECISION_CSV" \
  "$LIVE_SUMMARY_CSV" \
  "$LIVE_PACKET_DIR" \
  "$REBIND_CSV" \
  "$REBIND_SOURCE" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote

run_dir = Path(sys.argv[1])
packet_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
live_summary_csv = Path(sys.argv[5])
live_packet_dir = Path(sys.argv[6])
rebind_csv = Path(sys.argv[7])
rebind_source = sys.argv[8]

required_weaknesses = [
    "external_benchmark",
    "learned_chunk_ranking",
    "gpu_speedup",
    "real_nlg",
]
required_fields = [
    "run_id",
    "weakness_id",
    "source_receipt_hash",
    "review_receipt_hash",
    "authority_receipt_hash",
    "rebuilt_artifact_uri",
    "rebuilt_artifact_hash",
    "claim_matrix_uri",
    "claim_matrix_hash",
    "regenerated_run_declared",
    "receipt_replayed_declared",
    "nonfixture_declared",
    "runtime_live_fetch_bound_declared",
    "promotion_row_ready_declared",
    "routing_trigger_rate",
    "active_jump_rate",
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

def read_rows(path, fields=None):
    if not path.is_file():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if fields:
            missing = [field for field in fields if field not in (reader.fieldnames or [])]
            if missing:
                raise SystemExit(f"missing v13-j rebind columns: {','.join(missing)}")
        return list(reader)

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

def status(condition):
    return "pass" if condition else "blocked"

run_hash_entries, run_hash_verified = verify_manifest(run_dir)
run_hash_manifest_ready = int(run_hash_entries > 0 and run_hash_entries == run_hash_verified)

live_summary = first_row(live_summary_csv)
live_packet_hash_entries, live_packet_hash_verified = verify_manifest(live_packet_dir)
live_packet_hash_ready = int(
    live_packet_hash_entries > 0 and live_packet_hash_entries == live_packet_hash_verified
)
live_network_receipt_contract_ready = as_int(live_summary, "live_network_receipt_contract_ready")
candidate_real_evidence_live_network_ready = as_int(live_summary, "candidate_real_evidence_live_network_ready")
v13_real_evidence_promotion_ready = as_int(live_summary, "v13_real_evidence_promotion_ready")
run_id = live_summary.get("run_id", run_dir.name)

live_manifest = {}
live_manifest_path = live_packet_dir / "live_network_manifest.json"
if live_manifest_path.is_file():
    live_manifest = json.loads(live_manifest_path.read_text(encoding="utf-8"))
live_csv = Path(live_manifest.get("live_csv", ""))
live_rows = read_rows(live_csv) if live_csv.is_file() else []
live_hashes = {}
for row in live_rows:
    weakness = row.get("weakness_id", "")
    live_hashes[weakness] = (
        row.get("source_receipt_hash", ""),
        row.get("review_receipt_hash", ""),
        row.get("authority_receipt_hash", ""),
    )

rows = read_rows(rebind_csv, required_fields)
weakness_counts = {weakness: 0 for weakness in required_weaknesses}
packet_rows = []
run_id_match_rows = 0
receipt_hash_match_rows = 0
artifact_hash_verified_rows = 0
contract_flag_ready_rows = 0
routing_sum = 0.0
jump_sum = 0.0

for row in rows:
    weakness = row.get("weakness_id", "")
    if weakness in weakness_counts:
        weakness_counts[weakness] += 1
    run_id_match = int(row.get("run_id") == run_id and run_id == run_dir.name)
    expected_hashes = live_hashes.get(weakness, ("", "", ""))
    receipt_hash_match = int(
        row.get("source_receipt_hash", "") == expected_hashes[0]
        and row.get("review_receipt_hash", "") == expected_hashes[1]
        and row.get("authority_receipt_hash", "") == expected_hashes[2]
        and all(value.startswith("sha256:") for value in expected_hashes)
    )
    artifact_hash_verified = (
        hash_matches(row.get("rebuilt_artifact_uri", ""), row.get("rebuilt_artifact_hash", ""))
        + hash_matches(row.get("claim_matrix_uri", ""), row.get("claim_matrix_hash", ""))
    )
    flags_ready = int(
        as_int(row, "regenerated_run_declared") == 1
        and as_int(row, "receipt_replayed_declared") == 1
        and as_int(row, "nonfixture_declared") == 1
        and as_int(row, "runtime_live_fetch_bound_declared") == 1
        and as_int(row, "promotion_row_ready_declared") == 1
    )
    routing = as_float(row, "routing_trigger_rate")
    jump = as_float(row, "active_jump_rate")

    run_id_match_rows += run_id_match
    receipt_hash_match_rows += 3 * receipt_hash_match
    artifact_hash_verified_rows += artifact_hash_verified
    contract_flag_ready_rows += int(
        weakness in required_weaknesses
        and run_id_match == 1
        and receipt_hash_match == 1
        and artifact_hash_verified == 2
        and flags_ready == 1
        and abs(routing) < 0.000001
        and abs(jump) < 0.000001
    )
    routing_sum += routing
    jump_sum += jump

    packet_rows.append({
        "weakness_id": weakness,
        "run_id_match": run_id_match,
        "receipt_hashes_match": 3 * receipt_hash_match,
        "artifact_hashes_verified": artifact_hash_verified,
        "contract_flags_ready": flags_ready,
        "routing_trigger_rate": f"{routing:.6f}",
        "active_jump_rate": f"{jump:.6f}",
    })

required_weakness_rows = sum(1 for weakness in required_weaknesses if weakness_counts[weakness] == 1)
duplicate_or_unknown_rows = len(rows) - sum(weakness_counts.values()) + sum(
    max(0, count - 1) for count in weakness_counts.values()
)
expected_receipt_hash_rows = 3 * len(required_weaknesses)
expected_artifact_hash_rows = 2 * len(required_weaknesses)
rebind_contract_ready = int(
    run_hash_manifest_ready == 1
    and live_network_receipt_contract_ready == 1
    and live_packet_hash_ready == 1
    and len(rows) == len(required_weaknesses)
    and required_weakness_rows == len(required_weaknesses)
    and duplicate_or_unknown_rows == 0
    and run_id_match_rows == len(required_weaknesses)
    and receipt_hash_match_rows == expected_receipt_hash_rows
    and artifact_hash_verified_rows == expected_artifact_hash_rows
    and contract_flag_ready_rows == len(required_weaknesses)
    and abs(routing_sum) < 0.000001
    and abs(jump_sum) < 0.000001
)
candidate_real_evidence_rebind_ready = int(
    rebind_contract_ready == 1 and candidate_real_evidence_live_network_ready == 1
)
real_release_package_ready = int(
    candidate_real_evidence_rebind_ready == 1 and v13_real_evidence_promotion_ready == 1
)

action = "v13-real-evidence-rebind-package-missing"
if run_hash_manifest_ready != 1:
    action = "v13-real-evidence-rebind-run-hash-mismatch"
elif live_network_receipt_contract_ready != 1 or live_packet_hash_ready != 1:
    action = "v13-real-evidence-rebind-live-network-not-ready"
elif len(rows) != len(required_weaknesses) or required_weakness_rows != len(required_weaknesses) or duplicate_or_unknown_rows != 0:
    action = "v13-real-evidence-rebind-required-weakness-rows-missing"
elif run_id_match_rows != len(required_weaknesses):
    action = "v13-real-evidence-rebind-run-id-mismatch"
elif receipt_hash_match_rows != expected_receipt_hash_rows:
    action = "v13-real-evidence-rebind-receipt-hash-mismatch"
elif artifact_hash_verified_rows != expected_artifact_hash_rows:
    action = "v13-real-evidence-rebind-artifact-hash-mismatch"
elif contract_flag_ready_rows != len(required_weaknesses):
    action = "v13-real-evidence-rebind-contract-incomplete"
elif abs(routing_sum) >= 0.000001 or abs(jump_sum) >= 0.000001:
    action = "v13-real-evidence-rebind-jump-guardrail-active"
elif candidate_real_evidence_live_network_ready != 1:
    action = "v13-real-evidence-rebind-await-runtime-live-fetch"
elif v13_real_evidence_promotion_ready != 1:
    action = "v13-real-evidence-rebind-ready-await-promotion-regeneration"
elif real_release_package_ready == 1:
    action = "v13-real-evidence-rebind-release-ready"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

rows_csv = packet_dir / "rebind_rows.csv"
fieldnames = list(packet_rows[0].keys()) if packet_rows else [
    "weakness_id",
    "run_id_match",
    "receipt_hashes_match",
    "artifact_hashes_verified",
    "contract_flags_ready",
    "routing_trigger_rate",
    "active_jump_rate",
]
with rows_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(packet_rows)

manifest = {
    "artifact_scope": "v13-j-real-evidence-rebind-gate",
    "run_dir": str(run_dir),
    "live_summary_csv": str(live_summary_csv),
    "live_packet_dir": str(live_packet_dir),
    "rebind_csv": str(rebind_csv),
    "required_weaknesses": required_weaknesses,
    "claim": "verifies that live-network receipts can be rebound into same-run promotion replacement rows before release promotion",
}
(packet_dir / "rebind_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

rebind_packet_hash_entries, rebind_packet_hash_verified = verify_manifest(packet_dir)
rebind_packet_hash_ready = int(
    rebind_packet_hash_entries > 0 and rebind_packet_hash_entries == rebind_packet_hash_verified
)
rebind_contract_ready = int(rebind_contract_ready == 1 and rebind_packet_hash_ready == 1)
candidate_real_evidence_rebind_ready = int(
    candidate_real_evidence_rebind_ready == 1 and rebind_packet_hash_ready == 1
)
real_release_package_ready = int(real_release_package_ready == 1 and rebind_packet_hash_ready == 1)

summary_fields = [
    "rebind_scope",
    "rebind_source",
    "run_id",
    "run_dir",
    "rebind_packet_dir",
    "run_hash_entries",
    "run_hash_verified",
    "run_hash_manifest_ready",
    "live_network_receipt_contract_ready",
    "candidate_real_evidence_live_network_ready",
    "v13_real_evidence_promotion_ready",
    "live_packet_hash_entries",
    "live_packet_hash_verified",
    "live_packet_hash_ready",
    "rebind_packet_hash_entries",
    "rebind_packet_hash_verified",
    "rebind_packet_hash_ready",
    "rebind_rows",
    "required_weakness_rows",
    "duplicate_or_unknown_rows",
    "run_id_match_rows",
    "receipt_hash_match_rows",
    "expected_receipt_hash_rows",
    "artifact_hash_verified_rows",
    "expected_artifact_hash_rows",
    "contract_flag_ready_rows",
    "rebind_contract_ready",
    "candidate_real_evidence_rebind_ready",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "rebind_scope": "v13-j-real-evidence-rebind-gate",
    "rebind_source": rebind_source,
    "run_id": run_id,
    "run_dir": str(run_dir),
    "rebind_packet_dir": str(packet_dir),
    "run_hash_entries": run_hash_entries,
    "run_hash_verified": run_hash_verified,
    "run_hash_manifest_ready": run_hash_manifest_ready,
    "live_network_receipt_contract_ready": live_network_receipt_contract_ready,
    "candidate_real_evidence_live_network_ready": candidate_real_evidence_live_network_ready,
    "v13_real_evidence_promotion_ready": v13_real_evidence_promotion_ready,
    "live_packet_hash_entries": live_packet_hash_entries,
    "live_packet_hash_verified": live_packet_hash_verified,
    "live_packet_hash_ready": live_packet_hash_ready,
    "rebind_packet_hash_entries": rebind_packet_hash_entries,
    "rebind_packet_hash_verified": rebind_packet_hash_verified,
    "rebind_packet_hash_ready": rebind_packet_hash_ready,
    "rebind_rows": len(rows),
    "required_weakness_rows": required_weakness_rows,
    "duplicate_or_unknown_rows": duplicate_or_unknown_rows,
    "run_id_match_rows": run_id_match_rows,
    "receipt_hash_match_rows": receipt_hash_match_rows,
    "expected_receipt_hash_rows": expected_receipt_hash_rows,
    "artifact_hash_verified_rows": artifact_hash_verified_rows,
    "expected_artifact_hash_rows": expected_artifact_hash_rows,
    "contract_flag_ready_rows": contract_flag_ready_rows,
    "rebind_contract_ready": rebind_contract_ready,
    "candidate_real_evidence_rebind_ready": candidate_real_evidence_rebind_ready,
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
    ("live-network-binding", status(live_network_receipt_contract_ready == 1 and live_packet_hash_ready == 1), f"live_contract={live_network_receipt_contract_ready} hash={live_packet_hash_ready}"),
    ("required-weakness-rows", status(required_weakness_rows == len(required_weaknesses) and duplicate_or_unknown_rows == 0), f"required={required_weakness_rows}/{len(required_weaknesses)} duplicate_or_unknown={duplicate_or_unknown_rows}"),
    ("run-id-binding", status(run_id_match_rows == len(required_weaknesses)), f"run_id_match={run_id_match_rows}/{len(required_weaknesses)}"),
    ("receipt-hash-replay", status(receipt_hash_match_rows == expected_receipt_hash_rows), f"receipt_hash_match={receipt_hash_match_rows}/{expected_receipt_hash_rows}"),
    ("artifact-hash-binding", status(artifact_hash_verified_rows == expected_artifact_hash_rows), f"artifact_hash={artifact_hash_verified_rows}/{expected_artifact_hash_rows}"),
    ("rebind-contract-flags", status(contract_flag_ready_rows == len(required_weaknesses)), f"contract_flags={contract_flag_ready_rows}/{len(required_weaknesses)}"),
    ("runtime-live-fetch", status(candidate_real_evidence_live_network_ready == 1), f"live_candidate={candidate_real_evidence_live_network_ready}"),
    ("candidate-rebind", status(candidate_real_evidence_rebind_ready == 1), f"candidate={candidate_real_evidence_rebind_ready} action={action}"),
    ("v13-real-evidence-rebind", status(real_release_package_ready == 1), f"release={real_release_package_ready} promotion={v13_real_evidence_promotion_ready}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "rebind_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
