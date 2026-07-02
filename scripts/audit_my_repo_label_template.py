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


TOOL_VERSION = "audit_my_repo_alpha.v1"
CLAIM_BOUNDARY = "alpha-local-code-doc-audit-only"
TEMPLATE_SCHEMA_VERSION = "local_repo_audit_label_template.v1"
MANIFEST_SCHEMA_VERSION = "local_repo_audit_label_template_manifest.v1"
SAFE_CASE_ID = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")

LABEL_TEMPLATE_FIELDS = [
    "case_id",
    "candidate_label_id",
    "template_only",
    "human_labeled",
    "synthetic",
    "source_finding_id",
    "source_review_queue_id",
    "plugin_id",
    "rule_id",
    "plugin_rule_ids",
    "audit_type",
    "severity",
    "confidence",
    "language",
    "suggested_expected",
    "suggested_expected_abstain",
    "human_expected",
    "human_expected_abstain",
    "human_priority",
    "file_path",
    "expected_line_start",
    "expected_line_end",
    "expected_span_sha256",
    "citation_id",
    "source_file_sha256",
    "additional_citation_count",
    "question_sha256",
    "finding_answer_sha256",
    "finding_answer",
    "span_text_preview",
    "reviewer_notes",
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
    "design_partner_beta_candidate_ready",
]

LABEL_TEMPLATE_ARTIFACTS = (
    "label_template.csv",
    "label_template.json",
    "label_template.jsonl",
)
MANAGED_TOP_LEVEL = set(LABEL_TEMPLATE_ARTIFACTS) | {
    "label_template_manifest.json",
    "label_template_sha256sums.txt",
}
LABEL_TEMPLATE_SCHEMA_FILES = {
    "schemas/local_repo_audit_label_template.schema.json": "local_repo_audit_label_template.schema.json",
    "schemas/local_repo_audit_label_template_manifest.schema.json": "local_repo_audit_label_template_manifest.schema.json",
}


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def sha256_hex(path: Path) -> str:
    return sha256_file(path).split(":", 1)[1]


def sha256_text(text: str) -> str:
    return "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()


def root_dir() -> Path:
    return Path(__file__).resolve().parents[1]


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=LABEL_TEMPLATE_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def validate_json_schema(root: Path, schema_rel: str, instance: Path) -> tuple[bool, str]:
    result = subprocess.run(
        [
            sys.executable,
            str(root / "tools" / "validate_json_schemas.py"),
            "--schema-instance",
            str(root / schema_rel),
            str(instance),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    detail = (result.stderr or result.stdout).strip().splitlines()
    return result.returncode == 0, detail[0] if detail else ""


def verify_audit_output(root: Path, audit_output: Path, *, allow_source_drift: bool) -> None:
    cmd = [sys.executable, str(root / "tools" / "verify_local_audit.py"), str(audit_output)]
    if allow_source_drift:
        cmd.append("--allow-source-drift")
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        raise ValueError(f"--audit-output must point at a verified local audit bundle{suffix}")


def audit_output_sha256(audit_output: Path) -> str:
    digest = hashlib.sha256()
    for rel in [
        "audit_manifest.json",
        "audit_findings.csv",
        "citation_spans.csv",
        "source_snapshot.json",
        "audit_semantic_summary.json",
        "sha256sums.txt",
    ]:
        path = audit_output / rel
        digest.update(rel.encode("utf-8"))
        digest.update(b"\0")
        digest.update(sha256_file(path).encode("utf-8") if path.is_file() else b"missing")
        digest.update(b"\n")
    return "sha256:" + digest.hexdigest()


def normalize_case_id(raw: str, audit_manifest: dict) -> str:
    case_id = (raw or "").strip()
    if not case_id:
        cache_key = str(audit_manifest.get("cache_key", ""))
        case_id = f"audit_{cache_key[:12]}" if cache_key else "audit_case"
    if not SAFE_CASE_ID.fullmatch(case_id):
        raise ValueError("case_id must be a safe identifier with letters, numbers, '.', '_' or '-'")
    return case_id


def first_rule_id(plugin_rule_ids: str) -> str:
    rule_ids = [cell for cell in str(plugin_rule_ids).split("|") if cell]
    return rule_ids[0] if rule_ids else ""


def rows_by_finding_id(rows: list[dict[str, str]]) -> dict[str, list[dict[str, str]]]:
    grouped: dict[str, list[dict[str, str]]] = {}
    for row in rows:
        grouped.setdefault(str(row.get("finding_id", "")), []).append(row)
    return grouped


def build_template_rows(audit_output: Path, case_id: str) -> list[dict[str, str]]:
    manifest = read_json(audit_output / "audit_manifest.json")
    findings = read_csv_rows(audit_output / "audit_findings.csv")
    citations = rows_by_finding_id(read_csv_rows(audit_output / "citation_spans.csv"))
    review_queue = {
        row.get("finding_id", ""): row
        for row in read_csv_rows(audit_output / "manual_review_queue.csv")
    }
    real_benchmark_confirmed = (
        str(manifest.get("namespace", "")) == "real_benchmark"
        and int(manifest.get("real_benchmark_namespace_confirmed", 0)) == 1
    )
    synthetic = "0" if real_benchmark_confirmed else "1"
    rows: list[dict[str, str]] = []
    candidate_idx = 1
    for finding in findings:
        if str(finding.get("suppressed", "0")) == "1":
            continue
        finding_id = str(finding.get("finding_id", ""))
        spans = citations.get(finding_id, [])
        primary_span = spans[0] if spans else {}
        candidate_label_id = f"{case_id}_{candidate_idx:04d}"
        candidate_idx += 1
        answer = str(finding.get("answer", ""))
        question = str(finding.get("question", ""))
        row = {
            "case_id": case_id,
            "candidate_label_id": candidate_label_id,
            "template_only": "1",
            "human_labeled": "0",
            "synthetic": synthetic,
            "source_finding_id": finding_id,
            "source_review_queue_id": str(review_queue.get(finding_id, {}).get("review_queue_id", "")),
            "plugin_id": str(finding.get("plugin_id", "")),
            "rule_id": first_rule_id(str(finding.get("plugin_rule_ids", ""))),
            "plugin_rule_ids": str(finding.get("plugin_rule_ids", "")),
            "audit_type": str(finding.get("audit_type", "")),
            "severity": str(finding.get("severity", "")),
            "confidence": str(finding.get("confidence", "")),
            "language": str(finding.get("language", "")),
            "suggested_expected": "present",
            "suggested_expected_abstain": str(finding.get("abstain", "0")),
            "human_expected": "",
            "human_expected_abstain": "",
            "human_priority": "",
            "file_path": str(primary_span.get("file_path", "")),
            "expected_line_start": str(primary_span.get("line_start", "")),
            "expected_line_end": str(primary_span.get("line_end", "")),
            "expected_span_sha256": str(primary_span.get("span_sha256", "")),
            "citation_id": str(primary_span.get("citation_id", "")),
            "source_file_sha256": str(primary_span.get("sha256", "")),
            "additional_citation_count": str(max(0, len(spans) - 1)),
            "question_sha256": sha256_text(question),
            "finding_answer_sha256": sha256_text(answer),
            "finding_answer": answer,
            "span_text_preview": str(primary_span.get("span_text_preview", "")),
            "reviewer_notes": "",
            "release_ready": "0",
            "public_comparison_claim_ready": "0",
            "real_model_execution_ready": "0",
            "design_partner_beta_candidate_ready": "0",
        }
        rows.append(row)
    return rows


def template_payload(rows: list[dict[str, str]]) -> dict:
    return {
        "schema_version": TEMPLATE_SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "claim_boundary": CLAIM_BOUNDARY,
        "template_only": 1,
        "human_label_rows": 0,
        "candidate_label_rows": len(rows),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "design_partner_beta_candidate_ready": 0,
        "rows": rows,
    }


def artifact_sha256s(out_dir: Path) -> dict[str, str]:
    return {rel: sha256_file(out_dir / rel) for rel in LABEL_TEMPLATE_ARTIFACTS}


def label_template_schema_sha256s(root: Path) -> dict[str, str]:
    return {
        rel: sha256_file(root / "schemas" / filename)
        for rel, filename in LABEL_TEMPLATE_SCHEMA_FILES.items()
    }


def write_sha_manifest(out_dir: Path, rels: list[str]) -> None:
    lines = []
    seen: set[str] = set()
    for rel in rels:
        rel_path = Path(rel)
        if rel_path.is_absolute() or ".." in rel_path.parts or rel in seen:
            raise ValueError(f"invalid label-template sha manifest path: {rel}")
        seen.add(rel)
        lines.append(f"{sha256_hex(out_dir / rel)}  {rel}")
    (out_dir / "label_template_sha256sums.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_template_dir(
    root: Path,
    out_dir: Path,
    audit_output: Path,
    *,
    case_id: str,
    allow_source_drift: bool,
) -> None:
    verify_audit_output(root, audit_output, allow_source_drift=allow_source_drift)
    audit_manifest = read_json(audit_output / "audit_manifest.json")
    source_snapshot = read_json(audit_output / "source_snapshot.json")
    semantic_summary = read_json(audit_output / "audit_semantic_summary.json")
    rows = build_template_rows(audit_output, case_id)
    write_csv(out_dir / "label_template.csv", rows)
    (out_dir / "label_template.jsonl").write_text(
        "".join(json.dumps(row, sort_keys=True) + "\n" for row in rows),
        encoding="utf-8",
    )
    write_json(out_dir / "label_template.json", template_payload(rows))
    manifest = {
        "schema_version": MANIFEST_SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "claim_boundary": CLAIM_BOUNDARY,
        "label_template_source_sha256": sha256_file(root / "scripts" / "audit_my_repo_label_template.py"),
        "local_audit_verifier_source_sha256": sha256_file(root / "tools" / "verify_local_audit.py"),
        "schema_sha256s": label_template_schema_sha256s(root),
        "input_audit_output": str(audit_output),
        "input_audit_output_sha256": audit_output_sha256(audit_output),
        "input_audit_manifest_sha256": sha256_file(audit_output / "audit_manifest.json"),
        "input_audit_cache_key": str(audit_manifest.get("cache_key", "")),
        "input_audit_namespace": str(audit_manifest.get("namespace", "")),
        "input_audit_real_benchmark_namespace_confirmed": int(
            audit_manifest.get("real_benchmark_namespace_confirmed", 0)
        ),
        "input_audit_semantic_result_sha256": str(semantic_summary.get("semantic_result_sha256", "")),
        "input_repo_git_available": int(source_snapshot.get("git_available", 0)),
        "input_repo_git_head": str(source_snapshot.get("git_head", "")),
        "input_repo_git_dirty": int(source_snapshot.get("git_dirty", 0)),
        "case_id": case_id,
        "template_only": 1,
        "human_label_rows": 0,
        "candidate_label_rows": len(rows),
        "artifact_sha256s": artifact_sha256s(out_dir),
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "design_partner_beta_candidate_ready": 0,
    }
    write_json(out_dir / "label_template_manifest.json", manifest)
    write_sha_manifest(out_dir, ["label_template_manifest.json", *LABEL_TEMPLATE_ARTIFACTS])


def read_sha_manifest(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        if "  " not in line:
            raise ValueError("invalid label template sha manifest line")
        digest, rel = line.split("  ", 1)
        rel_path = Path(rel)
        if rel_path.is_absolute() or ".." in rel_path.parts or rel in entries:
            raise ValueError(f"invalid label template sha manifest path: {rel}")
        entries[rel] = digest
    return entries


def csv_rows_match_json(csv_rows: list[dict[str, str]], json_rows: list[dict]) -> bool:
    normalized_json_rows = [{field: str(row.get(field, "")) for field in LABEL_TEMPLATE_FIELDS} for row in json_rows]
    return csv_rows == normalized_json_rows


def verify_template_dir(
    out_dir: Path,
    *,
    allow_source_drift: bool = False,
    enforce_env_path_guard: bool = True,
) -> list[str]:
    errors: list[str] = []
    root = root_dir()
    if enforce_env_path_guard and is_forbidden_env_path(out_dir):
        return ["refusing .env-like label template path"]
    for rel in [*LABEL_TEMPLATE_ARTIFACTS, "label_template_manifest.json", "label_template_sha256sums.txt"]:
        if not (out_dir / rel).is_file():
            errors.append(f"missing label template artifact: {rel}")
    if errors:
        return errors
    for child in out_dir.iterdir():
        if child.name not in MANAGED_TOP_LEVEL:
            errors.append(f"unexpected label template output entry: {child.name}")
    for schema_rel, instance in [
        ("schemas/local_repo_audit_label_template.schema.json", out_dir / "label_template.json"),
        ("schemas/local_repo_audit_label_template_manifest.schema.json", out_dir / "label_template_manifest.json"),
    ]:
        ok, detail = validate_json_schema(root, schema_rel, instance)
        if not ok:
            errors.append(f"schema validation failed for {instance.name}{': ' + detail if detail else ''}")
    try:
        payload = read_json(out_dir / "label_template.json")
        manifest = read_json(out_dir / "label_template_manifest.json")
        sha_entries = read_sha_manifest(out_dir / "label_template_sha256sums.txt")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as exc:
        return [*errors, f"label template parse error: {exc}"]

    expected_sha_paths = {"label_template_manifest.json", *LABEL_TEMPLATE_ARTIFACTS}
    if set(sha_entries) != expected_sha_paths:
        errors.append("label template sha manifest must bind exactly the managed artifacts")
    for rel, digest in sha_entries.items():
        if sha256_hex(out_dir / rel) != digest:
            errors.append(f"label template sha drift: {rel}")
    manifest_artifacts = manifest.get("artifact_sha256s", {})
    if set(manifest_artifacts) != set(LABEL_TEMPLATE_ARTIFACTS):
        errors.append("label template manifest artifact_sha256s mismatch")
    for rel in LABEL_TEMPLATE_ARTIFACTS:
        if manifest_artifacts.get(rel) != sha256_file(out_dir / rel):
            errors.append(f"label template manifest artifact sha drift: {rel}")
    if manifest.get("label_template_source_sha256") != sha256_file(root / "scripts" / "audit_my_repo_label_template.py"):
        errors.append("label template manifest source sha drift")
    if manifest.get("local_audit_verifier_source_sha256") != sha256_file(root / "tools" / "verify_local_audit.py"):
        errors.append("label template manifest verifier sha drift")
    if manifest.get("schema_sha256s") != label_template_schema_sha256s(root):
        errors.append("label template manifest schema sha drift")

    rows = payload.get("rows", [])
    if not isinstance(rows, list):
        rows = []
        errors.append("label_template.json rows must be a list")
    csv_rows = read_csv_rows(out_dir / "label_template.csv")
    jsonl_rows = [json.loads(line) for line in (out_dir / "label_template.jsonl").read_text(encoding="utf-8").splitlines() if line.strip()]
    if not csv_rows_match_json(csv_rows, rows):
        errors.append("label_template.csv must match label_template.json rows")
    if not csv_rows_match_json(csv_rows, jsonl_rows):
        errors.append("label_template.jsonl must match label_template.csv rows")
    if payload.get("candidate_label_rows") != len(rows) or manifest.get("candidate_label_rows") != len(rows):
        errors.append("candidate_label_rows must match row count")
    if payload.get("human_label_rows") != 0 or manifest.get("human_label_rows") != 0:
        errors.append("label template must not claim human label rows")
    if any(str(row.get("case_id", "")) != str(manifest.get("case_id", "")) for row in csv_rows):
        errors.append("label template rows must match manifest case_id")
    for blocked_key in [
        "release_ready",
        "public_comparison_claim_ready",
        "real_model_execution_ready",
        "design_partner_beta_candidate_ready",
    ]:
        if payload.get(blocked_key) != 0 or manifest.get(blocked_key) != 0:
            errors.append(f"label template must keep {blocked_key}=0")
    for row in csv_rows:
        if row.get("template_only") != "1" or row.get("human_labeled") != "0":
            errors.append("label template rows must stay template-only and unlabeled")
        for blocked_key in [
            "release_ready",
            "public_comparison_claim_ready",
            "real_model_execution_ready",
            "design_partner_beta_candidate_ready",
        ]:
            if row.get(blocked_key) != "0":
                errors.append(f"label template row must keep {blocked_key}=0")
        if not row.get("case_id") or not row.get("candidate_label_id") or not row.get("source_finding_id"):
            errors.append("label template rows must bind case, candidate, and source finding ids")
        if not row.get("source_review_queue_id"):
            errors.append("label template rows must bind source review queue ids")

    audit_output = Path(str(manifest.get("input_audit_output", ""))).expanduser()
    if not audit_output.is_absolute():
        errors.append("label template manifest input_audit_output must be absolute")
    elif not audit_output.is_dir():
        errors.append("label template input_audit_output is missing")
    else:
        try:
            verify_audit_output(root, audit_output, allow_source_drift=allow_source_drift)
            audit_manifest = read_json(audit_output / "audit_manifest.json")
            source_snapshot = read_json(audit_output / "source_snapshot.json")
            semantic_summary = read_json(audit_output / "audit_semantic_summary.json")
            if manifest.get("input_audit_output_sha256") != audit_output_sha256(audit_output):
                errors.append("label template manifest input audit output sha drift")
            if manifest.get("input_audit_manifest_sha256") != sha256_file(audit_output / "audit_manifest.json"):
                errors.append("label template manifest audit_manifest sha drift")
            if manifest.get("input_audit_cache_key") != str(audit_manifest.get("cache_key", "")):
                errors.append("label template manifest input audit cache key drift")
            if manifest.get("input_audit_namespace") != str(audit_manifest.get("namespace", "")):
                errors.append("label template manifest input audit namespace drift")
            if manifest.get("input_audit_real_benchmark_namespace_confirmed") != int(
                audit_manifest.get("real_benchmark_namespace_confirmed", 0)
            ):
                errors.append("label template manifest real benchmark confirmation drift")
            if manifest.get("input_audit_semantic_result_sha256") != str(semantic_summary.get("semantic_result_sha256", "")):
                errors.append("label template manifest semantic result sha drift")
            if manifest.get("input_repo_git_available") != int(source_snapshot.get("git_available", 0)):
                errors.append("label template manifest git_available drift")
            if manifest.get("input_repo_git_head") != str(source_snapshot.get("git_head", "")):
                errors.append("label template manifest git_head drift")
            if manifest.get("input_repo_git_dirty") != int(source_snapshot.get("git_dirty", 0)):
                errors.append("label template manifest git_dirty drift")
            expected_rows = build_template_rows(audit_output, str(manifest.get("case_id", "")))
            if csv_rows != expected_rows:
                errors.append("label template rows drift from input audit output")
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
        raise ValueError(f"label template output path is not a directory: {out_dir}")
    children = list(out_dir.iterdir())
    if not children:
        return None
    if not overwrite:
        raise ValueError("label template output directory already contains artifacts; use a fresh --out or pass --overwrite")
    for child in children:
        if child.name not in MANAGED_TOP_LEVEL:
            raise ValueError(f"refusing to delete unrelated label template output entry: {child.name}; use a fresh --out")
    backup_dir = Path(tempfile.mkdtemp(prefix=f".{out_dir.name}.label_template_backup.", dir=out_dir.parent))
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


def generate_template(args: argparse.Namespace) -> None:
    root = root_dir()
    audit_output = Path(args.audit_output).expanduser().resolve()
    out_dir = Path(args.out).expanduser().resolve()
    verify_audit_output(root, audit_output, allow_source_drift=args.allow_source_drift)
    audit_manifest = read_json(audit_output / "audit_manifest.json")
    case_id = normalize_case_id(args.case_id, audit_manifest)
    backup_dir: Path | None = None
    prepared_output = False
    out_dir.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=f".{out_dir.name}.label_template_staging.", dir=out_dir.parent))
    try:
        backup_dir = prepare_output_dir(out_dir, args.overwrite)
        prepared_output = True
        write_template_dir(root, staging, audit_output, case_id=case_id, allow_source_drift=args.allow_source_drift)
        if os.environ.get("AUDIT_MY_REPO_LABEL_TEMPLATE_TAMPER_BEFORE_VERIFY") == "1":
            payload = read_json(staging / "label_template.json")
            payload["release_ready"] = 1
            write_json(staging / "label_template.json", payload)
        errors = verify_template_dir(
            staging,
            allow_source_drift=args.allow_source_drift,
            enforce_env_path_guard=False,
        )
        if errors:
            raise RuntimeError("; ".join(errors))
        if out_dir.exists():
            out_dir.rmdir()
        os.replace(staging, out_dir)
        errors = verify_template_dir(out_dir, allow_source_drift=args.allow_source_drift)
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
    parser = argparse.ArgumentParser(description="Create or verify local audit human label templates.")
    parser.add_argument("--audit-output", help="Verified audit output directory to convert into a label template.")
    parser.add_argument("--out", help="Output directory for the label template bundle.")
    parser.add_argument("--case-id", default="", help="Safe case id to stamp into candidate label rows.")
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing managed label template output.")
    parser.add_argument(
        "--allow-source-drift",
        action="store_true",
        help="Verify a historical audit bundle without comparing source spans to the current target worktree.",
    )
    parser.add_argument("--verify-existing", help="Verify an existing label template output directory.")
    args = parser.parse_args(argv)
    try:
        if args.verify_existing:
            raw_verify_path = Path(args.verify_existing).expanduser()
            if is_forbidden_env_path(raw_verify_path):
                raise ValueError("refusing .env-like label template path")
            errors = verify_template_dir(raw_verify_path.resolve(), allow_source_drift=args.allow_source_drift)
            if errors:
                for error in errors:
                    print(error, file=sys.stderr)
                return 1
            print("label_template_verify: ok")
            return 0
        if not args.audit_output or not args.out:
            raise ValueError("--audit-output and --out are required unless --verify-existing is used")
        generate_template(args)
        print(f"label_template: wrote {Path(args.out).expanduser().resolve()}")
        return 0
    except (ValueError, FileNotFoundError, NotADirectoryError) as exc:
        print(f"label_template_input_error: {exc}", file=sys.stderr)
        return 2
    except (
        OSError,
        UnicodeDecodeError,
        json.JSONDecodeError,
        csv.Error,
        subprocess.SubprocessError,
        RuntimeError,
    ) as exc:
        print(f"label_template_verify_error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
