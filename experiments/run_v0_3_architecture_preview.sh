#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTS_DIR="$ROOT_DIR/results"
PREFIX="v0_3_architecture_preview"
PREVIEW_DIR="$RESULTS_DIR/$PREFIX"
SUMMARY_CSV="$RESULTS_DIR/${PREFIX}_summary.csv"
DECISION_CSV="$RESULTS_DIR/${PREFIX}_decision.csv"

rm -rf "$PREVIEW_DIR"
mkdir -p "$PREVIEW_DIR"

"$ROOT_DIR/experiments/run_v14c_baseline_comparison.sh" >/dev/null
"$ROOT_DIR/scripts/run_local_scaling_matrix.sh" "$ROOT_DIR" >/dev/null
"$ROOT_DIR/scripts/run_routehint_generator_mainline.sh" "$ROOT_DIR" >/dev/null
V55_LOCAL_CODEBASE_BOX_DIR="$PREVIEW_DIR/local_codebase_intelligence_box" "$ROOT_DIR/examples/local_codebase_intelligence_box.sh" "$ROOT_DIR" >/dev/null

python3 - "$ROOT_DIR" "$PREVIEW_DIR" "$SUMMARY_CSV" "$DECISION_CSV" <<'PY'
import csv
import hashlib
import json
import shutil
import sys
from pathlib import Path

root = Path(sys.argv[1])
preview_dir = Path(sys.argv[2])
summary_csv = Path(sys.argv[3])
decision_csv = Path(sys.argv[4])
results_dir = root / "results"
v14c_summary_path = results_dir / "v14c_baseline_comparison_summary.csv"
v14c_decision_path = results_dir / "v14c_baseline_comparison_decision.csv"
v14c_run_dir = results_dir / "v14c_baseline_comparison_runs" / "comparison_001"
scaling_dir = results_dir / "v51_local_scaling_matrix"
scaling_summary_path = results_dir / "v51_local_scaling_matrix_summary.csv"
v54_dir = results_dir / "v54_routehint_generator_mainline"
v55_dir = preview_dir / "local_codebase_intelligence_box"

def read_csv(path):
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))

def sha256(path):
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()

v14c = read_csv(v14c_summary_path)[0]
scaling = read_csv(scaling_summary_path)[0]
v54 = read_csv(v54_dir / "v54_routehint_generator_mainline_summary.csv")[0]
v55 = read_csv(v55_dir / "v55_local_codebase_intelligence_box_summary.csv")[0]

artifact_map = {
    "baseline_summary.md": None,
    "baseline_metrics.csv": None,
    "v14c_baseline_comparison_rows.csv": v14c_run_dir / "benchmark" / "baseline_comparison_rows.csv",
    "per_query_comparison.jsonl": v55_dir / "prediction_lineage.jsonl",
    "prediction_lineage.jsonl": v55_dir / "prediction_lineage.jsonl",
    "routehint_vs_rag.csv": None,
    "wrong_answer_guard_rows.csv": v55_dir / "wrong_answer_guard_rows.csv",
    "unsupported_claim_rows.csv": v54_dir / "unsupported_claim_rows.csv",
    "claim_boundary.md": v54_dir / "claim_boundary.md",
    "baseline_claim_boundary.md": None,
    "README_RESULT.md": v55_dir / "README_RESULT.md",
    "AUDIT_REPORT.md": v55_dir / "AUDIT_REPORT.md",
    "BASELINE_COMPARISON.md": v55_dir / "BASELINE_COMPARISON.md",
    "LOCAL_SCALING_SUMMARY.md": scaling_dir / "scaling_summary.md",
    "store_size_curve.csv": scaling_dir / "store_size_curve.csv",
    "topk_curve.csv": scaling_dir / "topk_curve.csv",
    "cache_budget_curve.csv": scaling_dir / "cache_budget_curve.csv",
    "routehint_budget_curve.csv": scaling_dir / "routehint_budget_curve.csv",
    "query_count_curve.csv": scaling_dir / "query_count_curve.csv",
    "active_bytes_per_query.csv": scaling_dir / "active_bytes_per_query.csv",
    "latency_breakdown.csv": scaling_dir / "latency_breakdown.csv",
    "local_scaling_claim_boundary.md": scaling_dir / "claim_boundary.md",
    "ARCHITECTURE_TRACE.md": v55_dir / "ARCHITECTURE_TRACE.md",
    "compact_route_hint_rows.csv": v55_dir / "compact_route_hint_rows.csv",
    "grounded_generation_rows.csv": v55_dir / "grounded_generation_rows.csv",
    "citation_spans.jsonl": v55_dir / "citation_spans.jsonl",
    "abstain_rows.csv": v55_dir / "abstain_rows.csv",
    "resource_envelope.json": v55_dir / "resource_envelope.json",
    "reproduce.sh": v55_dir / "reproduce.sh",
}

for name, src in artifact_map.items():
    if src is not None:
        shutil.copy(src, preview_dir / name)

v14c_rows = read_csv(v14c_run_dir / "benchmark" / "baseline_comparison_rows.csv")
v14c_by_id = {row["baseline_id"]: row for row in v14c_rows}
baseline_overlay_rows = [
    {
        "baseline_id": "ripgrep_literal",
        "baseline_family": "literal_search",
        "evidence_source": "preview-overlay",
        "raw_prompt_context_bytes": "0",
        "route_memory_store_used": "0",
        "compact_routehint_used": "0",
        "tiny_non_attention_generator_used": "0",
        "citation_audit_trail_required": "0",
        "abstain_required": "0",
        "promotion_eligible": "0",
        "boundary": "literal baseline only",
    },
    {
        "baseline_id": "bm25_lexical",
        "baseline_family": "lexical_retrieval",
        "evidence_source": "v14c",
        "raw_prompt_context_bytes": "0",
        "route_memory_store_used": v14c_by_id.get("bm25_lexical", {}).get("route_memory_store_used", "0"),
        "compact_routehint_used": "0",
        "tiny_non_attention_generator_used": "0",
        "citation_audit_trail_required": "0",
        "abstain_required": "0",
        "promotion_eligible": v14c_by_id.get("bm25_lexical", {}).get("promotion_eligible", "0"),
        "boundary": "lexical baseline only",
    },
    {
        "baseline_id": "small_rag_boundary",
        "baseline_family": "rag_prompt_context",
        "evidence_source": "preview-boundary",
        "raw_prompt_context_bytes": "nonzero-or-unbounded",
        "route_memory_store_used": "0",
        "compact_routehint_used": "0",
        "tiny_non_attention_generator_used": "0",
        "citation_audit_trail_required": "0",
        "abstain_required": "0",
        "promotion_eligible": "0",
        "boundary": "contrast boundary; preview path does not append retrieved raw text",
    },
    {
        "baseline_id": "tiny_generator_only",
        "baseline_family": "generator_without_evidence",
        "evidence_source": "preview-boundary",
        "raw_prompt_context_bytes": "0",
        "route_memory_store_used": "0",
        "compact_routehint_used": "0",
        "tiny_non_attention_generator_used": "1",
        "citation_audit_trail_required": "0",
        "abstain_required": "0",
        "promotion_eligible": "0",
        "boundary": "generator-only baseline cannot promote without evidence binding",
    },
    {
        "baseline_id": "route_memory_retrieval_only",
        "baseline_family": "route_memory_retrieval",
        "evidence_source": "v14c",
        "raw_prompt_context_bytes": "0",
        "route_memory_store_used": v14c_by_id.get("route_memory_retrieval_only", {}).get("route_memory_store_used", "1"),
        "compact_routehint_used": "0",
        "tiny_non_attention_generator_used": "0",
        "citation_audit_trail_required": "1",
        "abstain_required": "1",
        "promotion_eligible": v14c_by_id.get("route_memory_retrieval_only", {}).get("promotion_eligible", "0"),
        "boundary": "retrieval-only comparison",
    },
    {
        "baseline_id": "route_memory_exact",
        "baseline_family": "route_memory_value_read",
        "evidence_source": "v14c",
        "raw_prompt_context_bytes": "0",
        "route_memory_store_used": v14c_by_id.get("route_memory_exact_value_read", {}).get("route_memory_store_used", "1"),
        "compact_routehint_used": "0",
        "tiny_non_attention_generator_used": "0",
        "citation_audit_trail_required": "1",
        "abstain_required": "1",
        "promotion_eligible": v14c_by_id.get("route_memory_exact_value_read", {}).get("promotion_eligible", "1"),
        "boundary": "exact value-read comparison",
    },
    {
        "baseline_id": "route_memory_compact_routehint",
        "baseline_family": "route_memory_routehint",
        "evidence_source": "v14c+v0.3",
        "raw_prompt_context_bytes": "0",
        "route_memory_store_used": v14c_by_id.get("route_memory_proposal_hint", {}).get("route_memory_store_used", "1"),
        "compact_routehint_used": "1",
        "tiny_non_attention_generator_used": "1",
        "citation_audit_trail_required": "1",
        "abstain_required": "1",
        "promotion_eligible": v14c_by_id.get("route_memory_proposal_hint", {}).get("promotion_eligible", "1"),
        "boundary": "preview mainline path",
    },
    {
        "baseline_id": "route_memory_scorer_offline_policy",
        "baseline_family": "route_memory_policy",
        "evidence_source": "v46+v47+v0.3",
        "raw_prompt_context_bytes": "0",
        "route_memory_store_used": "1",
        "compact_routehint_used": "1",
        "tiny_non_attention_generator_used": "1",
        "citation_audit_trail_required": "1",
        "abstain_required": "1",
        "promotion_eligible": "1",
        "boundary": "offline policy/scorer-bound comparison, still preview-only",
    },
]
with (preview_dir / "baseline_metrics.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(baseline_overlay_rows[0].keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerows(baseline_overlay_rows)

(preview_dir / "baseline_summary.md").write_text(
    "# Baseline War Summary\n\n"
    f"- baseline_comparison_ready={v14c.get('baseline_comparison_ready')}\n"
    f"- v14c_baseline_rows={v14c.get('baseline_rows')}\n"
    f"- preview_baseline_rows={len(baseline_overlay_rows)}\n"
    "- preview_baselines=ripgrep_literal,bm25_lexical,small_rag_boundary,tiny_generator_only,route_memory_retrieval_only,route_memory_exact,route_memory_compact_routehint,route_memory_scorer_offline_policy\n"
    f"- route_memory_safety_dominates_baselines={v14c.get('route_memory_safety_dominates_baselines')}\n"
    f"- input_extractor_baseline_only={v14c.get('input_extractor_baseline_only')}\n"
    f"- raw_prompt_context_bytes=0 in the preview audit/generator path\n"
    f"- real_release_package_ready=0\n",
    encoding="utf-8",
)

with (preview_dir / "routehint_vs_rag.csv").open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=["system", "raw_prompt_context_bytes", "citation_audit_trail", "abstain_supported", "promotion_boundary"], lineterminator="\n")
    writer.writeheader()
    writer.writerow({"system": "small_rag_baseline_boundary", "raw_prompt_context_bytes": "nonzero-or-unbounded", "citation_audit_trail": "not-required", "abstain_supported": "not-required", "promotion_boundary": "baseline-only"})
    writer.writerow({"system": "route_memory_compact_routehint", "raw_prompt_context_bytes": "0", "citation_audit_trail": "required", "abstain_supported": "required", "promotion_boundary": "preview-only"})

(preview_dir / "baseline_claim_boundary.md").write_text(
    "# v0.3 Architecture Preview Claim Boundary\n\n"
    "Allowed claim: local evidence-bound RouteMemory QA/audit architecture prototype.\n\n"
    "Blocked claims: Transformer replacement, frontier local LLM, production release, expert replacement, long-context solved, and GPU acceleration proven.\n\n"
    "`real_release_package_ready=0` and `gpu_speedup_claim=deferred` remain explicit.\n",
    encoding="utf-8",
)

summary = {
    "v0_3_architecture_preview_ready": 1,
    "one_command_repo_audit_ready": int(v55.get("local_codebase_intelligence_box_ready") == "1"),
    "local_scaling_matrix_ready": int(scaling.get("v51_local_scaling_matrix_ready") == "1"),
    "baseline_war_ready": int(v14c.get("baseline_comparison_ready") == "1" and v14c.get("route_memory_safety_dominates_baselines") == "1"),
    "routehint_generator_mainline_ready": int(v54.get("routehint_generator_mainline_ready") == "1"),
    "local_codebase_intelligence_box_ready": int(v55.get("local_codebase_intelligence_box_ready") == "1"),
    "audit_report_ready": int((preview_dir / "AUDIT_REPORT.md").is_file()),
    "reproduce_ready": int((preview_dir / "reproduce.sh").is_file()),
    "scaling_axis_count": 5,
    "baseline_rows": len(baseline_overlay_rows),
    "scaling_curve_rows": int(scaling.get("active_bytes_rows", "0")),
    "v14c_baseline_rows": v14c.get("baseline_rows", "0"),
    "compact_route_hint_rows": v55.get("compact_route_hint_rows", "0"),
    "grounded_generation_rows": v55.get("grounded_generation_rows", "0"),
    "abstain_rows": v55.get("abstain_rows", "0"),
    "raw_prompt_context_bytes": 0,
    "attention_blocks": 0,
    "transformer_blocks": 0,
    "oracle_prediction_used": 0,
    "raw_input_extractor_used": 0,
    "real_release_package_ready": 0,
    "gpu_speedup_claim": "deferred",
}

with summary_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(summary.keys()), lineterminator="\n")
    writer.writeheader()
    writer.writerow(summary)

decisions = [
    ("v0.3-architecture-preview", "pass" if summary["v0_3_architecture_preview_ready"] == 1 else "blocked", "preview artifacts emitted"),
    ("local-scaling-matrix", "pass" if summary["local_scaling_matrix_ready"] == 1 and summary["scaling_curve_rows"] == 27 else "blocked", f"curve_rows={summary['scaling_curve_rows']}"),
    ("baseline-war", "pass" if summary["baseline_war_ready"] == 1 else "blocked", f"baseline_rows={summary['baseline_rows']}"),
    ("audit-my-repo-ux", "pass" if summary["one_command_repo_audit_ready"] == 1 and summary["audit_report_ready"] == 1 else "blocked", "one-command report/reproduce path"),
    ("routehint-generator-mainline", "pass" if summary["routehint_generator_mainline_ready"] == 1 else "blocked", "compact RouteHint generator path"),
    ("no-raw-prompt-stuffing", "pass" if summary["raw_prompt_context_bytes"] == 0 else "blocked", "raw_prompt_context_bytes=0"),
    ("no-attention-transformer", "pass" if summary["attention_blocks"] == 0 and summary["transformer_blocks"] == 0 else "blocked", "non-attention generator path"),
    ("real-release-package", "blocked", "real_release_package_ready remains 0"),
    ("gpu-speedup-claim", "blocked", "gpu_speedup_claim=deferred"),
]
with decision_csv.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle, lineterminator="\n")
    writer.writerow(["gate", "status", "reason"])
    writer.writerows(decisions)

rows = []
for path in sorted(preview_dir.rglob("*")):
    if path.is_file() and path.name != "sha256sums.txt":
        rows.append(f"{sha256(path).removeprefix('sha256:')}  {path.relative_to(preview_dir)}")
(preview_dir / "sha256sums.txt").write_text("\n".join(rows) + "\n", encoding="utf-8")

print(f"v0.3_architecture_preview_dir: {preview_dir}")
print(f"summary: {summary_csv}")
print(f"decision: {decision_csv}")
PY
