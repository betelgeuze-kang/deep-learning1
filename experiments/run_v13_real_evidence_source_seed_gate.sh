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

PREFIX="v13_real_evidence_source_seed_gate"
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_evidence_source_seed_gate_smoke"
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_evidence_source_seed_gate_full"
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
SEED_CSV="${V13_REAL_EVIDENCE_SOURCE_SEED_CSV:-$RESULTS_DIR/${PREFIX}_seed.csv}"
SEED_SOURCE="generated-current-source-seed"
LIVE_FETCH_REQUESTED="${V13_REAL_EVIDENCE_SOURCE_SEED_LIVE_FETCH:-0}"

if [[ -n "${V13_REAL_EVIDENCE_SOURCE_SEED_CSV:-}" ]]; then
  SEED_SOURCE="provided-source-seed-csv"
  if [[ ! -s "$SEED_CSV" ]]; then
    echo "V13_REAL_EVIDENCE_SOURCE_SEED_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  SEED_CACHE_DIR="$RESULTS_DIR/${PREFIX}_seed_cache"
  rm -rf "$SEED_CACHE_DIR"
  mkdir -p "$SEED_CACHE_DIR"
  python3 - "$SEED_CACHE_DIR" "$SEED_CSV" "$RUN_ID" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

cache_dir = Path(sys.argv[1])
seed_csv = Path(sys.argv[2])
run_id = sys.argv[3]

rows = [
    {
        "weakness_id": "external_benchmark",
        "evidence_family": "external-benchmark",
        "source_uri": "https://github.com/NVIDIA/RULER",
        "review_uri": "https://github.com/THUDM/LongBench",
        "authority_uri": "https://arxiv.org/abs/2404.06654",
        "evidence_class": "official-benchmark-source-seed",
        "source_note": "RULER and LongBench official/public source seed; still not a runner-owned comparison result",
        "official_or_public_declared": 1,
        "independent_declared": 1,
        "runner_owned_declared": 0,
        "nonfixture_declared": 1,
        "claim_evidence_declared": 0,
        "live_fetch_candidate_declared": 1,
    },
    {
        "weakness_id": "learned_chunk_ranking",
        "evidence_family": "learned-scorer",
        "source_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "review_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "authority_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "evidence_class": "project-source-only",
        "source_note": "Project source can describe h10 scorer mechanics but is not external teacher/source authority",
        "official_or_public_declared": 0,
        "independent_declared": 0,
        "runner_owned_declared": 0,
        "nonfixture_declared": 0,
        "claim_evidence_declared": 0,
        "live_fetch_candidate_declared": 1,
    },
    {
        "weakness_id": "gpu_speedup",
        "evidence_family": "resource-speed",
        "source_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "review_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "authority_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "evidence_class": "project-source-only",
        "source_note": "Project source can describe h9 scaffolding but is not measured GPU speedup evidence",
        "official_or_public_declared": 0,
        "independent_declared": 0,
        "runner_owned_declared": 0,
        "nonfixture_declared": 0,
        "claim_evidence_declared": 0,
        "live_fetch_candidate_declared": 1,
    },
    {
        "weakness_id": "real_nlg",
        "evidence_family": "pc-routelm-nlg",
        "source_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "review_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "authority_uri": "https://github.com/betelgeuze-kang/deep-learning1",
        "evidence_class": "project-source-only",
        "source_note": "Project source can describe h11/v13 NLG diagnostics but is not a nonfixture generator transcript",
        "official_or_public_declared": 0,
        "independent_declared": 0,
        "runner_owned_declared": 0,
        "nonfixture_declared": 0,
        "claim_evidence_declared": 0,
        "live_fetch_candidate_declared": 1,
    },
]

fieldnames = [
    "run_id",
    "weakness_id",
    "evidence_family",
    "source_uri",
    "review_uri",
    "authority_uri",
    "evidence_class",
    "source_note",
    "seed_cache_uri",
    "seed_cache_hash",
    "official_or_public_declared",
    "independent_declared",
    "runner_owned_declared",
    "nonfixture_declared",
    "claim_evidence_declared",
    "live_fetch_candidate_declared",
    "routing_trigger_rate",
    "active_jump_rate",
]
for row in rows:
    path = cache_dir / f"{row['weakness_id']}.json"
    path.write_text(json.dumps(row, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    row["run_id"] = run_id
    row["seed_cache_uri"] = "file://" + str(path)
    row["seed_cache_hash"] = "sha256:" + digest
    row["routing_trigger_rate"] = "0.000000"
    row["active_jump_rate"] = "0.000000"

with seed_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
PY
fi

python3 - \
  "$PACKET_DIR" \
  "$SUMMARY_CSV" \
  "$DECISION_CSV" \
  "$SEED_CSV" \
  "$SEED_SOURCE" \
  "$LIVE_FETCH_REQUESTED" <<'PY'
import csv
import hashlib
import json
import shutil
import ssl
import sys
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import unquote
from urllib.request import Request, urlopen

packet_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
seed_csv = Path(sys.argv[4])
seed_source = sys.argv[5]
live_fetch_requested = sys.argv[6] == "1"

required_weaknesses = [
    "external_benchmark",
    "learned_chunk_ranking",
    "gpu_speedup",
    "real_nlg",
]
required_fields = [
    "run_id",
    "weakness_id",
    "evidence_family",
    "source_uri",
    "review_uri",
    "authority_uri",
    "evidence_class",
    "source_note",
    "seed_cache_uri",
    "seed_cache_hash",
    "official_or_public_declared",
    "independent_declared",
    "runner_owned_declared",
    "nonfixture_declared",
    "claim_evidence_declared",
    "live_fetch_candidate_declared",
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

def read_rows(path):
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = [field for field in required_fields if field not in (reader.fieldnames or [])]
        if missing:
            raise SystemExit(f"missing v13-l source seed columns: {','.join(missing)}")
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

def fetch_uri(receipt_dir, weakness, kind, uri):
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
                req = Request(uri, method=attempt_method, headers={"User-Agent": "betelgeuze-v13l-source-seed/1"})
                with urlopen(req, timeout=8, context=ssl.create_default_context()) as response:
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
                error = f"http-error:{exc.code}"
                break
            except URLError as exc:
                error = f"url-error:{exc.reason}"
            except Exception as exc:  # pragma: no cover - defensive receipt detail.
                error = f"fetch-error:{type(exc).__name__}:{exc}"
    receipt = {
        "artifact_scope": "v13-l-real-evidence-source-seed-gate",
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
    return int(200 <= status < 400 and https_real_uri(final_uri)), path

def status(condition):
    return "pass" if condition else "blocked"

rows = read_rows(seed_csv)
if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)
receipt_dir = packet_dir / "runtime_receipts"
if live_fetch_requested:
    receipt_dir.mkdir()

weakness_counts = {weakness: 0 for weakness in required_weaknesses}
packet_rows = []
run_id = rows[0].get("run_id", "run_001") if rows else "run_001"
cache_hash_verified_rows = 0
https_triad_rows = 0
official_benchmark_seed_rows = 0
project_source_only_rows = 0
claim_evidence_class_rows = 0
claim_evidence_declared_rows = 0
live_fetch_candidate_rows = 0
live_fetch_verified_receipts = 0
routing_sum = 0.0
jump_sum = 0.0

for row in rows:
    weakness = row.get("weakness_id", "")
    if weakness in weakness_counts:
        weakness_counts[weakness] += 1
    cache_ok = hash_matches(row.get("seed_cache_uri", ""), row.get("seed_cache_hash", ""))
    https_triad = int(
        https_real_uri(row.get("source_uri", ""))
        and https_real_uri(row.get("review_uri", ""))
        and https_real_uri(row.get("authority_uri", ""))
    )
    evidence_class = row.get("evidence_class", "")
    official_benchmark = int(
        weakness == "external_benchmark"
        and evidence_class == "official-benchmark-source-seed"
        and as_int(row, "official_or_public_declared") == 1
        and as_int(row, "independent_declared") == 1
        and as_int(row, "nonfixture_declared") == 1
    )
    project_source_only = int(evidence_class == "project-source-only")
    claim_class = int(evidence_class == "official-or-independent-claim-evidence")
    claim_declared = int(as_int(row, "claim_evidence_declared") == 1)
    live_candidate = int(as_int(row, "live_fetch_candidate_declared") == 1 and https_triad == 1)
    routing = as_float(row, "routing_trigger_rate")
    jump = as_float(row, "active_jump_rate")
    row_live_receipts = 0
    if live_fetch_requested and live_candidate:
        for kind, field in (("source", "source_uri"), ("review", "review_uri"), ("authority", "authority_uri")):
            ok, _ = fetch_uri(receipt_dir, weakness, kind, row.get(field, ""))
            row_live_receipts += ok

    cache_hash_verified_rows += cache_ok
    https_triad_rows += https_triad
    official_benchmark_seed_rows += official_benchmark
    project_source_only_rows += project_source_only
    claim_evidence_class_rows += claim_class
    claim_evidence_declared_rows += claim_declared
    live_fetch_candidate_rows += live_candidate
    live_fetch_verified_receipts += row_live_receipts
    routing_sum += routing
    jump_sum += jump

    packet_rows.append({
        "weakness_id": weakness,
        "evidence_class": evidence_class,
        "cache_hash_verified": cache_ok,
        "https_triad_ready": https_triad,
        "official_benchmark_seed_ready": official_benchmark,
        "project_source_only": project_source_only,
        "claim_evidence_class_ready": claim_class,
        "claim_evidence_declared": claim_declared,
        "live_fetch_candidate_ready": live_candidate,
        "live_fetch_verified_receipts": row_live_receipts,
        "routing_trigger_rate": f"{routing:.6f}",
        "active_jump_rate": f"{jump:.6f}",
    })

required_weakness_rows = sum(1 for weakness in required_weaknesses if weakness_counts[weakness] == 1)
duplicate_or_unknown_rows = len(rows) - sum(weakness_counts.values()) + sum(
    max(0, count - 1) for count in weakness_counts.values()
)
expected_receipts = 3 * len(required_weaknesses)
source_seed_contract_ready = int(
    len(rows) == len(required_weaknesses)
    and required_weakness_rows == len(required_weaknesses)
    and duplicate_or_unknown_rows == 0
    and cache_hash_verified_rows == len(required_weaknesses)
    and https_triad_rows == len(required_weaknesses)
    and live_fetch_candidate_rows == len(required_weaknesses)
    and abs(routing_sum) < 0.000001
    and abs(jump_sum) < 0.000001
)
live_fetch_seed_ready = int(
    live_fetch_requested
    and live_fetch_verified_receipts == expected_receipts
)
candidate_real_evidence_source_seed_ready = int(
    source_seed_contract_ready == 1
    and live_fetch_seed_ready == 1
    and claim_evidence_class_rows == len(required_weaknesses)
    and claim_evidence_declared_rows == len(required_weaknesses)
    and project_source_only_rows == 0
)
real_release_package_ready = 0

action = "v13-real-evidence-source-seed-missing"
if len(rows) != len(required_weaknesses) or required_weakness_rows != len(required_weaknesses) or duplicate_or_unknown_rows != 0:
    action = "v13-real-evidence-source-seed-required-weakness-rows-missing"
elif cache_hash_verified_rows != len(required_weaknesses):
    action = "v13-real-evidence-source-seed-cache-hash-mismatch"
elif https_triad_rows != len(required_weaknesses):
    action = "v13-real-evidence-source-seed-https-triad-incomplete"
elif live_fetch_candidate_rows != len(required_weaknesses):
    action = "v13-real-evidence-source-seed-live-fetch-candidate-incomplete"
elif abs(routing_sum) >= 0.000001 or abs(jump_sum) >= 0.000001:
    action = "v13-real-evidence-source-seed-jump-guardrail-active"
elif project_source_only_rows > 0 or claim_evidence_class_rows != len(required_weaknesses) or claim_evidence_declared_rows != len(required_weaknesses):
    action = "v13-real-evidence-source-seed-await-claim-evidence"
elif not live_fetch_requested or live_fetch_verified_receipts != expected_receipts:
    action = "v13-real-evidence-source-seed-await-runtime-fetch"
elif candidate_real_evidence_source_seed_ready == 1:
    action = "v13-real-evidence-source-seed-ready-await-rebind"

rows_csv = packet_dir / "source_seed_rows.csv"
with rows_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(packet_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(packet_rows)

manifest = {
    "artifact_scope": "v13-l-real-evidence-source-seed-gate",
    "seed_source": seed_source,
    "seed_csv": str(seed_csv),
    "live_fetch_requested": live_fetch_requested,
    "required_weaknesses": required_weaknesses,
    "claim": "separates current public source seeds from real claim evidence before runtime live fetch/rebind promotion",
}
(packet_dir / "source_seed_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

packet_hash_entries, packet_hash_verified = verify_manifest(packet_dir)
packet_hash_ready = int(packet_hash_entries > 0 and packet_hash_entries == packet_hash_verified)
source_seed_contract_ready = int(source_seed_contract_ready == 1 and packet_hash_ready == 1)
candidate_real_evidence_source_seed_ready = int(
    candidate_real_evidence_source_seed_ready == 1 and packet_hash_ready == 1
)

summary_fields = [
    "source_seed_scope",
    "seed_source",
    "run_id",
    "source_seed_packet_dir",
    "live_fetch_requested",
    "packet_hash_entries",
    "packet_hash_verified",
    "packet_hash_ready",
    "seed_rows",
    "required_weakness_rows",
    "duplicate_or_unknown_rows",
    "cache_hash_verified_rows",
    "https_triad_rows",
    "official_benchmark_seed_rows",
    "project_source_only_rows",
    "claim_evidence_class_rows",
    "claim_evidence_declared_rows",
    "live_fetch_candidate_rows",
    "live_fetch_verified_receipts",
    "expected_live_fetch_receipts",
    "source_seed_contract_ready",
    "live_fetch_seed_ready",
    "candidate_real_evidence_source_seed_ready",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "source_seed_scope": "v13-l-real-evidence-source-seed-gate",
    "seed_source": seed_source,
    "run_id": run_id,
    "source_seed_packet_dir": str(packet_dir),
    "live_fetch_requested": int(live_fetch_requested),
    "packet_hash_entries": packet_hash_entries,
    "packet_hash_verified": packet_hash_verified,
    "packet_hash_ready": packet_hash_ready,
    "seed_rows": len(rows),
    "required_weakness_rows": required_weakness_rows,
    "duplicate_or_unknown_rows": duplicate_or_unknown_rows,
    "cache_hash_verified_rows": cache_hash_verified_rows,
    "https_triad_rows": https_triad_rows,
    "official_benchmark_seed_rows": official_benchmark_seed_rows,
    "project_source_only_rows": project_source_only_rows,
    "claim_evidence_class_rows": claim_evidence_class_rows,
    "claim_evidence_declared_rows": claim_evidence_declared_rows,
    "live_fetch_candidate_rows": live_fetch_candidate_rows,
    "live_fetch_verified_receipts": live_fetch_verified_receipts,
    "expected_live_fetch_receipts": expected_receipts,
    "source_seed_contract_ready": source_seed_contract_ready,
    "live_fetch_seed_ready": live_fetch_seed_ready,
    "candidate_real_evidence_source_seed_ready": candidate_real_evidence_source_seed_ready,
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
    ("required-weakness-rows", status(required_weakness_rows == len(required_weaknesses) and duplicate_or_unknown_rows == 0), f"required={required_weakness_rows}/{len(required_weaknesses)} duplicate_or_unknown={duplicate_or_unknown_rows}"),
    ("seed-cache-hashes", status(cache_hash_verified_rows == len(required_weaknesses)), f"cache={cache_hash_verified_rows}/{len(required_weaknesses)}"),
    ("https-source-triad", status(https_triad_rows == len(required_weaknesses)), f"https={https_triad_rows}/{len(required_weaknesses)}"),
    ("external-benchmark-source-seed", status(official_benchmark_seed_rows == 1), f"official_benchmark_seed={official_benchmark_seed_rows}"),
    ("project-source-only-blocker", status(project_source_only_rows == 0), f"project_source_only={project_source_only_rows}"),
    ("claim-evidence-class", status(claim_evidence_class_rows == len(required_weaknesses) and claim_evidence_declared_rows == len(required_weaknesses)), f"claim_class={claim_evidence_class_rows}/{len(required_weaknesses)} claim_declared={claim_evidence_declared_rows}/{len(required_weaknesses)}"),
    ("runtime-live-fetch", status(live_fetch_seed_ready == 1), f"live_fetch={live_fetch_verified_receipts}/{expected_receipts} requested={int(live_fetch_requested)}"),
    ("candidate-source-seed", status(candidate_real_evidence_source_seed_ready == 1), f"candidate={candidate_real_evidence_source_seed_ready} action={action}"),
    ("v13-real-evidence-source-seed", status(real_release_package_ready == 1), f"release={real_release_package_ready}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "source_seed_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
