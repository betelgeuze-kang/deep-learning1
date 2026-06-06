#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v58_blind_eval_contract"
RUN_ID="${V58_CONTRACT_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v57_domain_expert_packs_contract.sh" >/dev/null

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

v52_dir = results / "v52_llm_rag_baseline_war" / "baseline_001"
v57_dir = results / "v57_domain_expert_packs_contract" / "contract_001"
v52_summary = list(csv.DictReader((results / "v52_llm_rag_baseline_war_summary.csv").open(newline="", encoding="utf-8")))[0]
v57_summary = list(csv.DictReader((results / "v57_domain_expert_packs_contract_summary.csv").open(newline="", encoding="utf-8")))[0]


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
    "baseline_registry.csv",
    "evaluation_contract_rows.csv",
    "score_axis_rows.csv",
    "V52_BASELINE_WAR_BOUNDARY.md",
    "v52_llm_rag_baseline_war_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v52_dir / rel, f"source_v52/{rel}")
for rel in [
    "domain_pack_target_rows.csv",
    "expert_review_contract_rows.csv",
    "domain_policy_gate_rows.csv",
    "V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md",
    "v57_domain_expert_packs_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v57_dir / rel, f"source_v57/{rel}")

system_rows = [
    ("blind_A", "D", "30B open-weight LLM + RAG", "required", 0, "30b-open-weight-rag-run-missing"),
    ("blind_B", "E", "70B open-weight LLM + RAG", "required", 0, "70b-open-weight-rag-run-missing"),
    ("blind_C", "F", "100B+ API or hosted model + RAG", "optional-preferred", 0, "100b-plus-hosted-api-credentials-or-run-missing"),
    ("blind_D", "G", "RouteMemory + RouteHint", "required", 1, ""),
    ("blind_E", "H", "RouteMemory + RouteHint + source-verified scorer + domain policy", "required", 1, ""),
]
blind_system_rows = []
for blind_id, system_id, system_name, required_status, seed_ready, blocker in system_rows:
    blind_system_rows.append(
        {
            "blind_system_id": blind_id,
            "source_system_id": system_id,
            "source_system_name": system_name,
            "required_status": required_status,
            "seed_response_ready": seed_ready,
            "real_blind_response_ready": 0,
            "identity_hidden_from_reviewer": 1,
            "same_query_set_required": 1,
            "same_evidence_budget_required": 1,
            "citation_required": 1,
            "abstain_required": 1,
            "blocking_reason": blocker,
        }
    )
write_csv(run_dir / "blind_system_mapping_rows.csv", list(blind_system_rows[0].keys()), blind_system_rows)

query_rows = [
    ("codebase_qa", 180, "v53-public-repo-query-freeze-required"),
    ("internal_docs_qa", 80, "v57-domain-pack-query-freeze-required"),
    ("ruler_niah", 80, "v56-official-source-query-freeze-required"),
    ("longbench_v2", 80, "v56-official-source-query-freeze-required"),
    ("incident_log_qa", 40, "v57-domain-pack-query-freeze-required"),
    ("product_manual_qa", 40, "v57-domain-pack-query-freeze-required"),
]
blind_query_rows = []
for domain, target_rows, freeze_source in query_rows:
    blind_query_rows.append(
        {
            "domain": domain,
            "target_blind_eval_rows": target_rows,
            "seed_blind_eval_rows": 0,
            "missing_blind_eval_rows": target_rows,
            "query_freeze_required": 1,
            "pre_output_query_selection_required": 1,
            "negative_controls_required": 1,
            "source_span_bound_required": 1,
            "freeze_source": freeze_source,
        }
    )
write_csv(run_dir / "blind_eval_query_contract_rows.csv", list(blind_query_rows[0].keys()), blind_query_rows)

evaluator_contract_rows = [
    ("reviewer_packet", "required", "blind response rows without system identity"),
    ("system_key_sealed", "required", "system identity mapping sealed until scoring is complete"),
    ("query_freeze_manifest", "required", "queries selected before answer rows are inspected"),
    ("same_evidence_budget_manifest", "required", "all systems receive symmetric source/evidence budget"),
    ("citation_rubric", "required", "citation correctness scored independently of answer style"),
    ("abstain_rubric", "required", "unsupported claims must be scored as abstain/fail explicitly"),
    ("wrong_answer_rubric", "required", "wrong answers are counted separately from abstentions"),
    ("resource_side_table", "required", "latency/memory/cost scored outside blind answer quality"),
    ("inter_rater_rows", "required", "two or more reviewers or adjudication manifest"),
    ("posthoc_leak_audit", "required", "no query selection after seeing model outputs"),
    ("sha256_manifest", "required", "hashes for all blind eval artifacts"),
]
write_csv(
    run_dir / "blind_evaluator_contract_rows.csv",
    ["contract_artifact", "required_status", "notes"],
    [{"contract_artifact": artifact, "required_status": status, "notes": notes} for artifact, status, notes in evaluator_contract_rows],
)

gate_rows = [
    ("v52-baseline-contract", "pass", "A-H baseline registry and symmetric evaluator contract are present"),
    ("v57-domain-pack-contract", "pass", "domain pack and expert review contracts are present"),
    ("query-freeze-contract", "pass", "500-row blind query target and pre-output freeze contract are emitted"),
    ("blind-system-anonymization", "pass", "blind IDs are defined separately from source system IDs"),
    ("30b-blind-response-row", "blocked", "30B LLM+RAG blind response rows are missing"),
    ("70b-blind-response-row", "blocked", "70B LLM+RAG blind response rows are missing"),
    ("100b-plus-blind-response-row", "blocked", "100B+ hosted/API blind response rows are missing or deferred"),
    ("human-blind-review", "blocked", "human blind review rows and inter-rater/adjudication rows are missing"),
    ("v58-full-blind-eval", "blocked", "v58 needs >=500 blind eval rows with sealed identity and symmetric evidence"),
    ("real-release-package", "blocked", "v58 contract is not a release package"),
]
write_csv(
    run_dir / "blind_eval_gate_rows.csv",
    ["gate", "status", "reason"],
    [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in gate_rows],
)

target_blind_rows = sum(int(row["target_blind_eval_rows"]) for row in blind_query_rows)
seed_blind_rows = sum(int(row["seed_blind_eval_rows"]) for row in blind_query_rows)
missing_blind_rows = target_blind_rows - seed_blind_rows
required_system_rows = [row for row in blind_system_rows if row["required_status"] == "required"]
ready_required_blind_system_rows = sum(int(row["real_blind_response_ready"]) for row in required_system_rows)
summary = {
    "v58_blind_eval_contract_ready": 1,
    "v58_ready": 0,
    "blind_system_rows": len(blind_system_rows),
    "required_blind_system_rows": len(required_system_rows),
    "ready_required_blind_system_rows": ready_required_blind_system_rows,
    "target_blind_eval_rows": target_blind_rows,
    "seed_blind_eval_rows": seed_blind_rows,
    "missing_blind_eval_rows": missing_blind_rows,
    "query_freeze_contract_ready": 1,
    "pre_output_query_selection_required": 1,
    "same_evidence_budget_required": 1,
    "identity_hidden_from_reviewer": 1,
    "human_blind_review_ready": 0,
    "inter_rater_rows_ready": 0,
    "required_30b_blind_response_ready": 0,
    "required_70b_blind_response_ready": 0,
    "optional_100b_plus_blind_response_status": "deferred-with-reason",
    "v52_baseline_war_contract_ready": int(v52_summary.get("v52_baseline_war_contract_ready", "0")),
    "v57_domain_expert_packs_contract_ready": int(v57_summary.get("v57_domain_expert_packs_contract_ready", "0")),
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(gate_rows)

(run_dir / "V58_BLIND_EVAL_BOUNDARY.md").write_text(
    "# v58 Blind Eval Boundary\n\n"
    "This is the v58 blind-evaluation contract scaffold, not the completed blind evaluation versus 30B-150B-class systems.\n\n"
    "Seed evidence:\n\n"
    f"- v52_baseline_war_contract_ready={v52_summary.get('v52_baseline_war_contract_ready')}\n"
    f"- v57_domain_expert_packs_contract_ready={v57_summary.get('v57_domain_expert_packs_contract_ready')}\n"
    f"- target_blind_eval_rows={target_blind_rows}\n\n"
    "Still blocked:\n\n"
    "- 30B and 70B LLM+RAG blind response rows\n"
    "- optional 100B+ hosted/API blind response rows or explicit final deferral\n"
    "- human blind review rows and inter-rater/adjudication rows\n"
    f"- missing_blind_eval_rows={missing_blind_rows}\n\n"
    "Do not publish blind-eval or 30B-150B comparison claims from this scaffold. Query selection must be frozen before outputs, reviewer packets must hide system identity, and all systems must receive symmetric evidence budgets.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v58-blind-eval-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v58_blind_eval_contract_ready": 1,
    "v58_ready": 0,
    "target_blind_eval_rows": target_blind_rows,
    "seed_blind_eval_rows": seed_blind_rows,
    "missing_blind_eval_rows": missing_blind_rows,
    "v52_summary_sha256": sha256(results / "v52_llm_rag_baseline_war_summary.csv"),
    "v57_summary_sha256": sha256(results / "v57_domain_expert_packs_contract_summary.csv"),
    "required_30b_blind_response_ready": 0,
    "required_70b_blind_response_ready": 0,
    "human_blind_review_ready": 0,
    "inter_rater_rows_ready": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v58_blind_eval_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "blind_system_mapping_rows.csv",
    "blind_eval_query_contract_rows.csv",
    "blind_evaluator_contract_rows.csv",
    "blind_eval_gate_rows.csv",
    "V58_BLIND_EVAL_BOUNDARY.md",
    "v58_blind_eval_manifest.json",
    "source_v52/baseline_registry.csv",
    "source_v52/evaluation_contract_rows.csv",
    "source_v52/score_axis_rows.csv",
    "source_v52/V52_BASELINE_WAR_BOUNDARY.md",
    "source_v52/v52_llm_rag_baseline_war_manifest.json",
    "source_v52/sha256_manifest.csv",
    "source_v57/domain_pack_target_rows.csv",
    "source_v57/expert_review_contract_rows.csv",
    "source_v57/domain_policy_gate_rows.csv",
    "source_v57/V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md",
    "source_v57/v57_domain_expert_packs_manifest.json",
    "source_v57/sha256_manifest.csv",
]
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v58_blind_eval_contract_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
