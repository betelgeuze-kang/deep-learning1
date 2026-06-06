#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v60b_release_preflight_candidate_audit/preflight_001"
SUMMARY_CSV="$RESULTS_DIR/v60b_release_preflight_candidate_audit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v60b_release_preflight_candidate_audit_decision.csv"

V60B_REUSE_EXISTING="${V60B_REUSE_EXISTING:-1}" "$ROOT_DIR/experiments/run_v60b_release_preflight_candidate_audit.sh" >/dev/null

python3 - "$RUN_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import sys
from pathlib import Path

run_dir = Path(sys.argv[1])
summary_csv = Path(sys.argv[2])
decision_csv = Path(sys.argv[3])


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


summary_rows = read_csv(summary_csv)
if len(summary_rows) != 1:
    raise SystemExit(f"expected one v60b summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v60b_release_preflight_candidate_audit_ready": "1",
    "v60_ready": "0",
    "v59b_one_command_candidate_demo_ready": "1",
    "v59_ready": "0",
    "candidate_stage_rows": "12",
    "candidate_ready_stage_rows": "12",
    "full_ready_stage_rows": "3",
    "release_requirement_rows": "11",
    "release_requirement_ready_rows": "3",
    "release_requirement_blocked_rows": "8",
    "allowed_limited_claim_rows": "1",
    "forbidden_claim_rows": "5",
    "real_30b_70b_rows_ready": "0",
    "complete_source_audit_ready": "0",
    "human_domain_review_ready": "0",
    "human_blind_review_ready": "0",
    "human_release_review_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v60b {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v59b-candidate-input", "candidate-preflight-audit", "candidate-chain-hash-binding"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v60b gate should pass: {gate}")
for gate in [
    "v1-release-ready",
    "real-llm-baseline-comparison",
    "complete-code-doc-qa-review",
    "real-blind-eval",
    "release-artifact-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v60b gate should remain blocked: {gate}")

required_files = [
    "release_preflight_requirement_rows.csv",
    "release_preflight_claim_rows.csv",
    "stage_release_audit_rows.csv",
    "release_preflight_decision_rows.csv",
    "V60B_RELEASE_PREFLIGHT_CANDIDATE_AUDIT_BOUNDARY.md",
    "v60b_release_preflight_candidate_audit_manifest.json",
    "sha256_manifest.csv",
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
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v60b artifact: {rel}")

requirements = read_csv(run_dir / "release_preflight_requirement_rows.csv")
if len(requirements) != 11:
    raise SystemExit("v60b should list eleven release preflight requirements")
ready = {row["requirement"] for row in requirements if row["ready"] == "1"}
if ready != {"candidate_chain_replay", "one_command_candidate_entrypoint", "candidate_artifact_hashes"}:
    raise SystemExit(f"v60b ready requirement mismatch: {ready}")
if any(row["status"] != ("pass" if row["ready"] == "1" else "blocked") for row in requirements):
    raise SystemExit("v60b requirement status should match readiness")

claims = {row["claim_id"]: row["status"] for row in read_csv(run_dir / "release_preflight_claim_rows.csv")}
if claims.get("candidate_chain_replay_ready") != "allowed_limited":
    raise SystemExit("v60b should allow only candidate-chain replay wording")
for claim in ["v1_0_release_ready", "beats_30b_150b_llm_rag", "safe_grounded_code_doc_qa_superiority", "expert_replacement", "production_release"]:
    if claims.get(claim) != "forbidden":
        raise SystemExit(f"v60b forbidden claim missing: {claim}")

stage_audit = read_csv(run_dir / "stage_release_audit_rows.csv")
if len(stage_audit) != 12:
    raise SystemExit("v60b should audit 12 candidate stages")
if any(row["release_acceptable"] != "0" for row in stage_audit):
    raise SystemExit("v60b should not mark candidate stages release-acceptable")

manifest = json.loads((run_dir / "v60b_release_preflight_candidate_audit_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v60b_release_preflight_candidate_audit_ready") != 1 or manifest.get("v60_ready") != 0:
    raise SystemExit("v60b manifest readiness mismatch")
if manifest.get("release_requirement_blocked_rows") != 8 or manifest.get("real_release_package_ready") != 0:
    raise SystemExit("v60b manifest should keep release blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v60b sha256 mismatch: {rel}")

boundary = (run_dir / "V60B_RELEASE_PREFLIGHT_CANDIDATE_AUDIT_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "consumes the v59b one-command candidate replay",
    "not the v1.0 Architecture Challenge Release",
    "Allowed limited wording",
    "Do not publish v1.0 release readiness",
]:
    if snippet not in boundary:
        raise SystemExit(f"v60b boundary missing {snippet}")
PY

echo "v60b release preflight candidate audit smoke passed"
