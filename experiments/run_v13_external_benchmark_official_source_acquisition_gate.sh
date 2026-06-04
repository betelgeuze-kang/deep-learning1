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

PREFIX="v13_external_benchmark_official_source_acquisition_gate"
SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_external_benchmark_official_source_acquisition_gate_smoke"
  SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_external_benchmark_official_source_acquisition_gate_full"
  SOURCE_LIVE_PREFIX="v13_real_evidence_source_seed_live_fetch_gate_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SOURCE_LIVE_SUMMARY_CSV="${V13_EXTERNAL_BENCHMARK_SOURCE_LIVE_SUMMARY_CSV:-$RESULTS_DIR/${SOURCE_LIVE_PREFIX}_summary.csv}"
SOURCE_LIVE_PACKET_DIR="${V13_EXTERNAL_BENCHMARK_SOURCE_LIVE_PACKET_DIR:-$RESULTS_DIR/${SOURCE_LIVE_PREFIX}_packet/$RUN_ID}"
LIVE_ACQUISITION_REQUESTED="${V13_EXTERNAL_BENCHMARK_SOURCE_ACQUISITION_LIVE:-0}"

"$ROOT_DIR/experiments/run_v13_real_evidence_source_seed_live_fetch_gate.sh" "${RUN_ARGS[@]}" >/dev/null

python3 - \
  "$PACKET_DIR" \
  "$SUMMARY_CSV" \
  "$DECISION_CSV" \
  "$SOURCE_LIVE_SUMMARY_CSV" \
  "$SOURCE_LIVE_PACKET_DIR" \
  "$LIVE_ACQUISITION_REQUESTED" <<'PY'
import csv
import hashlib
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

packet_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
source_live_summary_csv = Path(sys.argv[4])
source_live_packet_dir = Path(sys.argv[5])
live_acquisition_requested = sys.argv[6] == "1"

scope = "v13-n-external-benchmark-official-source-acquisition-gate"
required_artifacts = [
    ("ruler_repo", "source_uri", "git-ls-remote-head"),
    ("longbench_repo", "review_uri", "git-ls-remote-head"),
    ("ruler_paper", "authority_uri", "http-head"),
]

def utc_now():
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")

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

def status(condition):
    return "pass" if condition else "blocked"

def https_real_uri(uri):
    if not uri.startswith("https://"):
        return 0
    lowered = uri.lower()
    bad_markers = ["placeholder", "fixture", "example.invalid", "localhost"]
    return int(not any(marker in lowered for marker in bad_markers))

def write_text(path, text):
    path.write_text(text, encoding="utf-8")
    return "sha256:" + sha256(path)

def git_ls_remote(receipt_dir, artifact_id, uri):
    started = utc_now()
    stdout_path = receipt_dir / f"{artifact_id}_ls_remote_stdout.txt"
    stderr_path = receipt_dir / f"{artifact_id}_ls_remote_stderr.txt"
    error = ""
    returncode = 999
    stdout = ""
    stderr = ""
    try:
        completed = subprocess.run(
            ["git", "ls-remote", uri, "HEAD"],
            check=False,
            capture_output=True,
            text=True,
            timeout=30,
        )
        returncode = completed.returncode
        stdout = completed.stdout
        stderr = completed.stderr
    except Exception as exc:
        error = type(exc).__name__ + ": " + str(exc)
    finished = utc_now()
    stdout_hash = write_text(stdout_path, stdout)
    stderr_hash = write_text(stderr_path, stderr)
    head_sha = ""
    head_ref = ""
    parts = stdout.strip().split()
    if len(parts) >= 2:
        head_sha = parts[0]
        head_ref = parts[1]
    receipt = {
        "artifact_scope": scope,
        "artifact_id": artifact_id,
        "uri": uri,
        "method": "git ls-remote HEAD",
        "returncode": returncode,
        "status": 200 if returncode == 0 else 0,
        "head_sha": head_sha,
        "head_ref": head_ref,
        "stdout_path": str(stdout_path),
        "stdout_hash": stdout_hash,
        "stderr_path": str(stderr_path),
        "stderr_hash": stderr_hash,
        "started_at_utc": started,
        "finished_at_utc": finished,
        "error": error,
        "runner_owned_live_acquisition": 1,
    }
    return receipt

def http_head(artifact_id, uri):
    started = utc_now()
    final_uri = ""
    status_code = 0
    headers = {}
    error = ""
    method = "HEAD"
    try:
        request = Request(uri, method="HEAD", headers={"User-Agent": "codex-v13n-source-acquisition/1.0"})
        with urlopen(request, timeout=30) as response:
            status_code = response.status
            final_uri = response.geturl()
            headers = dict(response.headers.items())
    except HTTPError as exc:
        status_code = exc.code
        final_uri = exc.geturl()
        headers = dict(exc.headers.items()) if exc.headers else {}
        error = "HTTPError: " + str(exc)
    except URLError as exc:
        error = "URLError: " + str(exc.reason)
    except Exception as exc:
        error = type(exc).__name__ + ": " + str(exc)
    finished = utc_now()
    return {
        "artifact_scope": scope,
        "artifact_id": artifact_id,
        "uri": uri,
        "final_uri": final_uri,
        "method": method,
        "status": status_code,
        "headers": headers,
        "started_at_utc": started,
        "finished_at_utc": finished,
        "error": "" if 200 <= status_code < 400 else error,
        "runner_owned_live_acquisition": 1,
    }

source_live_summary = first_row(source_live_summary_csv)
source_live_packet_hash_entries, source_live_packet_hash_verified = verify_manifest(source_live_packet_dir)
source_live_packet_hash_ready = int(
    source_live_packet_hash_entries > 0 and source_live_packet_hash_entries == source_live_packet_hash_verified
)
source_seed_contract_ready = as_int(source_live_summary, "seed_contract_ready")
source_seed_live_fetch_receipt_ready = as_int(source_live_summary, "source_seed_live_fetch_receipt_ready")

seed_csv = Path("")
seed_packet_dir = Path("")
source_live_manifest_path = source_live_packet_dir / "source_seed_live_fetch_manifest.json"
if source_live_manifest_path.is_file():
    manifest = json.loads(source_live_manifest_path.read_text(encoding="utf-8"))
    seed_csv = Path(manifest.get("seed_csv", ""))
    seed_packet_dir = Path(manifest.get("seed_packet_dir", ""))

seed_rows = read_rows(seed_csv)
external_rows = [row for row in seed_rows if row.get("weakness_id") == "external_benchmark"]
external_seed = external_rows[0] if len(external_rows) == 1 else {}
official_benchmark_seed_rows = int(
    len(external_rows) == 1
    and external_seed.get("evidence_class") == "official-benchmark-source-seed"
    and as_int(external_seed, "official_or_public_declared") == 1
    and as_int(external_seed, "nonfixture_declared") == 1
)
routing_sum = sum(as_float(row, "routing_trigger_rate") for row in seed_rows)
jump_sum = sum(as_float(row, "active_jump_rate") for row in seed_rows)

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)
receipt_dir = packet_dir / "acquisition_receipts"
receipt_dir.mkdir()

packet_rows = []
acquisition_receipt_rows = 0
acquisition_json_shape_rows = 0
repo_head_rows = 0
http_status_rows = 0
https_rows = 0
runner_owned_rows = 0
error_empty_rows = 0

for artifact_id, uri_field, expected_method in required_artifacts:
    uri = external_seed.get(uri_field, "")
    receipt = {
        "artifact_scope": scope,
        "artifact_id": artifact_id,
        "uri": uri,
        "method": expected_method,
        "status": 0,
        "error": "live acquisition not requested",
        "runner_owned_live_acquisition": 0,
    }
    if live_acquisition_requested and uri:
        if expected_method.startswith("git-"):
            receipt = git_ls_remote(receipt_dir, artifact_id, uri)
        else:
            receipt = http_head(artifact_id, uri)
    receipt_path = receipt_dir / f"{artifact_id}_receipt.json"
    receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    receipt_hash = "sha256:" + sha256(receipt_path)

    acquisition_receipt_rows += int(receipt_path.is_file())
    kind_ok = int(receipt.get("artifact_scope") == scope and receipt.get("artifact_id") == artifact_id)
    https_ok = https_real_uri(receipt.get("uri", ""))
    runner_ok = int(receipt.get("runner_owned_live_acquisition") == 1)
    error_ok = int(receipt.get("error", "") == "")
    status_ok = int(isinstance(receipt.get("status"), int) and 200 <= receipt.get("status") < 400)
    if expected_method.startswith("git-"):
        method_ok = int(receipt.get("method") == "git ls-remote HEAD")
        head_ok = int(
            receipt.get("returncode") == 0
            and receipt.get("head_ref") == "HEAD"
            and len(receipt.get("head_sha", "")) >= 40
        )
        repo_head_rows += head_ok
        shape_ok = int(kind_ok and https_ok and runner_ok and method_ok and head_ok and status_ok and error_ok)
    else:
        method_ok = int(receipt.get("method") == "HEAD")
        http_ok = int(
            status_ok
            and https_real_uri(receipt.get("final_uri", ""))
            and isinstance(receipt.get("headers"), dict)
        )
        http_status_rows += http_ok
        shape_ok = int(kind_ok and https_ok and runner_ok and method_ok and http_ok and error_ok)

    acquisition_json_shape_rows += shape_ok
    https_rows += https_ok
    runner_owned_rows += runner_ok
    error_empty_rows += error_ok

    packet_rows.append({
        "artifact_id": artifact_id,
        "source_role": uri_field,
        "uri": uri,
        "expected_method": expected_method,
        "receipt_uri": "file://" + str(receipt_path),
        "receipt_hash": receipt_hash,
        "https_ready": https_ok,
        "runner_owned_live_acquisition": runner_ok,
        "method_ready": method_ok,
        "repo_head_ready": 1 if expected_method.startswith("git-") and shape_ok else 0,
        "http_status_ready": 1 if expected_method == "http-head" and shape_ok else 0,
        "json_shape_ready": shape_ok,
        "error_empty": error_ok,
        "routing_trigger_rate": "0.000000",
        "active_jump_rate": "0.000000",
    })

rows_csv = packet_dir / "official_source_acquisition_rows.csv"
with rows_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(packet_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(packet_rows)

manifest = {
    "artifact_scope": scope,
    "source_live_summary_csv": str(source_live_summary_csv),
    "source_live_packet_dir": str(source_live_packet_dir),
    "seed_packet_dir": str(seed_packet_dir),
    "seed_csv": str(seed_csv),
    "required_artifacts": [artifact for artifact, _, _ in required_artifacts],
    "claim": "runner-owned official/public source acquisition for external benchmark seeds only; not benchmark result evidence",
}
(packet_dir / "official_source_acquisition_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

packet_hash_entries, packet_hash_verified = verify_manifest(packet_dir)
packet_hash_ready = int(packet_hash_entries > 0 and packet_hash_entries == packet_hash_verified)
required_source_rows = len(required_artifacts)
source_live_upstream_ready = int(source_seed_contract_ready == 1 and source_live_packet_hash_ready == 1)
external_benchmark_official_source_acquisition_ready = int(
    source_live_upstream_ready == 1
    and official_benchmark_seed_rows == 1
    and live_acquisition_requested
    and acquisition_receipt_rows == required_source_rows
    and acquisition_json_shape_rows == required_source_rows
    and repo_head_rows == 2
    and http_status_rows == 1
    and runner_owned_rows == required_source_rows
    and error_empty_rows == required_source_rows
    and packet_hash_ready == 1
    and abs(routing_sum) < 0.000001
    and abs(jump_sum) < 0.000001
)
candidate_external_benchmark_result_ready = 0
real_release_package_ready = 0

action = "v13-external-benchmark-source-acquisition-not-requested"
if source_live_upstream_ready != 1:
    action = "v13-external-benchmark-source-acquisition-upstream-not-ready"
elif official_benchmark_seed_rows != 1:
    action = "v13-external-benchmark-source-acquisition-seed-missing"
elif not live_acquisition_requested:
    action = "v13-external-benchmark-source-acquisition-not-requested"
elif acquisition_json_shape_rows != required_source_rows:
    action = "v13-external-benchmark-source-acquisition-incomplete"
elif external_benchmark_official_source_acquisition_ready == 1:
    action = "v13-external-benchmark-source-acquisition-ready-await-result-run"

summary_fields = [
    "external_benchmark_source_acquisition_scope",
    "run_id",
    "external_benchmark_source_acquisition_packet_dir",
    "source_seed_contract_ready",
    "source_seed_live_fetch_receipt_ready",
    "source_live_packet_hash_ready",
    "official_benchmark_seed_rows",
    "live_acquisition_requested",
    "required_source_rows",
    "acquisition_receipt_rows",
    "acquisition_json_shape_rows",
    "repo_head_rows",
    "http_status_rows",
    "https_rows",
    "runner_owned_rows",
    "error_empty_rows",
    "packet_hash_entries",
    "packet_hash_verified",
    "packet_hash_ready",
    "external_benchmark_official_source_acquisition_ready",
    "candidate_external_benchmark_result_ready",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "external_benchmark_source_acquisition_scope": scope,
    "run_id": source_live_summary.get("run_id", source_live_packet_dir.name),
    "external_benchmark_source_acquisition_packet_dir": str(packet_dir),
    "source_seed_contract_ready": source_seed_contract_ready,
    "source_seed_live_fetch_receipt_ready": source_seed_live_fetch_receipt_ready,
    "source_live_packet_hash_ready": source_live_packet_hash_ready,
    "official_benchmark_seed_rows": official_benchmark_seed_rows,
    "live_acquisition_requested": int(live_acquisition_requested),
    "required_source_rows": required_source_rows,
    "acquisition_receipt_rows": acquisition_receipt_rows if live_acquisition_requested else 0,
    "acquisition_json_shape_rows": acquisition_json_shape_rows if live_acquisition_requested else 0,
    "repo_head_rows": repo_head_rows,
    "http_status_rows": http_status_rows,
    "https_rows": https_rows,
    "runner_owned_rows": runner_owned_rows,
    "error_empty_rows": error_empty_rows,
    "packet_hash_entries": packet_hash_entries,
    "packet_hash_verified": packet_hash_verified,
    "packet_hash_ready": packet_hash_ready,
    "external_benchmark_official_source_acquisition_ready": external_benchmark_official_source_acquisition_ready,
    "candidate_external_benchmark_result_ready": candidate_external_benchmark_result_ready,
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
    ("source-seed-upstream", status(source_live_upstream_ready == 1), f"seed_contract={source_seed_contract_ready} source_live_packet_hash={source_live_packet_hash_ready}"),
    ("source-seed-live-fetch", status(source_seed_live_fetch_receipt_ready == 1), f"source_seed_live_fetch_receipt_ready={source_seed_live_fetch_receipt_ready}"),
    ("official-benchmark-seed", status(official_benchmark_seed_rows == 1), f"rows={official_benchmark_seed_rows}"),
    ("live-acquisition-requested", status(live_acquisition_requested), f"requested={int(live_acquisition_requested)}"),
    ("acquisition-receipts", status(acquisition_receipt_rows == required_source_rows and live_acquisition_requested), f"receipts={acquisition_receipt_rows}/{required_source_rows}"),
    ("repo-heads", status(repo_head_rows == 2), f"repo_heads={repo_head_rows}/2"),
    ("http-authority", status(http_status_rows == 1), f"http_status={http_status_rows}/1"),
    ("official-source-acquisition", status(external_benchmark_official_source_acquisition_ready == 1), f"ready={external_benchmark_official_source_acquisition_ready} action={action}"),
    ("candidate-external-benchmark-result", status(candidate_external_benchmark_result_ready == 1), f"candidate_result={candidate_external_benchmark_result_ready}"),
    ("real-release-package", status(real_release_package_ready == 1), f"release={real_release_package_ready}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "external_benchmark_source_acquisition_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
