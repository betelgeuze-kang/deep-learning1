#!/usr/bin/env python3
"""Validate AMR beta human-label and maintainer-feedback inputs.

This is a read-only progress/status guard for blockers 9.2 and 9.3. It checks
human decision JSON/JSONL and maintainer feedback JSON/JSONL before benchmark
execution. It does not compile labels, does not run real_benchmark, and does
not promote readiness.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

MIN_HUMAN_LABELS_FOR_BETA = 300
MIN_MAINTAINER_FEEDBACK_FOR_BETA = 3
VALID_EXPECTED = {"present", "absent"}
VALID_PRIORITY = {"", "P0", "P1", "P2", "P3"}
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
PLACEHOLDER_RE = re.compile(r"(^$|example|placeholder|replace|todo)", re.IGNORECASE)


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def truthy(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def good_operator_value(value: object) -> bool:
    return not PLACEHOLDER_RE.search(str(value or "").strip())


def read_json_or_jsonl(path: Path, input_name: str) -> list[dict]:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} file")
    text = path.read_text(encoding="utf-8")
    stripped = text.strip()
    if not stripped:
        raise ValueError(f"{input_name} file is empty")
    if stripped.startswith("["):
        payload = json.loads(stripped)
        if not isinstance(payload, list):
            raise ValueError(f"{input_name} JSON must be a list")
        return payload
    if stripped.startswith("{"):
        try:
            payload = json.loads(stripped)
        except json.JSONDecodeError:
            payload = None
        if isinstance(payload, dict):
            for key in ["decisions", "feedback", "rows"]:
                rows = payload.get(key)
                if isinstance(rows, list):
                    return rows
    rows = []
    for index, line in enumerate(text.splitlines(), start=1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row, dict):
            raise ValueError(f"{input_name} line {index} must be an object")
        rows.append(row)
    return rows


def load_template_context(template_dirs: list[str]) -> tuple[set[str], set[str]]:
    candidate_ids: set[str] = set()
    case_ids: set[str] = set()
    for raw in template_dirs:
        path = Path(raw).expanduser().resolve()
        if is_forbidden_env_path(path):
            raise ValueError("refusing .env-like template path")
        payload_path = path / "label_template.json"
        if not payload_path.is_file():
            raise ValueError(f"template dir missing label_template.json: {path}")
        payload = json.loads(payload_path.read_text(encoding="utf-8"))
        rows = payload.get("rows", [])
        if not isinstance(rows, list):
            raise ValueError(f"template rows must be a list: {payload_path}")
        for row in rows:
            if not isinstance(row, dict):
                continue
            candidate_id = str(row.get("candidate_label_id") or "").strip()
            case_id = str(row.get("case_id") or "").strip()
            if candidate_id:
                candidate_ids.add(candidate_id)
            if case_id:
                case_ids.add(case_id)
    return candidate_ids, case_ids


def load_case_ids_from_repo_intake(path_text: str) -> set[str]:
    if not path_text:
        return set()
    path = Path(path_text).expanduser().resolve()
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like repo intake path")
    text = path.read_text(encoding="utf-8")
    case_ids: set[str] = set()
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped.startswith("|") or not stripped.endswith("|"):
            continue
        cells = [cell.strip() for cell in stripped.strip("|").split("|")]
        if not cells or cells[0].lower() in {"case_id", "---"}:
            continue
        if set(cells[0].replace(":", "").strip()) <= {"-"}:
            continue
        if good_operator_value(cells[0]):
            case_ids.add(cells[0])
    return case_ids


def validate_decisions(
    rows: list[dict],
    *,
    known_candidate_ids: set[str],
    min_labels: int,
) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    seen: set[str] = set()
    valid_rows = 0
    for index, row in enumerate(rows, start=1):
        candidate_id = str(row.get("candidate_label_id") or "").strip()
        row_errors: list[str] = []
        if not candidate_id:
            row_errors.append(f"decision row {index}: missing candidate_label_id")
        elif not good_operator_value(candidate_id):
            row_errors.append(f"decision row {index}: candidate_label_id must not be example/placeholder")
        elif candidate_id in seen:
            row_errors.append(f"decision row {index}: duplicate candidate_label_id")
        elif known_candidate_ids and candidate_id not in known_candidate_ids:
            row_errors.append(f"decision row {index}: unknown candidate_label_id")
        seen.add(candidate_id)
        if truthy(row.get("template_only", False)):
            row_errors.append(f"decision row {index}: template_only must be false/absent")
        if not truthy(row.get("human_labeled", row.get("human_reviewed", False))):
            row_errors.append(f"decision row {index}: human_labeled must be true")
        expected = str(row.get("expected") or row.get("human_expected") or "").strip().lower()
        if expected not in VALID_EXPECTED:
            row_errors.append(f"decision row {index}: expected must be present or absent")
        priority = str(row.get("priority", row.get("human_priority", "")) or "").strip().upper()
        if priority not in VALID_PRIORITY:
            row_errors.append(f"decision row {index}: invalid priority")
        if row_errors:
            errors.extend(row_errors)
        else:
            valid_rows += 1
    if valid_rows < min_labels:
        errors.append(f"valid_human_label_rows {valid_rows} below required minimum {min_labels}")
    return errors, {"total_decision_rows": len(rows), "valid_human_label_rows": valid_rows}


def read_jsonl(path: Path, input_name: str) -> list[dict]:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} file")
    rows: list[dict] = []
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row, dict):
            raise ValueError(f"{input_name} line {index} must be an object")
        rows.append(row)
    return rows


def load_label_intake_context(label_intake_dirs: list[str]) -> tuple[set[str], set[str], dict[str, int]]:
    all_case_ids: set[str] = set()
    case_human_labeled: dict[str, bool] = {}
    case_synthetic: dict[str, bool] = {}
    label_rows = 0
    for raw in label_intake_dirs:
        path = Path(raw).expanduser().resolve()
        if is_forbidden_env_path(path):
            raise ValueError("refusing .env-like label intake path")
        labels_path = path / "benchmark_labels.jsonl"
        if not labels_path.is_file():
            raise ValueError(f"label intake dir missing benchmark_labels.jsonl: {path}")
        for row in read_jsonl(labels_path, "benchmark labels"):
            label_rows += 1
            case_id = str(row.get("case_id") or "").strip()
            if not case_id:
                raise ValueError(f"label intake row {label_rows}: missing case_id")
            if not good_operator_value(case_id):
                raise ValueError(f"label intake row {label_rows}: case_id must not be example/placeholder")
            all_case_ids.add(case_id)
            case_human_labeled[case_id] = case_human_labeled.get(case_id, False) or truthy(
                row.get("human_labeled", False)
            )
            case_synthetic[case_id] = case_synthetic.get(case_id, False) or truthy(row.get("synthetic", False))
    countable_case_ids = {
        case_id
        for case_id in all_case_ids
        if case_human_labeled.get(case_id, False) and not case_synthetic.get(case_id, False)
    }
    return all_case_ids, countable_case_ids, {
        "label_intake_dir_count": len(label_intake_dirs),
        "label_intake_label_rows": label_rows,
        "label_intake_case_count": len(all_case_ids),
        "label_intake_countable_case_count": len(countable_case_ids),
        "label_intake_synthetic_case_count": sum(1 for case_id in all_case_ids if case_synthetic.get(case_id, False)),
    }


def validate_feedback(
    rows: list[dict],
    *,
    known_case_ids: set[str],
    countable_case_ids: set[str],
    require_countable_cases: bool,
    min_maintainers: int,
) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    maintainer_ids: set[str] = set()
    countable_maintainer_ids: set[str] = set()
    countable_case_ids_seen: set[str] = set()
    valid_rows = 0
    for index, row in enumerate(rows, start=1):
        row_errors: list[str] = []
        case_id = str(row.get("case_id") or "").strip()
        maintainer_id = str(row.get("maintainer_id") or "").strip()
        feedback_text = str(row.get("feedback_text") or "")
        feedback_sha = str(row.get("feedback_text_sha256") or row.get("feedback_sha256") or "").strip()
        if not case_id:
            row_errors.append(f"feedback row {index}: missing case_id")
        elif not good_operator_value(case_id):
            row_errors.append(f"feedback row {index}: case_id must not be example/placeholder")
        elif known_case_ids and case_id not in known_case_ids:
            row_errors.append(f"feedback row {index}: unknown case_id")
        elif require_countable_cases and case_id not in countable_case_ids:
            row_errors.append(
                f"feedback row {index}: case_id is not countable for beta; "
                "requires non-synthetic human-labeled label intake"
            )
        if not maintainer_id:
            row_errors.append(f"feedback row {index}: missing maintainer_id")
        elif not good_operator_value(maintainer_id):
            row_errors.append(f"feedback row {index}: maintainer_id must not be example/placeholder")
        if not truthy(row.get("human_feedback", row.get("maintainer_feedback", False))):
            row_errors.append(f"feedback row {index}: human_feedback must be true")
        if truthy(row.get("synthetic", False)):
            row_errors.append(f"feedback row {index}: synthetic must be false/absent")
        if not feedback_text and not SHA_RE.fullmatch(feedback_sha):
            row_errors.append(f"feedback row {index}: feedback_text or feedback_text_sha256 required")
        if feedback_text and not good_operator_value(feedback_text):
            row_errors.append(f"feedback row {index}: feedback_text must not be example/placeholder")
        if row_errors:
            errors.extend(row_errors)
        else:
            valid_rows += 1
            maintainer_ids.add(maintainer_id)
            if not require_countable_cases or case_id in countable_case_ids:
                countable_maintainer_ids.add(maintainer_id)
                countable_case_ids_seen.add(case_id)
    effective_maintainer_count = len(countable_maintainer_ids) if require_countable_cases else len(maintainer_ids)
    if effective_maintainer_count < min_maintainers:
        errors.append(
            f"distinct_maintainer_id_count {effective_maintainer_count} below required minimum {min_maintainers}"
        )
    return errors, {
        "total_feedback_rows": len(rows),
        "valid_feedback_rows": valid_rows,
        "distinct_maintainer_id_count": len(maintainer_ids),
        "feedback_countable_case_rows": len(countable_case_ids_seen),
        "distinct_countable_maintainer_id_count": len(countable_maintainer_ids),
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--decisions", required=True, help="Human decision JSON/JSONL file.")
    parser.add_argument("--feedback", required=True, help="Maintainer feedback JSON/JSONL file.")
    parser.add_argument("--repo-intake", default="", help="Optional filled repo-intake sheet for known case_ids.")
    parser.add_argument("--template-dir", action="append", default=[], help="Optional label template dir; repeatable.")
    parser.add_argument(
        "--label-intake-dir",
        action="append",
        default=[],
        help="Optional verified label intake dir; repeatable. Enables counts-for-beta feedback checks.",
    )
    parser.add_argument("--min-labels", type=int, default=MIN_HUMAN_LABELS_FOR_BETA)
    parser.add_argument("--min-maintainers", type=int, default=MIN_MAINTAINER_FEEDBACK_FOR_BETA)
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        known_candidate_ids, template_case_ids = load_template_context(args.template_dir)
        label_intake_case_ids, countable_case_ids, label_intake_summary = load_label_intake_context(
            args.label_intake_dir
        )
        known_case_ids = template_case_ids | load_case_ids_from_repo_intake(args.repo_intake) | label_intake_case_ids
        decision_rows = read_json_or_jsonl(Path(args.decisions).expanduser().resolve(), "decisions")
        feedback_rows = read_json_or_jsonl(Path(args.feedback).expanduser().resolve(), "feedback")
        decision_errors, decision_summary = validate_decisions(
            decision_rows,
            known_candidate_ids=known_candidate_ids,
            min_labels=args.min_labels,
        )
        feedback_errors, feedback_summary = validate_feedback(
            feedback_rows,
            known_case_ids=known_case_ids,
            countable_case_ids=countable_case_ids,
            require_countable_cases=bool(args.label_intake_dir),
            min_maintainers=args.min_maintainers,
        )
    except Exception as exc:
        print(f"human_input_status: error: {exc}", file=sys.stderr)
        return 1

    errors = [*decision_errors, *feedback_errors]
    summary = {
        "schema": "amr_beta_human_input_status.v1",
        **decision_summary,
        "min_human_label_rows_required": args.min_labels,
        "human_label_requirement_met": int(decision_summary["valid_human_label_rows"] >= args.min_labels),
        **feedback_summary,
        **label_intake_summary,
        "min_maintainer_feedback_required": args.min_maintainers,
        "maintainer_feedback_requirement_met": int(
            (
                feedback_summary["distinct_countable_maintainer_id_count"]
                if args.label_intake_dir
                else feedback_summary["distinct_maintainer_id_count"]
            )
            >= args.min_maintainers
        ),
        "feedback_counts_for_beta_precheck": int(
            not args.label_intake_dir
            or (
                feedback_summary["valid_feedback_rows"] > 0
                and feedback_summary["valid_feedback_rows"] == len(feedback_rows)
                and feedback_summary["distinct_countable_maintainer_id_count"] >= args.min_maintainers
            )
        ),
        "ready_for_real_benchmark_inputs": int(not errors),
        "design_partner_beta_candidate_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }
    if args.json:
        print(json.dumps({**summary, "errors": errors}, indent=2, sort_keys=True))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    print(
        "human_input_status: ok "
        f"valid_human_label_rows={summary['valid_human_label_rows']} "
        f"distinct_maintainer_id_count={summary['distinct_maintainer_id_count']}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
