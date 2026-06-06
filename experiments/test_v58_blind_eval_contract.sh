#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v58_blind_eval_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v58_blind_eval_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v58_blind_eval_contract_decision.csv"

"$ROOT_DIR/experiments/run_v58_blind_eval_contract.sh" >/dev/null

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
    raise SystemExit(f"expected one v58 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v58_blind_eval_contract_ready": "1",
    "v58_ready": "0",
    "blind_system_rows": "5",
    "required_blind_system_rows": "4",
    "ready_required_blind_system_rows": "0",
    "target_blind_eval_rows": "500",
    "seed_blind_eval_rows": "0",
    "missing_blind_eval_rows": "500",
    "query_freeze_contract_ready": "1",
    "pre_output_query_selection_required": "1",
    "same_evidence_budget_required": "1",
    "identity_hidden_from_reviewer": "1",
    "human_blind_review_ready": "0",
    "inter_rater_rows_ready": "0",
    "required_30b_blind_response_ready": "0",
    "required_70b_blind_response_ready": "0",
    "optional_100b_plus_blind_response_status": "deferred-with-reason",
    "v52_baseline_war_contract_ready": "1",
    "v57_domain_expert_packs_contract_ready": "1",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v58 {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["v52-baseline-contract", "v57-domain-pack-contract", "query-freeze-contract", "blind-system-anonymization"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v58 gate should pass: {gate}")
for gate in [
    "30b-blind-response-row",
    "70b-blind-response-row",
    "100b-plus-blind-response-row",
    "human-blind-review",
    "v58-full-blind-eval",
    "real-release-package",
]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v58 gate should remain blocked: {gate}")

required_files = [
    "blind_system_mapping_rows.csv",
    "blind_eval_query_contract_rows.csv",
    "blind_evaluator_contract_rows.csv",
    "blind_eval_gate_rows.csv",
    "V58_BLIND_EVAL_BOUNDARY.md",
    "v58_blind_eval_manifest.json",
    "sha256_manifest.csv",
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
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v58 artifact: {rel}")

systems = read_csv(run_dir / "blind_system_mapping_rows.csv")
if len(systems) != 5:
    raise SystemExit("v58 should define five blind systems")
source_ids = {row["source_system_id"] for row in systems}
if source_ids != {"D", "E", "F", "G", "H"}:
    raise SystemExit(f"v58 should blind-map D-H, got {source_ids}")
for row in systems:
    for field in ["identity_hidden_from_reviewer", "same_query_set_required", "same_evidence_budget_required", "citation_required", "abstain_required"]:
        if row[field] != "1":
            raise SystemExit(f"v58 blind system should require {field}")
    if row["source_system_id"] in {"D", "E"} and row["real_blind_response_ready"] != "0":
        raise SystemExit("v58 D/E real blind rows should remain missing")
by_source = {row["source_system_id"]: row for row in systems}
if by_source["F"]["required_status"] != "optional-preferred" or "100b-plus" not in by_source["F"]["blocking_reason"]:
    raise SystemExit("v58 F should be optional-preferred and explicitly blocked/deferred")

query_rows = read_csv(run_dir / "blind_eval_query_contract_rows.csv")
if len(query_rows) != 6:
    raise SystemExit("v58 should define six blind query domains")
if sum(int(row["target_blind_eval_rows"]) for row in query_rows) != 500:
    raise SystemExit("v58 target blind rows should sum to 500")
if sum(int(row["missing_blind_eval_rows"]) for row in query_rows) != 500:
    raise SystemExit("v58 missing blind rows should sum to 500")
for row in query_rows:
    for field in ["query_freeze_required", "pre_output_query_selection_required", "negative_controls_required", "source_span_bound_required"]:
        if row[field] != "1":
            raise SystemExit(f"v58 query row should require {field}")

contract = {row["contract_artifact"] for row in read_csv(run_dir / "blind_evaluator_contract_rows.csv")}
for artifact in [
    "reviewer_packet",
    "system_key_sealed",
    "query_freeze_manifest",
    "same_evidence_budget_manifest",
    "citation_rubric",
    "abstain_rubric",
    "wrong_answer_rubric",
    "resource_side_table",
    "inter_rater_rows",
    "posthoc_leak_audit",
    "sha256_manifest",
]:
    if artifact not in contract:
        raise SystemExit(f"v58 evaluator contract missing {artifact}")

manifest = json.loads((run_dir / "v58_blind_eval_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v58_blind_eval_contract_ready") != 1 or manifest.get("v58_ready") != 0:
    raise SystemExit("v58 manifest readiness boundary mismatch")
if manifest.get("missing_blind_eval_rows") != 500:
    raise SystemExit("v58 manifest missing-blind-row mismatch")
for field in ["required_30b_blind_response_ready", "required_70b_blind_response_ready", "human_blind_review_ready", "inter_rater_rows_ready", "real_release_package_ready"]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v58 manifest should keep {field}=0")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v58 sha256 mismatch: {rel}")

boundary = (run_dir / "V58_BLIND_EVAL_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not the completed blind evaluation versus 30B-150B-class systems",
    "30B and 70B LLM+RAG blind response rows",
    "human blind review rows",
    "missing_blind_eval_rows=500",
    "Do not publish blind-eval or 30B-150B comparison claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v58 boundary missing {snippet}")
PY

echo "v58 blind eval contract smoke passed"
