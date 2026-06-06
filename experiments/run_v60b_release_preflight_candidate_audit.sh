#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v60b_release_preflight_candidate_audit"
RUN_ID="${V60B_RUN_ID:-preflight_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

if [[ "${V60B_REUSE_EXISTING:-1}" != "1" || ! -s "$RESULTS_DIR/v59b_one_command_candidate_demo_summary.csv" ]]; then
  V59B_REUSE_EXISTING="${V59B_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v59b_one_command_candidate_demo.sh" >/dev/null
fi

python3 - "$ROOT_DIR" "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime, timezone
from pathlib import Path

root = Path(sys.argv[1])
run_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results = root / "results"

v59b_dir = results / "v59b_one_command_candidate_demo" / "candidate_001"
v59b_summary_path = results / "v59b_one_command_candidate_demo_summary.csv"
v59b_decision_path = results / "v59b_one_command_candidate_demo_decision.csv"
v59b_summary = list(csv.DictReader(v59b_summary_path.open(newline="", encoding="utf-8")))[0]
v59b_decisions = list(csv.DictReader(v59b_decision_path.open(newline="", encoding="utf-8")))


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


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


source_rels = [
    "candidate_stage_replay_rows.csv",
    "candidate_one_command_rows.csv",
    "candidate_demo_gate_rows.csv",
    "README_RESULT.md",
    "V59B_ONE_COMMAND_CANDIDATE_DEMO_BOUNDARY.md",
    "v59b_one_command_candidate_demo_manifest.json",
    "sha256_manifest.csv",
]
for relpath in source_rels:
    copy(v59b_dir / relpath, f"source_v59b/{relpath}")
copy(v59b_summary_path, "source_v59b/v59b_one_command_candidate_demo_summary.csv")
copy(v59b_decision_path, "source_v59b/v59b_one_command_candidate_demo_decision.csv")

stage_rows = list(csv.DictReader((v59b_dir / "candidate_stage_replay_rows.csv").open(newline="", encoding="utf-8")))
gate_by_name = {row["gate"]: row for row in v59b_decisions}

preflight_requirements = [
    ("candidate_chain_replay", 1, "v59b candidate/intake chain replay is present"),
    ("one_command_candidate_entrypoint", 1, "candidate entrypoint exists and is hash-bound"),
    ("candidate_artifact_hashes", 1, "v59b candidate artifacts have sha256 coverage"),
    ("real_30b_70b_llm_rag_rows", 0, "real D/E 30B/70B LLM+RAG rows are missing"),
    ("optional_100b_plus_row_or_final_deferral", 0, "F is still optional/deferred without a final release decision"),
    ("complete_source_public_repo_audit", 0, "v53 remains canary-scope rather than complete-source audit"),
    ("human_domain_expert_review", 0, "v57b rows are not human-reviewed"),
    ("human_blind_review_and_inter_rater", 0, "v58b has templates but no human blind review/adjudication"),
    ("full_one_command_real_replay", 0, "v59b replays candidate/intake rows, not real measured/reviewed rows"),
    ("human_release_review", 0, "release review return is missing"),
    ("release_artifact_package", 0, "release package is not assembled from real rows"),
]
requirement_rows = []
for requirement, ready, reason in preflight_requirements:
    requirement_rows.append(
        {
            "requirement": requirement,
            "required_for_release": 1,
            "ready": ready,
            "status": "pass" if ready else "blocked",
            "blocking_reason": "" if ready else reason,
            "evidence": reason if ready else "",
        }
    )
write_csv(run_dir / "release_preflight_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

claim_rows = [
    ("candidate_chain_replay_ready", "allowed_limited", "The current v52b-v58b candidate/intake chain can be replayed from one command."),
    ("v1_0_release_ready", "forbidden", "real release package and release review are missing"),
    ("beats_30b_150b_llm_rag", "forbidden", "real D/E/F comparison and blind-review rows are missing"),
    ("safe_grounded_code_doc_qa_superiority", "forbidden", "complete-source A-H code/doc QA comparison rows are missing"),
    ("expert_replacement", "forbidden", "human expert pack review is missing and replacement claims are blocked"),
    ("production_release", "forbidden", "release package is not assembled from real rows"),
]
write_csv(
    run_dir / "release_preflight_claim_rows.csv",
    ["claim_id", "status", "reason"],
    [{"claim_id": claim_id, "status": status, "reason": reason} for claim_id, status, reason in claim_rows],
)

stage_audit_rows = []
for row in stage_rows:
    stage = row["stage"]
    candidate_ready = int(row["candidate_ready"])
    full_ready = int(row["full_ready"])
    stage_audit_rows.append(
        {
            "stage": stage,
            "candidate_ready": candidate_ready,
            "full_ready": full_ready,
            "release_acceptable": 0,
            "release_blocker": "" if full_ready else f"{stage} is candidate/intake evidence only or lacks required review/real rows",
        }
    )
write_csv(run_dir / "stage_release_audit_rows.csv", list(stage_audit_rows[0].keys()), stage_audit_rows)

decision_rows = [
    ("v59b-candidate-input", "pass", "v59b candidate replay bundle is present"),
    ("candidate-preflight-audit", "pass", "release requirements, claim rows, and stage audit rows are emitted"),
    ("candidate-chain-hash-binding", "pass", "copied v59b artifacts and this audit have sha256 manifests"),
    ("v1-release-ready", "blocked", "release requirements remain blocked"),
    ("real-llm-baseline-comparison", "blocked", "real 30B/70B/100B+ comparison rows are missing"),
    ("complete-code-doc-qa-review", "blocked", "complete-source audit and human review are missing"),
    ("real-blind-eval", "blocked", "human blind review and inter-rater rows are missing"),
    ("release-artifact-package", "blocked", "real release package is missing"),
]
write_csv(decision_csv, ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])
write_csv(run_dir / "release_preflight_decision_rows.csv", ["gate", "status", "reason"], [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows])

summary = {
    "v60b_release_preflight_candidate_audit_ready": 1,
    "v60_ready": 0,
    "v59b_one_command_candidate_demo_ready": int(v59b_summary.get("v59b_one_command_candidate_demo_ready", "0")),
    "v59_ready": int(v59b_summary.get("v59_ready", "0")),
    "candidate_stage_rows": int(v59b_summary.get("candidate_stage_rows", "0")),
    "candidate_ready_stage_rows": int(v59b_summary.get("candidate_ready_stage_rows", "0")),
    "full_ready_stage_rows": int(v59b_summary.get("full_ready_stage_rows", "0")),
    "release_requirement_rows": len(requirement_rows),
    "release_requirement_ready_rows": sum(int(row["ready"]) for row in requirement_rows),
    "release_requirement_blocked_rows": sum(1 for row in requirement_rows if row["status"] == "blocked"),
    "allowed_limited_claim_rows": sum(1 for _, status, _ in claim_rows if status == "allowed_limited"),
    "forbidden_claim_rows": sum(1 for _, status, _ in claim_rows if status == "forbidden"),
    "real_30b_70b_rows_ready": 0,
    "complete_source_audit_ready": 0,
    "human_domain_review_ready": 0,
    "human_blind_review_ready": 0,
    "human_release_review_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

(run_dir / "V60B_RELEASE_PREFLIGHT_CANDIDATE_AUDIT_BOUNDARY.md").write_text(
    "# v60b Release Preflight Candidate Audit Boundary\n\n"
    "This audit consumes the v59b one-command candidate replay and checks release blockers. "
    "It is not the v1.0 Architecture Challenge Release.\n\n"
    f"- candidate_stage_rows={summary['candidate_stage_rows']}\n"
    f"- candidate_ready_stage_rows={summary['candidate_ready_stage_rows']}\n"
    f"- full_ready_stage_rows={summary['full_ready_stage_rows']}\n"
    f"- release_requirement_blocked_rows={summary['release_requirement_blocked_rows']}\n"
    "- real_30b_70b_rows_ready=0\n"
    "- human_blind_review_ready=0\n"
    "- real_release_package_ready=0\n\n"
    "Allowed limited wording: the current candidate/intake chain can be replayed from one command.\n\n"
    "Do not publish v1.0 release readiness, 30B-150B comparison wins, safe grounded QA superiority, expert replacement, or production-release claims from this preflight audit.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v60b-release-preflight-candidate-audit",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v60b_release_preflight_candidate_audit_ready": 1,
    "v60_ready": 0,
    "v59b_summary_sha256": sha256(v59b_summary_path),
    "v59b_manifest_sha256": sha256(v59b_dir / "v59b_one_command_candidate_demo_manifest.json"),
    "release_requirement_blocked_rows": summary["release_requirement_blocked_rows"],
    "real_release_package_ready": 0,
}
(run_dir / "v60b_release_preflight_candidate_audit_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "release_preflight_requirement_rows.csv",
    "release_preflight_claim_rows.csv",
    "stage_release_audit_rows.csv",
    "release_preflight_decision_rows.csv",
    "V60B_RELEASE_PREFLIGHT_CANDIDATE_AUDIT_BOUNDARY.md",
    "v60b_release_preflight_candidate_audit_manifest.json",
    "source_v59b/candidate_stage_replay_rows.csv",
    "source_v59b/candidate_one_command_rows.csv",
    "source_v59b/candidate_demo_gate_rows.csv",
    "source_v59b/README_RESULT.md",
    "source_v59b/V59B_ONE_COMMAND_CANDIDATE_DEMO_BOUNDARY.md",
    "source_v59b/v59b_one_command_candidate_demo_manifest.json",
    "source_v59b/sha256_manifest.csv",
    "source_v59b/v59b_one_command_candidate_demo_summary.csv",
    "source_v59b/v59b_one_command_candidate_demo_decision.csv",
]
artifact_rows = []
for relpath in artifact_rels:
    path = run_dir / relpath
    artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v60b_release_preflight_candidate_audit_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
