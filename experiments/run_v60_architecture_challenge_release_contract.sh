#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v60_architecture_challenge_release_contract"
RUN_ID="${V60_CONTRACT_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v59_one_command_challenge_demo_contract.sh" >/dev/null

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

v59_dir = results / "v59_one_command_challenge_demo_contract" / "contract_001"
v59_summary = list(csv.DictReader((results / "v59_one_command_challenge_demo_contract_summary.csv").open(newline="", encoding="utf-8")))[0]


def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def copy(src, rel):
    dst = run_dir / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    return dst


for rel in [
    "challenge_stage_contract_rows.csv",
    "one_command_demo_rows.csv",
    "one_command_demo_gate_rows.csv",
    "README_RESULT.md",
    "V59_ONE_COMMAND_CHALLENGE_DEMO_BOUNDARY.md",
    "v59_one_command_challenge_demo_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v59_dir / rel, f"source_v59/{rel}")
copy(results / "v59_one_command_challenge_demo_contract_summary.csv", "source_v59/v59_one_command_challenge_demo_contract_summary.csv")
copy(results / "v59_one_command_challenge_demo_contract_decision.csv", "source_v59/v59_one_command_challenge_demo_contract_decision.csv")

requirements = [
    ("v52_30b_70b_llm_rag_baselines", 0, "real 30B and 70B LLM+RAG rows are missing"),
    ("v53_public_repo_query_scale", 0, "10+ public repos and 1000+ source-span-bound query rows are missing"),
    ("v54_routehint_generation_main_run", 0, "1000+ grounded RouteHint generation rows are missing"),
    ("v55_scaling_law_main_run", 0, "six-axis / 100+ row scaling main run is missing"),
    ("v56_expanded_ruler_longbench", 0, "expanded RULER/LongBench main rows are missing"),
    ("v57_domain_expert_packs", 0, "human-reviewed domain expert pack rows are missing"),
    ("v58_blind_eval", 0, "500+ blind eval rows and human review are missing"),
    ("v59_one_command_replay", 0, "one command currently replays contracts, not real measured rows"),
    ("human_release_review", 0, "human/release review return is missing"),
    ("release_artifact_package", 0, "release artifact package is not assembled from real rows"),
]
requirement_rows = []
for requirement, ready, blocker in requirements:
    requirement_rows.append(
        {
            "requirement": requirement,
            "required_for_v1_0_release": 1,
            "ready": ready,
            "status": "pass" if ready else "blocked",
            "blocking_reason": blocker,
        }
    )
write_csv(run_dir / "release_requirement_rows.csv", list(requirement_rows[0].keys()), requirement_rows)

allowed_claim_rows = [
    {
        "claim_id": "architecture-challenge-contract-scaffold",
        "status": "allowed_limited",
        "public_wording": "v1.0 Architecture Challenge contract scaffold covering v52-v60 gates",
        "evidence": "v52-v59 contract artifacts plus v60 release audit contract",
    },
    {
        "claim_id": "local-architecture-preview",
        "status": "allowed_limited",
        "public_wording": "local evidence-bound RouteMemory/RouteHint QA and audit preview",
        "evidence": "v0.3/v52-v59 contract artifacts",
    },
]
write_csv(run_dir / "allowed_claim_rows.csv", list(allowed_claim_rows[0].keys()), allowed_claim_rows)

forbidden_claim_rows = [
    ("v1_0_release_ready", "v60_ready=0 and real_release_package_ready=0"),
    ("beats_30b_150b_llm_rag", "30B/70B/100B+ real rows and blind-eval rows are missing"),
    ("transformer_replacement", "architecture replacement evidence is not supplied"),
    ("frontier_local_llm_equivalence", "no 30B-150B-class measured equivalence evidence"),
    ("long_context_solved", "expanded RULER/LongBench main rows are missing"),
    ("gpu_or_hip_acceleration", "GPU/HIP speedup evidence is not part of v52-v60 contracts"),
    ("expert_replacement", "v57 keeps expert_replacement_claim=0"),
    ("production_release", "human/release review and real package are missing"),
]
write_csv(
    run_dir / "forbidden_claim_rows.csv",
    ["claim_id", "blocking_reason"],
    [{"claim_id": claim_id, "blocking_reason": reason} for claim_id, reason in forbidden_claim_rows],
)

decision_rows = [
    ("v60-release-contract", "pass", "release requirements, allowed claims, forbidden claims, and source v59 bundle are emitted"),
    ("v59-contract-input", "pass", "v59 one-command contract bundle is present"),
    ("claim-boundary", "pass", "allowed claims are bounded and forbidden claims are explicit"),
    ("real-30b-70b-baselines", "blocked", "real 30B/70B LLM+RAG rows are missing"),
    ("full-scale-code-doc-qa", "blocked", "v53 public repo/query scale is missing"),
    ("generation-scaling-benchmark-domain-blind-main-runs", "blocked", "v54-v58 main evidence rows are missing"),
    ("human-release-review", "blocked", "human/release review return is missing"),
    ("real-release-package", "blocked", "real_release_package_ready remains 0"),
]
write_csv(
    run_dir / "release_decision_rows.csv",
    ["gate", "status", "reason"],
    [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in decision_rows],
)

summary = {
    "v60_release_contract_ready": 1,
    "v60_ready": 0,
    "release_requirement_rows": len(requirement_rows),
    "release_requirement_ready_rows": sum(int(row["ready"]) for row in requirement_rows),
    "release_requirement_blocked_rows": sum(1 for row in requirement_rows if row["status"] == "blocked"),
    "allowed_claim_rows": len(allowed_claim_rows),
    "forbidden_claim_rows": len(forbidden_claim_rows),
    "v59_one_command_challenge_demo_contract_ready": int(v59_summary.get("v59_one_command_challenge_demo_contract_ready", "0")),
    "v59_ready": int(v59_summary.get("v59_ready", "0")),
    "real_30b_70b_rows_ready": 0,
    "public_repo_query_scale_ready": 0,
    "routehint_generation_main_ready": 0,
    "scaling_law_main_ready": 0,
    "expanded_benchmark_ready": 0,
    "domain_expert_pack_ready": 0,
    "blind_eval_ready": 0,
    "one_command_real_replay_ready": 0,
    "human_release_review_ready": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decision_rows)

(run_dir / "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md").write_text(
    "# v60 Architecture Challenge Release Boundary\n\n"
    "This is the v60 release-audit contract scaffold, not the completed v1.0 Architecture Challenge Release.\n\n"
    "Allowed wording:\n\n"
    "- v1.0 Architecture Challenge contract scaffold covering v52-v60 gates.\n"
    "- local evidence-bound RouteMemory/RouteHint QA and audit preview.\n\n"
    "Still blocked:\n\n"
    "- real 30B/70B/100B+ LLM+RAG comparison rows\n"
    "- full public repo/query scale\n"
    "- RouteHint generation, scaling-law, expanded benchmark, domain-pack, blind-eval main rows\n"
    "- one-command replay over real measured rows\n"
    "- human/release review\n"
    "- real release package\n\n"
    "Do not publish v1.0 release, 30B-150B win, Transformer replacement, frontier local LLM, long-context solved, GPU acceleration, expert replacement, or production-release claims from this scaffold.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v60-architecture-challenge-release-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v60_release_contract_ready": 1,
    "v60_ready": 0,
    "real_release_package_ready": 0,
    "release_requirement_rows": len(requirement_rows),
    "release_requirement_blocked_rows": sum(1 for row in requirement_rows if row["status"] == "blocked"),
    "allowed_claim_rows": len(allowed_claim_rows),
    "forbidden_claim_rows": len(forbidden_claim_rows),
    "v59_summary_sha256": sha256(results / "v59_one_command_challenge_demo_contract_summary.csv"),
    "v59_manifest_sha256": sha256(v59_dir / "v59_one_command_challenge_demo_manifest.json"),
}
(run_dir / "v60_architecture_challenge_release_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "release_requirement_rows.csv",
    "allowed_claim_rows.csv",
    "forbidden_claim_rows.csv",
    "release_decision_rows.csv",
    "V60_ARCHITECTURE_CHALLENGE_RELEASE_BOUNDARY.md",
    "v60_architecture_challenge_release_manifest.json",
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
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v60_architecture_challenge_release_contract_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
