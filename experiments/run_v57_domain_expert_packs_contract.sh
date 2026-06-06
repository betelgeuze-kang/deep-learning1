#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v57_domain_expert_packs_contract"
RUN_ID="${V57_CONTRACT_RUN_ID:-contract_001}"
RUN_DIR="$RESULTS_DIR/$PREFIX/$RUN_ID"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$RUN_DIR"
mkdir -p "$RUN_DIR"

"$ROOT_DIR/experiments/run_v47_offline_domain_policy_update.sh" >/dev/null
"$ROOT_DIR/experiments/run_v48_multi_domain_generator_evidence.sh" >/dev/null
"$ROOT_DIR/experiments/run_v52_llm_rag_baseline_war.sh" >/dev/null
"$ROOT_DIR/experiments/run_v56_ruler_longbench_expanded_contract.sh" >/dev/null

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

v47_dir = results / "v47_offline_domain_policy_update" / "policy_001"
v48_dir = results / "v48_multi_domain_generator_evidence" / "run_001"
v52_dir = results / "v52_llm_rag_baseline_war" / "baseline_001"
v56_dir = results / "v56_ruler_longbench_expanded_contract" / "contract_001"

v47_summary = list(csv.DictReader((results / "v47_offline_domain_policy_update_summary.csv").open(newline="", encoding="utf-8")))[0]
v48_summary = list(csv.DictReader((results / "v48_multi_domain_generator_evidence_summary.csv").open(newline="", encoding="utf-8")))[0]
v52_summary = list(csv.DictReader((results / "v52_llm_rag_baseline_war_summary.csv").open(newline="", encoding="utf-8")))[0]
v56_summary = list(csv.DictReader((results / "v56_ruler_longbench_expanded_contract_summary.csv").open(newline="", encoding="utf-8")))[0]


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
    "offline_domain_policy_rows.csv",
    "offline_domain_policy.json",
    "policy_source_rows.csv",
    "V47_OFFLINE_DOMAIN_POLICY_BOUNDARY.md",
    "v47_offline_domain_policy_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v47_dir / rel, f"source_v47/{rel}")
for rel in [
    "route_memory_evidence_rows.csv",
    "compact_route_hint_rows.csv",
    "grounded_generation_rows.csv",
    "V48_MULTI_DOMAIN_GENERATOR_BOUNDARY.md",
    "v48_multi_domain_generator_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v48_dir / rel, f"source_v48/{rel}")
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
    "benchmark_family_target_rows.csv",
    "expanded_benchmark_artifact_contract_rows.csv",
    "benchmark_invariant_rows.csv",
    "V56_RULER_LONGBENCH_EXPANDED_BOUNDARY.md",
    "v56_ruler_longbench_expanded_manifest.json",
    "sha256_manifest.csv",
]:
    copy(v56_dir / rel, f"source_v56/{rel}")

pack_targets = [
    ("codebase_qa", "public code/doc QA audit", 250, 1, 1, 1, "seeded-by-v47-v48-v52"),
    ("internal_docs_qa", "closed-corpus internal documentation QA", 150, 1, 1, 0, "seeded-by-v48"),
    ("ruler_niah", "needle-in-a-haystack benchmark policy", 150, 0, 1, 1, "seeded-by-v48-v56"),
    ("longbench_v2", "long-document benchmark policy", 150, 1, 1, 1, "seeded-by-v47-v48-v56"),
    ("incident_log_qa", "incident/postmortem audit policy", 150, 0, 0, 0, "missing-domain-corpus"),
    ("product_manual_qa", "product manual and support policy", 150, 0, 0, 0, "missing-domain-corpus"),
]
pack_rows = []
for domain, pack_scope, target_rows, policy_seed, generation_seed, benchmark_seed, status in pack_targets:
    seed_sources = policy_seed + generation_seed + benchmark_seed
    seed_rows = seed_sources * 5
    pack_rows.append(
        {
            "domain_pack": domain,
            "pack_scope": pack_scope,
            "target_eval_rows": target_rows,
            "seed_eval_rows": seed_rows,
            "missing_eval_rows": max(0, target_rows - seed_rows),
            "policy_seed_ready": policy_seed,
            "generation_seed_ready": generation_seed,
            "benchmark_seed_ready": benchmark_seed,
            "source_span_bound_required": 1,
            "abstain_policy_required": 1,
            "wrong_answer_guard_required": 1,
            "domain_policy_required": 1,
            "human_expert_review_required": 1,
            "status": status,
        }
    )
write_csv(run_dir / "domain_pack_target_rows.csv", list(pack_rows[0].keys()), pack_rows)

review_rows = [
    ("domain_scope_card", "required", "domain owner, allowed corpus, forbidden claims, data sensitivity"),
    ("gold_query_set", "required", "source-span-bound expert/gold queries with negative controls"),
    ("rubric", "required", "citation, abstention, wrong-answer, and policy-compliance rubric"),
    ("expert_identity", "required", "named reviewer or review body with conflict disclosure"),
    ("blind_review_form", "required", "review rows without system identity leakage"),
    ("failure_taxonomy", "required", "domain-specific failure categories and severity"),
    ("policy_update_diff", "required", "offline policy changes with before/after hashes"),
    ("privacy_review", "required", "data boundary and local-only handling review"),
    ("reproducibility_manifest", "required", "one-command pack replay and artifact hashes"),
]
write_csv(
    run_dir / "expert_review_contract_rows.csv",
    ["contract_artifact", "required_status", "notes"],
    [{"contract_artifact": artifact, "required_status": status, "notes": notes} for artifact, status, notes in review_rows],
)

gate_rows = [
    ("policy_seed", "pass", "v47 offline policy rows are present"),
    ("multi_domain_generation_seed", "pass", "v48 multi-domain RouteHint generation rows are present"),
    ("baseline_symmetry_contract", "pass", "v52 A-H baseline/evaluation contract is present"),
    ("expanded_benchmark_seed", "pass", "v56 RULER/LongBench seed contract is present"),
    ("domain_pack_eval_scale", "blocked", "six packs need 1000 total expert-pack eval rows"),
    ("human_expert_review", "blocked", "no human expert review return is supplied"),
    ("blind_eval_ready", "blocked", "v58 blind evaluation is not supplied"),
    ("expert_replacement_claim", "blocked", "expert replacement claim is forbidden"),
    ("real_release_package", "blocked", "v57 contract is not a release package"),
]
write_csv(
    run_dir / "domain_policy_gate_rows.csv",
    ["gate", "status", "reason"],
    [{"gate": gate, "status": status, "reason": reason} for gate, status, reason in gate_rows],
)

pack_total_target_rows = sum(int(row["target_eval_rows"]) for row in pack_rows)
pack_seed_rows = sum(int(row["seed_eval_rows"]) for row in pack_rows)
missing_pack_rows = max(0, pack_total_target_rows - pack_seed_rows)
summary = {
    "v57_domain_expert_packs_contract_ready": 1,
    "v57_domain_expert_packs_ready": 0,
    "domain_pack_rows": len(pack_rows),
    "target_eval_rows": pack_total_target_rows,
    "seed_eval_rows": pack_seed_rows,
    "missing_eval_rows": missing_pack_rows,
    "policy_seed_rows": int(v47_summary.get("policy_rows", "0")),
    "generation_seed_rows": int(v48_summary.get("generation_rows", "0")),
    "baseline_system_rows": int(v52_summary.get("baseline_system_rows", "0")),
    "benchmark_seed_rows": int(v56_summary.get("seed_total_rows", "0")),
    "expert_review_contract_rows": len(review_rows),
    "source_span_bound_required": 1,
    "abstain_policy_required": 1,
    "wrong_answer_guard_required": 1,
    "domain_policy_required": 1,
    "human_expert_review_ready": 0,
    "blind_eval_ready": 0,
    "expert_replacement_claim": 0,
    "real_release_package_ready": 0,
}
write_csv(summary_csv, list(summary.keys()), [summary])

with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(gate_rows)

(run_dir / "V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md").write_text(
    "# v57 Domain Expert Packs Boundary\n\n"
    "This is the v57 domain expert packs contract scaffold, not completed expert-reviewed domain packs.\n\n"
    "Seed evidence:\n\n"
    f"- v47 policy_rows={v47_summary.get('policy_rows')}\n"
    f"- v48 generation_rows={v48_summary.get('generation_rows')}\n"
    f"- v52 baseline_system_rows={v52_summary.get('baseline_system_rows')}\n"
    f"- v56 benchmark_seed_rows={v56_summary.get('seed_total_rows')}\n\n"
    "Still blocked:\n\n"
    f"- missing_eval_rows={missing_pack_rows}\n"
    "- human expert review return\n"
    "- blind v58 evaluation\n"
    "- real release package\n\n"
    "Do not publish domain-expert or expert-replacement claims from this scaffold. It only defines the pack contract, policy gates, and review artifacts required before v58.\n",
    encoding="utf-8",
)

manifest = {
    "manifest_scope": "v57-domain-expert-packs-contract",
    "generated_at_utc": datetime.now(timezone.utc).isoformat(),
    "v57_domain_expert_packs_contract_ready": 1,
    "v57_domain_expert_packs_ready": 0,
    "domain_pack_rows": len(pack_rows),
    "target_eval_rows": pack_total_target_rows,
    "seed_eval_rows": pack_seed_rows,
    "missing_eval_rows": missing_pack_rows,
    "v47_summary_sha256": sha256(results / "v47_offline_domain_policy_update_summary.csv"),
    "v48_summary_sha256": sha256(results / "v48_multi_domain_generator_evidence_summary.csv"),
    "v52_summary_sha256": sha256(results / "v52_llm_rag_baseline_war_summary.csv"),
    "v56_summary_sha256": sha256(results / "v56_ruler_longbench_expanded_contract_summary.csv"),
    "human_expert_review_ready": 0,
    "blind_eval_ready": 0,
    "expert_replacement_claim": 0,
    "real_release_package_ready": 0,
}
(run_dir / "v57_domain_expert_packs_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

artifact_rels = [
    "domain_pack_target_rows.csv",
    "expert_review_contract_rows.csv",
    "domain_policy_gate_rows.csv",
    "V57_DOMAIN_EXPERT_PACKS_BOUNDARY.md",
    "v57_domain_expert_packs_manifest.json",
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
artifact_rows = []
for rel in artifact_rels:
    path = run_dir / rel
    artifact_rows.append({"path": rel, "sha256": sha256(path), "bytes": path.stat().st_size})
write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)

print(f"v57_domain_expert_packs_contract_dir: {run_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
