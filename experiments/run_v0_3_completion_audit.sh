#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
AUDIT_DIR="$RESULTS_DIR/v0_3_completion_audit"
SUMMARY_CSV="$RESULTS_DIR/v0_3_completion_audit_summary.csv"
DECISION_CSV="$RESULTS_DIR/v0_3_completion_audit_decision.csv"

"$ROOT_DIR/experiments/test_v51_local_scaling_matrix.sh" >/dev/null
"$ROOT_DIR/experiments/test_v0_3_architecture_preview.sh" >/dev/null

rm -rf "$AUDIT_DIR"
mkdir -p "$AUDIT_DIR"

python3 - "$ROOT_DIR" "$AUDIT_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])
audit_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results_dir = root / "results"
preview_dir = results_dir / "v0_3_architecture_preview"
scaling_dir = results_dir / "v51_local_scaling_matrix"
v54_dir = results_dir / "v54_routehint_generator_mainline"

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

def exists(rel):
    return (root / rel).is_file() and (root / rel).stat().st_size > 0

preview_summary = read_csv(results_dir / "v0_3_architecture_preview_summary.csv")[0]
scaling_summary = read_csv(results_dir / "v51_local_scaling_matrix_summary.csv")[0]
v54_metrics = json.loads((v54_dir / "generation_metrics.json").read_text(encoding="utf-8"))
baseline_rows = read_csv(preview_dir / "baseline_metrics.csv")
wrong_guard_rows = read_csv(preview_dir / "wrong_answer_guard_rows.csv")
store_rows = read_csv(preview_dir / "store_size_curve.csv")
active_rows = read_csv(preview_dir / "active_bytes_per_query.csv")

requirements = [
    ("v51-local-scaling-command", exists("scripts/run_local_scaling_matrix.sh"), "scripts/run_local_scaling_matrix.sh"),
    ("v51-store-size-curve", scaling_summary.get("store_size_curve_rows") == "7", "results/v51_local_scaling_matrix/store_size_curve.csv"),
    ("v51-topk-curve", scaling_summary.get("topk_curve_rows") == "6", "results/v51_local_scaling_matrix/topk_curve.csv"),
    ("v51-cache-budget-curve", scaling_summary.get("cache_budget_curve_rows") == "5", "results/v51_local_scaling_matrix/cache_budget_curve.csv"),
    ("v51-routehint-budget-curve", scaling_summary.get("routehint_budget_curve_rows") == "5", "results/v51_local_scaling_matrix/routehint_budget_curve.csv"),
    ("v51-query-count-curve", scaling_summary.get("query_count_curve_rows") == "4", "results/v51_local_scaling_matrix/query_count_curve.csv"),
    ("v51-active-bytes-bounded", len(store_rows) == 7 and int(store_rows[-1]["active_bytes_per_query"]) < int(store_rows[-1]["store_size_bytes"]), "results/v51_local_scaling_matrix/active_bytes_per_query.csv"),
    ("v52-eight-baseline-war", preview_summary.get("baseline_rows") == "8", "results/v0_3_architecture_preview/baseline_metrics.csv"),
    ("v52-routehint-vs-rag-boundary", exists("results/v0_3_architecture_preview/routehint_vs_rag.csv"), "results/v0_3_architecture_preview/routehint_vs_rag.csv"),
    ("v52-wrong-answer-guard", len(wrong_guard_rows) > 0 and all(row.get("wrong_answer_guard_pass") == "1" for row in wrong_guard_rows), "results/v0_3_architecture_preview/wrong_answer_guard_rows.csv"),
    ("v53-audit-command", exists("scripts/audit_my_repo.sh"), "scripts/audit_my_repo.sh"),
    ("v53-audit-report", exists("results/v0_3_architecture_preview/AUDIT_REPORT.md"), "results/v0_3_architecture_preview/AUDIT_REPORT.md"),
    ("v53-machine-artifacts", exists("results/v0_3_architecture_preview/prediction_lineage.jsonl") and exists("results/v0_3_architecture_preview/citation_spans.jsonl"), "results/v0_3_architecture_preview/prediction_lineage.jsonl"),
    ("v53-reproduce", exists("results/v0_3_architecture_preview/reproduce.sh"), "results/v0_3_architecture_preview/reproduce.sh"),
    ("v54-generator-command", exists("scripts/run_routehint_generator_mainline.sh"), "scripts/run_routehint_generator_mainline.sh"),
    ("v54-mainline-artifacts", all(exists(f"results/v54_routehint_generator_mainline/{name}") for name in ["route_memory_evidence_rows.csv", "generator_input_rows.csv", "grounded_generation_rows.csv", "citation_rows.csv", "sha256_manifest.csv"]), "results/v54_routehint_generator_mainline/"),
    ("v54-no-raw-prompt-stuffing", v54_metrics.get("raw_prompt_context_appended_rows") == 0, "results/v54_routehint_generator_mainline/generation_metrics.json"),
    ("v54-no-attention-transformer", v54_metrics.get("attention_blocks") == 0 and v54_metrics.get("transformer_blocks") == 0, "results/v54_routehint_generator_mainline/generation_metrics.json"),
    ("v54-proposal-hint-equals-generation", v54_metrics.get("proposal_hint_used_rows") == v54_metrics.get("generation_rows"), "results/v54_routehint_generator_mainline/generation_metrics.json"),
    ("v54-abstention-ready", v54_metrics.get("missing_query_abstention_ready") == 1, "results/v54_routehint_generator_mainline/generation_metrics.json"),
    ("v55-showcase-command", exists("examples/local_codebase_intelligence_box.sh"), "examples/local_codebase_intelligence_box.sh"),
    ("v55-showcase-bundle", all(exists(f"results/v0_3_architecture_preview/{name}") for name in ["README_RESULT.md", "BASELINE_COMPARISON.md", "LOCAL_SCALING_SUMMARY.md", "ARCHITECTURE_TRACE.md", "sha256sums.txt"]), "results/v0_3_architecture_preview/"),
    ("claim-transformer-blocked", "Transformer replacement" in (preview_dir / "baseline_claim_boundary.md").read_text(encoding="utf-8"), "results/v0_3_architecture_preview/baseline_claim_boundary.md"),
    ("claim-frontier-llm-blocked", "frontier local LLM" in (preview_dir / "claim_boundary.md").read_text(encoding="utf-8"), "results/v0_3_architecture_preview/claim_boundary.md"),
    ("claim-gpu-speedup-deferred", preview_summary.get("gpu_speedup_claim") == "deferred", "results/v0_3_architecture_preview_summary.csv"),
    ("claim-release-blocked", preview_summary.get("real_release_package_ready") == "0", "results/v0_3_architecture_preview_summary.csv"),
    ("readme-quickstart", "audit_my_repo.sh" in (root / "README.md").read_text(encoding="utf-8") and "test_v0_3_architecture_preview.sh" in (root / "README.md").read_text(encoding="utf-8"), "README.md"),
]

requirement_rows = [
    {
        "requirement": name,
        "status": "pass" if passed else "blocked",
        "evidence": evidence,
    }
    for name, passed, evidence in requirements
]

def write_csv(path, fieldnames, rows):
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

write_csv(audit_dir / "completion_requirements.csv", ["requirement", "status", "evidence"], requirement_rows)

pass_count = sum(1 for row in requirement_rows if row["status"] == "pass")
blocked_count = len(requirement_rows) - pass_count

summary = {
    "v0_3_completion_audit_ready": int(blocked_count == 0),
    "requirement_rows": len(requirement_rows),
    "pass_rows": pass_count,
    "blocked_rows": blocked_count,
    "v51_local_scaling_matrix_ready": int(scaling_summary.get("v51_local_scaling_matrix_ready") == "1"),
    "v0_3_architecture_preview_ready": int(preview_summary.get("v0_3_architecture_preview_ready") == "1"),
    "baseline_rows": preview_summary.get("baseline_rows", "0"),
    "scaling_curve_rows": preview_summary.get("scaling_curve_rows", "0"),
    "real_release_package_ready": 0,
    "gpu_speedup_claim": "deferred",
}
write_csv(summary_csv, list(summary.keys()), [summary])

decisions = [
    {"gate": "v0.3-completion-audit", "status": "pass" if blocked_count == 0 else "blocked", "reason": f"pass={pass_count} blocked={blocked_count}"},
    {"gate": "local-only-implementation", "status": "pass", "reason": "all local commands and artifacts generated"},
    {"gate": "remote-push-pr", "status": "blocked", "reason": "requires explicit user approval before remote mutation"},
    {"gate": "real-release-package", "status": "blocked", "reason": "real_release_package_ready remains 0"},
    {"gate": "gpu-speedup-claim", "status": "blocked", "reason": "gpu_speedup_claim=deferred"},
]
write_csv(decision_csv, ["gate", "status", "reason"], decisions)

(audit_dir / "COMPLETION_AUDIT.md").write_text(
    "# v0.3 Completion Audit\n\n"
    f"- requirement_rows={len(requirement_rows)}\n"
    f"- pass_rows={pass_count}\n"
    f"- blocked_rows={blocked_count}\n"
    "- local implementation: complete when blocked_rows=0\n"
    "- remote push/PR: blocked until explicit user approval\n"
    "- release and GPU-speedup claims remain blocked\n\n"
    "See `completion_requirements.csv` for requirement-by-requirement evidence.\n",
    encoding="utf-8",
)

pr_lines = [
    "## Summary",
    "",
    "- Adds the v0.3 Architecture Preview clone-and-run audit surface.",
    "- Adds Local Scaling Matrix, 8-way Baseline War, audit UX, RouteHint generator mainline, and Local Codebase Intelligence Box artifacts.",
    "- Keeps claims bounded to local evidence-bound QA/audit assistance; release-ready, Transformer replacement, frontier LLM, long-context solved, expert replacement, and GPU-speedup claims remain blocked.",
    "",
    "## Verification",
    "",
    "- `./experiments/test_v51_local_scaling_matrix.sh`",
    "- `./experiments/test_v0_3_architecture_preview.sh`",
    "- `./experiments/run_v0_3_completion_audit.sh`",
    "",
    "## Completion Evidence",
    "",
    f"- requirement_rows={len(requirement_rows)}",
    f"- pass_rows={pass_count}",
    f"- blocked_rows={blocked_count}",
    f"- baseline_rows={summary['baseline_rows']}",
    f"- scaling_curve_rows={summary['scaling_curve_rows']}",
    "- `real_release_package_ready=0`",
    "- `gpu_speedup_claim=deferred`",
]
(audit_dir / "PR_BODY.md").write_text("\n".join(pr_lines) + "\n", encoding="utf-8")

sha_rows = []
for path in sorted(audit_dir.rglob("*")):
    if path.is_file() and path.name != "sha256_manifest.csv":
        sha_rows.append({"path": str(path.relative_to(audit_dir)), "sha256": sha256(path)})
write_csv(audit_dir / "sha256_manifest.csv", ["path", "sha256"], sha_rows)

print(f"completion_audit: {audit_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
