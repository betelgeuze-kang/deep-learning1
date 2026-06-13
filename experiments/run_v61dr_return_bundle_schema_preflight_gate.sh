#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dr_return_bundle_schema_preflight_gate"
RUN_ID="${V61DR_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
RETURN_BUNDLE_DIR="${V61DR_RETURN_BUNDLE_DIR:-}"

if [[ "${V61DR_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dr_return_bundle_schema_preflight_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DQ_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61dq_return_schema_remediation_packet_gate.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$RETURN_BUNDLE_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
return_bundle_arg = sys.argv[5]
return_bundle_dir = Path(return_bundle_arg).expanduser().resolve() if return_bundle_arg else None
results = root / "results"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def as_int(row, key):
    return int(row.get(key, "0") or "0")


def flag(value):
    return "1" if value else "0"


def required_fields(row):
    value = row.get("required_fields", "")
    if not value:
        return []
    return [part for part in value.split(";") if part]


sources = {
    "v61dq_summary": results / "v61dq_return_schema_remediation_packet_gate_summary.csv",
    "v61dq_decision": results / "v61dq_return_schema_remediation_packet_gate_decision.csv",
    "v61dq_artifacts": results / "v61dq_return_schema_remediation_packet_gate/packet_001/return_schema_remediation_artifact_rows.csv",
    "v61dq_families": results / "v61dq_return_schema_remediation_packet_gate/packet_001/return_schema_remediation_family_rows.csv",
    "v61dq_commands": results / "v61dq_return_schema_remediation_packet_gate/packet_001/return_schema_remediation_command_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dr source {key}: {path}")

copy(sources["v61dq_summary"], "source_v61dq/v61dq_return_schema_remediation_packet_gate_summary.csv")
copy(sources["v61dq_decision"], "source_v61dq/v61dq_return_schema_remediation_packet_gate_decision.csv")
copy(sources["v61dq_artifacts"], "source_v61dq/return_schema_remediation_artifact_rows.csv")
copy(sources["v61dq_families"], "source_v61dq/return_schema_remediation_family_rows.csv")
copy(sources["v61dq_commands"], "source_v61dq/return_schema_remediation_command_rows.csv")

v61dq = read_csv(sources["v61dq_summary"])[0]
artifact_contracts = read_csv(sources["v61dq_artifacts"])
source_family_rows = {row["schema_family"]: row for row in read_csv(sources["v61dq_families"])}
source_command_rows = read_csv(sources["v61dq_commands"])

if v61dq.get("v61dq_return_schema_remediation_packet_gate_ready") != "1":
    raise SystemExit("v61dr requires v61dq ready")

return_bundle_exists = return_bundle_dir is not None and return_bundle_dir.is_dir()
artifact_rows = []
for contract in artifact_contracts:
    rel_path = contract["artifact_path"]
    artifact_path = return_bundle_dir / rel_path if return_bundle_exists else None
    exists = artifact_path.is_file() if artifact_path else False
    non_empty = exists and artifact_path.stat().st_size > 0
    suffix = Path(rel_path).suffix
    expected_rows = as_int(contract, "expected_rows")
    fields = required_fields(contract)
    observed_rows = 0
    parse_pass = False
    field_pass = False
    row_count_pass = False
    failure_reason = "return bundle directory not supplied" if return_bundle_dir is None else "artifact missing"

    if exists and non_empty:
        if suffix == ".json":
            try:
                payload = json.loads(artifact_path.read_text(encoding="utf-8"))
                parse_pass = isinstance(payload, dict)
                observed_rows = 1 if parse_pass else 0
                if fields == ["json_document"]:
                    field_pass = parse_pass
                else:
                    field_pass = parse_pass and all(field in payload for field in fields)
                row_count_pass = parse_pass and expected_rows == observed_rows
                failure_reason = "ready" if field_pass and row_count_pass else "json required fields or row count mismatch"
            except Exception as exc:  # noqa: BLE001 - script should surface parse detail in CSV.
                failure_reason = f"json parse failed: {exc}"
        elif suffix == ".csv":
            try:
                with artifact_path.open(newline="", encoding="utf-8") as handle:
                    reader = csv.DictReader(handle)
                    csv_rows = list(reader)
                    header = reader.fieldnames or []
                parse_pass = bool(header)
                observed_rows = len(csv_rows)
                field_pass = parse_pass and all(field in header for field in fields)
                row_count_pass = parse_pass and observed_rows == expected_rows
                failure_reason = "ready" if field_pass and row_count_pass else "csv header or row count mismatch"
            except Exception as exc:  # noqa: BLE001
                failure_reason = f"csv parse failed: {exc}"
        else:
            failure_reason = f"unsupported artifact suffix: {suffix}"

    artifact_pass = exists and non_empty and parse_pass and field_pass and row_count_pass
    artifact_rows.append(
        {
            "schema_family": contract["schema_family"],
            "artifact_path": rel_path,
            "artifact_name": contract["artifact_name"],
            "expected_rows": str(expected_rows),
            "observed_rows": str(observed_rows),
            "required_field_count": contract["required_field_count"],
            "required_fields": contract["required_fields"],
            "artifact_exists": flag(exists),
            "artifact_non_empty": flag(non_empty),
            "parse_pass": flag(parse_pass),
            "required_field_pass": flag(field_pass),
            "row_count_pass": flag(row_count_pass),
            "schema_preflight_pass": flag(artifact_pass),
            "failure_reason": failure_reason,
        }
    )
write_csv(run_dir / "return_bundle_schema_preflight_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

family_rows = []
for family in ["dispatch-receipt-json", "review-chunk-return-csv", "aggregate-review-return", "generation-result-return"]:
    related = [row for row in artifact_rows if row["schema_family"] == family]
    source = source_family_rows[family]
    pass_rows = sum(row["schema_preflight_pass"] == "1" for row in related)
    exists_rows = sum(row["artifact_exists"] == "1" for row in related)
    non_empty_rows = sum(row["artifact_non_empty"] == "1" for row in related)
    parse_rows = sum(row["parse_pass"] == "1" for row in related)
    field_rows = sum(row["required_field_pass"] == "1" for row in related)
    count_rows = sum(row["row_count_pass"] == "1" for row in related)
    family_rows.append(
        {
            "schema_family": family,
            "expected_artifact_rows": str(len(related)),
            "present_artifact_rows": str(exists_rows),
            "non_empty_artifact_rows": str(non_empty_rows),
            "parse_pass_artifact_rows": str(parse_rows),
            "required_field_pass_artifact_rows": str(field_rows),
            "row_count_pass_artifact_rows": str(count_rows),
            "schema_preflight_pass_artifact_rows": str(pass_rows),
            "schema_preflight_missing_artifact_rows": str(len(related) - exists_rows),
            "expected_row_instances": str(sum(as_int(row, "expected_rows") for row in related)),
            "observed_row_instances": str(sum(as_int(row, "observed_rows") for row in related)),
            "accepted_payload_rows": source["accepted_payload_rows"],
            "validator_gate": source["validator_gate"],
            "schema_preflight_ready": flag(pass_rows == len(related)),
            "acceptance_ready": source["acceptance_ready"],
        }
    )
write_csv(run_dir / "return_bundle_schema_preflight_family_rows.csv", list(family_rows[0].keys()), family_rows)

command_rows = [
    {
        "command_id": "00-run-schema-preflight",
        "ready_to_run_now": "1",
        "command": "V61DR_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V61DR_REUSE_EXISTING=0 ./experiments/run_v61dr_return_bundle_schema_preflight_gate.sh",
        "expected_transition": "schema_preflight_pass=1 before downstream intake",
    }
]
for row in source_command_rows:
    command_rows.append(row)
write_csv(run_dir / "return_bundle_schema_preflight_command_rows.csv", list(command_rows[0].keys()), command_rows)

preflight_pass_rows = sum(row["schema_preflight_pass"] == "1" for row in artifact_rows)
present_rows = sum(row["artifact_exists"] == "1" for row in artifact_rows)
non_empty_rows = sum(row["artifact_non_empty"] == "1" for row in artifact_rows)
parse_rows = sum(row["parse_pass"] == "1" for row in artifact_rows)
field_rows = sum(row["required_field_pass"] == "1" for row in artifact_rows)
row_count_rows = sum(row["row_count_pass"] == "1" for row in artifact_rows)
expected_row_instances = sum(as_int(row, "expected_rows") for row in artifact_rows)
observed_row_instances = sum(as_int(row, "observed_rows") for row in artifact_rows)
schema_preflight_pass = preflight_pass_rows == len(artifact_rows)
expected_payload_rows = as_int(v61dq, "expected_payload_rows")

metric = {
    "metric_id": "v61dr_return_bundle_schema_preflight_gate_metrics",
    "v61dq_return_schema_remediation_packet_gate_ready": v61dq["v61dq_return_schema_remediation_packet_gate_ready"],
    "source_gate_rows": "1",
    "return_bundle_dir_supplied": flag(return_bundle_dir is not None),
    "return_bundle_dir_exists": flag(return_bundle_exists),
    "schema_preflight_artifact_rows": str(len(artifact_rows)),
    "schema_preflight_pass_rows": str(preflight_pass_rows),
    "schema_preflight_missing_rows": str(len(artifact_rows) - present_rows),
    "schema_preflight_non_empty_rows": str(non_empty_rows),
    "schema_parse_pass_rows": str(parse_rows),
    "schema_required_field_pass_rows": str(field_rows),
    "schema_row_count_pass_rows": str(row_count_rows),
    "schema_preflight_pass": flag(schema_preflight_pass),
    "schema_family_rows": str(len(family_rows)),
    "schema_family_ready_rows": str(sum(row["schema_preflight_ready"] == "1" for row in family_rows)),
    "schema_preflight_command_rows": str(len(command_rows)),
    "ready_schema_preflight_command_rows": str(sum(row["ready_to_run_now"] == "1" for row in command_rows)),
    "expected_schema_artifact_rows": str(as_int(v61dq, "expected_schema_artifact_rows")),
    "expected_artifact_row_instances": str(expected_row_instances),
    "observed_artifact_row_instances": str(observed_row_instances),
    "expected_payload_rows": str(expected_payload_rows),
    "accepted_payload_rows": "0",
    "schema_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dr": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_bundle_schema_preflight_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dr_return_bundle_schema_preflight_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "schema-preflight-surface", "status": "pass", "reason": f"schema_preflight_artifact_rows={len(artifact_rows)}"},
    {
        "gate": "return-bundle-schema-preflight",
        "status": "pass" if schema_preflight_pass else "blocked",
        "reason": f"schema_preflight_pass_rows={preflight_pass_rows}/{len(artifact_rows)}",
    },
    {"gate": "downstream-row-acceptance", "status": "blocked", "reason": f"accepted_payload_rows=0/{expected_payload_rows}"},
    {"gate": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

runtime_gap_rows = [
    {"gap": "schema-preflight-surface", "status": "ready", "reason": f"schema_preflight_artifact_rows={len(artifact_rows)}"},
    {
        "gap": "return-bundle-schema-preflight",
        "status": "ready" if schema_preflight_pass else "blocked",
        "reason": f"schema_preflight_pass_rows={preflight_pass_rows}/{len(artifact_rows)}",
    },
    {"gap": "downstream-row-acceptance", "status": "blocked", "reason": f"accepted_payload_rows=0/{expected_payload_rows}"},
    {"gap": "actual-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

boundary = f"""# v61dr Return Bundle Schema Preflight Gate

This gate validates a supplied final return bundle against the v61dq remediation
artifact schema before downstream intake. It checks file presence, non-empty
payloads, CSV headers, JSON required fields, and artifact-level row counts.

Evidence emitted:

- return_bundle_dir_supplied={metric['return_bundle_dir_supplied']}
- return_bundle_dir_exists={metric['return_bundle_dir_exists']}
- schema_preflight_artifact_rows={len(artifact_rows)}
- schema_preflight_pass_rows={preflight_pass_rows}
- schema_preflight_pass={metric['schema_preflight_pass']}
- schema_family_ready_rows={metric['schema_family_ready_rows']}
- expected_artifact_row_instances={expected_row_instances}
- observed_artifact_row_instances={observed_row_instances}
- expected_payload_rows={expected_payload_rows}
- accepted_payload_rows=0
- schema_acceptance_ready=0
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61dr=0

Allowed wording: return bundle schema preflight is available, and a supplied
bundle may pass this pre-submit schema check.

Blocked wording: downstream review acceptance, generation result acceptance,
actual generation, latency, near-frontier quality, v1.0 comparison, or release
readiness.
"""
(run_dir / "V61DR_RETURN_BUNDLE_SCHEMA_PREFLIGHT_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

verifier = run_dir / "VERIFY_RETURN_SCHEMA_PREFLIGHT.sh"
verifier.write_text(
    f"""#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/final_return_bundle" >&2
  exit 2
fi

ROOT_DIR="$(cd "$(dirname "${{BASH_SOURCE[0]}}")/../../.." && pwd)"
RUN_ID="verify_$$"
V61DR_RUN_ID="$RUN_ID" V61DR_RETURN_BUNDLE_DIR="$1" V61DR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dr_return_bundle_schema_preflight_gate.sh" >/dev/null

python3 - "$ROOT_DIR/results/v61dr_return_bundle_schema_preflight_gate_summary.csv" <<'PYVERIFY'
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as handle:
    summary = list(csv.DictReader(handle))[0]

if summary.get("schema_preflight_pass") != "1":
    raise SystemExit("schema preflight failed")
print("v61dr return bundle schema preflight passed")
PYVERIFY
""",
    encoding="utf-8",
)
verifier.chmod(0o755)

manifest = {
    "manifest_scope": "v61dr-return-bundle-schema-preflight-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dr_return_bundle_schema_preflight_gate_ready": 1,
    "return_bundle_dir_supplied": as_int(metric, "return_bundle_dir_supplied"),
    "schema_preflight_artifact_rows": len(artifact_rows),
    "schema_preflight_pass_rows": preflight_pass_rows,
    "schema_preflight_pass": as_int(metric, "schema_preflight_pass"),
    "expected_artifact_row_instances": expected_row_instances,
    "observed_artifact_row_instances": observed_row_instances,
    "accepted_payload_rows": 0,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dr_return_bundle_schema_preflight_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61dr_return_bundle_schema_preflight_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
