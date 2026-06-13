#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v61dj_post_claim_return_evidence_contract_gate"
RUN_ID="${V61DJ_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

if [[ "${V61DJ_REUSE_EXISTING:-0}" == "1" && -s "$SUMMARY_CSV" && -s "$RUN_DIR/sha256_manifest.csv" ]]; then
  echo "v61dj_post_claim_return_evidence_contract_gate_dir: $RUN_DIR"
  echo "summary: $SUMMARY_CSV"
  echo "decision: $DECISION_CSV"
  exit 0
fi

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

V61DI_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61di_post_claim_generation_unblock_audit_gate.sh" >/dev/null
V61DF_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v61df_external_review_generation_return_operator_packet.sh" >/dev/null
V53AL_REUSE_EXISTING=1 "$ROOT_DIR/experiments/run_v53al_complete_source_external_return_bundle_preflight.sh" >/dev/null

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1]).resolve()
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
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


sources = {
    "v61di_summary": results / "v61di_post_claim_generation_unblock_audit_gate_summary.csv",
    "v61di_decision": results / "v61di_post_claim_generation_unblock_audit_gate_decision.csv",
    "v61di_stages": results / "v61di_post_claim_generation_unblock_audit_gate" / "audit_001" / "post_claim_generation_unblock_stage_rows.csv",
    "v61di_commands": results / "v61di_post_claim_generation_unblock_audit_gate" / "audit_001" / "post_claim_generation_unblock_command_rows.csv",
    "v61df_summary": results / "v61df_external_review_generation_return_operator_packet_summary.csv",
    "v61df_decision": results / "v61df_external_review_generation_return_operator_packet_decision.csv",
    "v61df_review_artifacts": results / "v61df_external_review_generation_return_operator_packet" / "packet_001" / "operator_packet" / "REVIEW_RETURN_REQUIRED_ARTIFACTS.csv",
    "v61df_generation_artifacts": results / "v61df_external_review_generation_return_operator_packet" / "packet_001" / "operator_packet" / "GENERATION_RESULT_REQUIRED_ARTIFACTS.csv",
    "v53al_summary": results / "v53al_complete_source_external_return_bundle_preflight_summary.csv",
    "v53al_decision": results / "v53al_complete_source_external_return_bundle_preflight_decision.csv",
    "v53al_preflight_rows": results / "v53al_complete_source_external_return_bundle_preflight" / "preflight_001" / "external_return_bundle_preflight_rows.csv",
}
for key, path in sources.items():
    if not path.is_file():
        raise SystemExit(f"missing v61dj source {key}: {path}")

copy(sources["v61di_summary"], "source_v61di/v61di_post_claim_generation_unblock_audit_gate_summary.csv")
copy(sources["v61di_decision"], "source_v61di/v61di_post_claim_generation_unblock_audit_gate_decision.csv")
copy(sources["v61di_stages"], "source_v61di/post_claim_generation_unblock_stage_rows.csv")
copy(sources["v61di_commands"], "source_v61di/post_claim_generation_unblock_command_rows.csv")
copy(sources["v61df_summary"], "source_v61df/v61df_external_review_generation_return_operator_packet_summary.csv")
copy(sources["v61df_decision"], "source_v61df/v61df_external_review_generation_return_operator_packet_decision.csv")
copy(sources["v61df_review_artifacts"], "source_v61df/REVIEW_RETURN_REQUIRED_ARTIFACTS.csv")
copy(sources["v61df_generation_artifacts"], "source_v61df/GENERATION_RESULT_REQUIRED_ARTIFACTS.csv")
copy(sources["v53al_summary"], "source_v53al/v53al_complete_source_external_return_bundle_preflight_summary.csv")
copy(sources["v53al_decision"], "source_v53al/v53al_complete_source_external_return_bundle_preflight_decision.csv")
copy(sources["v53al_preflight_rows"], "source_v53al/external_return_bundle_preflight_rows.csv")

v61di = read_csv(sources["v61di_summary"])[0]
v61df = read_csv(sources["v61df_summary"])[0]
v53al = read_csv(sources["v53al_summary"])[0]
stage_rows = read_csv(sources["v61di_stages"])
review_artifacts = read_csv(sources["v61df_review_artifacts"])
generation_artifacts = read_csv(sources["v61df_generation_artifacts"])

for field, row in [
    ("v61di_post_claim_generation_unblock_audit_gate_ready", v61di),
    ("v61df_external_review_generation_return_operator_packet_ready", v61df),
    ("v53al_complete_source_external_return_bundle_preflight_ready", v53al),
]:
    if row.get(field) != "1":
        raise SystemExit(f"v61dj requires {field}=1")

blocked_stages = [row for row in stage_rows if row["status"] == "blocked"]
blocker_rows = [
    {
        "contract_blocker_id": row["unblock_stage_id"],
        "source_gate": row["source_gate"],
        "contract_status": "unsatisfied",
        "actual_value": row["actual_value"],
        "required_next_evidence": row["required_next_evidence"],
        "blocking_reason": row["blocking_reason"],
    }
    for row in blocked_stages
]
write_csv(run_dir / "return_evidence_contract_blocker_rows.csv", list(blocker_rows[0].keys()), blocker_rows)

artifact_rows = []
for row in review_artifacts + generation_artifacts:
    expected = int(row["expected_rows"])
    accepted = int(row["accepted_rows"])
    artifact_rows.append(
        {
            "external_return_family": row["external_return_family"],
            "return_artifact": row["return_artifact"],
            "expected_rows": row["expected_rows"],
            "accepted_rows": row["accepted_rows"],
            "missing_rows": str(max(expected - accepted, 0)),
            "target_env_var": row["target_env_var"],
            "contract_status": "satisfied" if expected > 0 and accepted == expected else "unsatisfied",
            "source_current_status": row["current_status"],
            "checkpoint_payload_bytes_committed_to_repo": "0",
        }
    )
write_csv(run_dir / "return_evidence_contract_artifact_rows.csv", list(artifact_rows[0].keys()), artifact_rows)

family_rows = []
for family in ["aggregate-review-return", "generation-result-return"]:
    family_artifacts = [row for row in artifact_rows if row["external_return_family"] == family]
    expected_rows = sum(int(row["expected_rows"]) for row in family_artifacts)
    accepted_rows = sum(int(row["accepted_rows"]) for row in family_artifacts)
    family_rows.append(
        {
            "external_return_family": family,
            "required_artifacts": str(len(family_artifacts)),
            "satisfied_artifacts": str(sum(row["contract_status"] == "satisfied" for row in family_artifacts)),
            "unsatisfied_artifacts": str(sum(row["contract_status"] != "satisfied" for row in family_artifacts)),
            "expected_rows": str(expected_rows),
            "accepted_rows": str(accepted_rows),
            "missing_rows": str(max(expected_rows - accepted_rows, 0)),
            "family_contract_ready": str(int(expected_rows > 0 and accepted_rows == expected_rows)),
        }
    )
write_csv(run_dir / "return_evidence_contract_family_rows.csv", list(family_rows[0].keys()), family_rows)

command_rows = [
    {
        "command_id": "01-verify-operator-packet",
        "ready_to_run_now": "1",
        "command": "results/v61df_external_review_generation_return_operator_packet/packet_001/operator_packet/VERIFY_EXTERNAL_RETURN_PACKET.sh",
        "contract_transition": "operator packet remains valid",
    },
    {
        "command_id": "02-preflight-final-return-bundle",
        "ready_to_run_now": "1",
        "command": "V53AL_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AL_REUSE_EXISTING=0 ./experiments/run_v53al_complete_source_external_return_bundle_preflight.sh",
        "contract_transition": "return_bundle_preflight_pass=1",
    },
    {
        "command_id": "03-run-return-acceptance-replay",
        "ready_to_run_now": "0",
        "command": "V53AM_RETURN_BUNDLE_DIR=/path/to/final_return_bundle V53AM_REUSE_EXISTING=0 ./experiments/run_v53am_complete_source_return_acceptance_replay.sh",
        "contract_transition": "review/generation returns propagate through v53/v61 gates",
    },
    {
        "command_id": "04-refresh-generation-unblock-audit",
        "ready_to_run_now": "0",
        "command": "V61DI_REUSE_EXISTING=0 ./experiments/run_v61di_post_claim_generation_unblock_audit_gate.sh",
        "contract_transition": "unblock stages are recomputed after returns",
    },
    {
        "command_id": "05-rerun-return-contract",
        "ready_to_run_now": "0",
        "command": "V61DJ_REUSE_EXISTING=0 ./experiments/run_v61dj_post_claim_return_evidence_contract_gate.sh",
        "contract_transition": "contract satisfaction is recomputed",
    },
]
write_csv(run_dir / "return_evidence_contract_command_rows.csv", list(command_rows[0].keys()), command_rows)

runtime_gap_rows = [
    {"gap": "contract-surface", "status": "ready", "reason": "contract rows emitted"},
    {"gap": "return-bundle-preflight-pass", "status": "blocked", "reason": f"preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}"},
    {"gap": "aggregate-review-return", "status": "blocked", "reason": f"accepted_human_review_rows={v61di['accepted_human_review_rows']}/{v61di['expected_human_review_rows']}"},
    {"gap": "generation-result-return", "status": "blocked", "reason": f"accepted_generation_result_artifacts={v61di['accepted_generation_result_artifacts']}/{v61di['expected_generation_result_artifacts']}"},
    {"gap": "actual-model-generation", "status": "blocked", "reason": f"actual_model_generation_ready={v61di['actual_model_generation_ready']}"},
]
write_csv(run_dir / "runtime_gap_rows.csv", list(runtime_gap_rows[0].keys()), runtime_gap_rows)

satisfied_artifacts = sum(row["contract_status"] == "satisfied" for row in artifact_rows)
unsatisfied_artifacts = len(artifact_rows) - satisfied_artifacts
review_family = next(row for row in family_rows if row["external_return_family"] == "aggregate-review-return")
generation_family = next(row for row in family_rows if row["external_return_family"] == "generation-result-return")
ready_commands = sum(row["ready_to_run_now"] == "1" for row in command_rows)

metric = {
    "metric_id": "v61dj_post_claim_return_evidence_contract_gate_metrics",
    "v61di_post_claim_generation_unblock_audit_gate_ready": v61di["v61di_post_claim_generation_unblock_audit_gate_ready"],
    "v61df_external_review_generation_return_operator_packet_ready": v61df["v61df_external_review_generation_return_operator_packet_ready"],
    "v53al_complete_source_external_return_bundle_preflight_ready": v53al["v53al_complete_source_external_return_bundle_preflight_ready"],
    "source_gate_rows": "3",
    "contract_surface_ready": "1",
    "return_contract_blocker_rows": str(len(blocker_rows)),
    "unsatisfied_return_contract_blocker_rows": str(len(blocker_rows)),
    "return_artifact_contract_rows": str(len(artifact_rows)),
    "satisfied_return_artifact_contract_rows": str(satisfied_artifacts),
    "unsatisfied_return_artifact_contract_rows": str(unsatisfied_artifacts),
    "return_artifact_family_rows": str(len(family_rows)),
    "return_contract_command_rows": str(len(command_rows)),
    "ready_return_contract_command_rows": str(ready_commands),
    "preflight_surface_ready": v53al["preflight_surface_ready"],
    "return_bundle_preflight_pass": v53al["return_bundle_preflight_pass"],
    "preflight_rows": v53al["preflight_rows"],
    "preflight_pass_rows": v53al["preflight_pass_rows"],
    "preflight_missing_rows": v53al["preflight_missing_rows"],
    "review_return_required_artifacts": v61df["review_return_required_artifacts"],
    "generation_result_required_artifacts": v61df["generation_result_required_artifacts"],
    "review_return_expected_rows": review_family["expected_rows"],
    "review_return_accepted_rows": review_family["accepted_rows"],
    "review_return_missing_rows": review_family["missing_rows"],
    "generation_result_expected_rows": generation_family["expected_rows"],
    "generation_result_accepted_contract_rows": generation_family["accepted_rows"],
    "generation_result_missing_rows": generation_family["missing_rows"],
    "accepted_human_review_rows": v61di["accepted_human_review_rows"],
    "expected_human_review_rows": v61di["expected_human_review_rows"],
    "accepted_adjudication_rows": v61di["accepted_adjudication_rows"],
    "expected_adjudication_rows": v61di["expected_adjudication_rows"],
    "runtime_admission_accepted_rows": v61di["runtime_admission_accepted_rows"],
    "generation_execution_admitted_rows": v61di["generation_execution_admitted_rows"],
    "generation_execution_admission_rows": v61di["generation_execution_admission_rows"],
    "accepted_generation_result_artifacts": v61di["accepted_generation_result_artifacts"],
    "expected_generation_result_artifacts": v61di["expected_generation_result_artifacts"],
    "generation_result_accepted_rows": v61di["generation_result_accepted_rows"],
    "generation_result_acceptance_rows": v61di["generation_result_acceptance_rows"],
    "actual_model_generation_ready": v61di["actual_model_generation_ready"],
    "v1_0_comparison_ready": v61di["v1_0_comparison_ready"],
    "near_frontier_claim_ready": "0",
    "production_latency_claim_ready": "0",
    "real_release_package_ready": "0",
    "checkpoint_payload_bytes_downloaded_by_v61dj": "0",
    "checkpoint_payload_bytes_committed_to_repo": "0",
    "route_jump_rows": "0",
}
write_csv(run_dir / "return_evidence_contract_metric_rows.csv", list(metric.keys()), [metric])

summary = {
    "v61dj_post_claim_return_evidence_contract_gate_ready": "1",
    **{key: value for key, value in metric.items() if key != "metric_id"},
}
write_csv(summary_csv, list(summary.keys()), [summary])

decision_rows = [
    {"gate": "contract-surface-ready", "status": "pass", "reason": "return evidence contract rows emitted"},
    {"gate": "source-v61di-ready", "status": "pass", "reason": "v61di unblock audit is ready"},
    {"gate": "source-v61df-ready", "status": "pass", "reason": "v61df operator packet is ready"},
    {"gate": "source-v53al-ready", "status": "pass", "reason": "v53al preflight surface is ready"},
    {"gate": "return-bundle-preflight-pass", "status": "blocked", "reason": "return_bundle_preflight_pass=0"},
    {"gate": "aggregate-review-return-contract", "status": "blocked", "reason": f"review_return_accepted_rows={review_family['accepted_rows']}/{review_family['expected_rows']}"},
    {"gate": "generation-result-return-contract", "status": "blocked", "reason": f"generation_result_accepted_contract_rows={generation_family['accepted_rows']}/{generation_family['expected_rows']}"},
    {"gate": "actual-model-generation", "status": "blocked", "reason": "actual_model_generation_ready=0"},
    {"gate": "manifest-only-no-repo-payload", "status": "pass", "reason": "checkpoint payload bytes committed to repo remain 0"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

boundary = f"""# v61dj Post-Claim Return Evidence Contract Gate

This gate turns the remaining v61di generation-unblock blockers into a
machine-readable return evidence contract. It consumes v61di, v61df, and v53al;
it does not create review rows, generation rows, latency evidence, or release
evidence.

Evidence emitted:

- return_contract_blocker_rows={len(blocker_rows)}
- unsatisfied_return_contract_blocker_rows={len(blocker_rows)}
- return_artifact_contract_rows={len(artifact_rows)}
- satisfied_return_artifact_contract_rows={satisfied_artifacts}
- unsatisfied_return_artifact_contract_rows={unsatisfied_artifacts}
- return_artifact_family_rows={len(family_rows)}
- return_contract_command_rows={len(command_rows)}
- ready_return_contract_command_rows={ready_commands}
- return_bundle_preflight_pass={v53al['return_bundle_preflight_pass']}
- preflight_pass_rows={v53al['preflight_pass_rows']}/{v53al['preflight_rows']}
- preflight_missing_rows={v53al['preflight_missing_rows']}
- review_return_required_artifacts={v61df['review_return_required_artifacts']}
- generation_result_required_artifacts={v61df['generation_result_required_artifacts']}
- review_return_expected_rows={review_family['expected_rows']}
- review_return_accepted_rows={review_family['accepted_rows']}
- generation_result_expected_rows={generation_family['expected_rows']}
- generation_result_accepted_contract_rows={generation_family['accepted_rows']}
- accepted_human_review_rows={v61di['accepted_human_review_rows']}/{v61di['expected_human_review_rows']}
- accepted_adjudication_rows={v61di['accepted_adjudication_rows']}/{v61di['expected_adjudication_rows']}
- runtime_admission_accepted_rows={v61di['runtime_admission_accepted_rows']}
- generation_execution_admitted_rows={v61di['generation_execution_admitted_rows']}/{v61di['generation_execution_admission_rows']}
- accepted_generation_result_artifacts={v61di['accepted_generation_result_artifacts']}/{v61di['expected_generation_result_artifacts']}
- generation_result_accepted_rows={v61di['generation_result_accepted_rows']}/{v61di['generation_result_acceptance_rows']}
- actual_model_generation_ready={v61di['actual_model_generation_ready']}
- checkpoint_payload_bytes_downloaded_by_v61dj=0

Allowed wording: return evidence contract is ready.
Blocked wording: returned review evidence accepted, generation result evidence
accepted, actual generation, v1.0 comparison, latency, near-frontier quality,
or release readiness.
"""
(run_dir / "V61DJ_POST_CLAIM_RETURN_EVIDENCE_CONTRACT_GATE_BOUNDARY.md").write_text(boundary, encoding="utf-8")

manifest = {
    "manifest_scope": "v61dj-post-claim-return-evidence-contract-gate",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v61dj_post_claim_return_evidence_contract_gate_ready": 1,
    "contract_surface_ready": 1,
    "return_contract_blocker_rows": len(blocker_rows),
    "unsatisfied_return_contract_blocker_rows": len(blocker_rows),
    "return_artifact_contract_rows": len(artifact_rows),
    "satisfied_return_artifact_contract_rows": satisfied_artifacts,
    "unsatisfied_return_artifact_contract_rows": unsatisfied_artifacts,
    "return_bundle_preflight_pass": as_int(v53al, "return_bundle_preflight_pass"),
    "actual_model_generation_ready": as_int(v61di, "actual_model_generation_ready"),
    "v1_0_comparison_ready": as_int(v61di, "v1_0_comparison_ready"),
    "real_release_package_ready": 0,
    "checkpoint_payload_bytes_committed_to_repo": 0,
}
(run_dir / "v61dj_post_claim_return_evidence_contract_gate_manifest.json").write_text(
    json.dumps(manifest, indent=2, sort_keys=True) + "\n",
    encoding="utf-8",
)

sha_rows = []
for path in sorted(run_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(run_dir)), "sha256": sha256(path), "bytes": str(path.stat().st_size)})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], sha_rows)
PY

echo "v61dj_post_claim_return_evidence_contract_gate_dir: $RUN_DIR"
echo "summary: $SUMMARY_CSV"
echo "decision: $DECISION_CSV"
