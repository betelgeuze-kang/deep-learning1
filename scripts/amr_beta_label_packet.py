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
import hashlib
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


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


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


def validate_decisions(rows: list[dict], known_candidate_ids: set[str]) -> tuple[list[str], set[str], int, list[dict]]:
    errors: list[str] = []
    seen: set[str] = set()
    seen_label_ids: set[str] = set()
    valid_ids: set[str] = set()
    valid_decision_rows: list[dict] = []
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
        label_id = str(row.get("label_id") or candidate_id).strip()
        label_error_count = len(row_errors)
        validate_optional_safe_id(
            errors=row_errors,
            row_prefix=f"decision row {index}",
            field="label_id",
            value=label_id,
            pattern=SAFE_ID_RE,
        )
        if label_id and len(row_errors) == label_error_count:
            if label_id in seen_label_ids:
                row_errors.append(f"decision row {index}: duplicate label_id")
            else:
                seen_label_ids.add(label_id)
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
            valid_decision_rows.append(
                {
                    "candidate_label_id": candidate_id,
                    "reviewer_id": str(row.get("reviewer_id") or "").strip(),
                }
            )
    return errors, valid_ids, valid_rows, valid_decision_rows


def reviewer_progress_rows(valid_decision_rows: list[dict], non_synthetic_candidate_ids: set[str]) -> list[dict]:
    grouped: dict[str, dict[str, object]] = {}
    for row in valid_decision_rows:
        reviewer_id = str(row.get("reviewer_id") or "").strip()
        if not reviewer_id:
            continue
        candidate_id = str(row.get("candidate_label_id") or "").strip()
        bucket = grouped.setdefault(
            reviewer_id,
            {
                "reviewer_id": reviewer_id,
                "valid_human_label_rows": 0,
                "non_synthetic_valid_human_label_rows": 0,
            },
        )
        bucket["valid_human_label_rows"] = int(bucket["valid_human_label_rows"]) + 1
        if candidate_id in non_synthetic_candidate_ids:
            bucket["non_synthetic_valid_human_label_rows"] = int(
                bucket["non_synthetic_valid_human_label_rows"]
            ) + 1
    return [grouped[reviewer_id] for reviewer_id in sorted(grouped)]


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
    non_synthetic_candidate_ids = {
        row["candidate_label_id"]
        for row in rows
        if str(row.get("synthetic", "0")) != "1"
    }
    return {
        "schema": "amr_beta_label_packet.v1",
        "case_id": case_id,
        "template_dirs": sorted({row["template_dir"] for row in rows}),
        "candidate_label_rows": len(rows),
        "synthetic_candidate_rows": synthetic_rows,
        "non_synthetic_candidate_rows": len(non_synthetic_candidate_ids),
        "valid_human_label_rows": len(reviewed_ids),
        "non_synthetic_valid_human_label_rows": len(reviewed_ids & non_synthetic_candidate_ids),
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
                "non_synthetic_candidate_rows": summary["non_synthetic_candidate_rows"],
                "valid_human_label_rows": summary["valid_human_label_rows"],
                "non_synthetic_valid_human_label_rows": summary["non_synthetic_valid_human_label_rows"],
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


def read_jsonl_file(path: Path, input_name: str) -> list[dict]:
    if not path.is_file():
        raise ValueError(f"missing {input_name}: {path}")
    rows: list[dict] = []
    for index, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        row = json.loads(line)
        if not isinstance(row, dict):
            raise ValueError(f"{input_name} line {index} must be an object")
        rows.append(row)
    return rows


def blocked_claim_errors(payload: dict, *, name: str) -> list[str]:
    errors: list[str] = []
    for key in BLOCKED_KEYS:
        if payload.get(key) != 0:
            errors.append(f"{name}: must keep {key}=0")
    return errors


def required_guard_errors(summary: dict, *, name: str, scoped: bool) -> list[str]:
    errors: list[str] = []
    for key in ["candidate_guard_passed", "decision_input_guard_passed", "output_path_guard_passed"]:
        if scoped and key not in summary:
            continue
        if summary.get(key) != 1:
            errors.append(f"{name}: {key} must be 1")
    if scoped:
        return errors
    if summary.get("label_template_verify_existing_required") != 1:
        errors.append(f"{name}: label_template_verify_existing_required must be 1")
    if summary.get("label_template_verify_existing_failed_dirs") != 0:
        errors.append(f"{name}: label_template_verify_existing_failed_dirs must be 0")
    passed_dirs = summary.get("label_template_verify_existing_passed_dirs")
    template_dir_count = summary.get("template_dir_count")
    if passed_dirs != template_dir_count:
        errors.append(f"{name}: label_template_verify_existing_passed_dirs must match template_dir_count")
    return errors


def canonical_rows(rows: list[dict]) -> list[str]:
    return sorted(json.dumps(row, sort_keys=True, separators=(",", ":")) for row in rows)


def verify_template_bindings(
    summary: dict,
    packet_rows: list[dict],
    *,
    name: str,
    scoped: bool,
) -> list[str]:
    errors: list[str] = []
    raw_fingerprints = summary.get("label_template_fingerprints", [])
    if not isinstance(raw_fingerprints, list):
        return [f"{name}: label_template_fingerprints must be a list"]
    if not scoped and summary.get("template_dir_count") != len(raw_fingerprints):
        errors.append(f"{name}: template_dir_count must match label_template_fingerprints")

    expected_fingerprints: list[dict[str, str]] = []
    expected_packet_rows: list[dict] = []
    seen_template_dirs: set[str] = set()
    for index, raw in enumerate(raw_fingerprints, start=1):
        if not isinstance(raw, dict):
            errors.append(f"{name}: label_template_fingerprints row {index} must be an object")
            continue
        raw_template_dir = str(raw.get("template_dir") or "").strip()
        if not raw_template_dir:
            errors.append(f"{name}: label_template_fingerprints row {index}: template_dir must be present")
            continue
        template_dir = Path(raw_template_dir).expanduser().resolve()
        if is_forbidden_env_path(template_dir):
            errors.append(f"{name}: label_template_fingerprints row {index}: template_dir must not be .env-like")
            continue
        if str(template_dir) in seen_template_dirs:
            errors.append(f"{name}: label_template_fingerprints row {index}: duplicate template_dir")
            continue
        seen_template_dirs.add(str(template_dir))

        template_verify_errors = verify_label_template_existing(template_dir)
        errors.extend(f"{name}: {error}" for error in template_verify_errors)
        template_json = template_dir / "label_template.json"
        template_manifest = template_dir / "label_template_manifest.json"
        try:
            expected_fingerprint = {
                "template_dir": str(template_dir),
                "label_template_json_sha256": sha256_file(template_json),
                "label_template_manifest_sha256": sha256_file(template_manifest)
                if template_manifest.is_file()
                else "",
            }
            rows, template_errors, _counts = load_template_dir(template_dir)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"{name}: template_dir parse error for {template_dir}: {exc}")
            continue
        expected_fingerprints.append(expected_fingerprint)
        errors.extend(f"{name}: {error}" for error in template_errors)
        expected_packet_rows.extend(rows)

    if raw_fingerprints != expected_fingerprints:
        errors.append(f"{name}: label_template_fingerprints must match current template files")
    if summary.get("label_template_bundle_sha256") != sha256_json(expected_fingerprints):
        errors.append(f"{name}: label_template_bundle_sha256 must match current label_template_fingerprints")
    expected_template_json_sha256s = [
        row["label_template_json_sha256"] for row in expected_fingerprints
    ]
    if summary.get("label_template_json_sha256s") != expected_template_json_sha256s:
        errors.append(f"{name}: label_template_json_sha256s must match current label_template_fingerprints")
    expected_template_manifest_sha256s = [
        row["label_template_manifest_sha256"]
        for row in expected_fingerprints
        if row["label_template_manifest_sha256"]
    ]
    if summary.get("label_template_manifest_sha256s") != expected_template_manifest_sha256s:
        errors.append(f"{name}: label_template_manifest_sha256s must match current label_template_fingerprints")

    packet_candidate_ids = {str(row.get("candidate_label_id") or "") for row in packet_rows}
    if scoped:
        expected_packet_rows = [
            row for row in expected_packet_rows if str(row.get("candidate_label_id") or "") in packet_candidate_ids
        ]
    if canonical_rows(packet_rows) != canonical_rows(expected_packet_rows):
        errors.append(f"{name}: reviewer_candidate_packet must match recorded label templates")
    return errors


def verified_decision_context(
    summary: dict,
    packet_rows: list[dict],
    *,
    name: str,
    scoped: bool,
) -> tuple[set[str], list[dict], int, list[str]]:
    errors: list[str] = []
    raw_fingerprints = summary.get("decisions_fingerprints", [])
    if not isinstance(raw_fingerprints, list):
        return set(), [], 0, [f"{name}: decisions_fingerprints must be a list"]

    recomputed_fingerprints: list[dict[str, str]] = []
    decision_rows: list[dict] = []
    for index, raw in enumerate(raw_fingerprints, start=1):
        if not isinstance(raw, dict):
            errors.append(f"{name}: decisions_fingerprints row {index} must be an object")
            continue
        raw_decisions = str(raw.get("decisions") or "").strip()
        if not raw_decisions:
            errors.append(f"{name}: decisions_fingerprints row {index}: decisions must be present")
            continue
        decision_path = Path(raw_decisions).expanduser().resolve()
        if is_forbidden_env_path(decision_path):
            errors.append(f"{name}: decisions_fingerprints row {index}: decisions must not be .env-like")
            continue
        if not decision_path.is_file():
            errors.append(f"{name}: decisions_fingerprints row {index}: decisions file is missing")
            continue
        try:
            decision_sha256 = sha256_file(decision_path)
            decision_rows.extend(read_json_or_jsonl(decision_path, "decisions"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"{name}: decisions_fingerprints row {index}: parse error: {exc}")
            continue
        recomputed_fingerprints.append(
            {
                "decisions": str(decision_path),
                "decisions_sha256": decision_sha256,
            }
        )
    if raw_fingerprints != recomputed_fingerprints:
        errors.append(f"{name}: decisions_fingerprints must match current decision files")
    if summary.get("decisions_bundle_sha256") != sha256_json(recomputed_fingerprints):
        errors.append(f"{name}: decisions_bundle_sha256 must match current decisions_fingerprints")
    expected_decision_sha256s = [
        row["decisions_sha256"] for row in recomputed_fingerprints
    ]
    if summary.get("decisions_sha256s") != expected_decision_sha256s:
        errors.append(f"{name}: decisions_sha256s must match current decisions_fingerprints")
    if not scoped and summary.get("decision_rows") != len(decision_rows):
        errors.append(f"{name}: decision_rows must match current decision files")

    known_candidate_ids = {str(row.get("candidate_label_id") or "").strip() for row in packet_rows}
    validation_rows = decision_rows
    if scoped:
        validation_rows = [
            row
            for row in decision_rows
            if str(row.get("candidate_label_id") or "").strip() in known_candidate_ids
        ]
    decision_errors, valid_decision_ids, _valid_rows, valid_decision_rows = validate_decisions(
        validation_rows,
        known_candidate_ids,
    )
    errors.extend(f"{name}: {error}" for error in decision_errors)
    return valid_decision_ids, valid_decision_rows, len(decision_rows), errors


def expected_summary_counts(
    packet_rows: list[dict],
    valid_decision_ids: set[str],
    *,
    min_human_label_rows_required: int = MIN_HUMAN_LABELS_FOR_BETA,
) -> dict[str, object]:
    known_candidate_ids = {str(row.get("candidate_label_id") or "") for row in packet_rows}
    valid_decision_ids = known_candidate_ids & set(valid_decision_ids)
    missing_ids = sorted(known_candidate_ids - valid_decision_ids)
    non_synthetic_candidate_ids = {
        str(row.get("candidate_label_id") or "")
        for row in packet_rows
        if str(row.get("synthetic", "0")) != "1"
    }
    progress_rows = case_progress_rows(packet_rows, valid_decision_ids)
    cases_ready = sum(1 for row in progress_rows if row["ready_for_label_intake"] == 1)
    all_cases_ready = int(bool(progress_rows) and cases_ready == len(progress_rows))
    non_synthetic_valid = len(valid_decision_ids & non_synthetic_candidate_ids)
    return {
        "case_count": len({str(row.get("case_id") or "") for row in packet_rows}),
        "candidate_label_rows": len(packet_rows),
        "synthetic_candidate_rows": sum(1 for row in packet_rows if str(row.get("synthetic", "0")) == "1"),
        "non_synthetic_candidate_rows": len(non_synthetic_candidate_ids),
        "missing_candidate_label_count": len(missing_ids),
        "valid_human_label_rows": len(valid_decision_ids),
        "non_synthetic_valid_human_label_rows": non_synthetic_valid,
        "all_candidates_reviewed": int(not missing_ids and bool(packet_rows)),
        "case_progress_rows": progress_rows,
        "cases_ready_for_label_intake": cases_ready,
        "cases_blocked_for_label_intake": len(progress_rows) - cases_ready,
        "human_label_requirement_met": int(non_synthetic_valid >= min_human_label_rows_required),
        "human_labels_remaining_to_minimum": max(0, min_human_label_rows_required - non_synthetic_valid),
        "ready_for_label_intake": int(
            non_synthetic_valid > 0
            and not missing_ids
            and all_cases_ready == 1
        ),
    }


def verify_summary_bindings(
    summary: dict,
    packet_rows: list[dict],
    missing_ids: list[str],
    *,
    name: str,
    scoped: bool = False,
    check_output_files: bool = True,
) -> list[str]:
    errors: list[str] = []
    if summary.get("schema") != "amr_beta_label_packet.v1":
        errors.append(f"{name}: schema must be amr_beta_label_packet.v1")
    errors.extend(blocked_claim_errors(summary, name=name))
    errors.extend(required_guard_errors(summary, name=name, scoped=scoped))
    errors.extend(verify_template_bindings(summary, packet_rows, name=name, scoped=scoped))
    valid_decision_ids, valid_decision_rows, _decision_rows, decision_errors = verified_decision_context(
        summary,
        packet_rows,
        name=name,
        scoped=scoped,
    )
    errors.extend(decision_errors)
    candidate_ids = {str(row.get("candidate_label_id") or "").strip() for row in packet_rows}
    expected_missing_ids = sorted(candidate_ids - valid_decision_ids)
    if sorted(missing_ids) != expected_missing_ids:
        errors.append(f"{name}: reviewer_missing_candidates must match current decision files")
    min_human_label_rows_required = summary.get("min_human_label_rows_required", MIN_HUMAN_LABELS_FOR_BETA)
    if not isinstance(min_human_label_rows_required, int):
        errors.append(f"{name}: min_human_label_rows_required must be an integer")
        min_human_label_rows_required = MIN_HUMAN_LABELS_FOR_BETA
    expected = expected_summary_counts(
        packet_rows,
        valid_decision_ids,
        min_human_label_rows_required=min_human_label_rows_required,
    )
    for key, value in expected.items():
        if scoped and key not in summary:
            continue
        if summary.get(key) != value:
            errors.append(f"{name}: {key} must match reviewer packet artifacts")
    reviewer_rows = summary.get("reviewer_progress_rows", [])
    if scoped and "reviewer_progress_rows" not in summary:
        reviewer_rows = []
        skip_reviewer_progress = True
    else:
        skip_reviewer_progress = False
    if not isinstance(reviewer_rows, list):
        errors.append(f"{name}: reviewer_progress_rows must be a list")
        reviewer_rows = []
    non_synthetic_candidate_ids = {
        str(row.get("candidate_label_id") or "")
        for row in packet_rows
        if str(row.get("synthetic", "0")) != "1"
    }
    expected_reviewer_rows = reviewer_progress_rows(valid_decision_rows, non_synthetic_candidate_ids)
    if not skip_reviewer_progress and reviewer_rows != expected_reviewer_rows:
        errors.append(f"{name}: reviewer_progress_rows must match current decision files")
    reviewer_row_sum = 0
    reviewer_non_synthetic_sum = 0
    reviewer_ids: set[str] = set()
    for index, row in enumerate(reviewer_rows, start=1):
        if not isinstance(row, dict):
            errors.append(f"{name}: reviewer_progress_rows row {index} must be an object")
            continue
        reviewer_id = str(row.get("reviewer_id") or "").strip()
        if not reviewer_id:
            errors.append(f"{name}: reviewer_progress_rows row {index}: reviewer_id must be present")
        if reviewer_id in reviewer_ids:
            errors.append(f"{name}: reviewer_progress_rows row {index}: duplicate reviewer_id")
        reviewer_ids.add(reviewer_id)
        reviewer_row_sum += int(row.get("valid_human_label_rows", 0) or 0)
        reviewer_non_synthetic_sum += int(row.get("non_synthetic_valid_human_label_rows", 0) or 0)
    if not skip_reviewer_progress and summary.get("distinct_reviewer_id_count") != len(reviewer_ids):
        errors.append(f"{name}: distinct_reviewer_id_count must match reviewer_progress_rows")
    if not skip_reviewer_progress and summary.get("valid_human_label_rows_with_reviewer_id") != reviewer_row_sum:
        errors.append(f"{name}: valid_human_label_rows_with_reviewer_id must match reviewer_progress_rows")
    if not skip_reviewer_progress and reviewer_non_synthetic_sum > int(summary.get("non_synthetic_valid_human_label_rows", 0) or 0):
        errors.append(f"{name}: reviewer non-synthetic rows must not exceed valid non-synthetic labels")
    if (
        not skip_reviewer_progress
        and "valid_human_label_rows_missing_reviewer_id" in summary
        and (
            int(summary.get("valid_human_label_rows", 0) or 0)
            - int(summary.get("valid_human_label_rows_with_reviewer_id", 0) or 0)
            != int(summary.get("valid_human_label_rows_missing_reviewer_id", 0) or 0)
        )
    ):
        errors.append(f"{name}: missing reviewer count must match valid label rows")
    if not check_output_files:
        return errors
    if scoped and "output_files" not in summary:
        return errors
    if "reviewer_candidate_packet.jsonl" not in summary.get("output_files", []):
        errors.append(f"{name}: output_files must include reviewer_candidate_packet.jsonl")
    if "reviewer_missing_candidates.jsonl" not in summary.get("output_files", []):
        errors.append(f"{name}: output_files must include reviewer_missing_candidates.jsonl")
    if "reviewer_progress_summary.json" not in summary.get("output_files", []):
        errors.append(f"{name}: output_files must include reviewer_progress_summary.json")
    return errors


def verify_packet_dir(path: Path, *, name: str = "label_packet", scoped: bool = False) -> tuple[dict, list[str]]:
    errors: list[str] = []
    if is_forbidden_env_path(path):
        return {}, [f"{name}: refusing .env-like packet path"]
    if not path.is_dir():
        return {}, [f"{name}: packet path must be a directory"]
    children = {child.name for child in path.iterdir()}
    if children != MANAGED_OUTPUTS:
        errors.append(f"{name}: packet directory must contain exactly managed reviewer packet artifacts")
    try:
        packet_rows = read_jsonl_file(path / "reviewer_candidate_packet.jsonl", "reviewer candidate packet")
        missing_rows = read_jsonl_file(path / "reviewer_missing_candidates.jsonl", "reviewer missing candidates")
        summary = read_json(path / "reviewer_progress_summary.json", "reviewer progress summary")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        return {}, [*errors, f"{name}: parse error: {exc}"]
    missing_ids = [str(row.get("candidate_label_id") or "").strip() for row in missing_rows]
    if any(not value for value in missing_ids):
        errors.append(f"{name}: reviewer_missing_candidates rows must include candidate_label_id")
    if len(missing_ids) != len(set(missing_ids)):
        errors.append(f"{name}: reviewer_missing_candidates must not contain duplicates")
    candidate_ids = [str(row.get("candidate_label_id") or "").strip() for row in packet_rows]
    if any(not value for value in candidate_ids):
        errors.append(f"{name}: reviewer_candidate_packet rows must include candidate_label_id")
    if len(candidate_ids) != len(set(candidate_ids)):
        errors.append(f"{name}: reviewer_candidate_packet must not contain duplicate candidate_label_id values")
    unknown_missing = sorted(set(missing_ids) - set(candidate_ids))
    if unknown_missing:
        errors.append(f"{name}: reviewer_missing_candidates contains unknown candidate_label_id")
    errors.extend(verify_summary_bindings(summary, packet_rows, missing_ids, name=name, scoped=scoped))
    return summary, errors


def verify_case_packet_root(path: Path) -> tuple[dict, list[str]]:
    errors: list[str] = []
    if is_forbidden_env_path(path):
        return {}, ["label_packet_index: refusing .env-like packet root"]
    if not path.is_dir():
        return {}, ["label_packet_index: packet root must be a directory"]
    index_path = path / MANAGED_CASE_INDEX
    if not index_path.is_file():
        return {}, [f"label_packet_index: missing {MANAGED_CASE_INDEX}"]
    try:
        index = read_json(index_path, "reviewer packet index")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        return {}, [f"label_packet_index: parse error: {exc}"]
    errors.extend(blocked_claim_errors(index, name="label_packet_index"))
    case_packets = index.get("case_packets", [])
    if not isinstance(case_packets, list):
        return index, ["label_packet_index: case_packets must be a list"]
    if index.get("case_packet_count") != len(case_packets):
        errors.append("label_packet_index: case_packet_count must match case_packets")
    expected_children = {MANAGED_CASE_INDEX}
    summaries_by_case: dict[str, dict] = {}
    all_packet_rows: list[dict] = []
    all_missing_ids: list[str] = []
    for row_index, row in enumerate(case_packets, start=1):
        if not isinstance(row, dict):
            errors.append(f"label_packet_index: case_packets row {row_index} must be an object")
            continue
        case_id = str(row.get("case_id") or "").strip()
        output_dir = str(row.get("output_dir") or "").strip()
        if not case_id:
            errors.append(f"label_packet_index: case_packets row {row_index}: case_id must be present")
            continue
        expected_children.add(case_id)
        if not output_dir:
            errors.append(f"label_packet_index: case_packets row {row_index}: output_dir must be present")
            continue
        case_dir = Path(output_dir).expanduser().resolve()
        if case_dir != (path / case_id).resolve():
            errors.append(f"label_packet_index: case_packets row {row_index}: output_dir must match case_id directory")
            continue
        case_summary, case_errors = verify_packet_dir(case_dir, name=f"label_packet[{case_id}]", scoped=True)
        errors.extend(case_errors)
        summaries_by_case[case_id] = case_summary
        try:
            all_packet_rows.extend(
                read_jsonl_file(case_dir / "reviewer_candidate_packet.jsonl", f"label_packet[{case_id}] candidate packet")
            )
            missing_rows = read_jsonl_file(
                case_dir / "reviewer_missing_candidates.jsonl",
                f"label_packet[{case_id}] missing candidates",
            )
            all_missing_ids.extend(str(missing.get("candidate_label_id") or "").strip() for missing in missing_rows)
        except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
            errors.append(f"label_packet_index: case_packets row {row_index}: parse error: {exc}")
        for key in [
            "candidate_label_rows",
            "synthetic_candidate_rows",
            "non_synthetic_candidate_rows",
            "valid_human_label_rows",
            "non_synthetic_valid_human_label_rows",
            "missing_candidate_label_count",
            "all_candidates_reviewed",
            "ready_for_label_intake",
        ]:
            if row.get(key) != case_summary.get(key):
                errors.append(f"label_packet_index: case_packets row {row_index}: {key} must match case summary")
    actual_children = {child.name for child in path.iterdir()}
    if actual_children != expected_children:
        errors.append("label_packet_index: packet root must contain only indexed case packet directories")
    expected_case_progress = [
        {
            "case_id": case_id,
            "template_dirs": summaries_by_case[case_id].get("template_dirs", []),
            "candidate_label_rows": summaries_by_case[case_id].get("candidate_label_rows"),
            "synthetic_candidate_rows": summaries_by_case[case_id].get("synthetic_candidate_rows"),
            "non_synthetic_candidate_rows": summaries_by_case[case_id].get("non_synthetic_candidate_rows"),
            "valid_human_label_rows": summaries_by_case[case_id].get("valid_human_label_rows"),
            "non_synthetic_valid_human_label_rows": summaries_by_case[case_id].get(
                "non_synthetic_valid_human_label_rows"
            ),
            "missing_candidate_label_count": summaries_by_case[case_id].get("missing_candidate_label_count"),
            "all_candidates_reviewed": summaries_by_case[case_id].get("all_candidates_reviewed"),
            "ready_for_label_intake": summaries_by_case[case_id].get("ready_for_label_intake"),
        }
        for case_id in sorted(summaries_by_case)
    ]
    if index.get("case_progress_rows") != expected_case_progress:
        errors.append("label_packet_index: case_progress_rows must match case packet summaries")
    errors.extend(
        verify_summary_bindings(
            index,
            all_packet_rows,
            all_missing_ids,
            name="label_packet_index",
            scoped=False,
            check_output_files=False,
        )
    )
    return index, errors


def verify_existing_packet_path(path: Path) -> tuple[dict, list[str]]:
    if (path / MANAGED_CASE_INDEX).is_file():
        return verify_case_packet_root(path)
    return verify_packet_dir(path)


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
        template_dirs = set(scoped_summary["template_dirs"])
        scoped_template_fingerprints = [
            row
            for row in summary["label_template_fingerprints"]
            if row["template_dir"] in template_dirs
        ]
        scoped_summary.update(
            {
                "label_template_fingerprints": scoped_template_fingerprints,
                "label_template_json_sha256s": [
                    row["label_template_json_sha256"] for row in scoped_template_fingerprints
                ],
                "label_template_manifest_sha256s": [
                    row["label_template_manifest_sha256"]
                    for row in scoped_template_fingerprints
                    if row["label_template_manifest_sha256"]
                ],
                "label_template_bundle_sha256": sha256_json(scoped_template_fingerprints),
                "decisions_fingerprints": summary["decisions_fingerprints"],
                "decisions_sha256s": summary["decisions_sha256s"],
                "decisions_bundle_sha256": summary["decisions_bundle_sha256"],
                "candidate_guard_passed": summary["candidate_guard_passed"],
                "decision_input_guard_passed": summary["decision_input_guard_passed"],
                "output_path_guard_passed": summary["output_path_guard_passed"],
            }
        )
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
                "synthetic_candidate_rows": scoped_summary["synthetic_candidate_rows"],
                "non_synthetic_candidate_rows": scoped_summary["non_synthetic_candidate_rows"],
                "valid_human_label_rows": scoped_summary["valid_human_label_rows"],
                "non_synthetic_valid_human_label_rows": scoped_summary["non_synthetic_valid_human_label_rows"],
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
    parser.add_argument("--verify-existing", default="", help="Verify an existing reviewer packet output directory.")
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
        if args.verify_existing:
            summary, verify_errors = verify_existing_packet_path(Path(args.verify_existing).expanduser().resolve())
            payload = {
                "schema": "amr_beta_label_packet_verify_existing.v1",
                "verify_existing": str(Path(args.verify_existing).expanduser().resolve()),
                "verify_existing_passed": int(not verify_errors),
                "creates_benchmark_evidence": 0,
                "runs_real_benchmark": 0,
                "compiles_labels": 0,
                "writes_reviewer_packets": 0,
                "release_ready": 0,
                "public_comparison_claim_ready": 0,
                "real_model_execution_ready": 0,
                "design_partner_beta_candidate_ready": 0,
                "packet_summary_sha256": sha256_json(summary) if summary else "",
                "errors": verify_errors,
            }
            if args.json:
                print(json.dumps(payload, indent=2, sort_keys=True))
            if verify_errors:
                for error in verify_errors:
                    print(error, file=sys.stderr)
                return 1
            if not args.json:
                print("label_packet_verify: ok")
            return 0
        if not args.template_dir:
            raise ValueError("at least one --template-dir is required")
        packet_rows: list[dict] = []
        errors: list[str] = []
        synthetic_candidate_rows = 0
        verify_passed_dirs = 0
        verify_failed_dirs = 0
        target_repo_paths: list[str] = []
        template_fingerprints: list[dict[str, str]] = []
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
            template_json = template_dir / "label_template.json"
            template_manifest = template_dir / "label_template_manifest.json"
            template_fingerprints.append(
                {
                    "template_dir": str(template_dir),
                    "label_template_json_sha256": sha256_file(template_json),
                    "label_template_manifest_sha256": sha256_file(template_manifest)
                    if template_manifest.is_file()
                    else "",
                }
            )
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
        decision_fingerprints: list[dict[str, str]] = []
        if not decision_input_errors:
            for raw_decisions in args.decisions:
                decision_path = Path(raw_decisions).expanduser().resolve()
                decision_fingerprints.append(
                    {
                        "decisions": str(decision_path),
                        "decisions_sha256": sha256_file(decision_path),
                    }
                )
                decision_rows.extend(read_json_or_jsonl(decision_path, "decisions"))
        decision_errors, valid_decision_ids, valid_human_label_rows, valid_decision_rows = validate_decisions(
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
        reviewer_rows = reviewer_progress_rows(valid_decision_rows, non_synthetic_candidate_ids)
        valid_human_label_rows_with_reviewer_id = sum(
            1 for row in valid_decision_rows if str(row.get("reviewer_id") or "").strip()
        )
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
        all_cases_ready_for_label_intake = int(
            bool(progress_rows) and cases_ready_for_label_intake == len(progress_rows)
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
            "non_synthetic_candidate_rows": len(non_synthetic_candidate_ids),
            "label_template_fingerprints": template_fingerprints,
            "label_template_json_sha256s": [
                row["label_template_json_sha256"] for row in template_fingerprints
            ],
            "label_template_manifest_sha256s": [
                row["label_template_manifest_sha256"]
                for row in template_fingerprints
                if row["label_template_manifest_sha256"]
            ],
            "label_template_bundle_sha256": sha256_json(template_fingerprints),
            "decisions_fingerprints": decision_fingerprints,
            "decisions_sha256s": [
                row["decisions_sha256"] for row in decision_fingerprints
            ],
            "decisions_bundle_sha256": sha256_json(decision_fingerprints),
            "decision_rows": len(decision_rows),
            "valid_human_label_rows": valid_human_label_rows,
            "valid_human_label_rows_with_reviewer_id": valid_human_label_rows_with_reviewer_id,
            "valid_human_label_rows_missing_reviewer_id": (
                valid_human_label_rows - valid_human_label_rows_with_reviewer_id
            ),
            "distinct_reviewer_id_count": len(reviewer_rows),
            "reviewer_progress_rows": reviewer_rows,
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
            "ready_for_label_intake": int(
                not errors
                and non_synthetic_valid_human_label_rows > 0
                and not missing_ids
                and all_cases_ready_for_label_intake == 1
            ),
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
