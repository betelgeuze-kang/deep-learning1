#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from audit_my_repo_label_template import (
    CLAIM_BOUNDARY,
    TOOL_VERSION,
    read_json,
    sha256_file,
    sha256_hex,
    validate_json_schema,
    verify_template_dir,
)


MANIFEST_SCHEMA_VERSION = "local_repo_audit_label_intake_manifest.v1"
LABEL_INTAKE_ARTIFACTS = ("benchmark_labels.jsonl",)
MANAGED_TOP_LEVEL = set(LABEL_INTAKE_ARTIFACTS) | {
    "label_intake_manifest.json",
    "label_intake_sha256sums.txt",
}
SAFE_LABEL_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,191}$")
SAFE_MAINTAINER_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:@+-]{0,191}$")
PLACEHOLDER_RE = re.compile(r"(^$|example|placeholder|replace|todo)", re.IGNORECASE)
VALID_LABEL_PRIORITIES = {"", "P0", "P1", "P2", "P3"}


def root_dir() -> Path:
    return Path(__file__).resolve().parents[1]


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def is_sha256_digest(value: str) -> bool:
    return bool(re.fullmatch(r"sha256:[0-9a-f]{64}", value))


def is_git_object_id(value: str) -> bool:
    return bool(re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", value))


def truthy(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def good_operator_value(value: object) -> bool:
    return not PLACEHOLDER_RE.search(str(value or "").strip())


def require_safe_non_placeholder_id(value: str, *, label: str, pattern: re.Pattern[str]) -> str:
    text = str(value or "").strip()
    if not text:
        raise ValueError(f"{label} is required")
    if not good_operator_value(text):
        raise ValueError(f"{label} must not be example/placeholder")
    if not pattern.fullmatch(text):
        raise ValueError(f"{label} must be a safe identifier")
    return text


def normalize_optional_safe_non_placeholder_id(
    value: object,
    *,
    label: str,
    pattern: re.Pattern[str],
) -> str:
    text = str(value or "").strip()
    if not text:
        return ""
    return require_safe_non_placeholder_id(text, label=label, pattern=pattern)


def is_forbidden_env_path(path: Path) -> bool:
    for part in path.parts:
        if part == ".env" or part.startswith(".env.") or part.endswith(".env") or ".env." in part:
            return True
    return False


def is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
    except ValueError:
        return False
    return True


def load_template_audit_context(template_dir: Path) -> tuple[dict, Path]:
    if is_forbidden_env_path(template_dir):
        raise ValueError("refusing .env-like template path")
    template_manifest = read_json(template_dir / "label_template_manifest.json")
    audit_output_raw = str(template_manifest.get("input_audit_output") or "").strip()
    if not audit_output_raw:
        raise ValueError("label template manifest missing input_audit_output")
    audit_output = Path(audit_output_raw).expanduser().resolve()
    if is_forbidden_env_path(audit_output):
        raise ValueError("refusing .env-like input audit output path")
    return read_json(audit_output / "audit_manifest.json"), audit_output


def validate_output_path(out_dir: Path, repo_path: str) -> None:
    if is_forbidden_env_path(out_dir):
        raise ValueError("refusing .env-like output directory")
    resolved_out_dir = out_dir.expanduser().resolve()
    if is_forbidden_env_path(resolved_out_dir):
        raise ValueError("refusing .env-like output directory")
    repo_text = str(repo_path or "").strip()
    if not repo_text:
        raise ValueError("repo_path is required for label-intake output path guard")
    repo = Path(repo_text).expanduser().resolve()
    if resolved_out_dir == repo or is_relative_to(resolved_out_dir, repo):
        raise ValueError("refusing --out inside target repo; use an output path outside the labeled repository")


def validate_decisions_input_path(decisions_path: Path, repo_path: str) -> None:
    if is_forbidden_env_path(decisions_path):
        raise ValueError("refusing to read .env-like decisions file")
    resolved = decisions_path.expanduser().resolve()
    if is_forbidden_env_path(resolved):
        raise ValueError("refusing to read .env-like decisions file")
    repo_text = str(repo_path or "").strip()
    if not repo_text:
        raise ValueError("repo_path is required for label-intake decisions path guard")
    repo = Path(repo_text).expanduser().resolve()
    if resolved == repo or is_relative_to(resolved, repo):
        raise ValueError(
            "refusing --decisions inside target repo; use a decisions file outside the labeled repository"
        )


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
            raise ValueError(f"JSON {input_name} file must contain a list")
        return payload
    if stripped.startswith("{"):
        try:
            payload = json.loads(stripped)
        except json.JSONDecodeError:
            payload = None
        rows = payload.get("decisions") if isinstance(payload, dict) else None
        if isinstance(rows, list):
            return rows
    return [json.loads(line) for line in text.splitlines() if line.strip()]


def read_jsonl(path: Path) -> list[dict]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def label_intake_schema_sha256s(root: Path) -> dict[str, str]:
    return {
        "schemas/local_repo_audit_label_intake_manifest.schema.json": sha256_file(
            root / "schemas" / "local_repo_audit_label_intake_manifest.schema.json"
        )
    }


def validate_template(root: Path, template_dir: Path, *, allow_source_drift: bool) -> None:
    errors = verify_template_dir(template_dir, allow_source_drift=allow_source_drift)
    if errors:
        raise ValueError(f"--template must point at a verified label template bundle: {errors[0]}")


def template_rows(template_dir: Path) -> list[dict[str, str]]:
    payload = read_json(template_dir / "label_template.json")
    rows = payload.get("rows", [])
    if not isinstance(rows, list):
        raise ValueError("label_template.json rows must be a list")
    return [{key: "" if value is None else str(value) for key, value in row.items()} for row in rows if isinstance(row, dict)]


def normalize_optional_binary(value: object, *, label: str) -> str:
    if value is None or value == "":
        return ""
    lowered = str(value).strip().lower()
    if lowered in {"1", "true", "yes", "y"}:
        return "1"
    if lowered in {"0", "false", "no", "n"}:
        return "0"
    raise ValueError(f"{label} must be 0/1/true/false when provided")


def normalize_label_priority(value: object, *, label: str) -> str:
    priority = str(value or "").strip().upper()
    if priority not in VALID_LABEL_PRIORITIES:
        raise ValueError(f"{label} priority must be P0, P1, P2, P3, or empty")
    return priority


def normalize_decisions(raw_rows: list[dict]) -> list[dict]:
    decisions: list[dict] = []
    seen: set[str] = set()
    seen_label_ids: set[str] = set()
    for idx, raw in enumerate(raw_rows, start=1):
        if not isinstance(raw, dict):
            raise ValueError(f"decision row {idx} must be an object")
        candidate_label_id = str(raw.get("candidate_label_id") or "").strip()
        if not candidate_label_id:
            raise ValueError(f"decision row {idx} missing candidate_label_id")
        candidate_label_id = require_safe_non_placeholder_id(
            candidate_label_id,
            label=f"decision row {idx} candidate_label_id",
            pattern=SAFE_LABEL_ID,
        )
        if candidate_label_id in seen:
            raise ValueError(f"duplicate decision for candidate_label_id: {candidate_label_id}")
        seen.add(candidate_label_id)
        if truthy(raw.get("template_only", False)):
            raise ValueError(f"decision {candidate_label_id} must not be marked template_only")
        if not truthy(raw.get("human_labeled", raw.get("human_reviewed", False))):
            raise ValueError(f"decision {candidate_label_id} must include human_labeled=true")
        expected = str(raw.get("expected") or raw.get("human_expected") or "").strip().lower()
        if expected not in {"present", "absent"}:
            raise ValueError(f"decision {candidate_label_id} expected must be present or absent")
        expected_abstain = normalize_optional_binary(
            raw.get("expected_abstain", raw.get("human_expected_abstain", "")),
            label=f"decision {candidate_label_id} expected_abstain",
        )
        label_id = require_safe_non_placeholder_id(
            str(raw.get("label_id") or candidate_label_id),
            label=f"decision {candidate_label_id} label_id",
            pattern=SAFE_LABEL_ID,
        )
        if label_id in seen_label_ids:
            raise ValueError(f"duplicate decision label_id: {label_id}")
        seen_label_ids.add(label_id)
        maintainer_id = normalize_optional_safe_non_placeholder_id(
            raw.get("maintainer_id"),
            label=f"decision {candidate_label_id} maintainer_id",
            pattern=SAFE_MAINTAINER_ID,
        )
        reviewer_id = normalize_optional_safe_non_placeholder_id(
            raw.get("reviewer_id"),
            label=f"decision {candidate_label_id} reviewer_id",
            pattern=SAFE_LABEL_ID,
        )
        decisions.append(
            {
                "candidate_label_id": candidate_label_id,
                "label_id": label_id,
                "expected": expected,
                "expected_abstain": expected_abstain,
                "priority": normalize_label_priority(
                    raw.get("priority", raw.get("human_priority", "")),
                    label=f"decision {candidate_label_id}",
                ),
                "maintainer_id": maintainer_id,
                "maintainer_feedback": int(bool(maintainer_id and truthy(raw.get("maintainer_feedback", False)))),
                "reviewer_id_sha256": sha256_text(reviewer_id) if reviewer_id else "",
            }
        )
    if not decisions:
        raise ValueError("decision input must contain at least one human-labeled row")
    return decisions


def resolve_repo_path(raw: str, audit_manifest: dict) -> str:
    repo_text = raw.strip() if raw else str(audit_manifest.get("target_repo", "")).strip()
    if not repo_text:
        raise ValueError("repo_path is required because the source audit manifest did not bind target_repo")
    repo = Path(repo_text).expanduser().resolve()
    if is_forbidden_env_path(repo):
        raise ValueError("refusing .env-like repo_path")
    if not repo.is_dir():
        raise ValueError(f"repo_path is not a directory: {repo}")
    return str(repo)


def resolve_expected_repo_git_head(raw: str, source_snapshot: dict) -> str:
    expected = raw.strip().lower() if raw else ""
    if expected and not is_git_object_id(expected):
        raise ValueError("--expected-repo-git-head must be a git object id")
    if expected:
        return expected
    if int(source_snapshot.get("git_available", 0)) == 1 and int(source_snapshot.get("git_dirty", 0)) == 0:
        return str(source_snapshot.get("git_head", "")).strip().lower()
    return ""


def compile_benchmark_labels(
    template_dir: Path,
    decisions_path: Path,
    *,
    repo_path: str,
    expected_repo_git_head: str,
) -> tuple[list[dict], list[dict]]:
    validate_decisions_input_path(decisions_path, repo_path)
    candidates = {row["candidate_label_id"]: row for row in template_rows(template_dir)}
    decisions = normalize_decisions(read_json_or_jsonl(decisions_path, "decisions"))
    labels: list[dict] = []
    for decision in decisions:
        candidate_id = decision["candidate_label_id"]
        candidate = candidates.get(candidate_id)
        if candidate is None:
            raise ValueError(f"decision references unknown candidate_label_id: {candidate_id}")
        if candidate.get("template_only") != "1" or candidate.get("human_labeled") != "0":
            raise ValueError(f"candidate {candidate_id} is not an unreviewed template row")
        expected = decision["expected"]
        expected_line_start = candidate.get("expected_line_start", "") if expected == "present" else ""
        expected_line_end = candidate.get("expected_line_end", "") if expected == "present" else ""
        expected_span_sha256 = candidate.get("expected_span_sha256", "") if expected == "present" else ""
        if expected == "present" and not (
            expected_line_start and expected_line_end and is_sha256_digest(expected_span_sha256)
        ):
            raise ValueError(f"present decision {candidate_id} requires a source-bound citation span")
        label = {
            "case_id": candidate["case_id"],
            "label_id": decision["label_id"],
            "repo_path": repo_path,
            "expected_repo_git_head": expected_repo_git_head,
            "human_labeled": True,
            "synthetic": truthy(candidate.get("synthetic", "0")),
            "priority": decision["priority"],
            "maintainer_id": decision["maintainer_id"],
            "maintainer_feedback": bool(decision["maintainer_feedback"]),
            "plugin_id": candidate["plugin_id"],
            "rule_id": candidate["rule_id"],
            "file_path": candidate["file_path"],
            "expected_line_start": expected_line_start,
            "expected_line_end": expected_line_end,
            "expected_span_sha256": expected_span_sha256,
            "expected": expected,
            "expected_abstain": decision["expected_abstain"],
            "source_candidate_label_id": candidate_id,
            "source_finding_id": candidate["source_finding_id"],
            "source_review_queue_id": candidate.get("source_review_queue_id", ""),
            "source_template_span_sha256": candidate.get("expected_span_sha256", ""),
        }
        labels.append(label)
    return labels, decisions


def artifact_sha256s(out_dir: Path) -> dict[str, str]:
    return {rel: sha256_file(out_dir / rel) for rel in LABEL_INTAKE_ARTIFACTS}


def write_sha_manifest(out_dir: Path, rels: list[str]) -> None:
    lines: list[str] = []
    seen: set[str] = set()
    for rel in rels:
        rel_path = Path(rel)
        if rel_path.is_absolute() or ".." in rel_path.parts or rel in seen:
            raise ValueError(f"invalid label-intake sha manifest path: {rel}")
        seen.add(rel)
        lines.append(f"{sha256_hex(out_dir / rel)}  {rel}")
    (out_dir / "label_intake_sha256sums.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def read_sha_manifest(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        if "  " not in line:
            raise ValueError("invalid label intake sha manifest line")
        digest, rel = line.split("  ", 1)
        rel_path = Path(rel)
        if rel_path.is_absolute() or ".." in rel_path.parts or rel in entries:
            raise ValueError(f"invalid label intake sha manifest path: {rel}")
        entries[rel] = digest
    return entries


def write_label_intake_dir(
    root: Path,
    out_dir: Path,
    template_dir: Path,
    decisions_path: Path,
    *,
    repo_path_override: str,
    expected_repo_git_head_override: str,
    allow_source_drift: bool,
) -> None:
    validate_template(root, template_dir, allow_source_drift=allow_source_drift)
    template_manifest = read_json(template_dir / "label_template_manifest.json")
    audit_manifest, audit_output = load_template_audit_context(template_dir)
    source_snapshot = read_json(audit_output / "source_snapshot.json")
    repo_path = resolve_repo_path(repo_path_override, audit_manifest)
    validate_output_path(out_dir, repo_path)
    expected_repo_git_head = resolve_expected_repo_git_head(expected_repo_git_head_override, source_snapshot)
    labels, decisions = compile_benchmark_labels(
        template_dir,
        decisions_path,
        repo_path=repo_path,
        expected_repo_git_head=expected_repo_git_head,
    )
    write_jsonl(out_dir / "benchmark_labels.jsonl", labels)
    reviewer_hashes = sorted({row["reviewer_id_sha256"] for row in decisions if row.get("reviewer_id_sha256")})
    manifest = {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "claim_boundary": CLAIM_BOUNDARY,
        "label_intake_source_sha256": sha256_file(root / "scripts" / "audit_my_repo_label_intake.py"),
        "label_template_source_sha256": sha256_file(root / "scripts" / "audit_my_repo_label_template.py"),
        "benchmark_runner_source_sha256": sha256_file(root / "scripts" / "audit_my_repo_benchmark.py"),
        "schema_sha256s": label_intake_schema_sha256s(root),
        "template_output": str(template_dir),
        "template_manifest_sha256": sha256_file(template_dir / "label_template_manifest.json"),
        "template_sha256sums_sha256": sha256_file(template_dir / "label_template_sha256sums.txt"),
        "decisions_input": str(decisions_path),
        "decisions_input_sha256": sha256_file(decisions_path),
        "input_audit_output": str(audit_output),
        "input_audit_manifest_sha256": sha256_file(audit_output / "audit_manifest.json"),
        "input_audit_cache_key": str(template_manifest.get("input_audit_cache_key", "")),
        "repo_path": repo_path,
        "expected_repo_git_head": expected_repo_git_head,
        "label_rows": len(labels),
        "human_label_rows": len(labels),
        "synthetic_label_rows": sum(int(bool(row["synthetic"])) for row in labels),
        "reviewer_id_sha256s": reviewer_hashes,
        "artifact_sha256s": artifact_sha256s(out_dir),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "design_partner_beta_candidate_ready": 0,
    }
    write_json(out_dir / "label_intake_manifest.json", manifest)
    write_sha_manifest(out_dir, ["label_intake_manifest.json", *LABEL_INTAKE_ARTIFACTS])


def verify_label_intake_dir(
    out_dir: Path,
    *,
    allow_source_drift: bool = False,
    enforce_env_path_guard: bool = True,
) -> list[str]:
    errors: list[str] = []
    root = root_dir()
    if enforce_env_path_guard and is_forbidden_env_path(out_dir):
        return ["refusing .env-like label intake path"]
    for rel in [*LABEL_INTAKE_ARTIFACTS, "label_intake_manifest.json", "label_intake_sha256sums.txt"]:
        if not (out_dir / rel).is_file():
            errors.append(f"missing label intake artifact: {rel}")
    if errors:
        return errors
    for child in out_dir.iterdir():
        if child.name not in MANAGED_TOP_LEVEL:
            errors.append(f"unexpected label intake output entry: {child.name}")
    ok, detail = validate_json_schema(
        root,
        "schemas/local_repo_audit_label_intake_manifest.schema.json",
        out_dir / "label_intake_manifest.json",
    )
    if not ok:
        errors.append(f"schema validation failed for label_intake_manifest.json{': ' + detail if detail else ''}")
    try:
        manifest = read_json(out_dir / "label_intake_manifest.json")
        sha_entries = read_sha_manifest(out_dir / "label_intake_sha256sums.txt")
        label_rows = read_jsonl(out_dir / "benchmark_labels.jsonl")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        return [*errors, f"label intake parse error: {exc}"]

    try:
        validate_output_path(out_dir, str(manifest.get("repo_path", "")))
    except ValueError as exc:
        errors.append(str(exc))
    expected_sha_paths = {"label_intake_manifest.json", *LABEL_INTAKE_ARTIFACTS}
    if set(sha_entries) != expected_sha_paths:
        errors.append("label intake sha manifest must bind exactly the managed artifacts")
    for rel, digest in sha_entries.items():
        if sha256_hex(out_dir / rel) != digest:
            errors.append(f"label intake sha drift: {rel}")
    if manifest.get("artifact_sha256s") != artifact_sha256s(out_dir):
        errors.append("label intake manifest artifact sha drift")
    if manifest.get("label_intake_source_sha256") != sha256_file(root / "scripts" / "audit_my_repo_label_intake.py"):
        errors.append("label intake manifest source sha drift")
    if manifest.get("label_template_source_sha256") != sha256_file(root / "scripts" / "audit_my_repo_label_template.py"):
        errors.append("label intake manifest template source sha drift")
    if manifest.get("benchmark_runner_source_sha256") != sha256_file(root / "scripts" / "audit_my_repo_benchmark.py"):
        errors.append("label intake manifest benchmark source sha drift")
    if manifest.get("schema_sha256s") != label_intake_schema_sha256s(root):
        errors.append("label intake manifest schema sha drift")
    for blocked_key in [
        "release_ready",
        "public_comparison_claim_ready",
        "real_model_execution_ready",
        "design_partner_beta_candidate_ready",
    ]:
        if manifest.get(blocked_key) != 0:
            errors.append(f"label intake manifest must keep {blocked_key}=0")
    template_dir = Path(str(manifest.get("template_output", ""))).expanduser()
    decisions_path = Path(str(manifest.get("decisions_input", ""))).expanduser()
    if not template_dir.is_absolute() or not template_dir.is_dir():
        errors.append("label intake manifest template_output must be an existing absolute directory")
    if not decisions_path.is_absolute() or not decisions_path.is_file():
        errors.append("label intake manifest decisions_input must be an existing absolute file")
    else:
        try:
            validate_decisions_input_path(decisions_path, str(manifest.get("repo_path", "")))
        except ValueError as exc:
            errors.append(str(exc))
    if not errors:
        try:
            validate_template(root, template_dir, allow_source_drift=allow_source_drift)
            template_manifest = read_json(template_dir / "label_template_manifest.json")
            audit_output = Path(str(template_manifest["input_audit_output"])).expanduser()
            if manifest.get("template_manifest_sha256") != sha256_file(template_dir / "label_template_manifest.json"):
                errors.append("label intake manifest template manifest sha drift")
            if manifest.get("template_sha256sums_sha256") != sha256_file(template_dir / "label_template_sha256sums.txt"):
                errors.append("label intake manifest template sha manifest drift")
            if manifest.get("decisions_input_sha256") != sha256_file(decisions_path):
                errors.append("label intake manifest decisions input sha drift")
            if manifest.get("input_audit_manifest_sha256") != sha256_file(audit_output / "audit_manifest.json"):
                errors.append("label intake manifest input audit manifest sha drift")
            expected_labels, decisions = compile_benchmark_labels(
                template_dir,
                decisions_path,
                repo_path=str(manifest.get("repo_path", "")),
                expected_repo_git_head=str(manifest.get("expected_repo_git_head", "")),
            )
            if label_rows != expected_labels:
                errors.append("benchmark_labels.jsonl drift from template and decisions")
            if manifest.get("label_rows") != len(expected_labels) or manifest.get("human_label_rows") != len(expected_labels):
                errors.append("label intake manifest label row counts drift")
            if manifest.get("synthetic_label_rows") != sum(int(bool(row["synthetic"])) for row in expected_labels):
                errors.append("label intake manifest synthetic label count drift")
            reviewer_hashes = sorted({row["reviewer_id_sha256"] for row in decisions if row.get("reviewer_id_sha256")})
            if manifest.get("reviewer_id_sha256s") != reviewer_hashes:
                errors.append("label intake manifest reviewer hash drift")
        except ValueError as exc:
            errors.append(str(exc))
    return errors


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def prepare_output_dir(out_dir: Path, overwrite: bool) -> Path | None:
    out_dir.parent.mkdir(parents=True, exist_ok=True)
    if not out_dir.exists():
        return None
    if not out_dir.is_dir():
        raise ValueError(f"label intake output path is not a directory: {out_dir}")
    children = list(out_dir.iterdir())
    if not children:
        return None
    if not overwrite:
        raise ValueError("label intake output directory already contains artifacts; use a fresh --out or pass --overwrite")
    for child in children:
        if child.name not in MANAGED_TOP_LEVEL:
            raise ValueError(f"refusing to delete unrelated label intake output entry: {child.name}; use a fresh --out")
    backup_dir = Path(tempfile.mkdtemp(prefix=f".{out_dir.name}.label_intake_backup.", dir=out_dir.parent))
    for child in children:
        os.replace(child, backup_dir / child.name)
    return backup_dir


def rollback_output_dir(out_dir: Path, backup_dir: Path | None) -> None:
    if out_dir.exists():
        if out_dir.is_dir():
            for child in list(out_dir.iterdir()):
                if child.name in MANAGED_TOP_LEVEL:
                    remove_path(child)
        elif out_dir.is_file() or out_dir.is_symlink():
            out_dir.unlink()
    if backup_dir is not None and backup_dir.exists():
        out_dir.mkdir(parents=True, exist_ok=True)
        for child in list(backup_dir.iterdir()):
            os.replace(child, out_dir / child.name)
        shutil.rmtree(backup_dir, ignore_errors=True)


def commit_output_dir(backup_dir: Path | None) -> None:
    if backup_dir is not None:
        shutil.rmtree(backup_dir, ignore_errors=True)


def generate_intake(args: argparse.Namespace) -> None:
    root = root_dir()
    raw_template_dir = Path(args.template).expanduser()
    raw_decisions_path = Path(args.decisions).expanduser()
    raw_out_dir = Path(args.out).expanduser()
    if is_forbidden_env_path(raw_template_dir):
        raise ValueError("refusing .env-like template path")
    if is_forbidden_env_path(raw_decisions_path):
        raise ValueError("refusing to read .env-like decisions file")
    if is_forbidden_env_path(raw_out_dir):
        raise ValueError("refusing .env-like output directory")
    template_dir = raw_template_dir.resolve()
    decisions_path = raw_decisions_path.resolve()
    out_dir = raw_out_dir.resolve()
    if is_forbidden_env_path(template_dir):
        raise ValueError("refusing .env-like template path")
    if is_forbidden_env_path(decisions_path):
        raise ValueError("refusing to read .env-like decisions file")
    if is_forbidden_env_path(out_dir):
        raise ValueError("refusing .env-like output directory")
    audit_manifest, _audit_output = load_template_audit_context(template_dir)
    repo_path = resolve_repo_path(args.repo_path, audit_manifest)
    validate_output_path(out_dir, repo_path)
    validate_decisions_input_path(decisions_path, repo_path)
    validate_template(root, template_dir, allow_source_drift=args.allow_source_drift)
    if not decisions_path.is_file():
        raise ValueError(f"--decisions is not a file: {decisions_path}")
    backup_dir: Path | None = None
    prepared_output = False
    out_dir.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=f".{out_dir.name}.label_intake_staging.", dir=out_dir.parent))
    try:
        backup_dir = prepare_output_dir(out_dir, args.overwrite)
        prepared_output = True
        write_label_intake_dir(
            root,
            staging,
            template_dir,
            decisions_path,
            repo_path_override=args.repo_path,
            expected_repo_git_head_override=args.expected_repo_git_head,
            allow_source_drift=args.allow_source_drift,
        )
        if os.environ.get("AUDIT_MY_REPO_LABEL_INTAKE_TAMPER_BEFORE_VERIFY") == "1":
            rows = read_jsonl(staging / "benchmark_labels.jsonl")
            rows[0]["human_labeled"] = False
            write_jsonl(staging / "benchmark_labels.jsonl", rows)
        errors = verify_label_intake_dir(
            staging,
            allow_source_drift=args.allow_source_drift,
            enforce_env_path_guard=False,
        )
        if errors:
            raise RuntimeError("; ".join(errors))
        if out_dir.exists():
            out_dir.rmdir()
        os.replace(staging, out_dir)
        errors = verify_label_intake_dir(out_dir, allow_source_drift=args.allow_source_drift)
        if errors:
            raise RuntimeError("; ".join(errors))
        commit_output_dir(backup_dir)
    except Exception:
        if staging.exists():
            shutil.rmtree(staging, ignore_errors=True)
        if prepared_output:
            rollback_output_dir(out_dir, backup_dir)
        raise


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Compile human label decisions into benchmark labels.")
    parser.add_argument("--template", help="Verified label template output directory.")
    parser.add_argument("--decisions", help="Human decision JSON/JSONL file keyed by candidate_label_id.")
    parser.add_argument("--out", help="Output directory for benchmark_labels.jsonl and intake manifest.")
    parser.add_argument("--repo-path", default="", help="Optional current local repository path for benchmark labels.")
    parser.add_argument("--expected-repo-git-head", default="", help="Optional expected git HEAD for benchmark labels.")
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing managed label intake output.")
    parser.add_argument(
        "--allow-source-drift",
        action="store_true",
        help="Verify historical template/audit bundles without comparing source spans to the current worktree.",
    )
    parser.add_argument("--verify-existing", help="Verify an existing label intake output directory.")
    args = parser.parse_args(argv)
    try:
        if args.verify_existing:
            raw_verify_path = Path(args.verify_existing).expanduser()
            if is_forbidden_env_path(raw_verify_path):
                raise ValueError("refusing .env-like label intake path")
            errors = verify_label_intake_dir(raw_verify_path.resolve(), allow_source_drift=args.allow_source_drift)
            if errors:
                for error in errors:
                    print(error, file=sys.stderr)
                return 1
            print("label_intake_verify: ok")
            return 0
        if not args.template or not args.decisions or not args.out:
            raise ValueError("--template, --decisions, and --out are required unless --verify-existing is used")
        generate_intake(args)
        print(f"label_intake: wrote {Path(args.out).expanduser().resolve()}")
        return 0
    except (ValueError, FileNotFoundError, NotADirectoryError) as exc:
        print(f"label_intake_input_error: {exc}", file=sys.stderr)
        return 2
    except (
        OSError,
        UnicodeDecodeError,
        json.JSONDecodeError,
        csv.Error,
        subprocess.SubprocessError,
        RuntimeError,
    ) as exc:
        print(f"label_intake_verify_error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
