#!/usr/bin/env python3
"""Prepare combined AMR beta benchmark inputs without running the benchmark.

This helper concatenates verified per-repo label-intake outputs into one
combined `benchmark_labels.jsonl` candidate input and writes a preflight summary.
It does not run `audit_my_repo_benchmark.py`, does not create benchmark
evidence, and does not promote readiness.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

MIN_REAL_REPOS_FOR_BETA = 10
MIN_HUMAN_LABELS_FOR_BETA = 300
TOOL_SCHEMA = "amr_beta_benchmark_input_prepare.v1"
BLOCKED_KEYS = [
    "release_ready",
    "public_comparison_claim_ready",
    "real_model_execution_ready",
    "design_partner_beta_candidate_ready",
]
PLACEHOLDER_RE = re.compile(r"(^$|example|placeholder|replace|todo)", re.IGNORECASE)
SAFE_ID_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,191}$")
GIT_OBJECT_RE = re.compile(r"^[0-9a-f]{40}$|^[0-9a-f]{64}$")
SHA_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def truthy(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def good_operator_value(value: object) -> bool:
    return not PLACEHOLDER_RE.search(str(value or "").strip())


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


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


def read_sha_manifest(path: Path) -> dict[str, str]:
    entries: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        if "  " not in line:
            raise ValueError(f"invalid sha manifest line in {path}")
        digest, rel = line.split("  ", 1)
        rel_path = Path(rel)
        if rel_path.is_absolute() or ".." in rel_path.parts or rel in entries:
            raise ValueError(f"invalid sha manifest path: {rel}")
        entries[rel] = digest
    return entries


def write_jsonl(path: Path, rows: list[dict]) -> None:
    path.write_text("".join(json.dumps(row, sort_keys=True) + "\n" for row in rows), encoding="utf-8")


def validate_label_row(row: dict, *, row_label: str, allow_synthetic: bool) -> list[str]:
    errors: list[str] = []
    case_id = str(row.get("case_id") or "").strip()
    label_id = str(row.get("label_id") or "").strip()
    repo_path = str(row.get("repo_path") or "").strip()
    expected_repo_git_head = str(row.get("expected_repo_git_head") or "").strip().lower()
    if not case_id or not SAFE_ID_RE.fullmatch(case_id) or not good_operator_value(case_id):
        errors.append(f"{row_label}: case_id must be safe and non-placeholder")
    if not label_id or not SAFE_ID_RE.fullmatch(label_id) or not good_operator_value(label_id):
        errors.append(f"{row_label}: label_id must be safe and non-placeholder")
    if not truthy(row.get("human_labeled", False)):
        errors.append(f"{row_label}: human_labeled must be true")
    if truthy(row.get("template_only", False)):
        errors.append(f"{row_label}: template_only must be false/absent")
    if truthy(row.get("synthetic", False)) and not allow_synthetic:
        errors.append(f"{row_label}: synthetic labels cannot feed AMR beta benchmark input")
    if row.get("expected") not in {"present", "absent"}:
        errors.append(f"{row_label}: expected must be present or absent")
    if not repo_path:
        errors.append(f"{row_label}: repo_path is required")
    elif not Path(repo_path).expanduser().is_absolute():
        errors.append(f"{row_label}: repo_path must be absolute")
    elif not Path(repo_path).expanduser().is_dir():
        errors.append(f"{row_label}: repo_path must exist as a directory")
    if not expected_repo_git_head:
        errors.append(f"{row_label}: expected_repo_git_head is required")
    elif not GIT_OBJECT_RE.fullmatch(expected_repo_git_head):
        errors.append(f"{row_label}: expected_repo_git_head must be a git object id")
    span = str(row.get("expected_span_sha256") or "").strip()
    if span and not SHA_RE.fullmatch(span):
        errors.append(f"{row_label}: expected_span_sha256 must be sha256:<64 hex>")
    if not str(row.get("source_candidate_label_id") or "").strip():
        errors.append(f"{row_label}: source_candidate_label_id is required")
    if not str(row.get("source_review_queue_id") or "").strip():
        errors.append(f"{row_label}: source_review_queue_id is required")
    return errors


def load_label_intake_dir(path: Path, *, allow_synthetic: bool) -> tuple[list[dict], list[str], dict]:
    errors: list[str] = []
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like label intake path")
    labels_path = path / "benchmark_labels.jsonl"
    manifest_path = path / "label_intake_manifest.json"
    sha_path = path / "label_intake_sha256sums.txt"
    for required in [labels_path, manifest_path, sha_path]:
        if not required.is_file():
            raise ValueError(f"label intake dir missing {required.name}: {path}")
    manifest = read_json(manifest_path)
    sha_entries = read_sha_manifest(sha_path)
    expected_sha_paths = {"label_intake_manifest.json", "benchmark_labels.jsonl"}
    if set(sha_entries) != expected_sha_paths:
        errors.append(f"{path}: label_intake_sha256sums.txt must bind exactly managed artifacts")
    for rel, digest in sha_entries.items():
        if sha256_file(path / rel) != f"sha256:{digest}" and sha256_file(path / rel) != digest:
            errors.append(f"{path}: sha drift for {rel}")
    artifact_sha = manifest.get("artifact_sha256s", {})
    if artifact_sha.get("benchmark_labels.jsonl") != sha256_file(labels_path):
        errors.append(f"{path}: manifest artifact sha drift for benchmark_labels.jsonl")
    for key in BLOCKED_KEYS:
        if manifest.get(key) != 0:
            errors.append(f"{path}: label intake manifest must keep {key}=0")
    rows = read_jsonl(labels_path, "benchmark labels")
    if manifest.get("human_label_rows") != len(rows) or manifest.get("label_rows") != len(rows):
        errors.append(f"{path}: manifest label row counts must match benchmark_labels.jsonl")
    if not allow_synthetic and int(manifest.get("synthetic_label_rows", 0)) != 0:
        errors.append(f"{path}: synthetic_label_rows must be 0 for AMR beta benchmark input")
    for index, row in enumerate(rows, start=1):
        errors.extend(validate_label_row(row, row_label=f"{path} row {index}", allow_synthetic=allow_synthetic))
    return rows, errors, manifest


def prepare_outputs(out_labels: Path, summary_path: Path, rows: list[dict], summary: dict, overwrite: bool) -> None:
    for path in [out_labels, summary_path]:
        if is_forbidden_env_path(path):
            raise ValueError("refusing .env-like output path")
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.exists() and not overwrite:
            raise ValueError(f"output already exists; use --overwrite: {path}")
    write_jsonl(out_labels, rows)
    summary["combined_labels_sha256"] = sha256_file(out_labels)
    summary_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label-intake-dir", action="append", required=True, help="Per-repo label intake dir; repeatable.")
    parser.add_argument("--out-labels", required=True, help="Combined benchmark labels JSONL output path.")
    parser.add_argument("--summary", required=True, help="Preparation summary JSON output path.")
    parser.add_argument("--feedback", default="", help="Optional maintainer feedback file path to bind into the run command.")
    parser.add_argument("--min-cases", type=int, default=MIN_REAL_REPOS_FOR_BETA)
    parser.add_argument("--min-labels", type=int, default=MIN_HUMAN_LABELS_FOR_BETA)
    parser.add_argument("--allow-synthetic", action="store_true", help="Testing only: allow synthetic labels.")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    errors: list[str] = []
    rows: list[dict] = []
    manifests: list[dict] = []
    try:
        for raw_dir in args.label_intake_dir:
            loaded_rows, intake_errors, manifest = load_label_intake_dir(
                Path(raw_dir).expanduser().resolve(),
                allow_synthetic=args.allow_synthetic,
            )
            rows.extend(loaded_rows)
            errors.extend(intake_errors)
            manifests.append(manifest)
        seen_labels: set[tuple[str, str]] = set()
        for row in rows:
            key = (str(row.get("case_id")), str(row.get("label_id")))
            if key in seen_labels:
                errors.append(f"duplicate combined label row: {key[0]}:{key[1]}")
            seen_labels.add(key)
        case_ids = sorted({str(row.get("case_id")) for row in rows})
        repo_paths = sorted({str(row.get("repo_path")) for row in rows})
        if len(case_ids) < args.min_cases:
            errors.append(f"case_count {len(case_ids)} below required minimum {args.min_cases}")
        if len(rows) < args.min_labels:
            errors.append(f"human_label_rows {len(rows)} below required minimum {args.min_labels}")
        feedback = str(Path(args.feedback).expanduser().resolve()) if args.feedback else ""
        if feedback and is_forbidden_env_path(Path(feedback)):
            raise ValueError("refusing .env-like feedback path")
        if feedback and not Path(feedback).is_file():
            raise ValueError(f"feedback file is not a file: {feedback}")
        summary = {
            "schema": TOOL_SCHEMA,
            "label_intake_dir_count": len(args.label_intake_dir),
            "case_count": len(case_ids),
            "repo_count": len(repo_paths),
            "human_label_rows": len(rows),
            "synthetic_label_rows": sum(1 for row in rows if truthy(row.get("synthetic", False))),
            "input_manifest_sha256s": [
                sha256_file(Path(raw_dir).expanduser().resolve() / "label_intake_manifest.json")
                for raw_dir in args.label_intake_dir
            ],
            "feedback_input": feedback,
            "benchmark_command": (
                "python3 scripts/audit_my_repo_benchmark.py "
                f"--labels {Path(args.out_labels).expanduser().resolve()} "
                f"{'--feedback ' + feedback + ' ' if feedback else ''}"
                "--namespace real_benchmark --confirm-real-benchmark-namespace "
                "--mode full --out results/audit_benchmark"
            ),
            "ready_for_runtime_approved_real_benchmark": int(not errors),
            "design_partner_beta_candidate_ready": 0,
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
        }
        if errors:
            if args.json:
                print(json.dumps({**summary, "errors": errors}, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        prepare_outputs(
            Path(args.out_labels).expanduser().resolve(),
            Path(args.summary).expanduser().resolve(),
            rows,
            summary,
            args.overwrite,
        )
        if args.json:
            print(json.dumps({**summary, "errors": []}, indent=2, sort_keys=True))
        else:
            print(
                "benchmark_input_prepare: ok "
                f"case_count={summary['case_count']} human_label_rows={summary['human_label_rows']}"
            )
        return 0
    except Exception as exc:
        print(f"benchmark_input_prepare: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": TOOL_SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
