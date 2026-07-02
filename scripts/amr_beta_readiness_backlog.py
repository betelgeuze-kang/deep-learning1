#!/usr/bin/env python3
"""Analyze AMR beta benchmark readiness and write a remediation backlog.

This consumes an existing `benchmark_readiness.json` produced by
`audit_my_repo_benchmark.py`. It does not run the benchmark, does not fabricate
human input, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

SCHEMA = "amr_beta_readiness_backlog.v1"
EXPECTED_READINESS_SCHEMA = "local_repo_audit_benchmark_readiness.v1"
BLOCKED_KEYS = [
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
]

GATE_REMEDIATION = {
    "real_repo_requirement_met": {
        "area": "repo_intake",
        "owner": "human_owner",
        "next_action": "Provide at least 10 real local repositories, then rerun the repo intake validator.",
    },
    "human_label_requirement_met": {
        "area": "human_labeling",
        "owner": "human_reviewer",
        "next_action": "Collect at least 300 non-template human decision rows and rerun label intake.",
    },
    "label_source_trace_requirement_met": {
        "area": "label_provenance",
        "owner": "operator",
        "next_action": "Regenerate label templates/intake so every label preserves candidate and review-queue trace ids.",
    },
    "repo_snapshot_requirement_met": {
        "area": "repo_snapshot",
        "owner": "human_owner",
        "next_action": "Clean worktrees, pin expected HEADs, and rerun repo intake plus label intake as needed.",
    },
    "maintainer_feedback_requirement_met": {
        "area": "maintainer_feedback",
        "owner": "human_owner",
        "next_action": "Collect feedback from at least 3 distinct maintainers attached to countable real cases.",
    },
    "overall_precision_requirement_met": {
        "area": "precision_hardening",
        "owner": "codex_after_real_evidence",
        "next_action": "Analyze FP/FN categories, separate label-quality issues from engine issues, then tune parsers/rules.",
    },
    "p0_p1_precision_requirement_met": {
        "area": "critical_precision_hardening",
        "owner": "codex_after_real_evidence",
        "next_action": "Prioritize P0/P1 FP/FN review and tighten high-severity evidence policy before rerun.",
    },
    "citation_validity_requirement_met": {
        "area": "citation_validity",
        "owner": "codex_after_real_evidence",
        "next_action": "Inspect failed citation rows and fix source span, parser, or citation binding defects.",
    },
    "label_citation_expectation_requirement_met": {
        "area": "label_citation_expectations",
        "owner": "human_reviewer_and_operator",
        "next_action": "Add or correct human citation expectations, then rerun label intake and benchmark.",
    },
    "standard_json_findings_requirement_met": {
        "area": "output_contract",
        "owner": "codex_after_real_evidence",
        "next_action": "Fix standard JSON finding contract failures before rerunning the benchmark.",
    },
    "install_success_requirement_met": {
        "area": "install_preflight",
        "owner": "operator",
        "next_action": "Repair install/preflight blockers in the target environment, then rerun benchmark checks.",
    },
    "first_report_requirement_met": {
        "area": "first_report",
        "owner": "operator",
        "next_action": "Inspect first-report failures/timeouts and reduce setup or report-generation blockers.",
    },
    "rerun_requirement_met": {
        "area": "rerun_reproducibility",
        "owner": "operator",
        "next_action": "Investigate rerun/cache/semantic drift and stabilize deterministic replay before rerun.",
    },
    "label_quality_requirement_met": {
        "area": "label_quality",
        "owner": "human_reviewer_and_operator",
        "next_action": "Remove broad, citation-unbound, duplicate, or contradictory label rows before rerun.",
    },
}


def is_forbidden_env_path(path: Path) -> bool:
    for part in path.parts:
        if part == ".env" or part.startswith(".env.") or part.endswith(".env") or ".env." in part:
            return True
    return False


def load_readiness(path: Path) -> dict:
    if is_forbidden_env_path(path):
        raise ValueError("refusing to read .env-like readiness path")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError("benchmark_readiness.json must contain an object")
    return payload


def validate_readiness(payload: dict) -> list[str]:
    errors: list[str] = []
    if payload.get("schema_version") != EXPECTED_READINESS_SCHEMA:
        errors.append("unexpected benchmark readiness schema_version")
    if payload.get("claim_boundary") != "alpha-local-code-doc-audit-only":
        errors.append("unexpected claim_boundary")
    for key in BLOCKED_KEYS:
        if payload.get(key) != 0:
            errors.append(f"benchmark_readiness must keep {key}=0")
    rows = payload.get("rows", [])
    if not isinstance(rows, list):
        errors.append("benchmark_readiness rows must be a list")
        rows = []
    gate_rows = len(rows)
    passed_rows = sum(1 for row in rows if int(row.get("passed", 0)) == 1)
    blocked_rows = gate_rows - passed_rows
    if payload.get("gate_rows") != gate_rows:
        errors.append("benchmark_readiness gate_rows mismatch")
    if payload.get("passed_gate_rows") != passed_rows:
        errors.append("benchmark_readiness passed_gate_rows mismatch")
    if payload.get("blocked_gate_rows") != blocked_rows:
        errors.append("benchmark_readiness blocked_gate_rows mismatch")
    if int(payload.get("design_partner_beta_candidate_ready", 0)) == 1 and blocked_rows:
        errors.append("beta-ready readiness cannot contain blocked gates")
    if int(payload.get("design_partner_beta_candidate_ready", 0)) == 0 and gate_rows and not blocked_rows:
        errors.append("non-ready readiness must expose at least one blocked gate")
    for index, row in enumerate(rows, start=1):
        if not isinstance(row, dict):
            errors.append(f"readiness row {index} must be an object")
            continue
        if not str(row.get("gate_id", "")):
            errors.append(f"readiness row {index} missing gate_id")
        if int(row.get("passed", 0)) not in {0, 1}:
            errors.append(f"readiness row {index} invalid passed flag")
        if int(row.get("passed", 0)) == 0 and not str(row.get("blocked_reason", "")).strip():
            errors.append(f"readiness row {index} blocked gate missing blocked_reason")
    return errors


def build_backlog(payload: dict) -> list[dict]:
    backlog: list[dict] = []
    for row in payload.get("rows", []):
        if int(row.get("passed", 0)) == 1:
            continue
        gate_id = str(row.get("gate_id", ""))
        remediation = GATE_REMEDIATION.get(
            gate_id,
            {
                "area": "unknown",
                "owner": "operator",
                "next_action": "Inspect the blocked readiness gate and update this backlog mapping.",
            },
        )
        backlog.append(
            {
                "gate_id": gate_id,
                "area": remediation["area"],
                "owner": remediation["owner"],
                "blocked_reason": str(row.get("blocked_reason", "")),
                "observed": str(row.get("observed", "")),
                "required": str(row.get("required", "")),
                "next_action": remediation["next_action"],
                "counts_as_release_ready": 0,
                "design_partner_beta_candidate_ready": 0,
            }
        )
    return backlog


def write_markdown(path: Path, summary: dict, backlog: list[dict]) -> None:
    lines = [
        "# AMR Beta Readiness Backlog",
        "",
        f"- design_partner_beta_candidate_ready: {summary['design_partner_beta_candidate_ready']}",
        f"- blocked_gate_rows: {summary['blocked_gate_rows']}",
        f"- backlog_items: {len(backlog)}",
        "- release/public/model readiness: 0",
        "",
    ]
    if not backlog:
        lines.append("No blocked readiness gates were reported.")
    for item in backlog:
        lines.extend(
            [
                f"## {item['gate_id']}",
                "",
                f"- area: {item['area']}",
                f"- owner: {item['owner']}",
                f"- observed: {item['observed']}",
                f"- required: {item['required']}",
                f"- blocked_reason: {item['blocked_reason']}",
                f"- next_action: {item['next_action']}",
                "",
            ]
        )
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def run_verify_existing(benchmark_out: Path) -> None:
    result = subprocess.run(
        [sys.executable, "scripts/audit_my_repo_benchmark.py", "--verify-existing", str(benchmark_out)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        raise ValueError(f"benchmark --verify-existing failed{suffix}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--readiness", help="Path to benchmark_readiness.json.")
    source.add_argument("--benchmark-out", help="Benchmark output directory containing benchmark_readiness.json.")
    parser.add_argument("--out-json", required=True, help="Backlog JSON output path.")
    parser.add_argument("--out-md", default="", help="Optional Markdown backlog output path.")
    parser.add_argument("--verify-existing", action="store_true", help="Run benchmark --verify-existing first.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        benchmark_out = Path(args.benchmark_out).expanduser().resolve() if args.benchmark_out else None
        if benchmark_out and args.verify_existing:
            run_verify_existing(benchmark_out)
        readiness_path = (
            benchmark_out / "benchmark_readiness.json"
            if benchmark_out
            else Path(args.readiness).expanduser().resolve()
        )
        payload = load_readiness(readiness_path)
        errors = validate_readiness(payload)
        backlog = build_backlog(payload) if not errors else []
        summary = {
            "schema": SCHEMA,
            "input_readiness": str(readiness_path),
            "product_readiness_calculated_from_real_labels": int(
                payload.get("product_readiness_calculated_from_real_labels", 0)
            ),
            "design_partner_beta_candidate_ready": int(payload.get("design_partner_beta_candidate_ready", 0)),
            "gate_rows": int(payload.get("gate_rows", 0)),
            "passed_gate_rows": int(payload.get("passed_gate_rows", 0)),
            "blocked_gate_rows": int(payload.get("blocked_gate_rows", 0)),
            "backlog_items": len(backlog),
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
        }
        out_json = Path(args.out_json).expanduser().resolve()
        out_md = Path(args.out_md).expanduser().resolve() if args.out_md else None
        for path in [out_json, *([out_md] if out_md else [])]:
            if is_forbidden_env_path(path):
                raise ValueError("refusing .env-like output path")
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.exists() and not args.overwrite:
                raise ValueError(f"output already exists; use --overwrite: {path}")
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            if args.json:
                print(json.dumps({**summary, "errors": errors, "backlog": []}, indent=2, sort_keys=True))
            return 1
        out_json.write_text(
            json.dumps({**summary, "backlog": backlog}, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        if out_md:
            write_markdown(out_md, summary, backlog)
        if args.json:
            print(json.dumps({**summary, "errors": [], "backlog": backlog}, indent=2, sort_keys=True))
        else:
            print(f"readiness_backlog: ok backlog_items={len(backlog)}")
        return 0
    except Exception as exc:
        print(f"readiness_backlog: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
