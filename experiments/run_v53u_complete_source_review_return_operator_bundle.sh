#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v53u_complete_source_review_return_operator_bundle"
RUN_ID="${V53U_RUN_ID:-bundle_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V53U_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v53u_complete_source_review_return_operator_bundle_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V53R_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53r_complete_source_review_packet.sh" >/dev/null
V53S_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53s_complete_source_review_return_intake.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

v53r_dir = results / "v53r_complete_source_review_packet" / "review_001"
v53s_dir = results / "v53s_complete_source_review_return_intake" / "intake_001"
operator_dir = run_dir / "operator_bundle"
operator_dir.mkdir(parents=True, exist_ok=True)


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


v53r_summary_path = results / "v53r_complete_source_review_packet_summary.csv"
v53s_summary_path = results / "v53s_complete_source_review_return_intake_summary.csv"
v53r_decision_path = results / "v53r_complete_source_review_packet_decision.csv"
v53s_decision_path = results / "v53s_complete_source_review_return_intake_decision.csv"
v53r = read_csv(v53r_summary_path)[0]
v53s = read_csv(v53s_summary_path)[0]
if v53r.get("v53r_complete_source_review_packet_ready") != "1":
    raise SystemExit("v53u requires v53r_complete_source_review_packet_ready=1")
if v53s.get("v53s_complete_source_review_return_intake_ready") != "1":
    raise SystemExit("v53u requires v53s_complete_source_review_return_intake_ready=1")

for src, rel in [
    (v53r_summary_path, "source_v53r/v53r_complete_source_review_packet_summary.csv"),
    (v53r_decision_path, "source_v53r/v53r_complete_source_review_packet_decision.csv"),
    (v53r_dir / "review_answer_packet_rows.csv", "source_v53r/review_answer_packet_rows.csv"),
    (v53r_dir / "review_queue_rows.csv", "source_v53r/review_queue_rows.csv"),
    (v53r_dir / "reviewer_assignment_template_rows.csv", "source_v53r/reviewer_assignment_template_rows.csv"),
    (v53r_dir / "review_return_template_rows.csv", "source_v53r/review_return_template_rows.csv"),
    (v53r_dir / "review_packet_index_rows.csv", "source_v53r/review_packet_index_rows.csv"),
    (v53r_dir / "sha256_manifest.csv", "source_v53r/sha256_manifest.csv"),
    (v53s_summary_path, "source_v53s/v53s_complete_source_review_return_intake_summary.csv"),
    (v53s_decision_path, "source_v53s/v53s_complete_source_review_return_intake_decision.csv"),
    (v53s_dir / "review_return_required_field_rows.csv", "source_v53s/review_return_required_field_rows.csv"),
    (v53s_dir / "review_return_row_template.csv", "source_v53s/review_return_row_template.csv"),
    (v53s_dir / "review_return_artifact_gate_rows.csv", "source_v53s/review_return_artifact_gate_rows.csv"),
    (v53s_dir / "review_return_metric_rows.csv", "source_v53s/review_return_metric_rows.csv"),
    (v53s_dir / "sha256_manifest.csv", "source_v53s/sha256_manifest.csv"),
]:
    copy(src, rel)

answer_rows = read_csv(v53r_dir / "review_answer_packet_rows.csv")
queue_rows = read_csv(v53r_dir / "review_queue_rows.csv")
assignment_rows = read_csv(v53r_dir / "reviewer_assignment_template_rows.csv")
required_field_rows = read_csv(v53s_dir / "review_return_required_field_rows.csv")
if len(answer_rows) != 7000 or len(queue_rows) != 7000:
    raise SystemExit("v53u expects 7000 review answer/queue rows")
if len(assignment_rows) != 21:
    raise SystemExit("v53u expects 21 reviewer assignment rows")
if len(required_field_rows) != 29:
    raise SystemExit("v53u expects 29 v53s required field rows")

owner_repos = sorted({row["owner_repo"] for row in answer_rows})
priority_by_system = Counter((row["system_id"], row["priority_class"]) for row in queue_rows)
answer_count_by_system = Counter(row["system_id"] for row in answer_rows)

chunk_rows = []
for row in assignment_rows:
    system_id = row["system_id"]
    scope = row["review_scope"]
    p0_rows = priority_by_system[(system_id, "p0_answer_or_policy_mismatch")]
    p1_rows = priority_by_system[(system_id, "p1_negative_abstain_review")]
    p2_rows = priority_by_system[(system_id, "p2_regular_source_review")]
    expected_human = answer_count_by_system[system_id] if scope == "primary-source-review" else 0
    expected_adjudication = p0_rows if scope == "secondary-adjudication-review" else 0
    expected_identity = 1
    expected_conflict = len(owner_repos)
    chunk_rows.append(
        {
            "review_chunk_id": f"v53u_chunk_{row['assignment_id']}",
            "assignment_id": row["assignment_id"],
            "reviewer_slot_id": row["reviewer_slot_id"],
            "system_id": system_id,
            "review_scope": scope,
            "assigned_answer_rows": row["assigned_answer_rows"],
            "priority_p0_rows": str(p0_rows),
            "priority_p1_rows": str(p1_rows),
            "priority_p2_rows": str(p2_rows),
            "expected_human_review_rows": str(expected_human),
            "expected_adjudication_rows": str(expected_adjudication),
            "expected_reviewer_identity_rows": str(expected_identity),
            "expected_conflict_disclosure_rows": str(expected_conflict),
            "return_artifact_prefix": f"{system_id}_{row['reviewer_slot_id']}",
            "chunk_ready": "1",
            "chunk_status": "pending-external-review-return",
        }
    )
write_csv(run_dir / "reviewer_workload_chunk_rows.csv", list(chunk_rows[0].keys()), chunk_rows)

artifact_rows = [
    {
        "return_artifact": "human_review_rows.csv",
        "required_rows": v53s["expected_human_review_rows"],
        "accepted_rows": v53s["accepted_human_review_rows"],
        "template_file": "operator_bundle/HUMAN_REVIEW_ROWS_TEMPLATE.csv",
        "source_schema": "source_v53s/review_return_required_field_rows.csv",
        "acceptance_gate": "human-review-artifacts",
        "artifact_ready": "0",
    },
    {
        "return_artifact": "adjudication_rows.csv",
        "required_rows": v53s["expected_adjudication_rows"],
        "accepted_rows": v53s["accepted_adjudication_rows"],
        "template_file": "operator_bundle/ADJUDICATION_ROWS_TEMPLATE.csv",
        "source_schema": "source_v53s/review_return_required_field_rows.csv",
        "acceptance_gate": "adjudication-artifacts",
        "artifact_ready": "0",
    },
    {
        "return_artifact": "reviewer_identity_rows.csv",
        "required_rows": v53s["expected_reviewer_identity_rows"],
        "accepted_rows": v53s["accepted_reviewer_identity_rows"],
        "template_file": "operator_bundle/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv",
        "source_schema": "source_v53s/review_return_required_field_rows.csv",
        "acceptance_gate": "reviewer-identity",
        "artifact_ready": "0",
    },
    {
        "return_artifact": "reviewer_conflict_rows.csv",
        "required_rows": v53s["expected_conflict_disclosure_rows"],
        "accepted_rows": v53s["accepted_conflict_disclosure_rows"],
        "template_file": "operator_bundle/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv",
        "source_schema": "source_v53s/review_return_required_field_rows.csv",
        "acceptance_gate": "conflict-disclosure",
        "artifact_ready": "0",
    },
    {
        "return_artifact": "acceptance_summary.json",
        "required_rows": "1",
        "accepted_rows": v53s["acceptance_summary_ready"],
        "template_file": "operator_bundle/ACCEPTANCE_SUMMARY_TEMPLATE.json",
        "source_schema": "source_v53s/review_return_required_field_rows.csv",
        "acceptance_gate": "acceptance-summary",
        "artifact_ready": "0",
    },
]
write_csv(run_dir / "review_return_expected_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

template_fields = {
    "HUMAN_REVIEW_ROWS_TEMPLATE.csv": [
        "review_answer_packet_id",
        "answer_id",
        "system_id",
        "query_id",
        "reviewer_id",
        "review_decision",
        "source_support_verified",
        "citation_verified",
        "policy_verified",
        "review_comment_sha256",
    ],
    "ADJUDICATION_ROWS_TEMPLATE.csv": [
        "adjudication_id",
        "review_answer_packet_id",
        "answer_id",
        "adjudicator_id",
        "adjudication_decision",
        "adjudication_reason_sha256",
    ],
    "REVIEWER_IDENTITY_ROWS_TEMPLATE.csv": [
        "assignment_id",
        "reviewer_id",
        "reviewer_slot_id",
        "system_id",
        "review_scope",
        "independence_declared",
        "credential_statement_sha256",
    ],
    "REVIEWER_CONFLICT_ROWS_TEMPLATE.csv": [
        "assignment_id",
        "reviewer_id",
        "owner_repo",
        "conflict_declared",
        "conflict_statement_sha256",
    ],
}
for filename, fields in template_fields.items():
    write_csv(operator_dir / filename, fields, [])

acceptance_template = {
    "review_protocol_version": "v53s",
    "acceptance_decision": "accepted",
    "expected_human_review_rows": int(v53s["expected_human_review_rows"]),
    "accepted_human_review_rows": "<fill-after-review>",
    "human_review_rows_sha256": "sha256:<fill-after-review>",
    "expected_adjudication_rows": int(v53s["expected_adjudication_rows"]),
    "accepted_adjudication_rows": "<fill-after-review>",
    "adjudication_rows_sha256": "sha256:<fill-after-review>",
    "expected_reviewer_identity_rows": int(v53s["expected_reviewer_identity_rows"]),
    "accepted_reviewer_identity_rows": "<fill-after-review>",
    "reviewer_identity_rows_sha256": "sha256:<fill-after-review>",
    "expected_conflict_disclosure_rows": int(v53s["expected_conflict_disclosure_rows"]),
    "accepted_conflict_disclosure_rows": "<fill-after-review>",
    "reviewer_conflict_rows_sha256": "sha256:<fill-after-review>",
}
(operator_dir / "ACCEPTANCE_SUMMARY_TEMPLATE.json").write_text(
    json.dumps(acceptance_template, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

(operator_dir / "README.md").write_text(
    "# v53u Complete-Source Review Return Operator Bundle\n\n"
    "This bundle packages the v53r/v53s complete-source review-return surface for "
    "external human/source review. It does not invent review judgments. The only "
    "accepted completion path is to populate a separate return directory and run "
    "v53s with `V53S_REVIEW_RETURN_DIR` pointing at that directory.\n\n"
    "Required return artifacts:\n\n"
    "- `human_review_rows.csv`: 7000 rows\n"
    "- `adjudication_rows.csv`: 1000 rows\n"
    "- `reviewer_identity_rows.csv`: 21 rows\n"
    "- `reviewer_conflict_rows.csv`: 210 rows\n"
    "- `acceptance_summary.json`: hashes and accepted row counts for those artifacts\n",
    encoding="utf-8",
)

(operator_dir / "RETURN_INTAKE_COMMANDS.md").write_text(
    "# Return Intake Commands\n\n"
    "After the external review team populates `/path/to/v53_review_return`, run:\n\n"
    "```bash\n"
    "V53S_REUSE_EXISTING=0 \\\n"
    "V53S_REVIEW_RETURN_DIR=/path/to/v53_review_return \\\n"
    "./experiments/run_v53s_complete_source_review_return_intake.sh\n\n"
    "V53T_REUSE_EXISTING=0 ./experiments/run_v53t_complete_source_audit_readiness_gate.sh\n"
    "```\n\n"
    "Do not mark v53/v1.0 comparison ready until v53s accepts every required "
    "return artifact and the downstream audit gate confirms the state.\n",
    encoding="utf-8",
)

verify_script = operator_dir / "VERIFY_REVIEW_RETURN_BUNDLE.sh"
verify_script.write_text(
    """#!/usr/bin/env bash
set -euo pipefail

BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
required_files=(
  "$BUNDLE_DIR/reviewer_workload_chunk_rows.csv"
  "$BUNDLE_DIR/review_return_expected_artifact_rows.csv"
  "$BUNDLE_DIR/operator_bundle/HUMAN_REVIEW_ROWS_TEMPLATE.csv"
  "$BUNDLE_DIR/operator_bundle/ADJUDICATION_ROWS_TEMPLATE.csv"
  "$BUNDLE_DIR/operator_bundle/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv"
  "$BUNDLE_DIR/operator_bundle/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv"
  "$BUNDLE_DIR/operator_bundle/ACCEPTANCE_SUMMARY_TEMPLATE.json"
  "$BUNDLE_DIR/source_v53r/review_answer_packet_rows.csv"
  "$BUNDLE_DIR/source_v53s/review_return_required_field_rows.csv"
)

for path in "${required_files[@]}"; do
  if [[ ! -s "$path" ]]; then
    echo "missing v53u review-return bundle file: $path" >&2
    exit 1
  fi
done

[[ "$(wc -l < "$BUNDLE_DIR/reviewer_workload_chunk_rows.csv" | tr -d ' ')" == "22" ]] || { echo "expected 21 reviewer chunk rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/review_return_expected_artifact_rows.csv" | tr -d ' ')" == "6" ]] || { echo "expected 5 return artifact rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/source_v53r/review_answer_packet_rows.csv" | tr -d ' ')" == "7001" ]] || { echo "expected 7000 review answer rows" >&2; exit 1; }
[[ "$(wc -l < "$BUNDLE_DIR/source_v53s/review_return_required_field_rows.csv" | tr -d ' ')" == "30" ]] || { echo "expected 29 required field rows" >&2; exit 1; }

python3 -m json.tool "$BUNDLE_DIR/operator_bundle/ACCEPTANCE_SUMMARY_TEMPLATE.json" >/dev/null

if find "$BUNDLE_DIR" -type f \( -name '*.safetensors' -o -name '*.bin' -o -name '*.pt' \) | grep -q .; then
  echo "model/checkpoint payload-like file found inside v53u bundle" >&2
  exit 1
fi

echo "v53u review return operator bundle shape verified"
""",
    encoding="utf-8",
)
verify_script.chmod(0o755)

bundle_files = [
    ("operator_bundle/README.md", "operator instructions"),
    ("operator_bundle/RETURN_INTAKE_COMMANDS.md", "return intake command sheet"),
    ("operator_bundle/HUMAN_REVIEW_ROWS_TEMPLATE.csv", "human review rows header template"),
    ("operator_bundle/ADJUDICATION_ROWS_TEMPLATE.csv", "adjudication rows header template"),
    ("operator_bundle/REVIEWER_IDENTITY_ROWS_TEMPLATE.csv", "reviewer identity rows header template"),
    ("operator_bundle/REVIEWER_CONFLICT_ROWS_TEMPLATE.csv", "reviewer conflict rows header template"),
    ("operator_bundle/ACCEPTANCE_SUMMARY_TEMPLATE.json", "acceptance summary json template"),
    ("operator_bundle/VERIFY_REVIEW_RETURN_BUNDLE.sh", "operator bundle shape verifier"),
]
bundle_file_rows = [
    {
        "bundle_file": rel,
        "purpose": purpose,
        "required": "1",
        "file_ready": "1",
        "fake_review_rows_included": "0",
    }
    for rel, purpose in bundle_files
]
write_csv(run_dir / "review_return_operator_bundle_file_rows.csv", list(bundle_file_rows[0].keys()), bundle_file_rows)

command_rows = [
    {
        "command_id": "verify-review-return-bundle-shape",
        "command": "results/v53u_complete_source_review_return_operator_bundle/bundle_001/operator_bundle/VERIFY_REVIEW_RETURN_BUNDLE.sh",
        "purpose": "verify source packet, return templates, and no payload-like files",
        "execution_ready": "1",
    },
    {
        "command_id": "run-v53s-review-return-intake",
        "command": "V53S_REUSE_EXISTING=0 V53S_REVIEW_RETURN_DIR=/path/to/v53_review_return ./experiments/run_v53s_complete_source_review_return_intake.sh",
        "purpose": "accept externally supplied human/source review return artifacts",
        "execution_ready": "0",
    },
    {
        "command_id": "run-v53t-readiness-refresh",
        "command": "V53T_REUSE_EXISTING=0 ./experiments/run_v53t_complete_source_audit_readiness_gate.sh",
        "purpose": "refresh complete-source audit readiness after accepted return",
        "execution_ready": "0",
    },
    {
        "command_id": "preserve-blocked-claims",
        "command": "do-not-claim-v53-or-v1.0-ready-until-review-return-ready",
        "purpose": "keep comparison/release wording blocked until accepted review evidence exists",
        "execution_ready": "1",
    },
]
write_csv(run_dir / "review_return_operator_command_rows.csv", list(command_rows[0].keys()), command_rows)

required_human = int(v53s["expected_human_review_rows"])
required_adjudication = int(v53s["expected_adjudication_rows"])
required_identity = int(v53s["expected_reviewer_identity_rows"])
required_conflict = int(v53s["expected_conflict_disclosure_rows"])
accepted_human = int(v53s["accepted_human_review_rows"])
accepted_adjudication = int(v53s["accepted_adjudication_rows"])
accepted_identity = int(v53s["accepted_reviewer_identity_rows"])
accepted_conflict = int(v53s["accepted_conflict_disclosure_rows"])
chunk_human = sum(int(row["expected_human_review_rows"]) for row in chunk_rows)
chunk_adjudication = sum(int(row["expected_adjudication_rows"]) for row in chunk_rows)
chunk_identity = sum(int(row["expected_reviewer_identity_rows"]) for row in chunk_rows)
chunk_conflict = sum(int(row["expected_conflict_disclosure_rows"]) for row in chunk_rows)
ready_chunks = sum(1 for row in chunk_rows if row["chunk_ready"] == "1")

requirement_rows = [
    {
        "requirement_id": "v53r-review-packet-input",
        "status": status(v53r["review_packet_ready"] == "1"),
        "required_value": "1",
        "actual_value": v53r["review_packet_ready"],
        "reason": "review queue and assignment packets are bound",
    },
    {
        "requirement_id": "v53s-return-intake-schema",
        "status": status(v53s["v53s_complete_source_review_return_intake_ready"] == "1"),
        "required_value": "1",
        "actual_value": v53s["v53s_complete_source_review_return_intake_ready"],
        "reason": "v53s return artifact schema and validator are bound",
    },
    {
        "requirement_id": "reviewer-workload-chunking",
        "status": status(ready_chunks == len(chunk_rows) and chunk_human == required_human and chunk_adjudication == required_adjudication),
        "required_value": f"chunks={len(assignment_rows)}; human={required_human}; adjudication={required_adjudication}",
        "actual_value": f"chunks={ready_chunks}; human={chunk_human}; adjudication={chunk_adjudication}",
        "reason": "operator workload rows map review/adjudication duties to reviewer assignments",
    },
    {
        "requirement_id": "reviewer-identity-conflict-return",
        "status": status(chunk_identity == required_identity and chunk_conflict == required_conflict),
        "required_value": f"identity={required_identity}; conflict={required_conflict}",
        "actual_value": f"identity={chunk_identity}; conflict={chunk_conflict}",
        "reason": "all reviewer assignment identity and conflict rows are planned",
    },
    {
        "requirement_id": "actual-human-review-return",
        "status": status(int(v53s["review_return_ready"]) == 1),
        "required_value": f"human={required_human}; adjudication={required_adjudication}; identity={required_identity}; conflict={required_conflict}",
        "actual_value": f"human={accepted_human}; adjudication={accepted_adjudication}; identity={accepted_identity}; conflict={accepted_conflict}",
        "reason": "operator bundle does not fabricate external review rows",
    },
]
write_csv(run_dir / "review_return_operator_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

runtime_gaps = [
    {
        "gap": "review-return-operator-bundle",
        "status": "ready",
        "evidence": f"bundle_files={len(bundle_file_rows)}; command_rows={len(command_rows)}",
    },
    {
        "gap": "human-review-return",
        "status": "blocked",
        "evidence": f"accepted_human_review_rows={accepted_human}/{required_human}",
    },
    {
        "gap": "adjudication-return",
        "status": "blocked",
        "evidence": f"accepted_adjudication_rows={accepted_adjudication}/{required_adjudication}",
    },
    {
        "gap": "v53-ready",
        "status": "blocked",
        "evidence": "review return is not accepted in the current default path",
    },
    {
        "gap": "v1.0-comparison-ready",
        "status": "blocked",
        "evidence": "human-reviewed complete-source audit is still absent",
    },
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gaps[0].keys()), runtime_gaps)

operator_bundle_handoff_ready = int(
    len(bundle_file_rows) == 8
    and len(command_rows) == 4
    and ready_chunks == len(chunk_rows)
    and chunk_human == required_human
    and chunk_adjudication == required_adjudication
    and chunk_identity == required_identity
    and chunk_conflict == required_conflict
)

metric = {
    "metric_id": "v53u_complete_source_review_return_operator_bundle_metrics",
    "v53r_complete_source_review_packet_ready": v53r["v53r_complete_source_review_packet_ready"],
    "v53s_complete_source_review_return_intake_ready": v53s["v53s_complete_source_review_return_intake_ready"],
    "review_packet_ready": v53r["review_packet_ready"],
    "review_return_ready": v53s["review_return_ready"],
    "review_answer_packet_rows": v53r["review_answer_packet_rows"],
    "review_queue_rows": v53r["review_queue_rows"],
    "reviewer_assignment_rows": v53r["review_assignment_template_rows"],
    "expected_human_review_rows": v53s["expected_human_review_rows"],
    "accepted_human_review_rows": v53s["accepted_human_review_rows"],
    "expected_adjudication_rows": v53s["expected_adjudication_rows"],
    "accepted_adjudication_rows": v53s["accepted_adjudication_rows"],
    "expected_reviewer_identity_rows": v53s["expected_reviewer_identity_rows"],
    "accepted_reviewer_identity_rows": v53s["accepted_reviewer_identity_rows"],
    "expected_conflict_disclosure_rows": v53s["expected_conflict_disclosure_rows"],
    "accepted_conflict_disclosure_rows": v53s["accepted_conflict_disclosure_rows"],
    "reviewer_workload_chunk_rows": str(len(chunk_rows)),
    "ready_reviewer_workload_chunk_rows": str(ready_chunks),
    "chunk_expected_human_review_rows": str(chunk_human),
    "chunk_expected_adjudication_rows": str(chunk_adjudication),
    "chunk_expected_reviewer_identity_rows": str(chunk_identity),
    "chunk_expected_conflict_disclosure_rows": str(chunk_conflict),
    "return_artifact_template_rows": str(len(artifact_rows)),
    "operator_bundle_file_rows": str(len(bundle_file_rows)),
    "operator_command_rows": str(len(command_rows)),
    "review_return_operator_bundle_handoff_ready": str(operator_bundle_handoff_ready),
    "quality_comparison_claim_ready": "0",
    "v53_ready": "0",
    "v1_0_comparison_ready": "0",
    "real_release_package_ready": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "review_return_operator_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v53u_complete_source_review_return_operator_bundle_ready": str(operator_bundle_handoff_ready),
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "v53r-review-packet-input", "status": "pass", "reason": "v53r review packet is bound"},
    {"gate": "v53s-return-intake-schema", "status": "pass", "reason": "v53s return validator is bound"},
    {"gate": "operator-bundle-shape", "status": "pass" if operator_bundle_handoff_ready else "blocked", "reason": f"bundle_files={len(bundle_file_rows)}; chunks={ready_chunks}/{len(chunk_rows)}"},
    {"gate": "zero-fake-review-rows", "status": "pass", "reason": "templates are header-only and actual review rows remain external"},
    {"gate": "human-review-return", "status": "blocked", "reason": f"accepted_human_review_rows={accepted_human}/{required_human}"},
    {"gate": "adjudication-return", "status": "blocked", "reason": f"accepted_adjudication_rows={accepted_adjudication}/{required_adjudication}"},
    {"gate": "reviewer-identity-return", "status": "blocked", "reason": f"accepted_reviewer_identity_rows={accepted_identity}/{required_identity}"},
    {"gate": "conflict-disclosure-return", "status": "blocked", "reason": f"accepted_conflict_disclosure_rows={accepted_conflict}/{required_conflict}"},
    {"gate": "v53-ready", "status": "blocked", "reason": "external review return has not been accepted"},
    {"gate": "v1.0-comparison-ready", "status": "blocked", "reason": "human-reviewed complete-source audit remains absent"},
    {"gate": "real-release-package", "status": "blocked", "reason": "v53u is an operator bundle, not a release package"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v53u Complete Source Review Return Operator Bundle Boundary

This layer packages the v53r review packet and v53s return-intake schema into an
operator handoff bundle. It does not create or accept human review judgments.

Evidence emitted:

- review_answer_packet_rows={v53r['review_answer_packet_rows']}
- review_queue_rows={v53r['review_queue_rows']}
- reviewer_workload_chunk_rows={len(chunk_rows)}
- ready_reviewer_workload_chunk_rows={ready_chunks}
- expected_human_review_rows={required_human}
- accepted_human_review_rows={accepted_human}
- expected_adjudication_rows={required_adjudication}
- accepted_adjudication_rows={accepted_adjudication}
- expected_reviewer_identity_rows={required_identity}
- accepted_reviewer_identity_rows={accepted_identity}
- expected_conflict_disclosure_rows={required_conflict}
- accepted_conflict_disclosure_rows={accepted_conflict}
- operator_bundle_file_rows={len(bundle_file_rows)}
- operator_command_rows={len(command_rows)}
- review_return_operator_bundle_handoff_ready={operator_bundle_handoff_ready}
- review_return_ready={v53s['review_return_ready']}
- v53_ready=0
- v1_0_comparison_ready=0

Allowed wording: reviewer-ready complete-source review-return operator bundle.

Blocked wording: accepted human-reviewed complete-source audit, v53 readiness,
v1.0 comparison readiness, quality comparison claim, or release readiness.
"""
(run_dir / "V53U_COMPLETE_SOURCE_REVIEW_RETURN_OPERATOR_BUNDLE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v53u-complete-source-review-return-operator-bundle",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v53u_complete_source_review_return_operator_bundle_ready": operator_bundle_handoff_ready,
    "review_return_operator_bundle_handoff_ready": operator_bundle_handoff_ready,
    "review_return_ready": int(v53s["review_return_ready"]),
    "v53_ready": 0,
    "v1_0_comparison_ready": 0,
    "real_release_package_ready": 0,
    "source_v53r_summary_sha256": sha256(v53r_summary_path),
    "source_v53s_summary_sha256": sha256(v53s_summary_path),
}
(run_dir / "v53u_complete_source_review_return_operator_bundle_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append(
            {
                "path": str(path.relative_to(run_dir)),
                "sha256": sha256(path),
                "bytes": str(path.stat().st_size),
            }
        )
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v53u_complete_source_review_return_operator_bundle_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
