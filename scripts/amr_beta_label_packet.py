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
import sys
from pathlib import Path

MIN_HUMAN_LABELS_FOR_BETA = 300
VALID_EXPECTED = {"present", "absent"}
VALID_PRIORITY = {"", "P0", "P1", "P2", "P3"}
PLACEHOLDER_RE = re.compile(r"(^$|example|placeholder|replace|todo)", re.IGNORECASE)
SAFE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,191}$")
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


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template-dir", action="append", default=[], help="Label template dir; repeatable.")
    parser.add_argument("--decisions", action="append", default=[], help="Human decision JSON/JSONL file; repeatable.")
    parser.add_argument("--out", default="", help="Optional output directory for reviewer packet artifacts.")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing managed packet artifacts.")
    parser.add_argument("--require-all-candidates", action="store_true", help="Fail if any template candidate has no valid decision.")
    parser.add_argument("--enforce-min-labels", action="store_true", help="Fail unless valid decisions meet --min-labels.")
    parser.add_argument("--min-labels", type=int, default=MIN_HUMAN_LABELS_FOR_BETA)
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
        for raw_template_dir in args.template_dir:
            template_dir = Path(raw_template_dir).expanduser().resolve()
            rows, template_errors, counts = load_template_dir(template_dir)
            packet_rows.extend(rows)
            errors.extend(template_errors)
            synthetic_candidate_rows += counts["synthetic_candidate_rows"]

        candidate_ids = [row["candidate_label_id"] for row in packet_rows]
        duplicate_candidate_ids = sorted({value for value in candidate_ids if candidate_ids.count(value) > 1})
        if duplicate_candidate_ids:
            errors.append(f"duplicate template candidate_label_id values: {', '.join(duplicate_candidate_ids[:10])}")
        known_candidate_ids = set(candidate_ids)

        decision_rows: list[dict] = []
        for raw_decisions in args.decisions:
            decision_rows.extend(read_json_or_jsonl(Path(raw_decisions).expanduser().resolve(), "decisions"))
        decision_errors, valid_decision_ids, valid_human_label_rows = validate_decisions(
            decision_rows,
            known_candidate_ids,
        )
        errors.extend(decision_errors)
        missing_ids = sorted(known_candidate_ids - valid_decision_ids)
        if args.require_all_candidates and missing_ids:
            errors.append(f"missing candidate_label_id decisions: {', '.join(missing_ids[:20])}")
        if args.enforce_min_labels and valid_human_label_rows < args.min_labels:
            errors.append(f"valid_human_label_rows {valid_human_label_rows} below required minimum {args.min_labels}")

        case_ids = sorted({row["case_id"] for row in packet_rows})
        summary = {
            "schema": "amr_beta_label_packet.v1",
            "template_dir_count": len(args.template_dir),
            "case_count": len(case_ids),
            "candidate_label_rows": len(packet_rows),
            "synthetic_candidate_rows": synthetic_candidate_rows,
            "decision_rows": len(decision_rows),
            "valid_human_label_rows": valid_human_label_rows,
            "missing_candidate_label_count": len(missing_ids),
            "all_candidates_reviewed": int(not missing_ids and bool(packet_rows)),
            "min_human_label_rows_required": args.min_labels,
            "human_label_requirement_met": int(valid_human_label_rows >= args.min_labels),
            "candidate_guard_passed": int(not errors),
            "ready_for_label_intake": int(not errors and valid_human_label_rows > 0 and not missing_ids),
            "output_files": sorted(MANAGED_OUTPUTS) if args.out else [],
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
            "design_partner_beta_candidate_ready": 0,
        }
        if args.json or not args.out:
            print(json.dumps({**summary, "errors": errors}, indent=2, sort_keys=True))
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        if args.out:
            write_outputs(Path(args.out).expanduser().resolve(), packet_rows, missing_ids, summary, args.overwrite)
        if not args.json and args.out:
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
