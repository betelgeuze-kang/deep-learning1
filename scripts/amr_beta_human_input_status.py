#!/usr/bin/env python3
"""Validate AMR beta human-label and maintainer-feedback inputs.

This is a read-only progress/status guard for blockers 9.2 and 9.3. It checks
human decision JSON/JSONL and maintainer feedback JSON/JSONL before benchmark
execution. It does not compile labels, does not run real_benchmark, and does
not promote readiness.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

MIN_HUMAN_LABELS_FOR_BETA = 300
MIN_MAINTAINER_FEEDBACK_FOR_BETA = 3
VALID_EXPECTED = {"present", "absent"}
VALID_PRIORITY = {"", "P0", "P1", "P2", "P3"}
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
PLACEHOLDER_RE = re.compile(r"(^$|example|placeholder|replace|todo)", re.IGNORECASE)
SAFE_LABEL_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,191}$")
SAFE_CASE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
SAFE_MAINTAINER_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:@+-]{0,191}$")


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def truthy(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def good_operator_value(value: object) -> bool:
    return not PLACEHOLDER_RE.search(str(value or "").strip())


def normalize_repo_intake_header(value: str) -> str:
    text = re.sub(r"\([^)]*\)", "", value.strip().lower())
    text = re.sub(r"[^a-z0-9]+", "_", text).strip("_")
    return {
        "repo_id": "case_id",
        "local_path": "repo_path",
        "path": "repo_path",
    }.get(text, text)


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def repo_intake_rows(path: Path) -> list[dict[str, str]]:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like repo intake path")
    text = path.read_text(encoding="utf-8")
    first_nonempty = next((line.strip() for line in text.splitlines() if line.strip()), "")
    if not first_nonempty:
        return []
    if first_nonempty.startswith("|"):
        rows: list[dict[str, str]] = []
        header: list[str] | None = None
        for line in text.splitlines():
            stripped = line.strip()
            if not stripped.startswith("|") or not stripped.endswith("|"):
                if header and rows:
                    break
                continue
            cells = [cell.strip() for cell in stripped.strip("|").split("|")]
            if all(set(cell.replace(":", "").strip()) <= {"-"} for cell in cells):
                continue
            normalized = [normalize_repo_intake_header(cell) for cell in cells]
            if header is None:
                if "case_id" in normalized or "repo_path" in normalized:
                    header = normalized
                continue
            rows.append({column: cells[index] if index < len(cells) else "" for index, column in enumerate(header)})
        return rows
    with path.open(newline="", encoding="utf-8") as handle:
        return [
            {normalize_repo_intake_header(key or ""): str(value or "").strip() for key, value in row.items()}
            for row in csv.DictReader(handle)
        ]


def load_repo_intake_context(path_text: str) -> tuple[set[str], set[str]]:
    if not path_text:
        return set(), set()
    rows = repo_intake_rows(Path(path_text).expanduser().resolve())
    case_ids: set[str] = set()
    repo_paths: set[str] = set()
    for row in rows:
        case_id = str(row.get("case_id") or "").strip()
        if case_id and good_operator_value(case_id):
            case_ids.add(case_id)
        raw_repo = str(row.get("repo_path") or "").strip()
        if raw_repo and good_operator_value(raw_repo):
            repo_paths.add(str(Path(raw_repo).expanduser().resolve()))
    return case_ids, repo_paths


def validate_output_paths(paths: dict[str, Path], target_repo_paths: set[str]) -> list[str]:
    errors: list[str] = []
    seen: dict[Path, str] = {}
    for name, path in paths.items():
        resolved = path.resolve()
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved in seen:
            errors.append(f"{name} must not reuse {seen[resolved]} path: {resolved}")
        seen[resolved] = name
        for raw_repo in sorted(target_repo_paths):
            repo_path = Path(raw_repo).expanduser().resolve()
            if resolved == repo_path or is_relative_to(resolved, repo_path):
                errors.append(f"{name} must not be inside target repo: {resolved} (repo: {repo_path})")
    return errors


def validate_optional_safe_id(
    *,
    errors: list[str],
    row_prefix: str,
    field: str,
    value: object,
    pattern: re.Pattern[str],
) -> None:
    text = str(value or "").strip()
    if not text:
        return
    if not good_operator_value(text):
        errors.append(f"{row_prefix}: {field} must not be example/placeholder")
    elif not pattern.fullmatch(text):
        errors.append(f"{row_prefix}: {field} must be a safe identifier")


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


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


def load_template_context(template_dirs: list[str]) -> tuple[set[str], set[str], set[str], set[str]]:
    candidate_ids: set[str] = set()
    non_synthetic_candidate_ids: set[str] = set()
    synthetic_candidate_ids: set[str] = set()
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
                if truthy(row.get("synthetic", True)):
                    synthetic_candidate_ids.add(candidate_id)
                else:
                    non_synthetic_candidate_ids.add(candidate_id)
            if case_id:
                case_ids.add(case_id)
    return candidate_ids, case_ids, non_synthetic_candidate_ids, synthetic_candidate_ids


def validate_decisions(
    rows: list[dict],
    *,
    known_candidate_ids: set[str],
    non_synthetic_candidate_ids: set[str],
    template_context_supplied: bool,
    min_labels: int,
) -> tuple[list[str], dict[str, int]]:
    errors: list[str] = []
    seen: set[str] = set()
    valid_rows = 0
    non_synthetic_valid_rows = 0
    synthetic_or_unverified_valid_rows = 0
    for index, row in enumerate(rows, start=1):
        candidate_id = str(row.get("candidate_label_id") or "").strip()
        row_errors: list[str] = []
        if not candidate_id:
            row_errors.append(f"decision row {index}: missing candidate_label_id")
        elif not good_operator_value(candidate_id):
            row_errors.append(f"decision row {index}: candidate_label_id must not be example/placeholder")
        elif not SAFE_LABEL_ID_RE.fullmatch(candidate_id):
            row_errors.append(f"decision row {index}: candidate_label_id must be a safe identifier")
        elif candidate_id in seen:
            row_errors.append(f"decision row {index}: duplicate candidate_label_id")
        elif known_candidate_ids and candidate_id not in known_candidate_ids:
            row_errors.append(f"decision row {index}: unknown candidate_label_id")
        seen.add(candidate_id)
        validate_optional_safe_id(
            errors=row_errors,
            row_prefix=f"decision row {index}",
            field="label_id",
            value=row.get("label_id"),
            pattern=SAFE_LABEL_ID_RE,
        )
        validate_optional_safe_id(
            errors=row_errors,
            row_prefix=f"decision row {index}",
            field="reviewer_id",
            value=row.get("reviewer_id"),
            pattern=SAFE_LABEL_ID_RE,
        )
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
            if template_context_supplied:
                if candidate_id in non_synthetic_candidate_ids:
                    non_synthetic_valid_rows += 1
                else:
                    synthetic_or_unverified_valid_rows += 1
            else:
                non_synthetic_valid_rows += 1
    if non_synthetic_valid_rows < min_labels:
        errors.append(
            "non_synthetic_valid_human_label_rows "
            f"{non_synthetic_valid_rows} below required minimum {min_labels}"
        )
    return errors, {
        "total_decision_rows": len(rows),
        "valid_human_label_rows": valid_rows,
        "non_synthetic_valid_human_label_rows": non_synthetic_valid_rows,
        "synthetic_or_unverified_human_label_rows": synthetic_or_unverified_valid_rows,
    }


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


def verify_label_intake_existing(path: Path) -> list[str]:
    if is_forbidden_env_path(path):
        return ["refusing .env-like label intake path"]
    tool = Path(__file__).resolve().parent / "audit_my_repo_label_intake.py"
    proc = subprocess.run(
        [sys.executable, str(tool), "--verify-existing", str(path)],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if proc.returncode == 0:
        return []
    detail = (proc.stderr or proc.stdout).strip()
    first_line = detail.splitlines()[0] if detail else "unknown failure"
    return [f"{path}: label_intake --verify-existing failed: {first_line}"]


def load_label_intake_context(
    label_intake_dirs: list[str],
    *,
    verify_existing: bool = True,
) -> tuple[set[str], set[str], dict[str, int]]:
    all_case_ids: set[str] = set()
    case_human_labeled: dict[str, bool] = {}
    case_synthetic: dict[str, bool] = {}
    label_rows = 0
    verify_passed_dirs = 0
    verify_failed_dirs = 0
    verify_errors: list[str] = []
    for raw in label_intake_dirs:
        path = Path(raw).expanduser().resolve()
        if is_forbidden_env_path(path):
            raise ValueError("refusing .env-like label intake path")
        if verify_existing:
            errors = verify_label_intake_existing(path)
            if errors:
                verify_failed_dirs += 1
                verify_errors.extend(errors)
            else:
                verify_passed_dirs += 1
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
            if not SAFE_CASE_ID_RE.fullmatch(case_id):
                raise ValueError(f"label intake row {label_rows}: case_id must be a safe identifier")
            all_case_ids.add(case_id)
            case_human_labeled[case_id] = case_human_labeled.get(case_id, False) or truthy(
                row.get("human_labeled", False)
            )
            case_synthetic[case_id] = case_synthetic.get(case_id, False) or truthy(row.get("synthetic", False))
    if verify_errors:
        raise ValueError("; ".join(verify_errors))
    countable_case_ids = {
        case_id
        for case_id in all_case_ids
        if case_human_labeled.get(case_id, False) and not case_synthetic.get(case_id, False)
    }
    return all_case_ids, countable_case_ids, {
        "label_intake_dir_count": len(label_intake_dirs),
        "label_intake_verify_existing_required": int(verify_existing and bool(label_intake_dirs)),
        "label_intake_verify_existing_passed_dirs": verify_passed_dirs,
        "label_intake_verify_existing_failed_dirs": verify_failed_dirs,
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
    seen_feedback_ids: set[str] = set()
    valid_rows = 0
    valid_feedback_text_input_rows = 0
    valid_feedback_hash_only_rows = 0
    valid_feedback_digest_rows = 0
    for index, row in enumerate(rows, start=1):
        row_errors: list[str] = []
        case_id = str(row.get("case_id") or "").strip()
        maintainer_id = str(row.get("maintainer_id") or "").strip()
        feedback_id = str(row.get("feedback_id") or f"feedback_{index:04d}").strip()
        feedback_text = str(row.get("feedback_text") or "")
        feedback_sha = str(row.get("feedback_text_sha256") or row.get("feedback_sha256") or "").strip()
        if not case_id:
            row_errors.append(f"feedback row {index}: missing case_id")
        elif not good_operator_value(case_id):
            row_errors.append(f"feedback row {index}: case_id must not be example/placeholder")
        elif not SAFE_CASE_ID_RE.fullmatch(case_id):
            row_errors.append(f"feedback row {index}: case_id must be a safe identifier")
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
        elif not SAFE_MAINTAINER_ID_RE.fullmatch(maintainer_id):
            row_errors.append(f"feedback row {index}: maintainer_id must be a safe identifier")
        if not feedback_id:
            row_errors.append(f"feedback row {index}: feedback_id must be a safe identifier")
        elif not good_operator_value(feedback_id):
            row_errors.append(f"feedback row {index}: feedback_id must not be example/placeholder")
        elif not SAFE_CASE_ID_RE.fullmatch(feedback_id):
            row_errors.append(f"feedback row {index}: feedback_id must be a safe identifier")
        if feedback_id:
            if feedback_id in seen_feedback_ids:
                row_errors.append(f"feedback row {index}: duplicate feedback_id")
            seen_feedback_ids.add(feedback_id)
        if not truthy(row.get("human_feedback", row.get("maintainer_feedback", False))):
            row_errors.append(f"feedback row {index}: human_feedback must be true")
        if truthy(row.get("synthetic", False)):
            row_errors.append(f"feedback row {index}: synthetic must be false/absent")
        if feedback_sha and not SHA_RE.fullmatch(feedback_sha):
            row_errors.append(f"feedback row {index}: feedback_text_sha256 must be sha256:<64 hex>")
        if feedback_text and SHA_RE.fullmatch(feedback_sha) and sha256_text(feedback_text) != feedback_sha:
            row_errors.append(f"feedback row {index}: feedback_text_sha256 must match feedback_text")
        if not feedback_text and not SHA_RE.fullmatch(feedback_sha):
            row_errors.append(f"feedback row {index}: feedback_text or feedback_text_sha256 required")
        if feedback_text and not good_operator_value(feedback_text):
            row_errors.append(f"feedback row {index}: feedback_text must not be example/placeholder")
        if row_errors:
            errors.extend(row_errors)
        else:
            valid_rows += 1
            if feedback_text:
                valid_feedback_text_input_rows += 1
            if not feedback_text and SHA_RE.fullmatch(feedback_sha):
                valid_feedback_hash_only_rows += 1
            if feedback_text or SHA_RE.fullmatch(feedback_sha):
                valid_feedback_digest_rows += 1
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
        "valid_feedback_text_input_rows": valid_feedback_text_input_rows,
        "valid_feedback_hash_only_rows": valid_feedback_hash_only_rows,
        "valid_feedback_digest_rows": valid_feedback_digest_rows,
        "distinct_maintainer_id_count": len(maintainer_ids),
        "feedback_countable_case_rows": len(countable_case_ids_seen),
        "distinct_countable_maintainer_id_count": len(countable_maintainer_ids),
    }


def progress_percent(value: int, minimum: int) -> float:
    if minimum <= 0:
        return 0.0
    return round(min(value, minimum) * 100.0 / minimum, 2)


def write_json(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like JSON output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_markdown(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like Markdown output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    lines = [
        "# AMR Beta Human Input Status",
        "",
        f"- ready_for_real_benchmark_inputs: {payload['ready_for_real_benchmark_inputs']}",
        f"- valid_human_label_rows: {payload['valid_human_label_rows']}",
        f"- non_synthetic_valid_human_label_rows: {payload['non_synthetic_valid_human_label_rows']}",
        f"- synthetic_or_unverified_human_label_rows: {payload['synthetic_or_unverified_human_label_rows']}",
        f"- min_human_label_rows_required: {payload['min_human_label_rows_required']}",
        f"- remaining_human_label_rows: {payload['remaining_human_label_rows']}",
        f"- human_label_progress_percent: {payload['human_label_progress_percent']}",
        f"- effective_maintainer_id_count: {payload['effective_maintainer_id_count']}",
        f"- min_maintainer_feedback_required: {payload['min_maintainer_feedback_required']}",
        f"- remaining_distinct_maintainer_ids: {payload['remaining_distinct_maintainer_ids']}",
        f"- maintainer_feedback_progress_percent: {payload['maintainer_feedback_progress_percent']}",
        f"- valid_feedback_text_input_rows: {payload['valid_feedback_text_input_rows']}",
        f"- valid_feedback_hash_only_rows: {payload['valid_feedback_hash_only_rows']}",
        f"- valid_feedback_digest_rows: {payload['valid_feedback_digest_rows']}",
        f"- feedback_counts_for_beta_precheck: {payload['feedback_counts_for_beta_precheck']}",
        f"- compiles_labels: {payload['compiles_labels']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- runs_benchmark: {payload['runs_benchmark']}",
        f"- output_path_guard_passed: {payload['output_path_guard_passed']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Errors",
        "",
    ]
    if payload["errors"]:
        lines.extend(f"- {error}" for error in payload["errors"])
    else:
        lines.append("- none")
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


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
    parser.add_argument("--out-json", default="", help="Optional read-only status JSON output.")
    parser.add_argument("--out-md", default="", help="Optional read-only status Markdown output.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument(
        "--skip-verify-existing",
        action="store_true",
        help="Testing only: skip audit_my_repo_label_intake.py --verify-existing checks.",
    )
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        (
            known_candidate_ids,
            template_case_ids,
            non_synthetic_candidate_ids,
            synthetic_candidate_ids,
        ) = load_template_context(args.template_dir)
        label_intake_case_ids, countable_case_ids, label_intake_summary = load_label_intake_context(
            args.label_intake_dir,
            verify_existing=not args.skip_verify_existing,
        )
        repo_intake_case_ids, target_repo_paths = load_repo_intake_context(args.repo_intake)
        output_paths = {}
        if args.out_json:
            output_paths["out_json"] = Path(args.out_json).expanduser().resolve()
        if args.out_md:
            output_paths["out_md"] = Path(args.out_md).expanduser().resolve()
        output_path_errors = validate_output_paths(output_paths, target_repo_paths)
        known_case_ids = template_case_ids | repo_intake_case_ids | label_intake_case_ids
        decision_rows = read_json_or_jsonl(Path(args.decisions).expanduser().resolve(), "decisions")
        feedback_rows = read_json_or_jsonl(Path(args.feedback).expanduser().resolve(), "feedback")
        decision_errors, decision_summary = validate_decisions(
            decision_rows,
            known_candidate_ids=known_candidate_ids,
            non_synthetic_candidate_ids=non_synthetic_candidate_ids,
            template_context_supplied=bool(args.template_dir),
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

    errors = [*decision_errors, *feedback_errors, *output_path_errors]
    effective_maintainer_id_count = (
        feedback_summary["distinct_countable_maintainer_id_count"]
        if args.label_intake_dir
        else feedback_summary["distinct_maintainer_id_count"]
    )
    countable_human_label_rows = decision_summary["non_synthetic_valid_human_label_rows"]
    summary = {
        "schema": "amr_beta_human_input_status.v1",
        **decision_summary,
        "template_dir_count": len(args.template_dir),
        "template_candidate_rows": len(known_candidate_ids),
        "template_non_synthetic_candidate_rows": len(non_synthetic_candidate_ids),
        "template_synthetic_or_unverified_candidate_rows": len(synthetic_candidate_ids),
        "min_human_label_rows_required": args.min_labels,
        "remaining_human_label_rows": max(0, args.min_labels - countable_human_label_rows),
        "human_label_progress_percent": progress_percent(countable_human_label_rows, args.min_labels),
        "human_label_requirement_met": int(countable_human_label_rows >= args.min_labels),
        **feedback_summary,
        **label_intake_summary,
        "min_maintainer_feedback_required": args.min_maintainers,
        "effective_maintainer_id_count": effective_maintainer_id_count,
        "remaining_distinct_maintainer_ids": max(0, args.min_maintainers - effective_maintainer_id_count),
        "maintainer_feedback_progress_percent": progress_percent(effective_maintainer_id_count, args.min_maintainers),
        "maintainer_feedback_requirement_met": int(effective_maintainer_id_count >= args.min_maintainers),
        "feedback_counts_for_beta_precheck": int(
            not args.label_intake_dir
            or (
                feedback_summary["valid_feedback_rows"] > 0
                and feedback_summary["valid_feedback_rows"] == len(feedback_rows)
                and feedback_summary["distinct_countable_maintainer_id_count"] >= args.min_maintainers
            )
        ),
        "ready_for_real_benchmark_inputs": int(not errors),
        "compiles_labels": 0,
        "creates_benchmark_evidence": 0,
        "runs_benchmark": 0,
        "output_path_guard_passed": int(not output_path_errors),
        "design_partner_beta_candidate_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
    }
    payload = {**summary, "errors": errors}
    try:
        if args.out_json and not output_path_errors:
            write_json(Path(args.out_json).expanduser().resolve(), payload, args.overwrite)
        if args.out_md and not output_path_errors:
            write_markdown(Path(args.out_md).expanduser().resolve(), payload, args.overwrite)
    except Exception as exc:
        print(f"human_input_status: error: {exc}", file=sys.stderr)
        return 1
    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
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
