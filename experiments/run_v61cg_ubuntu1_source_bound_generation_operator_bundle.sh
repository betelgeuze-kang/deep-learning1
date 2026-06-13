#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61cg_ubuntu1_source_bound_generation_operator_bundle"
RUN_ID="${V61CG_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61CG_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61cg_ubuntu1_source_bound_generation_operator_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61CF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61cf_ubuntu1_source_bound_generation_execution_packet.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import os
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"
model_id = "mistralai/Mixtral-8x22B-v0.1"


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)


def status(flag):
    return "pass" if flag else "blocked"


v61cf_dir = results / "v61cf_ubuntu1_source_bound_generation_execution_packet" / "packet_001"
v61cf_summary_path = results / "v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"
v61cf_decision_path = results / "v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv"
v61cf = read_csv(v61cf_summary_path)[0]
if v61cf.get("v61cf_ubuntu1_source_bound_generation_execution_packet_ready") != "1":
    raise SystemExit("v61cg requires v61cf_ubuntu1_source_bound_generation_execution_packet_ready=1")

for src, rel in [
    (v61cf_summary_path, "source_v61cf/v61cf_ubuntu1_source_bound_generation_execution_packet_summary.csv"),
    (v61cf_decision_path, "source_v61cf/v61cf_ubuntu1_source_bound_generation_execution_packet_decision.csv"),
    (v61cf_dir / "source_bound_generation_execution_packet_rows.csv", "source_v61cf/source_bound_generation_execution_packet_rows.csv"),
    (v61cf_dir / "source_bound_generation_prompt_manifest_rows.csv", "source_v61cf/source_bound_generation_prompt_manifest_rows.csv"),
    (v61cf_dir / "source_bound_generation_return_manifest_rows.csv", "source_v61cf/source_bound_generation_return_manifest_rows.csv"),
    (v61cf_dir / "source_bound_generation_operator_command_rows.csv", "source_v61cf/source_bound_generation_operator_command_rows.csv"),
    (v61cf_dir / "source_bound_generation_execution_requirement_rows.csv", "source_v61cf/source_bound_generation_execution_requirement_rows.csv"),
    (v61cf_dir / "runtime_gap_rows.csv", "source_v61cf/runtime_gap_rows.csv"),
    (v61cf_dir / "sha256_manifest.csv", "source_v61cf/sha256_manifest.csv"),
]:
    copy(src, rel)

packet_rows = read_csv(v61cf_dir / "source_bound_generation_execution_packet_rows.csv")
prompt_rows = read_csv(v61cf_dir / "source_bound_generation_prompt_manifest_rows.csv")
return_rows = read_csv(v61cf_dir / "source_bound_generation_return_manifest_rows.csv")
carried_command_rows = read_csv(v61cf_dir / "source_bound_generation_operator_command_rows.csv")
if len(packet_rows) != 1000:
    raise SystemExit("v61cg expects 1000 v61cf execution packet rows")
if len(prompt_rows) != 4:
    raise SystemExit("v61cg expects 4 v61cf prompt manifest rows")
if len(return_rows) != 5:
    raise SystemExit("v61cg expects 5 v61cf return manifest rows")
if len(carried_command_rows) != 6:
    raise SystemExit("v61cg expects 6 v61cf operator command rows")

target_root = v61cf["target_root_path"]
execution_ready = int(v61cf["generation_execution_ready"])
execution_admitted_rows = int(v61cf["generation_execution_admitted_rows"])
blocked_execution_rows = int(v61cf["blocked_execution_rows"])
page_hash_closure_ready = int(v61cf["page_hash_closure_ready"])
review_return_closure_ready = int(v61cf["review_return_closure_ready"])
generation_result_closure_ready = int(v61cf["generation_result_closure_ready"])
operator_bundle_handoff_ready = 1
generation_operator_execution_ready = int(execution_ready and execution_admitted_rows == len(packet_rows))

operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)

(operator_dir / "README.md").write_text(
    "# v61cg Source-Bound Generation Operator Bundle\n\n"
    "This bundle packages the v61cf execution packet for an operator-side real "
    "model generation run. It is a handoff contract only: do not copy checkpoint "
    "payload bytes into the repository, and do not claim actual generation until "
    "the returned artifacts pass v61bt/v61cc/v61ce intake.\n\n"
    "Required external inputs before execution:\n\n"
    "- completed full safetensors page-hash coverage\n"
    "- accepted complete-source human/source review return\n"
    "- external checkpoint root matching the target path in the packet\n"
    "- returned v61bt generation artifacts listed in RETURN_MANIFEST_TEMPLATE.csv\n",
    encoding="utf-8",
)

return_template_rows = [
    {
        "return_artifact": row["return_artifact"],
        "artifact_type": row["artifact_type"],
        "required": row["required"],
        "expected_rows": row["expected_rows"],
        "operator_status": "pending",
        "artifact_sha256": "",
        "notes": row["purpose"],
    }
    for row in return_rows
]
write_csv(operator_dir / "RETURN_MANIFEST_TEMPLATE.csv", list(return_template_rows[0].keys()), return_template_rows)

(operator_dir / "GENERATION_RETURN_CHECKLIST.md").write_text(
    "# Generation Return Checklist\n\n"
    "- Verify `source_bound_generation_execution_packet_rows.csv` has 1000 rows.\n"
    "- Run generation only after v61ce reports `generation_execution_ready=1`.\n"
    "- Return the five artifacts listed in `RETURN_MANIFEST_TEMPLATE.csv`.\n"
    "- Run v61bt result intake with `V61BT_GENERATION_RESULT_DIR` pointing to the returned artifact directory.\n"
    "- Re-run v61cc and v61ce after v61bt accepts the returned artifacts.\n",
    encoding="utf-8",
)

verify_script = operator_dir / "VERIFY_EXECUTION_PACKET.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKET_ROWS="$BUNDLE_DIR/source_v61cf/source_bound_generation_execution_packet_rows.csv"
PROMPT_ROWS="$BUNDLE_DIR/source_v61cf/source_bound_generation_prompt_manifest_rows.csv"
RETURN_ROWS="$BUNDLE_DIR/source_v61cf/source_bound_generation_return_manifest_rows.csv"
TEMPLATE_ROWS="$BUNDLE_DIR/operator_bundle/RETURN_MANIFEST_TEMPLATE.csv"

for path in "$PACKET_ROWS" "$PROMPT_ROWS" "$RETURN_ROWS" "$TEMPLATE_ROWS"; do
  if [[ ! -s "$path" ]]; then
    echo "missing required v61cg operator bundle file: $path" >&2
    exit 1
  fi
done

packet_line_count="$(wc -l < "$PACKET_ROWS" | tr -d ' ')"
prompt_line_count="$(wc -l < "$PROMPT_ROWS" | tr -d ' ')"
return_line_count="$(wc -l < "$RETURN_ROWS" | tr -d ' ')"
template_line_count="$(wc -l < "$TEMPLATE_ROWS" | tr -d ' ')"

[[ "$packet_line_count" == "1001" ]] || { echo "expected 1000 packet rows" >&2; exit 1; }
[[ "$prompt_line_count" == "5" ]] || { echo "expected 4 prompt rows" >&2; exit 1; }
[[ "$return_line_count" == "6" ]] || { echo "expected 5 return rows" >&2; exit 1; }
[[ "$template_line_count" == "6" ]] || { echo "expected 5 return template rows" >&2; exit 1; }

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "checkpoint payload-like file found inside operator bundle" >&2
  exit 1
fi

echo "v61cg execution packet bundle shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

bundle_file_rows = [
    ("operator_bundle/README.md", "operator instructions", "1"),
    ("operator_bundle/RETURN_MANIFEST_TEMPLATE.csv", "generation return manifest template", "1"),
    ("operator_bundle/GENERATION_RETURN_CHECKLIST.md", "return checklist", "1"),
    ("operator_bundle/VERIFY_EXECUTION_PACKET.sh", "shape verifier", "1"),
]
bundle_file_dicts = [
    {
        "bundle_file": rel,
        "purpose": purpose,
        "required": required,
        "file_ready": "1",
        "checkpoint_payload_bytes_committed_to_repo": "0",
    }
    for rel, purpose, required in bundle_file_rows
]
write_csv(run_dir / "source_bound_generation_operator_bundle_file_rows.csv", list(bundle_file_dicts[0].keys()), bundle_file_dicts)

bundle_command_rows = [
    {
        "command_id": "verify-operator-bundle-shape",
        "command": "results/v61cg_ubuntu1_source_bound_generation_operator_bundle/bundle_001/operator_bundle/VERIFY_EXECUTION_PACKET.sh",
        "purpose": "verify packet, prompt, and return manifest shape before handoff",
        "execution_ready": "1",
    },
    {
        "command_id": "refresh-source-bound-execution-packet",
        "command": "V61CF_REUSE_EXISTING=0 ./experiments/run_v61cf_ubuntu1_source_bound_generation_execution_packet.sh",
        "purpose": "refresh packet after closure states change",
        "execution_ready": "0",
    },
    {
        "command_id": "operator-run-real-generation",
        "command": "V61CF_PACKET_DIR=results/v61cf_ubuntu1_source_bound_generation_execution_packet/packet_001 V61BT_GENERATION_RESULT_DIR=$V61BT_GENERATION_RESULT_DIR ./operator/run_source_bound_generation.sh",
        "purpose": "operator-side generation run, intentionally external to this repository",
        "execution_ready": "0",
    },
    {
        "command_id": "intake-generation-return",
        "command": "V61BT_REUSE_EXISTING=0 V61BT_GENERATION_RESULT_DIR=$V61BT_GENERATION_RESULT_DIR ./experiments/run_v61bt_ubuntu1_actual_generation_result_intake.sh",
        "purpose": "accept returned generation artifacts after an external run",
        "execution_ready": "0",
    },
]
write_csv(run_dir / "source_bound_generation_operator_bundle_command_rows.csv", list(bundle_command_rows[0].keys()), bundle_command_rows)

requirement_rows = [
    {
        "requirement_id": "v61cf-execution-packet-input",
        "required_value": "v61cf ready",
        "actual_value": v61cf["v61cf_ubuntu1_source_bound_generation_execution_packet_ready"],
        "status": "pass",
        "reason": "v61cf packet evidence is bound",
    },
    {
        "requirement_id": "operator-bundle-shape",
        "required_value": "4 bundle files",
        "actual_value": str(len(bundle_file_dicts)),
        "status": "pass",
        "reason": "operator README, return template, checklist, and verifier are present",
    },
    {
        "requirement_id": "source-bound-generation-execution-ready",
        "required_value": "1",
        "actual_value": str(execution_ready),
        "status": status(execution_ready),
        "reason": f"blocked_execution_rows={blocked_execution_rows}",
    },
    {
        "requirement_id": "full-page-hash-closure",
        "required_value": "1",
        "actual_value": str(page_hash_closure_ready),
        "status": status(page_hash_closure_ready),
        "reason": "v61cg inherits the v61cf/v61ce full page-hash closure",
    },
    {
        "requirement_id": "complete-source-review-return",
        "required_value": "1",
        "actual_value": str(review_return_closure_ready),
        "status": status(review_return_closure_ready),
        "reason": "operator generation execution waits for accepted review/adjudication returns",
    },
    {
        "requirement_id": "actual-generation-result-return",
        "required_value": "1",
        "actual_value": str(generation_result_closure_ready),
        "status": status(generation_result_closure_ready),
        "reason": "operator generation execution still needs returned generation artifacts",
    },
    {
        "requirement_id": "operator-generation-execution-ready",
        "required_value": "1000 admitted rows",
        "actual_value": str(execution_admitted_rows),
        "status": status(generation_operator_execution_ready),
        "reason": "operator execution waits for v61cf/v61ce admission",
    },
    {
        "requirement_id": "manifest-only-no-repo-payload",
        "required_value": "0",
        "actual_value": "0",
        "status": "pass",
        "reason": "v61cg writes operator metadata and hashes only",
    },
]
write_csv(run_dir / "source_bound_generation_operator_bundle_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

metric = {
    "metric_id": "v61cg_ubuntu1_source_bound_generation_operator_bundle_metrics",
    "model_id": model_id,
    "target_root_path": target_root,
    "execution_packet_rows": v61cf["execution_packet_rows"],
    "prompt_manifest_rows": v61cf["prompt_manifest_rows"],
    "return_manifest_rows": v61cf["return_manifest_rows"],
    "carried_operator_command_rows": v61cf["operator_command_rows"],
    "bundle_operator_command_rows": str(len(bundle_command_rows)),
    "total_operator_command_rows": str(len(carried_command_rows) + len(bundle_command_rows)),
    "operator_bundle_file_rows": str(len(bundle_file_dicts)),
    "complete_source_query_rows": v61cf["complete_source_query_rows"],
    "expected_generation_result_artifacts": v61cf["expected_generation_result_artifacts"],
    "generation_closure_return_intake_ready": v61cf["generation_closure_return_intake_ready"],
    "generation_execution_admission_ready": v61cf["generation_execution_admission_ready"],
    "generation_execution_ready": v61cf["generation_execution_ready"],
    "generation_execution_admitted_rows": v61cf["generation_execution_admitted_rows"],
    "blocked_execution_rows": v61cf["blocked_execution_rows"],
    "page_hash_closure_ready": str(page_hash_closure_ready),
    "review_return_closure_ready": str(review_return_closure_ready),
    "generation_result_closure_ready": str(generation_result_closure_ready),
    "operator_bundle_handoff_ready": str(operator_bundle_handoff_ready),
    "generation_operator_execution_ready": str(generation_operator_execution_ready),
    "actual_model_generation_ready": "0",
    "source_bound_qa_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61cg": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "source_bound_generation_operator_bundle_metric_rows.csv", list(metric.keys()), [metric])

runtime_gap_rows = [
    ("v61cf-execution-packet-input", "ready", "v61cf packet is bound"),
    ("operator-bundle-shape", "ready", "operator bundle files are present"),
    ("full-page-hash-closure", "ready" if page_hash_closure_ready else "blocked", f"page_hash_closure_ready={page_hash_closure_ready}"),
    ("complete-source-review-return", status(review_return_closure_ready), f"review_return_closure_ready={review_return_closure_ready}"),
    ("actual-generation-result-return", status(generation_result_closure_ready), f"generation_result_closure_ready={generation_result_closure_ready}"),
    ("source-bound-generation-execution", status(execution_ready), f"blocked_execution_rows={blocked_execution_rows}"),
    ("actual-model-generation", "blocked", "operator bundle is not an executed generation run"),
    ("production-latency", "blocked", "not a production latency run"),
    ("near-frontier-quality", "blocked", "not an external quality review"),
    ("release-package", "blocked", "not release evidence"),
]
write_csv(
    run_dir / "runtime_gap_rows.csv",
    ["gap", "status", "reason"],
    [{"gap": gap, "status": state, "reason": reason} for gap, state, reason in runtime_gap_rows],
)

boundary = f"""# v61cg Ubuntu-1 Source-Bound Generation Operator Bundle Boundary

This bundle wraps the v61cf execution packet for operator handoff. It verifies
packet shape and return-manifest shape, but does not execute the model and does
not copy checkpoint payload bytes into the repository.

Current state:

- execution_packet_rows={v61cf['execution_packet_rows']}
- prompt_manifest_rows={v61cf['prompt_manifest_rows']}
- return_manifest_rows={v61cf['return_manifest_rows']}
- carried_operator_command_rows={v61cf['operator_command_rows']}
- bundle_operator_command_rows={len(bundle_command_rows)}
- total_operator_command_rows={len(carried_command_rows) + len(bundle_command_rows)}
- operator_bundle_file_rows={len(bundle_file_dicts)}
- complete_source_query_rows={v61cf['complete_source_query_rows']}
- expected_generation_result_artifacts={v61cf['expected_generation_result_artifacts']}
- generation_closure_return_intake_ready={v61cf['generation_closure_return_intake_ready']}
- generation_execution_ready={v61cf['generation_execution_ready']}
- generation_execution_admitted_rows={v61cf['generation_execution_admitted_rows']}
- blocked_execution_rows={v61cf['blocked_execution_rows']}
- page_hash_closure_ready={page_hash_closure_ready}
- review_return_closure_ready={review_return_closure_ready}
- generation_result_closure_ready={generation_result_closure_ready}
- operator_bundle_handoff_ready={operator_bundle_handoff_ready}
- generation_operator_execution_ready={generation_operator_execution_ready}
- actual_model_generation_ready=0
- checkpoint_payload_bytes_downloaded_by_v61cg=0
- checkpoint_payload_bytes_committed_to_repo=0

Blocked wording:

v61cg is an operator bundle only. It inherits the closed full safetensors
page-hash state from v61cf/v61ce, but it does not execute Mixtral generation
and does not claim production latency, near-frontier quality, or a release
package.
"""
(run_dir / "V61CG_UBUNTU1_SOURCE_BOUND_GENERATION_OPERATOR_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

summary = {
    "v61cg_ubuntu1_source_bound_generation_operator_bundle_ready": "1",
    "model_id": model_id,
    "v61cf_ubuntu1_source_bound_generation_execution_packet_ready": v61cf["v61cf_ubuntu1_source_bound_generation_execution_packet_ready"],
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decisions = [
    {"gate": "v61cf-execution-packet-input", "status": "pass", "reason": "v61cf packet evidence is bound"},
    {"gate": "operator-bundle-shape", "status": "pass", "reason": "operator files and verifier are present"},
    {"gate": "full-page-hash-closure", "status": status(page_hash_closure_ready), "reason": f"page_hash_closure_ready={page_hash_closure_ready}"},
    {"gate": "complete-source-review-return", "status": status(review_return_closure_ready), "reason": f"review_return_closure_ready={review_return_closure_ready}"},
    {"gate": "actual-generation-result-return", "status": status(generation_result_closure_ready), "reason": f"generation_result_closure_ready={generation_result_closure_ready}"},
    {"gate": "source-bound-generation-execution", "status": status(execution_ready), "reason": f"blocked_execution_rows={blocked_execution_rows}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "v61cg does not execute generation"},
    {"gate": "production-latency", "status": "blocked", "reason": "no production latency evidence"},
    {"gate": "near-frontier-quality", "status": "blocked", "reason": "no external near-frontier quality review"},
    {"gate": "real-release-package", "status": "blocked", "reason": "not a release package"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "no checkpoint payload bytes are copied into the repository"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decisions)

manifest = {
    "artifact": "v61cg_ubuntu1_source_bound_generation_operator_bundle",
    "created_at": datetime.now(timezone.utc).isoformat(),
    "model_id": model_id,
    "target_root_path": target_root,
    "v61cg_ubuntu1_source_bound_generation_operator_bundle_ready": 1,
    "source_v61cf_summary_sha256": sha256(v61cf_summary_path),
    "execution_packet_rows": int(v61cf["execution_packet_rows"]),
    "prompt_manifest_rows": int(v61cf["prompt_manifest_rows"]),
    "return_manifest_rows": int(v61cf["return_manifest_rows"]),
    "carried_operator_command_rows": int(v61cf["operator_command_rows"]),
    "bundle_operator_command_rows": len(bundle_command_rows),
    "total_operator_command_rows": len(carried_command_rows) + len(bundle_command_rows),
    "operator_bundle_file_rows": len(bundle_file_dicts),
    "page_hash_closure_ready": page_hash_closure_ready,
    "review_return_closure_ready": review_return_closure_ready,
    "generation_result_closure_ready": generation_result_closure_ready,
    "operator_bundle_handoff_ready": operator_bundle_handoff_ready,
    "generation_operator_execution_ready": generation_operator_execution_ready,
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_downloaded_by_v61cg": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61cg_ubuntu1_source_bound_generation_operator_bundle_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)
PY

echo "v61cg_ubuntu1_source_bound_generation_operator_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
