#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v60_architecture_challenge_release_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v60_architecture_challenge_release_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v60_architecture_challenge_release_contract_decision.csv"

"$ROOT_DIR/experiments/run_v60_architecture_challenge_release_contract.sh" >/dev/null

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
    raise SystemExit(f"expected one v60 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v60_release_contract_ready": "1",
    "v60_ready": "0",
    "release_requirement_rows": "10",
    "release_requirement_ready_rows": "0",
    "release_requirement_blocked_rows": "10",
    "allowed_claim_rows": "2",
    "forbidden_claim_rows": "8",
    "v59_one_command_challenge_demo_contract_ready": "1",
    "v59_ready": "0",
    "real_30b_70b_rows_ready": "0",
    "public_repo_query_scale_ready": "0",
    "routehint_generation_main_ready": "0",
    "scaling_law_main_ready": "0",
    "expanded_benchmark_ready": "0",
    "domain_expert_pack_ready": "0",
    "blind_eval_ready": "0",
    "one_command_real_replay_ready": "0",
    "human_release_review_ready": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v60 {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v60-release-contract", "v59-contract-input", "claim-boundary"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v60 gate should pass: {gate}")
for gate in [
    "real-30b-70b-baselines",
    "full-scale-code-doc-qa",
    "generation-scaling-benchmark-domain-blind-main-runs",
    "human-release-review",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v60 gate should remain blocked: {gate}")

required_files = [
    "release_requirement_rows.csv",
    "allowed_claim_rows.csv",
    "forbidden_claim_rows.csv",
    "release_decision_rows.csv",
    "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md",
    "v60_architecture_challenge_release_manifest.json",
    "sha256_manifest.csv",
    "source_v59/challenge_stage_contract_rows.csv",
    "source_v59/one_command_demo_rows.csv",
    "source_v59/one_command_demo_gate_rows.csv",
    "source_v59/README_RESULT.md",
    "source_v59/V59_ONE_COMMAND_CHALLENGE_DEMO_BOUNDARY.md",
    "source_v59/v59_one_command_challenge_demo_manifest.json",
    "source_v59/sha256_manifest.csv",
    "source_v59/v59_one_command_challenge_demo_contract_summary.csv",
    "source_v59/v59_one_command_challenge_demo_contract_decision.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v60 artifact: {rel}")

requirements = read_csv(run_dir / "release_requirement_rows.csv")
if len(requirements) != 10:
    raise SystemExit("v60 should list ten release requirements")
if any(row["ready"] != "0" or row["status"] != "blocked" for row in requirements):
    raise SystemExit("v60 release requirements should all remain blocked")

allowed = read_csv(run_dir / "allowed_claim_rows.csv")
for claim in ["architecture-challenge-contract-scaffold", "local-architecture-preview"]:
    if claim not in {row["claim_id"] for row in allowed}:
        raise SystemExit(f"v60 allowed claim missing {claim}")

forbidden = {row["claim_id"] for row in read_csv(run_dir / "forbidden_claim_rows.csv")}
for claim in [
    "v1_0_release_ready",
    "beats_30b_150b_llm_rag",
    "transformer_replacement",
    "frontier_local_llm_equivalence",
    "long_context_solved",
    "gpu_or_hip_acceleration",
    "expert_replacement",
    "production_release",
]:
    if claim not in forbidden:
        raise SystemExit(f"v60 forbidden claim missing {claim}")

manifest = json.loads((run_dir / "v60_architecture_challenge_release_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v60_release_contract_ready") != 1 or manifest.get("v60_ready") != 0:
    raise SystemExit("v60 manifest readiness boundary mismatch")
if manifest.get("real_release_package_ready") != 0 or manifest.get("release_requirement_blocked_rows") != 10:
    raise SystemExit("v60 manifest should keep release blocked")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v60 sha256 mismatch: {rel}")

boundary = (run_dir / "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed v1.0 Architecture Challenge Release",
    "Allowed wording",
    "real 30B/70B/100B+ LLM+RAG comparison rows",
    "Do not publish v1.0 release",
]:
    if snippet not in boundary:
        raise SystemExit(f"v60 boundary missing {snippet}")
PY

echo "v60 architecture challenge release contract smoke passed"
