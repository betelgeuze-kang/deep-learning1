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

PREFIX="v13_real_evidence_intake_gate"
PROMOTION_PREFIX="v13_real_evidence_promotion_gate"
BINDER_PREFIX="v13_real_run_binder_manifest"
RUN_ARGS=()
if [[ "$MODE" == "smoke" ]]; then
  PREFIX="v13_real_evidence_intake_gate_smoke"
  PROMOTION_PREFIX="v13_real_evidence_promotion_gate_smoke"
  BINDER_PREFIX="v13_real_run_binder_manifest_smoke"
  RUN_ARGS=(--smoke)
elif [[ "$MODE" == "full" ]]; then
  PREFIX="v13_real_evidence_intake_gate_full"
  PROMOTION_PREFIX="v13_real_evidence_promotion_gate_full"
  BINDER_PREFIX="v13_real_run_binder_manifest_full"
  RUN_ARGS=(--full)
fi

RUN_ID="${V13_REAL_RUN_ID:-run_001}"
RUN_DIR="${V13_REAL_EVIDENCE_INTAKE_RUN_DIR:-$RESULTS_DIR/${BINDER_PREFIX}_runs/$RUN_ID}"
RUN_SOURCE="generated-diagnostic-run"
if [[ -n "${V13_REAL_EVIDENCE_INTAKE_RUN_DIR:-}" ]]; then
  RUN_SOURCE="provided-run-dir"
fi

PACKET_DIR="$RESULTS_DIR/${PREFIX}_packet/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
PROMOTION_SUMMARY_CSV="$RESULTS_DIR/${PROMOTION_PREFIX}_summary.csv"
PROMOTION_PACKET_DIR="$RESULTS_DIR/${PROMOTION_PREFIX}_packet/$RUN_ID"
INTAKE_CSV="${V13_REAL_EVIDENCE_INTAKE_CSV:-$RESULTS_DIR/${PREFIX}_intake.csv}"
INTAKE_SOURCE="generated-missing-intake"

if [[ "$RUN_SOURCE" == "generated-diagnostic-run" ]]; then
  "$ROOT_DIR/experiments/run_v13_real_evidence_promotion_gate.sh" "${RUN_ARGS[@]}" >/dev/null
else
  V13_REAL_EVIDENCE_PROMOTION_RUN_DIR="$RUN_DIR" \
    "$ROOT_DIR/experiments/run_v13_real_evidence_promotion_gate.sh" "${RUN_ARGS[@]}" >/dev/null
fi

if [[ -n "${V13_REAL_EVIDENCE_INTAKE_CSV:-}" ]]; then
  INTAKE_SOURCE="provided-intake-csv"
  if [[ ! -s "$INTAKE_CSV" ]]; then
    echo "V13_REAL_EVIDENCE_INTAKE_CSV must point to a non-empty CSV" >&2
    exit 9
  fi
else
  cat >"$INTAKE_CSV" <<CSV
run_id,weakness_id,evidence_family,source_uri,review_uri,authority_uri,cache_uri,cache_hash,nonfixture_declared,independent_declared,runner_owned_declared,official_or_public_declared,source_bound_declared,metric_ready_declared,live_network_verified,real_evidence_declared,routing_trigger_rate,active_jump_rate
$RUN_ID,external_benchmark,external-benchmark,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,0,0,0,0,0
$RUN_ID,learned_chunk_ranking,learned-scorer,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,0,0,0,0,0
$RUN_ID,gpu_speedup,resource-speed,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,0,0,0,0,0
$RUN_ID,real_nlg,pc-routelm-nlg,MISSING,MISSING,MISSING,MISSING,MISSING,0,0,0,0,0,0,0,0,0,0
CSV
fi

python3 - \
  "$RUN_DIR" \
  "$RUN_SOURCE" \
  "$PACKET_DIR" \
  "$SUMMARY_CSV" \
  "$DECISION_CSV" \
  "$PROMOTION_SUMMARY_CSV" \
  "$PROMOTION_PACKET_DIR" \
  "$INTAKE_CSV" \
  "$INTAKE_SOURCE" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path
from urllib.parse import unquote

run_dir = Path(sys.argv[1])
run_source = sys.argv[2]
packet_dir = Path(sys.argv[3])
summary_csv = Path(sys.argv[4])
decision_csv = Path(sys.argv[5])
promotion_summary_csv = Path(sys.argv[6])
promotion_packet_dir = Path(sys.argv[7])
intake_csv = Path(sys.argv[8])
intake_source = sys.argv[9]

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
    "cache_uri",
    "cache_hash",
    "nonfixture_declared",
    "independent_declared",
    "runner_owned_declared",
    "official_or_public_declared",
    "source_bound_declared",
    "metric_ready_declared",
    "live_network_verified",
    "real_evidence_declared",
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
    if not path.is_file():
        return []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        missing = [field for field in required_fields if field not in (reader.fieldnames or [])]
        if missing:
            raise SystemExit(f"missing v13-h intake columns: {','.join(missing)}")
        return list(reader)

def first_row(path):
    if not path.is_file():
        return {}
    with path.open(newline="", encoding="utf-8") as handle:
        rows = list(csv.DictReader(handle))
    return rows[0] if rows else {}

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

run_hash_entries, run_hash_verified = verify_manifest(run_dir)
run_hash_manifest_ready = int(run_hash_entries > 0 and run_hash_entries == run_hash_verified)
promotion_packet_hash_entries, promotion_packet_hash_verified = verify_manifest(promotion_packet_dir)
promotion_packet_hash_ready = int(
    promotion_packet_hash_entries > 0 and promotion_packet_hash_entries == promotion_packet_hash_verified
)
promotion = first_row(promotion_summary_csv)
diagnostic_binding_ready = as_int(promotion, "diagnostic_binding_ready")
v13_real_evidence_promotion_ready = as_int(promotion, "real_evidence_promotion_ready")

rows = read_rows(intake_csv)
weakness_counts = {weakness: 0 for weakness in required_weaknesses}
intake_rows = []
run_id_match_rows = 0
cache_hash_verified_rows = 0
https_source_rows = 0
https_review_rows = 0
https_authority_rows = 0
contract_ready_rows = 0
live_network_verified_rows = 0
real_evidence_declared_rows = 0
real_evidence_ready_rows = 0
routing_sum = 0.0
jump_sum = 0.0

for row in rows:
    weakness_id = row.get("weakness_id", "")
    if weakness_id in weakness_counts:
        weakness_counts[weakness_id] += 1
    run_id_match = int(row.get("run_id") == run_dir.name)
    cache_hash_verified = hash_matches(row.get("cache_uri", ""), row.get("cache_hash", ""))
    https_source = https_real_uri(row.get("source_uri", ""))
    https_review = https_real_uri(row.get("review_uri", ""))
    https_authority = https_real_uri(row.get("authority_uri", ""))
    live_network_verified = as_int(row, "live_network_verified")
    real_evidence_declared = as_int(row, "real_evidence_declared")
    routing = as_float(row, "routing_trigger_rate")
    jump = as_float(row, "active_jump_rate")
    flags_ready = int(
        as_int(row, "nonfixture_declared") == 1
        and as_int(row, "independent_declared") == 1
        and as_int(row, "runner_owned_declared") == 1
        and as_int(row, "official_or_public_declared") == 1
        and as_int(row, "source_bound_declared") == 1
        and as_int(row, "metric_ready_declared") == 1
    )
    contract_ready = int(
        weakness_id in required_weaknesses
        and run_id_match == 1
        and cache_hash_verified == 1
        and flags_ready == 1
        and abs(routing) < 0.000001
        and abs(jump) < 0.000001
    )
    real_evidence_ready = int(
        contract_ready == 1
        and https_source == 1
        and https_review == 1
        and https_authority == 1
        and live_network_verified == 1
        and real_evidence_declared == 1
    )

    run_id_match_rows += run_id_match
    cache_hash_verified_rows += cache_hash_verified
    https_source_rows += https_source
    https_review_rows += https_review
    https_authority_rows += https_authority
    contract_ready_rows += contract_ready
    live_network_verified_rows += live_network_verified
    real_evidence_declared_rows += real_evidence_declared
    real_evidence_ready_rows += real_evidence_ready
    routing_sum += routing
    jump_sum += jump

    intake_rows.append({
        "weakness_id": weakness_id,
        "run_id_match": run_id_match,
        "cache_hash_verified": cache_hash_verified,
        "https_source_ready": https_source,
        "https_review_ready": https_review,
        "https_authority_ready": https_authority,
        "contract_ready": contract_ready,
        "live_network_verified": live_network_verified,
        "real_evidence_declared": real_evidence_declared,
        "real_evidence_ready": real_evidence_ready,
        "routing_trigger_rate": f"{routing:.6f}",
        "active_jump_rate": f"{jump:.6f}",
    })

required_weakness_rows = sum(1 for weakness in required_weaknesses if weakness_counts[weakness] == 1)
duplicate_or_unknown_rows = len(rows) - sum(weakness_counts.values()) + sum(
    max(0, count - 1) for count in weakness_counts.values()
)
intake_schema_ready = int(len(rows) > 0 and all(field in rows[0] for field in required_fields))
real_evidence_intake_contract_ready = int(
    diagnostic_binding_ready == 1
    and run_hash_manifest_ready == 1
    and promotion_packet_hash_ready == 1
    and intake_schema_ready == 1
    and len(rows) == len(required_weaknesses)
    and required_weakness_rows == len(required_weaknesses)
    and duplicate_or_unknown_rows == 0
    and contract_ready_rows == len(required_weaknesses)
    and abs(routing_sum) < 0.000001
    and abs(jump_sum) < 0.000001
)
candidate_real_evidence_intake_ready = int(
    real_evidence_intake_contract_ready == 1
    and real_evidence_ready_rows == len(required_weaknesses)
)
real_release_package_ready = int(
    candidate_real_evidence_intake_ready == 1 and v13_real_evidence_promotion_ready == 1
)

action = "v13-real-evidence-intake-package-missing"
if run_hash_manifest_ready != 1:
    action = "v13-real-evidence-intake-run-hash-mismatch"
elif diagnostic_binding_ready != 1 or promotion_packet_hash_ready != 1:
    action = "v13-real-evidence-intake-promotion-gate-not-ready"
elif len(rows) != len(required_weaknesses) or required_weakness_rows != len(required_weaknesses) or duplicate_or_unknown_rows != 0:
    action = "v13-real-evidence-intake-required-weakness-rows-missing"
elif run_id_match_rows != len(required_weaknesses):
    action = "v13-real-evidence-intake-run-id-mismatch"
elif cache_hash_verified_rows != len(required_weaknesses):
    action = "v13-real-evidence-intake-cache-hash-mismatch"
elif contract_ready_rows != len(required_weaknesses):
    action = "v13-real-evidence-intake-contract-incomplete"
elif abs(routing_sum) >= 0.000001 or abs(jump_sum) >= 0.000001:
    action = "v13-real-evidence-intake-jump-guardrail-active"
elif real_evidence_ready_rows != len(required_weaknesses):
    action = "v13-real-evidence-intake-await-live-network-verification"
elif v13_real_evidence_promotion_ready != 1:
    action = "v13-real-evidence-intake-ready-await-bound-run-regeneration"
elif real_release_package_ready == 1:
    action = "v13-real-evidence-intake-release-ready"

if packet_dir.exists():
    shutil.rmtree(packet_dir)
packet_dir.mkdir(parents=True)

rows_csv = packet_dir / "intake_rows.csv"
fieldnames = list(intake_rows[0].keys()) if intake_rows else [
    "weakness_id",
    "run_id_match",
    "cache_hash_verified",
    "https_source_ready",
    "https_review_ready",
    "https_authority_ready",
    "contract_ready",
    "live_network_verified",
    "real_evidence_declared",
    "real_evidence_ready",
    "routing_trigger_rate",
    "active_jump_rate",
]
with rows_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
    writer.writeheader()
    writer.writerows(intake_rows)

manifest = {
    "artifact_scope": "v13-h-real-evidence-intake-gate",
    "run_source": run_source,
    "run_dir": str(run_dir),
    "promotion_packet_dir": str(promotion_packet_dir),
    "intake_csv": str(intake_csv),
    "required_weaknesses": required_weaknesses,
    "claim": "validates the same-run intake package required before real benchmark/scorer/NLG/speed evidence can be rebound and promoted",
}
(packet_dir / "intake_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

with (packet_dir / "sha256sums.txt").open("w", encoding="utf-8") as handle:
    for path in sorted(packet_dir.rglob("*")):
        if path.is_file() and path.name != "sha256sums.txt":
            handle.write(f"{sha256(path)}  {path.relative_to(packet_dir)}\n")

intake_packet_hash_entries, intake_packet_hash_verified = verify_manifest(packet_dir)
intake_packet_hash_ready = int(
    intake_packet_hash_entries > 0 and intake_packet_hash_entries == intake_packet_hash_verified
)
real_evidence_intake_contract_ready = int(real_evidence_intake_contract_ready == 1 and intake_packet_hash_ready == 1)
candidate_real_evidence_intake_ready = int(candidate_real_evidence_intake_ready == 1 and intake_packet_hash_ready == 1)
real_release_package_ready = int(real_release_package_ready == 1 and intake_packet_hash_ready == 1)

summary_fields = [
    "intake_scope",
    "intake_source",
    "run_source",
    "run_id",
    "run_dir",
    "intake_packet_dir",
    "run_hash_entries",
    "run_hash_verified",
    "run_hash_manifest_ready",
    "promotion_packet_hash_entries",
    "promotion_packet_hash_verified",
    "promotion_packet_hash_ready",
    "intake_packet_hash_entries",
    "intake_packet_hash_verified",
    "intake_packet_hash_ready",
    "diagnostic_binding_ready",
    "v13_real_evidence_promotion_ready",
    "intake_rows",
    "required_weakness_rows",
    "duplicate_or_unknown_rows",
    "run_id_match_rows",
    "cache_hash_verified_rows",
    "https_source_rows",
    "https_review_rows",
    "https_authority_rows",
    "contract_ready_rows",
    "live_network_verified_rows",
    "real_evidence_declared_rows",
    "real_evidence_ready_rows",
    "real_evidence_intake_contract_ready",
    "candidate_real_evidence_intake_ready",
    "real_release_package_ready",
    "action",
    "routing_trigger_rate",
    "active_jump_rate",
]
summary_row = {
    "intake_scope": "v13-h-real-evidence-intake-gate",
    "intake_source": intake_source,
    "run_source": run_source,
    "run_id": run_dir.name,
    "run_dir": str(run_dir),
    "intake_packet_dir": str(packet_dir),
    "run_hash_entries": run_hash_entries,
    "run_hash_verified": run_hash_verified,
    "run_hash_manifest_ready": run_hash_manifest_ready,
    "promotion_packet_hash_entries": promotion_packet_hash_entries,
    "promotion_packet_hash_verified": promotion_packet_hash_verified,
    "promotion_packet_hash_ready": promotion_packet_hash_ready,
    "intake_packet_hash_entries": intake_packet_hash_entries,
    "intake_packet_hash_verified": intake_packet_hash_verified,
    "intake_packet_hash_ready": intake_packet_hash_ready,
    "diagnostic_binding_ready": diagnostic_binding_ready,
    "v13_real_evidence_promotion_ready": v13_real_evidence_promotion_ready,
    "intake_rows": len(rows),
    "required_weakness_rows": required_weakness_rows,
    "duplicate_or_unknown_rows": duplicate_or_unknown_rows,
    "run_id_match_rows": run_id_match_rows,
    "cache_hash_verified_rows": cache_hash_verified_rows,
    "https_source_rows": https_source_rows,
    "https_review_rows": https_review_rows,
    "https_authority_rows": https_authority_rows,
    "contract_ready_rows": contract_ready_rows,
    "live_network_verified_rows": live_network_verified_rows,
    "real_evidence_declared_rows": real_evidence_declared_rows,
    "real_evidence_ready_rows": real_evidence_ready_rows,
    "real_evidence_intake_contract_ready": real_evidence_intake_contract_ready,
    "candidate_real_evidence_intake_ready": candidate_real_evidence_intake_ready,
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
    ("promotion-gate-binding", status(diagnostic_binding_ready == 1 and promotion_packet_hash_ready == 1), f"diagnostic={diagnostic_binding_ready} promotion_packet_hash={promotion_packet_hash_ready}"),
    ("required-weakness-rows", status(required_weakness_rows == len(required_weaknesses) and duplicate_or_unknown_rows == 0), f"required={required_weakness_rows}/{len(required_weaknesses)} duplicate_or_unknown={duplicate_or_unknown_rows}"),
    ("run-id-binding", status(run_id_match_rows == len(required_weaknesses)), f"run_id_match={run_id_match_rows}/{len(required_weaknesses)}"),
    ("cache-hash-binding", status(cache_hash_verified_rows == len(required_weaknesses)), f"cache_hash={cache_hash_verified_rows}/{len(required_weaknesses)}"),
    ("contract-flags", status(contract_ready_rows == len(required_weaknesses)), f"contract_ready={contract_ready_rows}/{len(required_weaknesses)}"),
    ("https-authority-chain", status(https_source_rows == len(required_weaknesses) and https_review_rows == len(required_weaknesses) and https_authority_rows == len(required_weaknesses)), f"source={https_source_rows} review={https_review_rows} authority={https_authority_rows}"),
    ("live-network-verification", status(live_network_verified_rows == len(required_weaknesses)), f"live={live_network_verified_rows}/{len(required_weaknesses)}"),
    ("candidate-real-intake", status(candidate_real_evidence_intake_ready == 1), f"candidate={candidate_real_evidence_intake_ready} real_rows={real_evidence_ready_rows}/{len(required_weaknesses)}"),
    ("v13-real-evidence-intake", status(real_release_package_ready == 1), f"release={real_release_package_ready} action={action}"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)
PY

echo "intake_packet_dir: $PACKET_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
