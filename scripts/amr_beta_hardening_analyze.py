#!/usr/bin/env python3
"""Analyze AMR beta benchmark hardening categories.

This consumes existing benchmark artifacts and produces a compact FP/FN,
citation, and label-quality hardening backlog. It does not run benchmarks,
does not read repository source files, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from collections import Counter
from pathlib import Path

SCHEMA = "amr_beta_hardening_analysis.v1"
AUDIT_BENCHMARK = Path(__file__).resolve().parent / "audit_my_repo_benchmark.py"
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def read_csv(path: Path, input_name: str) -> list[dict[str, str]]:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} path")
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def read_json(path: Path, input_name: str) -> dict:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} path")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{input_name} must contain an object")
    return payload


def run_verify_existing(benchmark_out: Path) -> None:
    result = subprocess.run(
        [sys.executable, str(AUDIT_BENCHMARK), "--verify-existing", str(benchmark_out)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        raise ValueError(f"benchmark --verify-existing failed{suffix}")


def group_key(row: dict[str, str]) -> tuple[str, str, str, str]:
    return (
        row.get("plugin_id", ""),
        row.get("rule_id", ""),
        row.get("priority", ""),
        row.get("file_path", ""),
    )


def top_counter(counter: Counter[tuple[str, str, str, str]], limit: int) -> list[dict]:
    rows: list[dict] = []
    for (plugin_id, rule_id, priority, file_path), count in counter.most_common(limit):
        rows.append(
            {
                "count": count,
                "plugin_id": plugin_id,
                "rule_id": rule_id,
                "priority": priority,
                "file_path": file_path,
            }
        )
    return rows


def analyze_confusion(rows: list[dict[str, str]], limit: int) -> tuple[dict, list[dict]]:
    fp_rows = [row for row in rows if row.get("outcome") == "FP" or row.get("fp") == "1"]
    fn_rows = [row for row in rows if row.get("outcome") == "FN" or row.get("fn") == "1"]
    fp_counter = Counter(group_key(row) for row in fp_rows)
    fn_counter = Counter(group_key(row) for row in fn_rows)
    backlog: list[dict] = []
    if fp_rows:
        backlog.append(
            {
                "area": "precision_hardening",
                "kind": "false_positive",
                "count": len(fp_rows),
                "owner": "codex_after_real_evidence",
                "top_categories": top_counter(fp_counter, limit),
                "next_action": "Inspect top FP plugin/rule/file categories and tighten parser/rule evidence policy.",
                "design_partner_beta_candidate_ready": 0,
            }
        )
    if fn_rows:
        backlog.append(
            {
                "area": "recall_gap",
                "kind": "false_negative",
                "count": len(fn_rows),
                "owner": "codex_after_real_evidence",
                "top_categories": top_counter(fn_counter, limit),
                "next_action": "Inspect top FN categories and decide whether parser coverage or label scope needs remediation.",
                "design_partner_beta_candidate_ready": 0,
            }
        )
    return {"fp_rows": len(fp_rows), "fn_rows": len(fn_rows)}, backlog


def analyze_citations(rows: list[dict[str, str]], limit: int) -> tuple[dict, list[dict]]:
    failed = [row for row in rows if row.get("citation_valid") == "0"]
    reason_counter: Counter[tuple[str, str, str, str]] = Counter()
    for row in failed:
        reasons = [reason for reason in row.get("invalid_reasons", "").split("|") if reason]
        if not reasons:
            reasons = ["unknown"]
        for reason in reasons:
            reason_counter[(reason, "", "", row.get("file_path", ""))] += 1
    backlog: list[dict] = []
    if failed:
        backlog.append(
            {
                "area": "citation_validity",
                "kind": "citation_failure",
                "count": len(failed),
                "owner": "codex_after_real_evidence",
                "top_categories": top_counter(reason_counter, limit),
                "next_action": "Inspect invalid citation reason groups and repair source span or citation binding defects.",
                "design_partner_beta_candidate_ready": 0,
            }
        )
    return {"citation_failed_rows": len(failed)}, backlog


def analyze_label_quality(rows: list[dict[str, str]], limit: int) -> tuple[dict, list[dict]]:
    flag_to_area = {
        "is_broad": "label_quality_broad",
        "is_citation_unbound": "label_quality_citation_unbound",
        "is_duplicate": "label_quality_duplicate",
        "is_contradictory": "label_quality_contradictory",
    }
    summary: dict[str, int] = {}
    backlog: list[dict] = []
    for flag, area in flag_to_area.items():
        flagged = [row for row in rows if row.get(flag) == "1"]
        summary[f"{flag}_rows"] = len(flagged)
        if flagged:
            backlog.append(
                {
                    "area": area,
                    "kind": flag,
                    "count": len(flagged),
                    "owner": "human_reviewer_and_operator",
                    "top_categories": top_counter(Counter(group_key(row) for row in flagged), limit),
                    "next_action": "Fix or remove affected human label rows, then rerun label intake and benchmark.",
                    "design_partner_beta_candidate_ready": 0,
                }
            )
    return summary, backlog


def write_markdown(path: Path, payload: dict) -> None:
    lines = [
        "# AMR Beta Hardening Analysis",
        "",
        f"- fp_rows: {payload['fp_rows']}",
        f"- fn_rows: {payload['fn_rows']}",
        f"- citation_failed_rows: {payload['citation_failed_rows']}",
        f"- backlog_items: {payload['backlog_items']}",
        "- release/public/model readiness: 0",
        "",
    ]
    if not payload["backlog"]:
        lines.append("No hardening backlog items were produced from the supplied artifacts.")
    for item in payload["backlog"]:
        lines.extend(
            [
                f"## {item['area']}",
                "",
                f"- kind: {item['kind']}",
                f"- count: {item['count']}",
                f"- owner: {item['owner']}",
                f"- next_action: {item['next_action']}",
                "",
            ]
        )
        for category in item["top_categories"]:
            lines.append(
                "- category: "
                f"count={category['count']} plugin={category['plugin_id']} "
                f"rule={category['rule_id']} priority={category['priority']} file={category['file_path']}"
            )
        lines.append("")
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmark-out", required=True, help="Benchmark output directory.")
    parser.add_argument("--out-json", required=True, help="Hardening analysis JSON output path.")
    parser.add_argument("--out-md", default="", help="Optional Markdown output path.")
    parser.add_argument("--verify-existing", action="store_true")
    parser.add_argument("--top", type=int, default=10)
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        benchmark_out = Path(args.benchmark_out).expanduser().resolve()
        if is_forbidden_env_path(benchmark_out):
            raise ValueError("refusing .env-like benchmark output path")
        if args.verify_existing:
            run_verify_existing(benchmark_out)
        required = {
            "confusion": benchmark_out / "benchmark_confusion_rows.csv",
            "citation": benchmark_out / "benchmark_citation_validity.csv",
            "label_quality": benchmark_out / "benchmark_label_quality.csv",
            "readiness": benchmark_out / "benchmark_readiness.json",
        }
        missing = [name for name, path in required.items() if not path.is_file()]
        if missing:
            raise ValueError(f"benchmark output missing required artifacts: {', '.join(missing)}")
        readiness = read_json(required["readiness"], "benchmark readiness")
        for key, value in BLOCKED_FLAGS.items():
            if int(readiness.get(key, 0)) != value:
                raise ValueError(f"benchmark readiness must keep {key}=0")
        confusion_summary, confusion_backlog = analyze_confusion(read_csv(required["confusion"], "confusion"), args.top)
        citation_summary, citation_backlog = analyze_citations(read_csv(required["citation"], "citation validity"), args.top)
        label_summary, label_backlog = analyze_label_quality(read_csv(required["label_quality"], "label quality"), args.top)
        backlog = [*confusion_backlog, *citation_backlog, *label_backlog]
        payload = {
            "schema": SCHEMA,
            "benchmark_out": str(benchmark_out),
            "design_partner_beta_candidate_ready": int(readiness.get("design_partner_beta_candidate_ready", 0)),
            **BLOCKED_FLAGS,
            **confusion_summary,
            **citation_summary,
            **label_summary,
            "backlog_items": len(backlog),
            "backlog": backlog,
        }
        out_json = Path(args.out_json).expanduser().resolve()
        out_md = Path(args.out_md).expanduser().resolve() if args.out_md else None
        for path in [out_json, *([out_md] if out_md else [])]:
            if is_forbidden_env_path(path):
                raise ValueError("refusing .env-like output path")
            path.parent.mkdir(parents=True, exist_ok=True)
            if path.exists() and not args.overwrite:
                raise ValueError(f"output already exists; use --overwrite: {path}")
        out_json.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        if out_md:
            write_markdown(out_md, payload)
        if args.json:
            print(json.dumps({**payload, "errors": []}, indent=2, sort_keys=True))
        else:
            print(f"hardening_analysis: ok backlog_items={len(backlog)}")
        return 0
    except Exception as exc:
        print(f"hardening_analysis: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
