#!/usr/bin/env python3
"""Build AMR beta maintainer-feedback request packets.

This is a read-only operator helper for blocker 9.3. It consumes a filled repo
intake sheet, optional verified label-intake directories, and optional returned
maintainer feedback rows. It writes case/contact request packets and progress
summaries, but it does not create feedback, does not emit raw feedback text,
does not run benchmarks, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from pathlib import Path

import amr_beta_human_input_status as human_status
import amr_beta_repo_intake_validate as repo_intake

SCHEMA = "amr_beta_maintainer_feedback_packet.v1"
MIN_MAINTAINERS = human_status.MIN_MAINTAINER_FEEDBACK_FOR_BETA
BLOCKED_FLAGS = {
    "design_partner_beta_candidate_ready": 0,
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
MANAGED_OUTPUTS = {
    "maintainer_feedback_request_packet.jsonl",
    "maintainer_feedback_missing_cases.jsonl",
    "maintainer_feedback_progress_summary.json",
}


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def read_json_or_jsonl(path: Path, input_name: str) -> list[dict]:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} file")
    return human_status.read_json_or_jsonl(path, input_name)


def load_repo_intake(path: Path, min_repos: int) -> tuple[list[dict], list[str], dict]:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like repo intake path")
    rows = repo_intake.read_rows(path)
    errors, summary = repo_intake.validate_rows(rows, min_repos=min_repos)
    normalized_rows: list[dict] = []
    for index, row in enumerate(rows, start=1):
        _row_errors, normalized = repo_intake.validate_row(row, index)
        normalized_rows.append(normalized)
    return normalized_rows, errors, summary


def load_label_context(label_intake_dirs: list[str]) -> tuple[set[str], set[str], dict[str, int], Counter[str]]:
    all_case_ids, countable_case_ids, summary = human_status.load_label_intake_context(label_intake_dirs)
    label_counts: Counter[str] = Counter()
    for raw_dir in label_intake_dirs:
        path = Path(raw_dir).expanduser().resolve()
        if is_forbidden_env_path(path):
            raise ValueError("refusing .env-like label intake path")
        for row in human_status.read_jsonl(path / "benchmark_labels.jsonl", "benchmark labels"):
            case_id = str(row.get("case_id") or "").strip()
            if case_id:
                label_counts[case_id] += 1
    return all_case_ids, countable_case_ids, summary, label_counts


def feedback_digest_preview(row: dict) -> str:
    digest = str(row.get("feedback_text_sha256") or row.get("feedback_sha256") or "").strip()
    if digest:
        return digest
    text = str(row.get("feedback_text") or "")
    if text:
        return "present_unemitted"
    return ""


def build_request_rows(
    repo_rows: list[dict],
    *,
    countable_case_ids: set[str],
    label_counts: Counter[str],
    feedback_rows: list[dict],
) -> tuple[list[dict], list[dict], dict[str, int]]:
    feedback_by_case: dict[str, list[dict]] = defaultdict(list)
    for row in feedback_rows:
        case_id = str(row.get("case_id") or "").strip()
        if case_id:
            feedback_by_case[case_id].append(row)

    request_rows: list[dict] = []
    missing_rows: list[dict] = []
    cases_with_feedback = 0
    countable_cases_with_feedback = 0
    for row in repo_rows:
        case_id = str(row.get("case_id") or "").strip()
        if not case_id:
            continue
        case_feedback = feedback_by_case.get(case_id, [])
        maintainer_ids = sorted(
            {
                str(feedback.get("maintainer_id") or "").strip()
                for feedback in case_feedback
                if str(feedback.get("maintainer_id") or "").strip()
            }
        )
        has_feedback = bool(case_feedback)
        countable = int(case_id in countable_case_ids) if countable_case_ids else 0
        if has_feedback:
            cases_with_feedback += 1
        if has_feedback and countable:
            countable_cases_with_feedback += 1
        request = {
            "schema": SCHEMA,
            "case_id": case_id,
            "repo_path": row.get("repo_path_resolved", ""),
            "expected_repo_git_head": row.get("expected_repo_git_head", ""),
            "owner_or_maintainer_contact": row.get("owner_or_maintainer_contact", ""),
            "audit_mode": row.get("audit_mode", ""),
            "namespace": row.get("namespace", ""),
            "countable_for_beta_precheck": countable,
            "label_intake_label_rows": int(label_counts.get(case_id, 0)),
            "feedback_rows_received": len(case_feedback),
            "maintainer_ids_received": maintainer_ids,
            "feedback_text_sha256_status": sorted({feedback_digest_preview(feedback) for feedback in case_feedback}),
            "next_action": (
                "collect_human_maintainer_feedback"
                if not has_feedback
                else "verify_feedback_counts_for_beta"
            ),
            **BLOCKED_FLAGS,
        }
        request_rows.append(request)
        if not has_feedback:
            missing_rows.append(
                {
                    "case_id": case_id,
                    "owner_or_maintainer_contact": row.get("owner_or_maintainer_contact", ""),
                    "countable_for_beta_precheck": countable,
                }
            )
    return request_rows, missing_rows, {
        "case_rows_with_feedback": cases_with_feedback,
        "countable_case_rows_with_feedback": countable_cases_with_feedback,
    }


def prepare_output_dir(out_dir: Path, overwrite: bool) -> None:
    if is_forbidden_env_path(out_dir):
        raise ValueError("refusing .env-like output directory")
    out_dir.mkdir(parents=True, exist_ok=True)
    children = list(out_dir.iterdir())
    if not children:
        return
    if not overwrite:
        raise ValueError("feedback packet output directory already contains artifacts; use --overwrite")
    for child in children:
        if child.name not in MANAGED_OUTPUTS or not child.is_file():
            raise ValueError(f"refusing to delete unrelated feedback packet output entry: {child.name}")
    for child in children:
        child.unlink()


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def write_outputs(out_dir: Path, request_rows: list[dict], missing_rows: list[dict], summary: dict, overwrite: bool) -> None:
    prepare_output_dir(out_dir, overwrite)
    write_jsonl(out_dir / "maintainer_feedback_request_packet.jsonl", request_rows)
    write_jsonl(out_dir / "maintainer_feedback_missing_cases.jsonl", missing_rows)
    (out_dir / "maintainer_feedback_progress_summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-intake", required=True, help="Filled repo-intake Markdown or CSV.")
    parser.add_argument(
        "--label-intake-dir",
        action="append",
        default=[],
        help="Optional verified label intake dir; repeatable. Enables countable-for-beta precheck.",
    )
    parser.add_argument("--feedback", default="", help="Optional returned maintainer feedback JSON/JSONL.")
    parser.add_argument("--out", default="", help="Optional output directory for packet artifacts.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--min-repos", type=int, default=repo_intake.MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--min-maintainers", type=int, default=MIN_MAINTAINERS)
    parser.add_argument("--enforce-min-maintainers", action="store_true")
    parser.add_argument("--require-countable-cases", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        repo_path = Path(args.repo_intake).expanduser().resolve()
        repo_rows, repo_errors, repo_summary = load_repo_intake(repo_path, args.min_repos)
        known_case_ids = {str(row.get("case_id") or "").strip() for row in repo_rows if str(row.get("case_id") or "").strip()}

        label_summary = {
            "label_intake_dir_count": 0,
            "label_intake_label_rows": 0,
            "label_intake_case_count": 0,
            "label_intake_countable_case_count": 0,
            "label_intake_synthetic_case_count": 0,
        }
        countable_case_ids: set[str] = set()
        label_counts: Counter[str] = Counter()
        if args.label_intake_dir:
            label_case_ids, countable_case_ids, label_summary, label_counts = load_label_context(args.label_intake_dir)
            unknown_label_cases = sorted(label_case_ids - known_case_ids)
            for case_id in unknown_label_cases:
                repo_errors.append(f"label intake case_id not present in repo intake: {case_id}")
        elif args.require_countable_cases:
            repo_errors.append("--require-countable-cases requires at least one --label-intake-dir")

        feedback_rows: list[dict] = []
        feedback_errors: list[str] = []
        feedback_summary = {
            "total_feedback_rows": 0,
            "valid_feedback_rows": 0,
            "distinct_maintainer_id_count": 0,
            "feedback_countable_case_rows": 0,
            "distinct_countable_maintainer_id_count": 0,
        }
        if args.feedback:
            feedback_rows = read_json_or_jsonl(Path(args.feedback).expanduser().resolve(), "feedback")
            feedback_errors, feedback_summary = human_status.validate_feedback(
                feedback_rows,
                known_case_ids=known_case_ids,
                countable_case_ids=countable_case_ids,
                require_countable_cases=bool(args.label_intake_dir) or args.require_countable_cases,
                min_maintainers=0,
            )
        elif args.enforce_min_maintainers:
            feedback_errors.append("feedback file is required when --enforce-min-maintainers is set")

        request_rows, missing_rows, request_counts = build_request_rows(
            repo_rows,
            countable_case_ids=countable_case_ids,
            label_counts=label_counts,
            feedback_rows=feedback_rows,
        )
        effective_maintainer_count = (
            feedback_summary["distinct_countable_maintainer_id_count"]
            if args.label_intake_dir or args.require_countable_cases
            else feedback_summary["distinct_maintainer_id_count"]
        )
        maintainer_requirement_met = int(effective_maintainer_count >= args.min_maintainers)
        if args.enforce_min_maintainers and maintainer_requirement_met == 0:
            feedback_errors.append(
                f"distinct_maintainer_id_count {effective_maintainer_count} below required minimum {args.min_maintainers}"
            )

        errors = [*repo_errors, *feedback_errors]
        summary = {
            "schema": SCHEMA,
            "repo_intake": str(repo_path),
            "request_case_rows": len(request_rows),
            "missing_feedback_case_rows": len(missing_rows),
            **request_counts,
            **repo_summary,
            **label_summary,
            **feedback_summary,
            "min_maintainer_feedback_required": args.min_maintainers,
            "maintainer_feedback_requirement_met": maintainer_requirement_met,
            "feedback_counts_for_beta_precheck": int(
                bool(args.label_intake_dir)
                and feedback_summary["valid_feedback_rows"] > 0
                and feedback_summary["valid_feedback_rows"] == len(feedback_rows)
                and feedback_summary["distinct_countable_maintainer_id_count"] >= args.min_maintainers
            ),
            "ready_for_runtime_preflight_feedback": int(not errors and maintainer_requirement_met == 1),
            "raw_feedback_text_emitted": 0,
            "creates_benchmark_evidence": 0,
            "output_files": sorted(MANAGED_OUTPUTS) if args.out else [],
            **BLOCKED_FLAGS,
        }
        if errors:
            if args.json or not args.out:
                print(json.dumps({**summary, "errors": errors}, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        if args.out:
            write_outputs(Path(args.out).expanduser().resolve(), request_rows, missing_rows, summary, args.overwrite)
        if args.json or not args.out:
            print(json.dumps({**summary, "errors": []}, indent=2, sort_keys=True))
        if not args.json and args.out:
            print(
                "maintainer_feedback_packet: ok "
                f"request_case_rows={summary['request_case_rows']} "
                f"distinct_maintainer_id_count={summary['distinct_maintainer_id_count']} "
                f"distinct_countable_maintainer_id_count={summary['distinct_countable_maintainer_id_count']}"
            )
        return 0
    except Exception as exc:
        print(f"maintainer_feedback_packet: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
