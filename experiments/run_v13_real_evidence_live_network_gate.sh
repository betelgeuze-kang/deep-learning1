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

PREFIX="v13_real_evidence_live_network_gate"
INTAKE_PREFIX="v13_real_evidence_intake_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_evidence_live_network_gate_smoke"
  INTAKE_PREFIX="v13_real_evidence_intake_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_evidence_live_network_gate_full"
  INTAKE_PREFIX="v13_real_evidence_intake_gate_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
LIVE_CSV="${V13_REAL_EVIDENCE_LIVE_NETWORK_CSV:-$RESULTS_DIR/${PREFIX}_live_network.csv}"
INTAKE_SUMMARY_CSV="$RESULTS_DIR/${INTAKE_PREFIX}_summary.csv"
INTAKE_PACKET_DIR="$RESULTS_DIR/${INTAKE_PREFIX}_packet/$RUN_ID"
LIVE_SOURCE="generated-missing-live-network-receipts"
FETCH_REQUESTED="${V13_REAL_EVIDENCE_LIVE_NETWORK_FETCH:-0}"

"$ROOT_DIR/experiments/run_v13_real_evidence_intake_gate.sh" "${RUN_ARGS[@]}" >/dev/null

if [[ -n "${V13_REAL_EVIDENCE_LIVE_NETWORK_CSV:-}" ]]; then
  LIVE_SOURCE="provided-live-network-csv"
  if [[ ! -s "$LIVE_CSV" ]]; then
    echo "V13_REAL_EVIDENCE_LIVE_NETWORK_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
elif [[ "$FETCH_REQUESTED" == "1" ]]; then
  LIVE_SOURCE="runtime-live-fetch"
else
  cat >"$LIVE_CSV" <<CSV
run_id,weakness_id,source_status,review_status,authority_status,source_final_uri,review_final_uri,authority_final_uri,source_receipt_uri,review_receipt_uri,authority_receipt_uri,source_receipt_hash,review_receipt_hash,authority_receipt_hash,tls_verified,dns_verified,http_verified,runner_owned_live_fetch,nonfixture_declared,fixture_declared,live_network_verified,routing_trigger_rate,active_jump_rate
$RUN_ID,external_benchmark,0,0,0,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,1,0,0,0
$RUN_ID,learned_chunk_ranking,0,0,0,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,1,0,0,0
$RUN_ID,gpu_speedup,0,0,0,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,1,0,0,0
$RUN_ID,real_nlg,0,0,0,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,1,0,0,0
CSV
fi

python3 - \
  "$INTAKE_SUMMARY_CSV" \
  "$INTAKE_PACKET_DIR" \
  "$PACKET_DIR" \
  "$SUMMARY_CSV" \
  "$DECISION_CSV" \
  "$LIVE_CSV" \
  "$LIVE_SOURCE" \
  "$FETCH_REQUESTED" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import ssl
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import unquote
from urllib.request import Request, urlopen

intake_summary_csv = Path(sys.argv[1])
intake_packet_dir = Path(sys.argv[2])
packet_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
live_csv = Path(sys.argv[6])
live_source = sys.argv[7]
fetch_requested = sys.argv[8] == "1"

required_weaknesses = [
    "external_benchmark",
    "learned_chunk_ranking",
    "gpu_speedup",
    "real_nlg",
]
required_fields = [
    "run_id",
    "weakness_id",
    "source_status",
    "review_status",
    "authority_status",
    "source_final_uri",
    "review_final_uri",
    "authority_final_uri",
    "source_receipt_uri",
    "review_receipt_uri",
    "authority_receipt_uri",
    "source_receipt_hash",
    "review_receipt_hash",
    "authority_receipt_hash",
    "tls_verified",
    "dns_verified",
    "http_verified",
    "runner_owned_live_fetch",
    "nonfixture_declared",
    "fixture_declared",
    "live_network_verified",
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
                raise SystemExit(f"missing v13-i live network columns: {','.join(missing)}")
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

def https_real_uri(uri):
    if not uri.startswith("https://"):
        return 0
    lowered = uri.lower()
    bad_markers = ["placeholder", "fixture", "example.invalid", "localhost"]
    return int(not any(marker in lowered for marker in bad_markers))

def status_ready(row):
    return int(
        200 <= as_int(row, "source_status") < 400
        and 200 <= as_int(row, "review_status") < 400
        and 200 <= as_int(row, "authority_status") < 400
    )

def write_runtime_receipt(receipt_dir, weakness, kind, uri, timeout):
    started = datetime.now(timezone.utc).isoformat()
    status = 0
    final_uri = uri
    error = ""
    headers = {}
    method = "HEAD"
    if not uri.startswith("https://"):
        error = "non-https-uri"
    else:
        for attempt_method in ("HEAD", "GET"):
            method = attempt_method
            try:
                req = Request(uri, method=attempt_method, headers={"User-Agent": "betelgeuze-v13i-live-network-gate/1"})
                context = ssl.create_default_context()
                with urlopen(req, timeout=timeout, context=context) as response:
                    status = int(getattr(response, "status", response.getcode()))
                    final_uri = response.geturl()
                    headers = {
                        key.lower(): value
                        for key, value in response.headers.items()
                        if key.lower() in {"content-type", "content-length", "etag", "last-modified"}
                    }
                error = ""
                break
            except HTTPError as exc:
                status = int(exc.code)
                final_uri = exc.geturl() or uri
                headers = {
                    key.lower(): value
                    for key, value in exc.headers.items()
                    if key.lower() in {"content-type", "content-length", "etag", "last-modified"}
                }
                error = f"http-error:{exc.code}"
                break
            except URLError as exc:
                error = f"url-error:{exc.reason}"
            except Exception as exc:  # pragma: no cover - defensive receipt detail.
                error = f"fetch-error:{type(exc).__name__}:{exc}"
            if attempt_method == "HEAD":
                time.sleep(0.1)
    receipt = {
        "artifact_scope": "v13-i-real-evidence-live-network-gate",
        "weakness_id": weakness,
        "kind": kind,
        "uri": uri,
        "method": method,
        "status": status,
        "final_uri": final_uri,
        "started_at_utc": started,
        "finished_at_utc": datetime.now(timezone.utc).isoformat(),
        "headers": headers,
        "error": error,
    }
    path = receipt_dir / f"{weakness}_{kind}_receipt.json"
    path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return status, final_uri, path

intake_summary = first_row(intake_summary_csv)
intake_packet_hash_entries, intake_packet_hash_verified = verify_manifest(intake_packet_dir)
intake_packet_hash_ready = int(
    intake_packet_hash_entries > 0 and intake_packet_hash_entries == intake_packet_hash_verified
)
intake_contract_ready = as_int(intake_summary, "real_evidence_intake_contract_ready")
intake_candidate_ready = as_int(intake_summary, "candidate_real_evidence_intake_ready")
v13_real_evidence_promotion_ready = as_int(intake_summary, "v13_real_evidence_promotion_ready")
run_id = intake_summary.get("run_id", "run_001")

intake_manifest = {}
manifest_path = intake_packet_dir / "intake_manifest.json"
if manifest_path.is_file():
    intake_manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
intake_csv = Path(intake_manifest.get("intake_csv", ""))
intake_rows = read_rows(intake_csv) if intake_csv.is_file() else []

if live_source == "runtime-live-fetch":
    receipt_dir = packet_dir / "runtime_receipts"
    if packet_dir.exists():
        shutil.rmtree(packet_dir)
    receipt_dir.mkdir(parents=True)
    timeout = float(os.environ.get("V13_REAL_EVIDENCE_LIVE_NETWORK_TIMEOUT", "8"))
    rows = []
    by_weakness = {row.get("weakness_id", ""): row for row in intake_rows}
    for weakness in required_weaknesses:
        source = by_weakness.get(weakness, {})
        statuses = {}
        finals = {}
        receipt_uris = {}
        receipt_hashes = {}
        for kind, field in (("source", "source_uri"), ("review", "review_uri"), ("authority", "authority_uri")):
            status, final_uri, receipt = write_runtime_receipt(
                receipt_dir,
                weakness,
                kind,
                source.get(field, "MISSING"),
                timeout,
            )
            statuses[kind] = status
            finals[kind] = final_uri
            receipt_uris[kind] = "file://" + str(receipt)
            receipt_hashes[kind] = "sha256:" + sha256(receipt)
        ok = int(
            200 <= statuses["source"] < 400
            and 200 <= statuses["review"] < 400
            and 200 <= statuses["authority"] < 400
            and all(https_real_uri(finals[kind]) for kind in ("source", "review", "authority"))
        )
        rows.append({
            "run_id": run_id,
            "weakness_id": weakness,
            "source_status": statuses["source"],
            "review_status": statuses["review"],
            "authority_status": statuses["authority"],
            "source_final_uri": finals["source"],
            "review_final_uri": finals["review"],
            "authority_final_uri": finals["authority"],
            "source_receipt_uri": receipt_uris["source"],
            "review_receipt_uri": receipt_uris["review"],
            "authority_receipt_uri": receipt_uris["authority"],
            "source_receipt_hash": receipt_hashes["source"],
            "review_receipt_hash": receipt_hashes["review"],
            "authority_receipt_hash": receipt_hashes["authority"],
            "tls_verified": ok,
            "dns_verified": ok,
            "http_verified": ok,
            "runner_owned_live_fetch": 1,
            "nonfixture_declared": 1,
            "fixture_declared": 0,
            "live_network_verified": ok,
            "routing_trigger_rate": "0.000000",
            "active_jump_rate": "0.000000",
        })
    live_csv.parent.mkdir(parents=True, exist_ok=True)
    with live_csv.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=required_fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

rows = read_rows(live_csv, required_fields)
weakness_counts = {weakness: 0 for weakness in required_weaknesses}
packet_rows = []
run_id_match_rows = 0
receipt_hash_verified_rows = 0
https_final_uri_rows = 0
status_ready_rows = 0
network_flag_ready_rows = 0
runtime_fetch_rows = 0
fixture_rows = 0
live_network_verified_rows = 0
routing_sum = 0.0
jump_sum = 0.0

for row in rows:
    weakness = row.get("weakness_id", "")
    if weakness in weakness_counts:
        weakness_counts[weakness] += 1
    run_id_match = int(row.get("run_id") == run_id)
    source_receipt = hash_matches(row.get("source_receipt_uri", ""), row.get("source_receipt_hash", ""))
    review_receipt = hash_matches(row.get("review_receipt_uri", ""), row.get("review_receipt_hash", ""))
    authority_receipt = hash_matches(row.get("authority_receipt_uri", ""), row.get("authority_receipt_hash", ""))
    receipt_hash_verified = source_receipt + review_receipt + authority_receipt
    https_final = int(
        https_real_uri(row.get("source_final_uri", ""))
        and https_real_uri(row.get("review_final_uri", ""))
        and https_real_uri(row.get("authority_final_uri", ""))
    )
    statuses_ok = status_ready(row)
    flags_ok = int(
        as_int(row, "tls_verified") == 1
        and as_int(row, "dns_verified") == 1
        and as_int(row, "http_verified") == 1
        and as_int(row, "runner_owned_live_fetch") == 1
        and as_int(row, "nonfixture_declared") == 1
        and as_int(row, "live_network_verified") == 1
    )
    runtime_fetch = int(live_source == "runtime-live-fetch" and as_int(row, "fixture_declared") == 0)
    fixture = as_int(row, "fixture_declared")
    routing = as_float(row, "routing_trigger_rate")
    jump = as_float(row, "active_jump_rate")

    run_id_match_rows += run_id_match
    receipt_hash_verified_rows += receipt_hash_verified
    https_final_uri_rows += https_final
    status_ready_rows += statuses_ok
    network_flag_ready_rows += flags_ok
    runtime_fetch_rows += runtime_fetch
    fixture_rows += fixture
    live_network_verified_rows += as_int(row, "live_network_verified")
    routing_sum += routing
    jump_sum += jump

    packet_rows.append({
        "weakness_id": weakness,
        "run_id_match": run_id_match,
        "receipt_hashes_verified": receipt_hash_verified,
        "https_final_uri_ready": https_final,
        "status_ready": statuses_ok,
        "network_flags_ready": flags_ok,
        "runtime_fetch_ready": runtime_fetch,
        "fixture_declared": fixture,
        "live_network_verified": as_int(row, "live_network_verified"),
        "routing_trigger_rate": f"{routing:.6f}",
        "active_jump_rate": f"{jump:.6f}",
    })

required_weakness_rows = sum(1 for weakness in required_weaknesses if weakness_counts[weakness] == 1)
duplicate_or_unknown_rows = len(rows) - sum(weakness_counts.values()) + sum(
    max(0, count - 1) for count in weakness_counts.values()
)
expected_receipts = 3 * len(required_weaknesses)
live_network_receipt_contract_ready = int(
    intake_contract_ready == 1
    and intake_packet_hash_ready == 1
    and len(rows) == len(required_weaknesses)
    and required_weakness_rows == len(required_weaknesses)
    and duplicate_or_unknown_rows == 0
    and run_id_match_rows == len(required_weaknesses)
    and receipt_hash_verified_rows == expected_receipts
    and https_final_uri_rows == len(required_weaknesses)
    and status_ready_rows == len(required_weaknesses)
    and network_flag_ready_rows == len(required_weaknesses)
    and abs(routing_sum) < 0.000001
    and abs(jump_sum) < 0.000001
)
candidate_real_evidence_live_network_ready = int(
    live_network_receipt_contract_ready == 1
    and runtime_fetch_rows == len(required_weaknesses)
    and fixture_rows == 0
)
real_release_package_ready = int(
    candidate_real_evidence_live_network_ready == 1
    and v13_real_evidence_promotion_ready == 1
)

action = "v13-real-evidence-live-network-receipts-missing"
if intake_contract_ready != 1 or intake_packet_hash_ready != 1:
    action = "v13-real-evidence-live-network-intake-not-ready"
elif len(rows) != len(required_weaknesses) or required_weakness_rows != len(required_weaknesses) or duplicate_or_unknown_rows != 0:
    action = "v13-real-evidence-live-network-required-weakness-rows-missing"
elif run_id_match_rows != len(required_weaknesses):
    action = "v13-real-evidence-live-network-run-id-mismatch"
elif receipt_hash_verified_rows != expected_receipts:
    action = "v13-real-evidence-live-network-receipt-hash-mismatch"
elif https_final_uri_rows != len(required_weaknesses):
    action = "v13-real-evidence-live-network-final-uri-incomplete"
elif status_ready_rows != len(required_weaknesses):
    action = "v13-real-evidence-live-network-http-status-incomplete"
elif network_flag_ready_rows != len(required_weaknesses):
    action = "v13-real-evidence-live-network-flags-incomplete"
elif abs(routing_sum) >= 0.000001 or abs(jump_sum) >= 0.000001:
    action = "v13-real-evidence-live-network-jump-guardrail-active"
elif runtime_fetch_rows != len(required_weaknesses) or fixture_rows != 0:
    action = "v13-real-evidence-live-network-await-runtime-fetch"
elif v13_real_evidence_promotion_ready != 1:
    action = "v13-real-evidence-live-network-ready-await-bound-run-regeneration"
elif real_release_package_ready == 1:
    action = "v13-real-evidence-live-network-release-ready"

if live_source != "runtime-live-fetch" and packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True, exist_ok=True)

rows_csv = packet_dir / "live_network_rows.csv"
fieldnames = list(packet_rows[0].keys()) if packet_rows else [
    "weakness_id",
    "run_id_match",
    "receipt_hashes_verified",
    "https_final_uri_ready",
    "status_ready",
    "network_flags_ready",
    "runtime_fetch_ready",
    "fixture_declared",
    "live_network_verified",
    "routing_trigger_rate",
    "active_jump_rate",
]
with rows_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(packet_rows)

manifest = {
    "artifact_scope": "v13-i-real-evidence-live-network-gate",
    "live_source": live_source,
    "fetch_requested": fetch_requested,
    "intake_summary_csv": str(intake_summary_csv),
    "intake_packet_dir": str(intake_packet_dir),
    "live_csv": str(live_csv),
    "required_weaknesses": required_weaknesses,
    "claim": "verifies same-run live-network receipt evidence before real evidence can replace diagnostic/local packets",
}
(packet_dir / "live_network_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

live_packet_hash_entries, live_packet_hash_verified = verify_manifest(packet_dir)
live_packet_hash_ready = int(
    live_packet_hash_entries > 0 and live_packet_hash_entries == live_packet_hash_verified
)
live_network_receipt_contract_ready = int(
    live_network_receipt_contract_ready == 1 and live_packet_hash_ready == 1
)
candidate_real_evidence_live_network_ready = int(
    candidate_real_evidence_live_network_ready == 1 and live_packet_hash_ready == 1
)
real_release_package_ready = int(real_release_package_ready == 1 and live_packet_hash_ready == 1)

summary_fields = [
    "live_scope",
    "live_source",
    "run_id",
    "live_packet_dir",
    "intake_contract_ready",
    "intake_candidate_ready",
    "v13_real_evidence_promotion_ready",
    "intake_packet_hash_entries",
    "intake_packet_hash_verified",
    "intake_packet_hash_ready",
    "live_packet_hash_entries",
    "live_packet_hash_verified",
    "live_packet_hash_ready",
    "live_rows",
    "required_weakness_rows",
    "duplicate_or_unknown_rows",
    "run_id_match_rows",
    "receipt_hash_verified_rows",
    "expected_receipt_hash_rows",
    "https_final_uri_rows",
    "status_ready_rows",
    "network_flag_ready_rows",
    "runtime_fetch_rows",
    "fixture_rows",
    "live_network_verified_rows",
    "live_network_receipt_contract_ready",
    "candidate_real_evidence_live_network_ready",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "live_scope": "v13-i-real-evidence-live-network-gate",
    "live_source": live_source,
    "run_id": run_id,
    "live_packet_dir": str(packet_dir),
    "intake_contract_ready": intake_contract_ready,
    "intake_candidate_ready": intake_candidate_ready,
    "v13_real_evidence_promotion_ready": v13_real_evidence_promotion_ready,
    "intake_packet_hash_entries": intake_packet_hash_entries,
    "intake_packet_hash_verified": intake_packet_hash_verified,
    "intake_packet_hash_ready": intake_packet_hash_ready,
    "live_packet_hash_entries": live_packet_hash_entries,
    "live_packet_hash_verified": live_packet_hash_verified,
    "live_packet_hash_ready": live_packet_hash_ready,
    "live_rows": len(rows),
    "required_weakness_rows": required_weakness_rows,
    "duplicate_or_unknown_rows": duplicate_or_unknown_rows,
    "run_id_match_rows": run_id_match_rows,
    "receipt_hash_verified_rows": receipt_hash_verified_rows,
    "expected_receipt_hash_rows": expected_receipts,
    "https_final_uri_rows": https_final_uri_rows,
    "status_ready_rows": status_ready_rows,
    "network_flag_ready_rows": network_flag_ready_rows,
    "runtime_fetch_rows": runtime_fetch_rows,
    "fixture_rows": fixture_rows,
    "live_network_verified_rows": live_network_verified_rows,
    "live_network_receipt_contract_ready": live_network_receipt_contract_ready,
    "candidate_real_evidence_live_network_ready": candidate_real_evidence_live_network_ready,
    "real_release_package_ready": real_release_package_ready,
    "action": action,
    "routing_trigger_rate": f"{routing_sum:.6f}",
    "active_jump_rate": f"{jump_sum:.6f}",
}
with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=summary_fields, lineterminator="\n")
    writer.writeheader()
    writer.writerow(summary_row)

def status(condition):
    return "pass" if condition else "blocked"

decision_rows = [
    ("intake-contract", status(intake_contract_ready == 1 and intake_packet_hash_ready == 1), f"intake_contract={intake_contract_ready} hash={intake_packet_hash_ready}"),
    ("required-weakness-rows", status(required_weakness_rows == len(required_weaknesses) and duplicate_or_unknown_rows == 0), f"required={required_weakness_rows}/{len(required_weaknesses)} duplicate_or_unknown={duplicate_or_unknown_rows}"),
    ("run-id-binding", status(run_id_match_rows == len(required_weaknesses)), f"run_id_match={run_id_match_rows}/{len(required_weaknesses)}"),
    ("receipt-hash-binding", status(receipt_hash_verified_rows == expected_receipts), f"receipt_hashes={receipt_hash_verified_rows}/{expected_receipts}"),
    ("live-http-status", status(status_ready_rows == len(required_weaknesses)), f"status_ready={status_ready_rows}/{len(required_weaknesses)}"),
    ("network-declarations", status(network_flag_ready_rows == len(required_weaknesses)), f"flags={network_flag_ready_rows}/{len(required_weaknesses)}"),
    ("runtime-live-fetch", status(runtime_fetch_rows == len(required_weaknesses) and fixture_rows == 0), f"runtime={runtime_fetch_rows}/{len(required_weaknesses)} fixture_rows={fixture_rows}"),
    ("candidate-live-network", status(candidate_real_evidence_live_network_ready == 1), f"candidate={candidate_real_evidence_live_network_ready} action={action}"),
    ("v13-real-evidence-live-network", status(real_release_package_ready == 1), f"release={real_release_package_ready} promotion={v13_real_evidence_promotion_ready}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "live_network_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
