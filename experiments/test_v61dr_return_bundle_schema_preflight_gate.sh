#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dr_return_bundle_schema_preflight_gate"
RUN_DIR="$RESULTS_DIR/$PREFIX/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"
FIXTURE_DIR="$RESULTS_DIR/${PREFIX}_fixture/full_schema_fixture"

V61DR_REUSE_EXISTING="${V61DR_REUSE_EXISTING:-0}" "$ROOT_DIR/experiments/run_v61dr_return_bundle_schema_preflight_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" "$FIXTURE_DIR" "$ROOT_DIR" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])
fixture_dir = Path(sys.argv[4])
root = Path(sys.argv[5])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def required_fields(row):
    value = row.get("required_fields", "")
    if not value:
        return []
    return [part for part in value.split(";") if part]


summary = read_csv(summary_csv)[0]
expected_default = {
    "v61dr_return_bundle_schema_preflight_gate_ready": "1",
    "v61dq_return_schema_remediation_packet_gate_ready": "1",
    "source_gate_rows": "1",
    "return_bundle_dir_supplied": "0",
    "return_bundle_dir_exists": "0",
    "schema_preflight_artifact_rows": "81",
    "schema_preflight_pass_rows": "0",
    "schema_preflight_missing_rows": "81",
    "schema_preflight_non_empty_rows": "0",
    "schema_parse_pass_rows": "0",
    "schema_required_field_pass_rows": "0",
    "schema_row_count_pass_rows": "0",
    "schema_preflight_pass": "0",
    "schema_family_rows": "4",
    "schema_family_ready_rows": "0",
    "schema_preflight_command_rows": "5",
    "ready_schema_preflight_command_rows": "4",
    "expected_schema_artifact_rows": "81",
    "expected_payload_rows": "17483",
    "accepted_payload_rows": "0",
    "schema_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dr": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
}
for field, value in expected_default.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dr default {field}: expected {value}, got {summary.get(field)}")
if int(summary["expected_artifact_row_instances"]) <= int(summary["expected_payload_rows"]):
    raise SystemExit("v61dr expected artifact row instances should include non-payload schema rows")
if summary["observed_artifact_row_instances"] != "0":
    raise SystemExit("v61dr default observed row instances must be 0")

required_files = [
    "return_bundle_schema_preflight_artifact_rows.csv",
    "return_bundle_schema_preflight_family_rows.csv",
    "return_bundle_schema_preflight_command_rows.csv",
    "return_bundle_schema_preflight_metric_rows.csv",
    "runtime_gap_rows.csv",
    "V61DR_RETURN_BUNDLE_SCHEMA_PREFLIGHT_GATE_BOUNDARY.md",
    "VERIFY_RETURN_SCHEMA_PREFLIGHT.sh",
    "v61dr_return_bundle_schema_preflight_gate_manifest.json",
    "source_v61dq/return_schema_remediation_artifact_rows.csv",
    "sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v61dr artifact: {rel}")

artifact_rows = read_csv(run_dir / "return_bundle_schema_preflight_artifact_rows.csv")
family_rows = {row["schema_family"]: row for row in read_csv(run_dir / "return_bundle_schema_preflight_family_rows.csv")}
decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if len(artifact_rows) != 81:
    raise SystemExit("v61dr expected 81 artifact preflight rows")
if set(family_rows) != {"dispatch-receipt-json", "review-chunk-return-csv", "aggregate-review-return", "generation-result-return"}:
    raise SystemExit("v61dr family set mismatch")
if decisions.get("return-bundle-schema-preflight") != "blocked":
    raise SystemExit("v61dr default schema preflight should be blocked")
if decisions.get("downstream-row-acceptance") != "blocked":
    raise SystemExit("v61dr downstream acceptance should stay blocked")

boundary = (run_dir / "V61DR_RETURN_BUNDLE_SCHEMA_PREFLIGHT_GATE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "schema_preflight_artifact_rows=81",
    "schema_preflight_pass=0",
    "accepted_payload_rows=0",
    "schema_acceptance_ready=0",
    "actual_model_generation_ready=0",
    "Blocked wording",
]:
    if snippet not in boundary:
        raise SystemExit(f"v61dr boundary missing snippet: {snippet}")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v61dr sha256 mismatch: {rel}")

source_artifacts = read_csv(root / "results/v61dq_return_schema_remediation_packet_gate/packet_001/return_schema_remediation_artifact_rows.csv")
if fixture_dir.exists():
    shutil.rmtree(fixture_dir)
fixture_dir.mkdir(parents=True)
for row in source_artifacts:
    rel = row["artifact_path"]
    path = fixture_dir / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = required_fields(row)
    expected_rows = int(row["expected_rows"])
    if rel.endswith(".json"):
        if fields == ["json_document"]:
            payload = {
                "review_protocol_version": "fixture-v1",
                "acceptance_decision": "fixture-schema-only",
                "fixture_notice": "schema preflight fixture; not review evidence",
            }
        else:
            payload = {field: f"fixture-{field}" for field in fields}
            for count_field in [
                "expected_generation_rows",
                "accepted_answer_rows",
                "accepted_citation_rows",
                "accepted_latency_rows",
            ]:
                if count_field in payload:
                    payload[count_field] = 1000
        path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    else:
        with path.open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=fields, lineterminator="\n")
            writer.writeheader()
            for index in range(expected_rows):
                writer.writerow({field: f"{field}_{index}" for field in fields})
PY

V61DR_RETURN_BUNDLE_DIR="$FIXTURE_DIR" V61DR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dr_return_bundle_schema_preflight_gate.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary = read_csv(summary_csv)[0]
expected_fixture = {
    "return_bundle_dir_supplied": "1",
    "return_bundle_dir_exists": "1",
    "schema_preflight_artifact_rows": "81",
    "schema_preflight_pass_rows": "81",
    "schema_preflight_missing_rows": "0",
    "schema_preflight_non_empty_rows": "81",
    "schema_parse_pass_rows": "81",
    "schema_required_field_pass_rows": "81",
    "schema_row_count_pass_rows": "81",
    "schema_preflight_pass": "1",
    "schema_family_ready_rows": "4",
    "expected_payload_rows": "17483",
    "accepted_payload_rows": "0",
    "schema_acceptance_ready": "0",
    "actual_model_generation_ready": "0",
}
for field, value in expected_fixture.items():
    if summary.get(field) != value:
        raise SystemExit(f"v61dr fixture {field}: expected {value}, got {summary.get(field)}")
if summary["observed_artifact_row_instances"] != summary["expected_artifact_row_instances"]:
    raise SystemExit("v61dr fixture observed row instances mismatch")
if int(summary["observed_artifact_row_instances"]) <= int(summary["expected_payload_rows"]):
    raise SystemExit("v61dr fixture should count schema rows beyond payload acceptance rows")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
if decisions.get("return-bundle-schema-preflight") != "pass":
    raise SystemExit("v61dr fixture schema preflight should pass")
if decisions.get("downstream-row-acceptance") != "blocked":
    raise SystemExit("v61dr fixture must keep downstream acceptance blocked")
manifest = json.loads((run_dir / "v61dr_return_bundle_schema_preflight_gate_manifest.json").read_text(encoding="utf-8"))
if manifest.get("schema_preflight_pass") != 1:
    raise SystemExit("v61dr fixture manifest preflight mismatch")
if manifest.get("accepted_payload_rows") != 0:
    raise SystemExit("v61dr fixture manifest must not accept payload rows")
PY

"$RUN_DIR/VERIFY_RETURN_SCHEMA_PREFLIGHT.sh" "$FIXTURE_DIR" >/dev/null

V61DR_REUSE_EXISTING=0 "$ROOT_DIR/experiments/run_v61dr_return_bundle_schema_preflight_gate.sh" >/dev/null

python3 - "$SUMMARY_CSV" <<'PY'
import csv
import sys

with open(sys.argv[1], newline="", encoding="utf-8") as handle:
    summary = list(csv.DictReader(handle))[0]
if summary.get("return_bundle_dir_supplied") != "0":
    raise SystemExit("v61dr canonical summary was not restored to no-return")
if summary.get("schema_preflight_pass_rows") != "0":
    raise SystemExit("v61dr canonical pass rows should be 0 after restore")
if summary.get("schema_preflight_pass") != "0":
    raise SystemExit("v61dr canonical schema preflight should remain blocked")
PY

if find "$RUN_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "v61dr produced model/checkpoint payload-like files" >&2
  exit 1
fi

echo "v61dr return bundle schema preflight gate smoke passed"
