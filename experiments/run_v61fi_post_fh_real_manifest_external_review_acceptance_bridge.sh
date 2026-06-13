#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61fi_post_fh_real_manifest_external_review_acceptance_bridge"
RUN_ID="${V61FI_RUN_ID:-bridge_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61FI_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61FH_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh" >/dev/null
V61FG_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61fg_post_ff_real_manifest_external_review_packet.sh" >/dev/null
V61FF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61ff_post_fe_real_manifest_replay_readiness_matrix.sh" >/dev/null

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
bridge_dir = run_dir / "real_manifest_external_review_acceptance_bridge"
bridge_dir.mkdir(parents=True, exist_ok=True)


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def sha256_hex(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


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


def as_int(row, key):
    return int(row.get(key, "0") or "0")


source_specs = {
    "v61fh": {
        "summary": results / "v61fh_post_fg_real_manifest_external_review_return_intake_summary.csv",
        "decision": results / "v61fh_post_fg_real_manifest_external_review_return_intake_decision.csv",
        "dir": results / "v61fh_post_fg_real_manifest_external_review_return_intake" / "intake_001",
        "ready_field": "v61fh_post_fg_real_manifest_external_review_return_intake_ready",
    },
    "v61fg": {
        "summary": results / "v61fg_post_ff_real_manifest_external_review_packet_summary.csv",
        "decision": results / "v61fg_post_ff_real_manifest_external_review_packet_decision.csv",
        "dir": results / "v61fg_post_ff_real_manifest_external_review_packet" / "packet_001",
        "ready_field": "v61fg_post_ff_real_manifest_external_review_packet_ready",
    },
    "v61ff": {
        "summary": results / "v61ff_post_fe_real_manifest_replay_readiness_matrix_summary.csv",
        "decision": results / "v61ff_post_fe_real_manifest_replay_readiness_matrix_decision.csv",
        "dir": results / "v61ff_post_fe_real_manifest_replay_readiness_matrix" / "matrix_001",
        "ready_field": "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready",
    },
}

summaries = {}
for label, spec in source_specs.items():
    if not spec["summary"].is_file():
        raise SystemExit(f"missing v61fi source summary: {spec['summary']}")
    summaries[label] = read_csv(spec["summary"])[0]
    if summaries[label].get(spec["ready_field"]) != "1":
        raise SystemExit(f"v61fi requires {label} {spec['ready_field']}=1")
    copy(spec["summary"], f"source_{label}/{spec['summary'].name}")
    if spec["decision"].is_file():
        copy(spec["decision"], f"source_{label}/{spec['decision'].name}")

source_artifacts = [
    ("v61fh", "real_manifest_external_review_required_artifact_rows.csv"),
    ("v61fh", "real_manifest_external_review_return_artifact_status_rows.csv"),
    ("v61fh", "real_manifest_external_review_return_acceptance_rows.csv"),
    ("v61fh", "real_manifest_external_review_return_requirement_rows.csv"),
    ("v61fh", "runtime_gap_rows.csv"),
    ("v61fg", "post_ff_real_manifest_external_review_checklist_rows.csv"),
    ("v61fg", "post_ff_real_manifest_external_review_claim_rows.csv"),
    ("v61ff", "post_fe_real_manifest_replay_readiness_rows.csv"),
    ("v61ff", "post_fe_real_manifest_replay_blocker_rows.csv"),
]
for label, rel in source_artifacts:
    src = source_specs[label]["dir"] / rel
    if not src.is_file():
        raise SystemExit(f"missing v61fi source artifact: {src}")
    copy(src, f"source_{label}/{rel}")

v61fh = summaries["v61fh"]
v61fg = summaries["v61fg"]
v61ff = summaries["v61ff"]

bridge_rows = [
    {
        "bridge_id": "01-v61fh-return-intake-ready",
        "source_gate": "v61fh",
        "status": "ready",
        "ready": "1",
        "observed": "v61fh return intake gate emitted",
        "acceptance_effect": "input gate ready",
    },
    {
        "bridge_id": "02-v61fg-review-packet-ready",
        "source_gate": "v61fg",
        "status": "ready",
        "ready": v61fg["page_manifest_external_review_packet_ready"],
        "observed": f"review_packet_rows={v61fg['review_packet_rows']}; packet_file_rows={v61fg['packet_file_rows']}",
        "acceptance_effect": "review packet can be inspected",
    },
    {
        "bridge_id": "03-review-return-contract-ready",
        "source_gate": "v61fh",
        "status": "ready",
        "ready": "1",
        "observed": f"required_review_return_artifacts={v61fh['required_review_return_artifacts']}",
        "acceptance_effect": "return artifact contract fixed",
    },
    {
        "bridge_id": "04-real-manifest-runtime-evidence-review-ready",
        "source_gate": "v61fh",
        "status": "ready",
        "ready": v61fh["real_manifest_runtime_evidence_review_ready"],
        "observed": f"page_manifest_external_review_packet_ready={v61fh['page_manifest_external_review_packet_ready']}",
        "acceptance_effect": "page-manifest evidence can be reviewer-scoped",
    },
    {
        "bridge_id": "05-candidate-external-review-return",
        "source_gate": "v61fh",
        "status": "blocked",
        "ready": v61fh["candidate_external_review_return_ready"],
        "observed": f"accepted_review_return_artifacts={v61fh['accepted_review_return_artifacts']}/{v61fh['required_review_return_artifacts']}",
        "acceptance_effect": "candidate preflight only after return artifacts exist",
    },
    {
        "bridge_id": "06-real-external-review-return",
        "source_gate": "v61fh",
        "status": "blocked",
        "ready": v61fh["external_review_return_ready"],
        "observed": f"external_review_return_ready={v61fh['external_review_return_ready']}",
        "acceptance_effect": "real reviewer authority not certified",
    },
    {
        "bridge_id": "07-review-checklist-acceptance",
        "source_gate": "v61fh",
        "status": "blocked",
        "ready": "0",
        "observed": f"accepted_review_checklist_rows={v61fh['accepted_review_checklist_rows']}/{v61fh['review_checklist_rows']}",
        "acceptance_effect": "checklist return rows must be accepted",
    },
    {
        "bridge_id": "08-claim-boundary-acceptance",
        "source_gate": "v61fh",
        "status": "blocked",
        "ready": "0",
        "observed": f"accepted_claim_boundary_rows={v61fh['accepted_claim_boundary_rows']}/{v61fh['claim_boundary_rows']}",
        "acceptance_effect": "claim boundaries must be accepted",
    },
    {
        "bridge_id": "09-real-return-replay-admission",
        "source_gate": "v61ff",
        "status": "blocked",
        "ready": v61ff["real_return_replay_admission_ready"],
        "observed": f"real_return_replay_admission_ready={v61ff['real_return_replay_admission_ready']}",
        "acceptance_effect": "review acceptance alone does not open replay",
    },
    {
        "bridge_id": "10-row-acceptance",
        "source_gate": "v61ff",
        "status": "blocked",
        "ready": v61ff["row_acceptance_ready"],
        "observed": f"row_acceptance_ready={v61ff['row_acceptance_ready']}",
        "acceptance_effect": "row acceptance remains downstream",
    },
    {
        "bridge_id": "11-actual-model-generation",
        "source_gate": "v61ff",
        "status": "blocked",
        "ready": v61ff["actual_model_generation_ready"],
        "observed": f"actual_model_generation_ready={v61ff['actual_model_generation_ready']}",
        "acceptance_effect": "actual generation remains blocked",
    },
    {
        "bridge_id": "12-release-claims",
        "source_gate": "v61ff",
        "status": "blocked",
        "ready": "0",
        "observed": f"near_frontier_claim_ready={v61ff['near_frontier_claim_ready']}; production_latency_claim_ready={v61ff['production_latency_claim_ready']}; real_release_package_ready={v61ff['real_release_package_ready']}",
        "acceptance_effect": "quality, latency, and release claims remain blocked",
    },
]
write_csv(run_dir / "post_fh_real_manifest_external_review_acceptance_bridge_rows.csv", list(bridge_rows[0].keys()), bridge_rows)
write_csv(bridge_dir / "EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE_ROWS.csv", list(bridge_rows[0].keys()), bridge_rows)

blocker_rows = [row for row in bridge_rows if row["status"] == "blocked"]
write_csv(run_dir / "post_fh_real_manifest_external_review_acceptance_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)
write_csv(bridge_dir / "EXTERNAL_REVIEW_ACCEPTANCE_BLOCKER_ROWS.csv", list(blocker_rows[0].keys()), blocker_rows)

next_action_rows = [
    {"action_id": "01-send-v61fg-packet", "status": "ready", "command_or_artifact": "results/v61fg_post_ff_real_manifest_external_review_packet/packet_001/real_manifest_external_review_packet/", "expected_effect": "external reviewer receives zero-payload evidence packet"},
    {"action_id": "02-fill-v61fh-return-artifacts", "status": "blocked", "command_or_artifact": "results/v61fh_post_fg_real_manifest_external_review_return_intake/intake_001/real_manifest_external_review_return_intake/REQUIRED_REVIEW_RETURN_ARTIFACTS.csv", "expected_effect": "six real review-return artifacts are supplied"},
    {"action_id": "03-rerun-v61fh-intake", "status": "blocked", "command_or_artifact": "V61FH_EXTERNAL_REVIEW_RETURN_DIR=/path/to/return ./experiments/run_v61fh_post_fg_real_manifest_external_review_return_intake.sh", "expected_effect": "candidate external review return can open"},
    {"action_id": "04-rerun-v61fi-bridge", "status": "ready", "command_or_artifact": "./experiments/test_v61fi_post_fh_real_manifest_external_review_acceptance_bridge.sh", "expected_effect": "bridge blockers are recomputed"},
    {"action_id": "05-preserve-generation-blockers", "status": "ready", "command_or_artifact": "actual_model_generation_ready=0", "expected_effect": "generation/release claims stay blocked until full return chain closes"},
    {"action_id": "06-await-real-reviewer-authority", "status": "blocked", "command_or_artifact": "external reviewer identity and authority evidence", "expected_effect": "real external review can be considered only after non-fixture evidence"},
]
write_csv(run_dir / "post_fh_real_manifest_external_review_next_action_rows.csv", list(next_action_rows[0].keys()), next_action_rows)
write_csv(bridge_dir / "EXTERNAL_REVIEW_NEXT_ACTION_ROWS.csv", list(next_action_rows[0].keys()), next_action_rows)

claim_boundary_rows = [
    {"claim": "reviewer-ready real page-manifest evidence packet", "status": "allowed-with-boundary", "required_disclosure": "external review return is not yet accepted"},
    {"claim": "candidate external review return mechanics", "status": "blocked", "required_disclosure": "requires supplied six-artifact return directory"},
    {"claim": "real external review accepted", "status": "blocked", "required_disclosure": "requires non-fixture reviewer authority and accepted return rows"},
    {"claim": "actual model generation / near-frontier / latency / release", "status": "blocked", "required_disclosure": "requires replay, row acceptance, generation execution, result acceptance, and release audit"},
]
write_csv(run_dir / "post_fh_real_manifest_external_review_claim_boundary_rows.csv", list(claim_boundary_rows[0].keys()), claim_boundary_rows)
write_csv(bridge_dir / "EXTERNAL_REVIEW_CLAIM_BOUNDARY_ROWS.csv", list(claim_boundary_rows[0].keys()), claim_boundary_rows)

bridge_manifest = {
    "manifest_scope": "v61fi-post-fh-real-manifest-external-review-acceptance-bridge",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "bridge_rows": len(bridge_rows),
    "ready_bridge_rows": sum(row["status"] == "ready" for row in bridge_rows),
    "blocked_bridge_rows": sum(row["status"] == "blocked" for row in bridge_rows),
    "candidate_external_review_return_ready": as_int(v61fh, "candidate_external_review_return_ready"),
    "external_review_return_ready": as_int(v61fh, "external_review_return_ready"),
    "actual_model_generation_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(bridge_dir / "BRIDGE_MANIFEST.json").write_text(json.dumps(bridge_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

summary_md = bridge_dir / "EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE_SUMMARY.md"
summary_md.write_text(
    "\n".join(
        [
            "# v61fi Real Manifest External Review Acceptance Bridge",
            "",
            "This bridge connects the v61fh review-return intake to the v61ff",
            "replay/generation boundary. It does not certify real external review",
            "or open actual generation.",
            "",
            f"- bridge_rows={bridge_manifest['bridge_rows']}",
            f"- ready_bridge_rows={bridge_manifest['ready_bridge_rows']}",
            f"- blocked_bridge_rows={bridge_manifest['blocked_bridge_rows']}",
            f"- required_review_return_artifacts={v61fh['required_review_return_artifacts']}",
            f"- accepted_review_return_artifacts={v61fh['accepted_review_return_artifacts']}/{v61fh['required_review_return_artifacts']}",
            f"- candidate_external_review_return_ready={v61fh['candidate_external_review_return_ready']}",
            f"- external_review_return_ready={v61fh['external_review_return_ready']}",
            f"- real_return_replay_admission_ready={v61ff['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={v61ff['row_acceptance_ready']}",
            f"- actual_model_generation_ready={v61ff['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
        ]
    ),
    encoding="utf-8",
)

verify_script = bridge_dir / "VERIFY_EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE.sh"
verify_script.write_text(
    "\n".join(
        [
            "#!/usr/bin/env bash",
            "set -euo pipefail",
            'cd "$(dirname "$0")"',
            "python3 - <<'PY_VERIFY'",
            "import csv",
            "import hashlib",
            "import json",
            "from pathlib import Path",
            "",
            "root = Path('.')",
            "for line in (root / 'BRIDGE_SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():",
            "    if not line.strip():",
            "        continue",
            "    expected, rel = line.split(None, 1)",
            "    h = hashlib.sha256()",
            "    with (root / rel.strip()).open('rb') as handle:",
            "        for chunk in iter(lambda: handle.read(1024 * 1024), b''):",
            "            h.update(chunk)",
            "    if h.hexdigest() != expected:",
            "        raise SystemExit(f'sha256 mismatch for {rel.strip()}')",
            "manifest = json.loads((root / 'BRIDGE_MANIFEST.json').read_text(encoding='utf-8'))",
            "bridge_rows = list(csv.DictReader((root / 'EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE_ROWS.csv').open(newline='', encoding='utf-8')))",
            "if len(bridge_rows) != manifest['bridge_rows']:",
            "    raise SystemExit('bridge row count mismatch')",
            "if sum(row['status'] == 'ready' for row in bridge_rows) != manifest['ready_bridge_rows']:",
            "    raise SystemExit('ready bridge row count mismatch')",
            "if sum(row['status'] == 'blocked' for row in bridge_rows) != manifest['blocked_bridge_rows']:",
            "    raise SystemExit('blocked bridge row count mismatch')",
            "if manifest['external_review_return_ready'] != 0:",
            "    raise SystemExit('real external review must remain blocked')",
            "if manifest['actual_model_generation_ready'] != 0:",
            "    raise SystemExit('actual generation must remain blocked')",
            "if manifest['checkpoint_payload_bytes_committed_to_repo'] != 0:",
            "    raise SystemExit('checkpoint payload must remain zero')",
            "PY_VERIFY",
            "",
        ]
    ),
    encoding="utf-8",
)
os.chmod(verify_script, 0o755)

bridge_files_for_list = sorted(
    path
    for path in bridge_dir.rglob("*")
    if path.is_file() and path.name not in {"BRIDGE_FILE_LIST.txt", "BRIDGE_SHA256SUMS.txt"}
)
(bridge_dir / "BRIDGE_FILE_LIST.txt").write_text(
    "\n".join(str(path.relative_to(bridge_dir)) for path in bridge_files_for_list) + "\n",
    encoding="utf-8",
)
bridge_files_for_hash = sorted(path for path in bridge_dir.rglob("*") if path.is_file() and path.name != "BRIDGE_SHA256SUMS.txt")
(bridge_dir / "BRIDGE_SHA256SUMS.txt").write_text(
    "".join(f"{sha256_hex(path)}  {path.relative_to(bridge_dir)}\n" for path in bridge_files_for_hash),
    encoding="utf-8",
)

bridge_file_rows = sum(1 for path in bridge_dir.rglob("*") if path.is_file())
ready_bridge_rows = sum(row["status"] == "ready" for row in bridge_rows)
blocked_bridge_rows = len(bridge_rows) - ready_bridge_rows
ready_next_action_rows = sum(row["status"] == "ready" for row in next_action_rows)

summary = {
    "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_ready": "1",
    "v61fh_post_fg_real_manifest_external_review_return_intake_ready": v61fh["v61fh_post_fg_real_manifest_external_review_return_intake_ready"],
    "v61fg_post_ff_real_manifest_external_review_packet_ready": v61fg["v61fg_post_ff_real_manifest_external_review_packet_ready"],
    "v61ff_post_fe_real_manifest_replay_readiness_matrix_ready": v61ff["v61ff_post_fe_real_manifest_replay_readiness_matrix_ready"],
    "bridge_rows": str(len(bridge_rows)),
    "ready_bridge_rows": str(ready_bridge_rows),
    "blocked_bridge_rows": str(blocked_bridge_rows),
    "blocker_rows": str(len(blocker_rows)),
    "next_action_rows": str(len(next_action_rows)),
    "ready_next_action_rows": str(ready_next_action_rows),
    "claim_boundary_rows": str(len(claim_boundary_rows)),
    "blocked_claim_boundary_rows": str(sum(row["status"] == "blocked" for row in claim_boundary_rows)),
    "bridge_file_rows": str(bridge_file_rows),
    "metadata_only_bridge_file_rows": str(bridge_file_rows),
    "required_review_return_artifacts": v61fh["required_review_return_artifacts"],
    "accepted_review_return_artifacts": v61fh["accepted_review_return_artifacts"],
    "missing_review_return_artifacts": v61fh["missing_review_return_artifacts"],
    "review_checklist_rows": v61fh["review_checklist_rows"],
    "accepted_review_checklist_rows": v61fh["accepted_review_checklist_rows"],
    "claim_boundary_review_rows": v61fh["claim_boundary_rows"],
    "accepted_claim_boundary_rows": v61fh["accepted_claim_boundary_rows"],
    "candidate_external_review_return_ready": v61fh["candidate_external_review_return_ready"],
    "external_review_return_ready": v61fh["external_review_return_ready"],
    "real_manifest_runtime_evidence_review_ready": v61fh["real_manifest_runtime_evidence_review_ready"],
    "real_return_replay_admission_ready": v61ff["real_return_replay_admission_ready"],
    "row_acceptance_ready": v61ff["row_acceptance_ready"],
    "generation_execution_admitted_rows": v61ff["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61ff["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61ff["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61ff["expected_generation_result_artifacts"],
    "actual_model_generation_ready": "0",
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61fi": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": row["bridge_id"], "status": "pass" if row["status"] == "ready" else "blocked", "reason": row["observed"]}
    for row in bridge_rows
]
decision_rows.append({"gate": "bridge-shape", "status": "pass", "reason": f"bridge_rows={len(bridge_rows)}"})
decision_rows.append({"gate": "repo-checkpoint-payload", "status": "pass", "reason": "metadata-only acceptance bridge"})
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = run_dir / "V61FI_POST_FH_REAL_MANIFEST_EXTERNAL_REVIEW_ACCEPTANCE_BRIDGE_BOUNDARY.md"
boundary.write_text(
    "\n".join(
        [
            "# v61fi Post-v61fh Real Manifest External Review Acceptance Bridge Boundary",
            "",
            f"- bridge_rows={summary['bridge_rows']}",
            f"- ready_bridge_rows={summary['ready_bridge_rows']}",
            f"- blocked_bridge_rows={summary['blocked_bridge_rows']}",
            f"- required_review_return_artifacts={summary['required_review_return_artifacts']}",
            f"- accepted_review_return_artifacts={summary['accepted_review_return_artifacts']}/{summary['required_review_return_artifacts']}",
            f"- missing_review_return_artifacts={summary['missing_review_return_artifacts']}",
            f"- accepted_review_checklist_rows={summary['accepted_review_checklist_rows']}/{summary['review_checklist_rows']}",
            f"- accepted_claim_boundary_rows={summary['accepted_claim_boundary_rows']}/{summary['claim_boundary_review_rows']}",
            f"- candidate_external_review_return_ready={summary['candidate_external_review_return_ready']}",
            f"- external_review_return_ready={summary['external_review_return_ready']}",
            f"- real_return_replay_admission_ready={summary['real_return_replay_admission_ready']}",
            f"- row_acceptance_ready={summary['row_acceptance_ready']}",
            f"- generation_execution_admitted_rows={summary['generation_execution_admitted_rows']}/{summary['generation_execution_admission_rows']}",
            f"- accepted_generation_result_artifacts={summary['accepted_generation_result_artifacts']}/{summary['expected_generation_result_artifacts']}",
            f"- actual_model_generation_ready={summary['actual_model_generation_ready']}",
            "- checkpoint_payload_bytes_committed_to_repo=0",
            "",
            "Allowed wording:",
            "- v61fi bridges the v61fh return-intake contract into external-review acceptance blockers.",
            "",
            "Blocked wording:",
            "- Do not claim accepted external review, replay admission, row acceptance, actual generation, latency, quality, or release readiness from v61fi alone.",
            "",
        ]
    ),
    encoding="utf-8",
)

run_manifest = {
    "artifact": "v61fi_post_fh_real_manifest_external_review_acceptance_bridge",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    **{key: (int(value) if str(value).isdigit() else value) for key, value in summary.items()},
}
(run_dir / "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_manifest.json").write_text(
    json.dumps(run_manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61fi_post_fh_real_manifest_external_review_acceptance_bridge_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
