#!/usr/bin/env python3
"""Build AMR beta reviewer packets and decision progress summaries.

This is a read-only human-label operations helper for blocker 9.2. It consumes
existing label template directories and optional human decision JSON/JSONL
inputs, then reports candidate coverage and writes reviewer packet artifacts.

It does not run audits, does not compile benchmark labels, does not run
real_benchmark, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

MIN_HUMAN_LABELS_FOR_BETA = 300
VALID_EXPECTED = {"present", "absent"}
VALID_PRIORITY = {"", "P0", "P1", "P2", "P3"}
PLACEHOLDER_RE = re.compile(r"(^$|example|placeholder|replace|todo)", re.IGNORECASE)
SAFE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,191}$")
SAFE_MAINTAINER_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:@+-]{0,191}$")
BLOCKED_KEYS = [
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
    "design_partner_beta_candidate_ready",
]
MANAGED_OUTPUTS = {
    "reviewer_candidate_packet.jsonl",
    "reviewer_missing_candidates.jsonl",
    "reviewer_progress_summary.json",
}
MANAGED_CASE_INDEX = "reviewer_packet_index.json"


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def truthy(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def good_operator_value(value: object) -> bool:
    return not PLACEHOLDER_RE.search(str(value or "").strip())


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def read_json(path: Path, input_name: str) -> dict:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{input_name} must contain an object")
    return payload


def load_template_target_repo(path: Path) -> tuple[str, list[str]]:
    manifest_path = path / "label_template_manifest.json"
    if not manifest_path.is_file():
        return "", []
    errors: list[str] = []
    try:
        manifest = read_json(manifest_path, "label template manifest")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        return "", [f"{path}: label template manifest parse error: {exc}"]

    raw_audit_output = str(manifest.get("input_audit_output") or "").strip()
    if not raw_audit_output:
        return "", [f"{path}: label template manifest missing input_audit_output"]
    audit_output = Path(raw_audit_output).expanduser()
    if not audit_output.is_absolute():
        return "", [f"{path}: label template manifest input_audit_output must be absolute"]

    source_snapshot = audit_output / "source_snapshot.json"
    audit_manifest = audit_output / "audit_manifest.json"
    for candidate, input_name in [
        (source_snapshot, "source snapshot"),
        (audit_manifest, "audit manifest"),
    ]:
        if not candidate.is_file():
            continue
        try:
            payload = read_json(candidate, input_name)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"{path}: {input_name} parse error: {exc}")
            continue
        raw_target = str(payload.get("target_repo") or "").strip()
        if raw_target:
            target_repo = Path(raw_target).expanduser().resolve()
            if is_forbidden_env_path(target_repo):
                errors.append(f"{path}: target_repo must not be .env-like")
            return str(target_repo), errors
    errors.append(f"{path}: label template source snapshot missing target_repo")
    return "", errors


def validate_output_paths(paths: dict[str, Path], target_repo_paths: list[str]) -> list[str]:
    errors: list[str] = []
    resolved_by_name = {name: path.expanduser().resolve() for name, path in paths.items()}
    seen_paths: dict[Path, str] = {}
    for name, resolved in resolved_by_name.items():
        if is_forbidden_env_path(resolved):
            errors.append(f"{name} must not be .env-like")
        if resolved in seen_paths:
            errors.append(f"{name} must not reuse {seen_paths[resolved]} path: {resolved}")
        else:
            seen_paths[resolved] = name
        for raw_repo in target_repo_paths:
            repo_path = Path(raw_repo).expanduser().resolve()
            if resolved == repo_path or is_relative_to(resolved, repo_path):
                errors.append(f"{name} must not be inside target repo: {resolved} (repo: {repo_path})")
    return errors


def validate_decision_input_paths(paths: dict[str, Path], target_repo_paths: list[str]) -> list[str]:
    return validate_output_paths(paths, target_repo_paths)


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


def verify_label_template_existing(path: Path) -> list[str]:
    if is_forbidden_env_path(path):
        return ["refusing .env-like label template path"]
    tool = Path(__file__).resolve().parent / "audit_my_repo_label_template.py"
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
    return [f"{path}: label_template --verify-existing failed: {first_line}"]


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
            for key in ["decisions", "rows"]:
                rows = payload.get(key)
                if isinstance(rows, list):
                    return rows
    rows: list[dict] = []
    for index, line in enumerate(text.splitlines(), start=1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row, dict):
            raise ValueError(f"{input_name} line {index} must be an object")
        rows.append(row)
    return rows


def load_template_dir(path: Path) -> tuple[list[dict], list[str], dict[str, int]]:
    errors: list[str] = []
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like template path")
    payload_path = path / "label_template.json"
    if not payload_path.is_file():
        raise ValueError(f"template dir missing label_template.json: {path}")
    payload = json.loads(payload_path.read_text(encoding="utf-8"))
    rows = payload.get("rows", [])
    if not isinstance(rows, list):
        raise ValueError(f"template rows must be a list: {payload_path}")

    if payload.get("template_only") != 1:
        errors.append(f"{path}: label_template.json must keep template_only=1")
    if payload.get("human_label_rows") != 0:
        errors.append(f"{path}: label_template.json must keep human_label_rows=0")
    if payload.get("candidate_label_rows") != len(rows):
        errors.append(f"{path}: candidate_label_rows must match template row count")
    for key in BLOCKED_KEYS:
        if payload.get(key) != 0:
            errors.append(f"{path}: label_template.json must keep {key}=0")

    packet_rows: list[dict] = []
    synthetic_rows = 0
    for index, raw in enumerate(rows, start=1):
        if not isinstance(raw, dict):
            errors.append(f"{path}: template row {index} must be an object")
            continue
        candidate_id = str(raw.get("candidate_label_id") or "").strip()
        case_id = str(raw.get("case_id") or "").strip()
        if not candidate_id:
            errors.append(f"{path}: template row {index} missing candidate_label_id")
        elif not SAFE_ID_RE.fullmatch(candidate_id):
            errors.append(f"{path}: template row {index} candidate_label_id must be a safe identifier")
        elif not good_operator_value(candidate_id):
            errors.append(f"{path}: template row {index} candidate_label_id must not be example/placeholder")
        if not case_id:
            errors.append(f"{path}: template row {index} missing case_id")
        elif not SAFE_ID_RE.fullmatch(case_id):
            errors.append(f"{path}: template row {index} case_id must be a safe identifier")
        elif not good_operator_value(case_id):
            errors.append(f"{path}: template row {index} case_id must not be example/placeholder")
        if str(raw.get("template_only", "")) != "1":
            errors.append(f"{path}: template row {index} must keep template_only=1")
        if str(raw.get("human_labeled", "")) != "0":
            errors.append(f"{path}: template row {index} must keep human_labeled=0")
        for key in BLOCKED_KEYS:
            if str(raw.get(key, "")) != "0":
                errors.append(f"{path}: template row {index} must keep {key}=0")
        synthetic = str(raw.get("synthetic", "0"))
        if synthetic == "1":
            synthetic_rows += 1
        packet_rows.append(
            {
                "case_id": case_id,
                "candidate_label_id": candidate_id,
                "template_dir": str(path),
                "synthetic": synthetic,
                "source_finding_id": str(raw.get("source_finding_id", "")),
                "source_review_queue_id": str(raw.get("source_review_queue_id", "")),
                "plugin_id": str(raw.get("plugin_id", "")),
                "rule_id": str(raw.get("rule_id", "")),
                "audit_type": str(raw.get("audit_type", "")),
                "severity": str(raw.get("severity", "")),
                "confidence": str(raw.get("confidence", "")),
                "suggested_expected": str(raw.get("suggested_expected", "")),
                "file_path": str(raw.get("file_path", "")),
                "expected_line_start": str(raw.get("expected_line_start", "")),
                "expected_line_end": str(raw.get("expected_line_end", "")),
                "expected_span_sha256": str(raw.get("expected_span_sha256", "")),
                "citation_id": str(raw.get("citation_id", "")),
                "finding_answer": str(raw.get("finding_answer", "")),
                "span_text_preview": str(raw.get("span_text_preview", "")),
            }
        )
    return packet_rows, errors, {"synthetic_candidate_rows": synthetic_rows}


def validate_decisions(rows: list[dict], known_candidate_ids: set[str]) -> tuple[list[str], set[str], int]:
    errors: list[str] = []
    seen: set[str] = set()
    valid_ids: set[str] = set()
    valid_rows = 0
    for index, row in enumerate(rows, start=1):
        row_errors: list[str] = []
        candidate_id = str(row.get("candidate_label_id") or "").strip()
        if not candidate_id:
            row_errors.append(f"decision row {index}: missing candidate_label_id")
        elif not SAFE_ID_RE.fullmatch(candidate_id):
            row_errors.append(f"decision row {index}: candidate_label_id must be a safe identifier")
        elif not good_operator_value(candidate_id):
            row_errors.append(f"decision row {index}: candidate_label_id must not be example/placeholder")
        elif candidate_id in seen:
            row_errors.append(f"decision row {index}: duplicate candidate_label_id")
        elif candidate_id not in known_candidate_ids:
            row_errors.append(f"decision row {index}: unknown candidate_label_id")
        seen.add(candidate_id)
        validate_optional_safe_id(
            errors=row_errors,
            row_prefix=f"decision row {index}",
            field="label_id",
            value=row.get("label_id"),
            pattern=SAFE_ID_RE,
        )
        validate_optional_safe_id(
            errors=row_errors,
            row_prefix=f"decision row {index}",
            field="reviewer_id",
            value=row.get("reviewer_id"),
            pattern=SAFE_ID_RE,
        )
        validate_optional_safe_id(
            errors=row_errors,
            row_prefix=f"decision row {index}",
            field="maintainer_id",
            value=row.get("maintainer_id"),
            pattern=SAFE_MAINTAINER_ID_RE,
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
            valid_ids.add(candidate_id)
    return errors, valid_ids, valid_rows


def prepare_output_dir(out_dir: Path, overwrite: bool) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    children = list(out_dir.iterdir())
    if not children:
        return
    if not overwrite:
        raise ValueError("packet output directory already contains artifacts; use a fresh --out or pass --overwrite")
    for child in children:
        if child.name not in MANAGED_OUTPUTS or not child.is_file():
            raise ValueError(f"refusing to delete unrelated packet output entry: {child.name}; use a fresh --out")
    for child in children:
        child.unlink()


def group_rows_by_case(packet_rows: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = {}
    for row in packet_rows:
        grouped.setdefault(row["case_id"], []).append(row)
    return grouped


def case_summary(case_id: str, rows: list[dict], valid_decision_ids: set[str]) -> dict:
    candidate_ids = {row["candidate_label_id"] for row in rows}
    reviewed_ids = candidate_ids & valid_decision_ids
    missing_ids = sorted(candidate_ids - valid_decision_ids)
    synthetic_rows = sum(1 for row in rows if str(row.get("synthetic", "0")) == "1")
    return {
        "schema": "amr_beta_label_packet.v1",
        "case_id": case_id,
        "template_dirs": sorted({row["template_dir"] for row in rows}),
        "candidate_label_rows": len(rows),
        "synthetic_candidate_rows": synthetic_rows,
        "valid_human_label_rows": len(reviewed_ids),
        "missing_candidate_label_count": len(missing_ids),
        "all_candidates_reviewed": int(not missing_ids and bool(rows)),
        "ready_for_label_intake": int(bool(rows) and not missing_ids and synthetic_rows == 0),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "design_partner_beta_candidate_ready": 0,
    }


def case_progress_rows(packet_rows: list[dict], valid_decision_ids: set[str]) -> list[dict]:
    grouped = group_rows_by_case(packet_rows)
    rows: list[dict] = []
    for case_id in sorted(grouped):
        summary = case_summary(case_id, grouped[case_id], valid_decision_ids)
        rows.append(
            {
                "case_id": case_id,
                "template_dirs": summary["template_dirs"],
                "candidate_label_rows": summary["candidate_label_rows"],
                "synthetic_candidate_rows": summary["synthetic_candidate_rows"],
                "valid_human_label_rows": summary["valid_human_label_rows"],
                "missing_candidate_label_count": summary["missing_candidate_label_count"],
                "all_candidates_reviewed": summary["all_candidates_reviewed"],
                "ready_for_label_intake": summary["ready_for_label_intake"],
            }
        )
    return rows


def prepare_case_output_root(out_root: Path, case_ids: set[str], overwrite: bool) -> None:
    if is_forbidden_env_path(out_root):
        raise ValueError("refusing .env-like per-case packet output root")
    out_root.mkdir(parents=True, exist_ok=True)
    children = list(out_root.iterdir())
    if not children:
        return
    if not overwrite:
        raise ValueError(
            "per-case packet output root already contains artifacts; use a fresh "
            "--per-case-out-root or pass --overwrite"
        )
    for child in children:
        if child.is_file() and child.name == MANAGED_CASE_INDEX:
            continue
        if child.is_dir() and child.name in case_ids:
            for grandchild in child.iterdir():
                if grandchild.name not in MANAGED_OUTPUTS or not grandchild.is_file():
                    raise ValueError(
                        f"refusing to delete unrelated per-case packet entry: "
                        f"{child.name}/{grandchild.name}; use a fresh --per-case-out-root"
                    )
            continue
        raise ValueError(f"refusing to delete unrelated per-case packet entry: {child.name}")
    for child in children:
        if child.is_file() and child.name == MANAGED_CASE_INDEX:
            child.unlink()
        elif child.is_dir() and child.name in case_ids:
            for grandchild in child.iterdir():
                grandchild.unlink()


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def write_outputs(out_dir: Path, packet_rows: list[dict], missing_ids: list[str], summary: dict, overwrite: bool) -> None:
    prepare_output_dir(out_dir, overwrite)
    write_jsonl(out_dir / "reviewer_candidate_packet.jsonl", packet_rows)
    write_jsonl(out_dir / "reviewer_missing_candidates.jsonl", [{"candidate_label_id": value} for value in missing_ids])
    (out_dir / "reviewer_progress_summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_case_outputs(
    out_root: Path,
    packet_rows: list[dict],
    valid_decision_ids: set[str],
    summary: dict,
    overwrite: bool,
) -> None:
    grouped = group_rows_by_case(packet_rows)
    prepare_case_output_root(out_root, set(grouped), overwrite)
    index_rows: list[dict] = []
    for case_id in sorted(grouped):
        rows = grouped[case_id]
        scoped_summary = case_summary(case_id, rows, valid_decision_ids)
        missing_ids = sorted({row["candidate_label_id"] for row in rows} - valid_decision_ids)
        case_dir = out_root / case_id
        case_dir.mkdir(parents=True, exist_ok=True)
        write_jsonl(case_dir / "reviewer_candidate_packet.jsonl", rows)
        write_jsonl(
            case_dir / "reviewer_missing_candidates.jsonl",
            [{"candidate_label_id": value} for value in missing_ids],
        )
        (case_dir / "reviewer_progress_summary.json").write_text(
            json.dumps(scoped_summary, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        index_rows.append(
            {
                "case_id": case_id,
                "output_dir": str(case_dir),
                "candidate_label_rows": scoped_summary["candidate_label_rows"],
                "valid_human_label_rows": scoped_summary["valid_human_label_rows"],
                "missing_candidate_label_count": scoped_summary["missing_candidate_label_count"],
                "all_candidates_reviewed": scoped_summary["all_candidates_reviewed"],
                "ready_for_label_intake": scoped_summary["ready_for_label_intake"],
            }
        )
    index_payload = {
        **summary,
        "per_case_packet_root": str(out_root),
        "case_packets": index_rows,
        "case_packet_count": len(index_rows),
    }
    (out_root / MANAGED_CASE_INDEX).write_text(
        json.dumps(index_payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template-dir", action="append", default=[], help="Label template dir; repeatable.")
    parser.add_argument("--decisions", action="append", default=[], help="Human decision JSON/JSONL file; repeatable.")
    parser.add_argument("--out", default="", help="Optional output directory for reviewer packet artifacts.")
    parser.add_argument(
        "--per-case-out-root",
        default="",
        help="Optional root directory for one reviewer packet directory per case_id.",
    )
    parser.add_argument("--overwrite", action="store_true", help="Replace existing managed packet artifacts.")
    parser.add_argument("--require-all-candidates", action="store_true", help="Fail if any template candidate has no valid decision.")
    parser.add_argument("--enforce-min-labels", action="store_true", help="Fail unless valid decisions meet --min-labels.")
    parser.add_argument("--min-labels", type=int, default=MIN_HUMAN_LABELS_FOR_BETA)
    parser.add_argument(
        "--skip-verify-existing",
        action="store_true",
        help="Testing only: skip audit_my_repo_label_template.py --verify-existing checks.",
    )
    parser.add_argument("--json", action="store_true", help="Print JSON summary.")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    try:
        if not args.template_dir:
            raise ValueError("at least one --template-dir is required")
        packet_rows: list[dict] = []
        errors: list[str] = []
        synthetic_candidate_rows = 0
        verify_passed_dirs = 0
        verify_failed_dirs = 0
        target_repo_paths: list[str] = []
        for raw_template_dir in args.template_dir:
            template_dir = Path(raw_template_dir).expanduser().resolve()
            if not args.skip_verify_existing:
                verify_errors = verify_label_template_existing(template_dir)
                if verify_errors:
                    verify_failed_dirs += 1
                    errors.extend(verify_errors)
                else:
                    verify_passed_dirs += 1
            rows, template_errors, counts = load_template_dir(template_dir)
            packet_rows.extend(rows)
            errors.extend(template_errors)
            synthetic_candidate_rows += counts["synthetic_candidate_rows"]
            target_repo_path, target_repo_errors = load_template_target_repo(template_dir)
            if target_repo_path:
                target_repo_paths.append(target_repo_path)
            errors.extend(target_repo_errors)

        candidate_ids = [row["candidate_label_id"] for row in packet_rows]
        duplicate_candidate_ids = sorted({value for value in candidate_ids if candidate_ids.count(value) > 1})
        if duplicate_candidate_ids:
            errors.append(f"duplicate template candidate_label_id values: {', '.join(duplicate_candidate_ids[:10])}")
        known_candidate_ids = set(candidate_ids)

        decision_input_paths = {
            f"decisions_{index}": Path(raw_decisions)
            for index, raw_decisions in enumerate(args.decisions, start=1)
        }
        decision_input_errors = validate_decision_input_paths(
            decision_input_paths,
            sorted(set(target_repo_paths)),
        )
        decision_rows: list[dict] = []
        if not decision_input_errors:
            for raw_decisions in args.decisions:
                decision_rows.extend(read_json_or_jsonl(Path(raw_decisions).expanduser().resolve(), "decisions"))
        decision_errors, valid_decision_ids, valid_human_label_rows = validate_decisions(
            decision_rows,
            known_candidate_ids,
        )
        errors.extend(decision_input_errors)
        errors.extend(decision_errors)
        missing_ids = sorted(known_candidate_ids - valid_decision_ids)
        if args.require_all_candidates and missing_ids:
            errors.append(f"missing candidate_label_id decisions: {', '.join(missing_ids[:20])}")
        non_synthetic_candidate_ids = {
            row["candidate_label_id"]
            for row in packet_rows
            if str(row.get("synthetic", "0")) != "1"
        }
        non_synthetic_valid_human_label_rows = len(valid_decision_ids & non_synthetic_candidate_ids)
        if args.enforce_min_labels and non_synthetic_valid_human_label_rows < args.min_labels:
            errors.append(
                "non_synthetic_valid_human_label_rows "
                f"{non_synthetic_valid_human_label_rows} below required minimum {args.min_labels}"
            )
        case_ids = sorted({row["case_id"] for row in packet_rows})
        progress_rows = case_progress_rows(packet_rows, valid_decision_ids)
        cases_ready_for_label_intake = sum(
            1 for row in progress_rows if row["ready_for_label_intake"] == 1
        )
        output_requested = bool(args.out or args.per_case_out_root)
        output_paths: dict[str, Path] = {}
        if args.out:
            output_paths["out"] = Path(args.out)
        if args.per_case_out_root:
            output_paths["per_case_out_root"] = Path(args.per_case_out_root)
        output_path_errors = validate_output_paths(output_paths, sorted(set(target_repo_paths)))
        errors.extend(output_path_errors)
        output_files = sorted(MANAGED_OUTPUTS) if args.out else []
        if args.per_case_out_root:
            output_files = [
                *output_files,
                MANAGED_CASE_INDEX,
                "case_id/reviewer_candidate_packet.jsonl",
                "case_id/reviewer_missing_candidates.jsonl",
                "case_id/reviewer_progress_summary.json",
            ]
        summary = {
            "schema": "amr_beta_label_packet.v1",
            "template_dir_count": len(args.template_dir),
            "label_template_verify_existing_required": int(not args.skip_verify_existing),
            "label_template_verify_existing_passed_dirs": verify_passed_dirs,
            "label_template_verify_existing_failed_dirs": verify_failed_dirs,
            "case_count": len(case_ids),
            "candidate_label_rows": len(packet_rows),
            "synthetic_candidate_rows": synthetic_candidate_rows,
            "decision_rows": len(decision_rows),
            "valid_human_label_rows": valid_human_label_rows,
            "missing_candidate_label_count": len(missing_ids),
            "all_candidates_reviewed": int(not missing_ids and bool(packet_rows)),
            "min_human_label_rows_required": args.min_labels,
            "human_label_requirement_met": int(non_synthetic_valid_human_label_rows >= args.min_labels),
            "non_synthetic_valid_human_label_rows": non_synthetic_valid_human_label_rows,
            "human_labels_remaining_to_minimum": max(
                0,
                args.min_labels - non_synthetic_valid_human_label_rows,
            ),
            "case_progress_rows": progress_rows,
            "cases_ready_for_label_intake": cases_ready_for_label_intake,
            "cases_blocked_for_label_intake": len(progress_rows) - cases_ready_for_label_intake,
            "candidate_guard_passed": int(not errors),
            "decision_input_guard_passed": int(not decision_input_errors),
            "output_path_guard_passed": int(not output_path_errors),
            "ready_for_label_intake": int(not errors and valid_human_label_rows > 0 and not missing_ids),
            "output_files": output_files,
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
            "design_partner_beta_candidate_ready": 0,
        }
        if errors:
            if args.json or not output_requested:
                print(json.dumps({**summary, "errors": errors}, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        if args.out:
            write_outputs(Path(args.out).expanduser().resolve(), packet_rows, missing_ids, summary, args.overwrite)
        if args.per_case_out_root:
            write_case_outputs(
                Path(args.per_case_out_root).expanduser().resolve(),
                packet_rows,
                valid_decision_ids,
                summary,
                args.overwrite,
            )
        if args.json or not output_requested:
            print(json.dumps({**summary, "errors": []}, indent=2, sort_keys=True))
        if not args.json and output_requested:
            print(
                "label_packet: ok "
                f"candidate_label_rows={summary['candidate_label_rows']} "
                f"valid_human_label_rows={summary['valid_human_label_rows']} "
                f"missing_candidate_label_count={summary['missing_candidate_label_count']}"
            )
        return 0
    except Exception as exc:
        print(f"label_packet: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": "amr_beta_label_packet.v1", "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
