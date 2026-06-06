#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
RUN_DIR="$RESULTS_DIR/v57_domain_expert_packs_contract/contract_001"
SUMMARY_CSV="$RESULTS_DIR/v57_domain_expert_packs_contract_summary.csv"
DECISION_CSV="$RESULTS_DIR/v57_domain_expert_packs_contract_decision.csv"

"$ROOT_DIR/experiments/run_v57_domain_expert_packs_contract.sh" >/dev/null

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
    raise SystemExit(f"expected one v57 summary row, got {len(summary_rows)}")
summary = summary_rows[0]
expected = {
    "v57_domain_expert_packs_contract_ready": "1",
    "v57_domain_expert_packs_ready": "0",
    "domain_pack_rows": "6",
    "target_eval_rows": "1000",
    "seed_eval_rows": "50",
    "missing_eval_rows": "950",
    "policy_seed_rows": "15",
    "generation_seed_rows": "24",
    "baseline_system_rows": "8",
    "benchmark_seed_rows": "506",
    "expert_review_contract_rows": "9",
    "source_span_bound_required": "1",
    "abstain_policy_required": "1",
    "wrong_answer_guard_required": "1",
    "domain_policy_required": "1",
    "human_expert_review_ready": "0",
    "blind_eval_ready": "0",
    "expert_replacement_claim": "0",
    "real_release_package_ready": "0",
}
for field, value in expected.items():
    if summary.get(field) != value:
        raise SystemExit(f"v57 {field}: expected {value}, got {summary.get(field)}")

decisions = {row["gate"]: row["status"] for row in read_csv(decision_csv)}
for gate in ["policy_seed", "multi_domain_generation_seed", "baseline_symmetry_contract", "expanded_benchmark_seed"]:
    if decisions.get(gate) != "pass":
        raise SystemExit(f"v57 gate should pass: {gate}")
for gate in ["domain_pack_eval_scale", "human_expert_review", "blind_eval_ready", "expert_replacement_claim", "real_release_package"]:
    if decisions.get(gate) != "blocked":
        raise SystemExit(f"v57 gate should remain blocked: {gate}")

required_files = [
    "domain_pack_target_rows.csv",
    "expert_review_contract_rows.csv",
    "domain_policy_gate_rows.csv",
    "V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md",
    "v57_domain_expert_packs_manifest.json",
    "sha256_manifest.csv",
    "source_v47/offline_domain_policy_rows.csv",
    "source_v47/offline_domain_policy.json",
    "source_v47/policy_source_rows.csv",
    "source_v47/V47_OFFLINE_DOMAIN_POLICY_BOUNDARY.md",
    "source_v47/v47_offline_domain_policy_manifest.json",
    "source_v47/sha256_manifest.csv",
    "source_v48/route_memory_evidence_rows.csv",
    "source_v48/compact_route_hint_rows.csv",
    "source_v48/grounded_generation_rows.csv",
    "source_v48/V48_MULTI_DOMAIN_GENERATOR_BOUNDARY.md",
    "source_v48/v48_multi_domain_generator_manifest.json",
    "source_v48/sha256_manifest.csv",
    "source_v52/baseline_registry.csv",
    "source_v52/evaluation_contract_rows.csv",
    "source_v52/score_axis_rows.csv",
    "source_v52/V52_BASELINE_WAR_BOUNDARY.md",
    "source_v52/v52_llm_rag_baseline_war_manifest.json",
    "source_v52/sha256_manifest.csv",
    "source_v56/benchmark_family_target_rows.csv",
    "source_v56/expanded_benchmark_artifact_contract_rows.csv",
    "source_v56/benchmark_invariant_rows.csv",
    "source_v56/V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md",
    "source_v56/v56_ruler_longbench_expanded_manifest.json",
    "source_v56/sha256_manifest.csv",
]
for rel in required_files:
    path = run_dir / rel
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"missing v57 artifact: {rel}")

pack_rows = read_csv(run_dir / "domain_pack_target_rows.csv")
if len(pack_rows) != 6:
    raise SystemExit("v57 should define six domain packs")
if sum(int(row["target_eval_rows"]) for row in pack_rows) != 1000:
    raise SystemExit("v57 target eval rows should sum to 1000")
if sum(int(row["missing_eval_rows"]) for row in pack_rows) != 950:
    raise SystemExit("v57 missing eval rows should sum to 950")
by_pack = {row["domain_pack"]: row for row in pack_rows}
for pack in ["codebase_qa", "internal_docs_qa", "ruler_niah", "longbench_v2", "incident_log_qa", "product_manual_qa"]:
    if pack not in by_pack:
        raise SystemExit(f"v57 missing domain pack {pack}")
for row in pack_rows:
    for field in [
        "source_span_bound_required",
        "abstain_policy_required",
        "wrong_answer_guard_required",
        "domain_policy_required",
        "human_expert_review_required",
    ]:
        if row[field] != "1":
            raise SystemExit(f"v57 domain pack should require {field}")

review_contract = {row["contract_artifact"] for row in read_csv(run_dir / "expert_review_contract_rows.csv")}
for artifact in [
    "domain_scope_card",
    "gold_query_set",
    "rubric",
    "expert_identity",
    "blind_review_form",
    "failure_taxonomy",
    "policy_update_diff",
    "privacy_review",
    "reproducibility_manifest",
]:
    if artifact not in review_contract:
        raise SystemExit(f"v57 review contract missing {artifact}")

manifest = json.loads((run_dir / "v57_domain_expert_packs_manifest.json").read_text(encoding="utf-8"))
if manifest.get("v57_domain_expert_packs_contract_ready") != 1 or manifest.get("v57_domain_expert_packs_ready") != 0:
    raise SystemExit("v57 manifest readiness boundary mismatch")
if manifest.get("missing_eval_rows") != 950:
    raise SystemExit("v57 manifest missing-eval mismatch")
for field in ["human_expert_review_ready", "blind_eval_ready", "expert_replacement_claim", "real_release_package_ready"]:
    if manifest.get(field) != 0:
        raise SystemExit(f"v57 manifest should keep {field}=0")

sha_rows = {row["path"]: row["sha256"] for row in read_csv(run_dir / "sha256_manifest.csv")}
for rel in required_files:
    if rel == "sha256_manifest.csv":
        continue
    if sha_rows.get(rel) != sha256(run_dir / rel):
        raise SystemExit(f"v57 sha256 mismatch: {rel}")

boundary = (run_dir / "V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md").read_text(encoding="utf-8")
for snippet in [
    "not completed expert-reviewed domain packs",
    "missing_eval_rows=950",
    "human expert review return",
    "blind v58 evaluation",
    "Do not publish domain-expert or expert-replacement claims",
]:
    if snippet not in boundary:
        raise SystemExit(f"v57 boundary missing {snippet}")
PY

echo "v57 domain expert packs contract smoke passed"
