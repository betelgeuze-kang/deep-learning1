#!/usr/bin/env python3
from __future__ import annotations

import argparse
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
PACKAGE_SCHEMA_VERSION = "local_repo_audit_package_manifest.v1"
CLAIM_BOUNDARY = "alpha-local-code-doc-audit-only"
DETERMINISTIC_GENERATED_AT_UTC = "1970-01-01T00:00:00+00:00"
CHANGELOG_REL = "CHANGELOG.audit-my-repo.md"
MANIFEST_REL = "package_manifest.json"
SHA_MANIFEST_REL = "package_sha256s.txt"
PACKAGE_ARTIFACTS = (MANIFEST_REL, CHANGELOG_REL)
PACKAGE_MANAGED_ARTIFACTS = (*PACKAGE_ARTIFACTS, SHA_MANIFEST_REL)
STALE_PACKAGE_ARTIFACT_RE = re.compile(
    r"^(?:package_manifest|package_sha256s|CHANGELOG\.audit-my-repo)(?:[._-].+|~|\.bak)$"
)
REQUIRED_PRODUCT_FILES = (
    "scripts/audit_my_repo.py",
    "scripts/audit_my_repo.sh",
    "scripts/audit_my_repo_pr.sh",
    "scripts/audit_my_repo_benchmark.py",
    "scripts/audit_my_repo_first_report_smoke.py",
    "scripts/audit_my_repo_label_intake.py",
    "scripts/audit_my_repo_label_template.py",
    "scripts/audit_my_repo_package.py",
    "scripts/auditor_plugin_config_consistency.py",
    "scripts/auditor_plugin_deprecated_api.py",
    "scripts/auditor_plugin_doc_code_identity.py",
    "scripts/auditor_plugin_missing_evidence.py",
    "scripts/auditor_plugin_unsupported_claim.py",
    "scripts/auditor_plugin_user_question.py",
    "scripts/auditor_plugins.py",
    "tools/validate_json_schemas.py",
    "tools/verify_local_audit.py",
    "experiments/test_audit_my_repo_negative_controls.sh",
    "experiments/test_audit_my_repo_product_entrypoint.sh",
)
OPTIONAL_PRODUCT_FILES = (
    "docs/AUDIT_MY_REPO_ALPHA.md",
)


class PackageVerificationError(ValueError):
    pass


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


def changelog_text() -> str:
    return """# audit-my-repo alpha changelog

## audit_my_repo_alpha.v1 - 1970-01-01

### Added
- Local deterministic audit bundles with source-bound file, line, and sha256 citations.
- Abstention rows, manual-review queues, standard JSON findings, SARIF output, baseline diffs, deterministic JSON/HTML dashboards, diagnostics opt-in, and local benchmark outputs.
- Local PR/diff wrapper that writes a stable changed-files input for reproducible changed-file scoped audits without network fetches.
- First-report smoke runner that verifies install, run, report, and artifact verification inside the ten-minute alpha budget.
- Human-label template generator that turns a verified audit bundle into template-only candidate rows for design-partner review.
- Human-label intake compiler that turns explicit human decisions into benchmark-ready label rows without promoting template-only rows.
- Explicit confirmation gate for real-benchmark evaluation namespaces so fixture/synthetic runs cannot opt into readiness calculation by name alone.
- Split quick/full execution modes and split resource budgets for files, total bytes, file bytes, and findings.
- Local alpha package manifest generation with source sha256 binding and changelog verification.

### Boundaries
- No release readiness, public comparison readiness, real model execution, package upload, network download, GPU run, checkpoint download, or automatic accuracy claim is made.
- Design-partner beta candidacy remains blocked until real local repositories, human labels, citation validation, rerun checks, and maintainer feedback satisfy the benchmark gate.

### Verify
- ./scripts/audit_my_repo_package.py --verify-existing <package-dir>
- ./scripts/ai-verify.sh
"""


def source_sha256s(root: Path) -> dict[str, str]:
    rows: dict[str, str] = {}
    for rel in REQUIRED_PRODUCT_FILES:
        path = root / rel
        if not path.is_file():
            raise ValueError(f"missing required product source file: {rel}")
        rows[rel] = sha256_file(path)
    for rel in OPTIONAL_PRODUCT_FILES:
        path = root / rel
        if path.is_file():
            rows[rel] = sha256_file(path)
    return dict(sorted(rows.items()))


def schema_sha256s(root: Path) -> dict[str, str]:
    schemas = sorted(path for path in (root / "schemas").glob("local_repo_audit_*.schema.json") if path.is_file())
    if not schemas:
        raise ValueError("missing local_repo_audit schemas")
    return {str(path.relative_to(root)): sha256_file(path) for path in schemas}


def build_manifest(root: Path) -> dict:
    source_rows = source_sha256s(root)
    schema_rows = schema_sha256s(root)
    return {
        "schema_version": PACKAGE_SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "package_version": TOOL_VERSION,
        "claim_boundary": CLAIM_BOUNDARY,
        "generated_at_utc": DETERMINISTIC_GENERATED_AT_UTC,
        "package_kind": "local-alpha-reproducibility-package",
        "version_pinned": 1,
        "network_download_used": 0,
        "package_upload_performed": 0,
        "real_release_package_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "design_partner_beta_candidate_ready": 0,
        "source_file_count": len(source_rows),
        "schema_file_count": len(schema_rows),
        "changelog_path": CHANGELOG_REL,
        "changelog_sha256": sha256_text(changelog_text()),
        "source_sha256s": source_rows,
        "schema_sha256s": schema_rows,
        "entrypoints": [
            {
                "command": "./scripts/audit_my_repo.sh --version",
                "purpose": "print the pinned alpha tool version",
            },
            {
                "command": "./scripts/audit_my_repo.sh /path/to/repo --mode quick --out results/my_repo_audit",
                "purpose": "run the quick local audit mode",
            },
            {
                "command": "./scripts/audit_my_repo.sh --verify-existing results/my_repo_audit",
                "purpose": "verify a published audit bundle",
            },
            {
                "command": "./scripts/audit_my_repo_pr.sh /path/to/repo --base-ref main --head-ref HEAD --mode quick --out results/my_repo_audit_pr",
                "purpose": "run a local PR/diff scoped audit without network fetches",
            },
            {
                "command": "./scripts/audit_my_repo_benchmark.py --labels labels.jsonl --out results/audit_benchmark --mode full",
                "purpose": "evaluate user-provided local repositories with labels",
            },
            {
                "command": "./scripts/audit_my_repo_label_template.py --audit-output results/my_repo_audit --out results/my_repo_label_template --case-id my_repo",
                "purpose": "create template-only candidate rows for human labeling from a verified audit bundle",
            },
            {
                "command": "./scripts/audit_my_repo_label_intake.py --template results/my_repo_label_template --decisions decisions.jsonl --out results/my_repo_label_intake",
                "purpose": "compile explicit human decisions into benchmark_labels.jsonl for the local benchmark harness",
            },
            {
                "command": "./scripts/audit_my_repo_benchmark.py --label-intake results/my_repo_label_intake --out results/audit_benchmark --mode full",
                "purpose": "evaluate a verified human-label intake bundle with provenance-bound labels",
            },
            {
                "command": "./scripts/audit_my_repo_package.py --out results/audit_package",
                "purpose": "write this local alpha package manifest and changelog",
            },
            {
                "command": "./scripts/audit_my_repo_first_report_smoke.py --out results/audit_first_report_smoke",
                "purpose": "verify that a first-time local user can get a verified report within the alpha time budget",
            },
            {
                "command": "./scripts/audit_my_repo_first_report_smoke.py --verify-existing results/audit_first_report_smoke",
                "purpose": "re-verify the first-report smoke receipt and its audit output",
            },
        ],
        "verification_commands": [
            {
                "command": "python3 -m py_compile scripts/audit_my_repo.py tools/verify_local_audit.py scripts/audit_my_repo_benchmark.py scripts/audit_my_repo_first_report_smoke.py scripts/audit_my_repo_label_intake.py scripts/audit_my_repo_label_template.py scripts/audit_my_repo_package.py && bash -n scripts/audit_my_repo.sh scripts/audit_my_repo_pr.sh",
                "purpose": "check install-time Python and shell syntax for the local audit product",
            },
            {
                "command": "./scripts/audit_my_repo_package.py --verify-existing results/audit_package",
                "purpose": "verify package manifest, source hashes, changelog, and artifact hashes",
            },
            {
                "command": "./scripts/ai-verify.sh",
                "purpose": "run repository verification including audit product tests",
            },
        ],
    }


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_sha_manifest(out_dir: Path) -> None:
    rows = [f"{sha256_hex(out_dir / rel)}  {rel}" for rel in PACKAGE_ARTIFACTS]
    (out_dir / SHA_MANIFEST_REL).write_text("\n".join(rows) + "\n", encoding="utf-8")


def read_sha_manifest(path: Path) -> dict[str, str]:
    rows: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        parts = line.split(None, 1)
        if len(parts) != 2:
            raise ValueError("package_sha256s.txt has an invalid row")
        digest, rel = parts
        rel = rel.strip()
        rel_path = Path(rel)
        if not re.fullmatch(r"[0-9a-f]{64}", digest):
            raise ValueError(f"package sha row has invalid digest: {rel}")
        if rel in rows or rel_path.is_absolute() or ".." in rel_path.parts:
            raise ValueError(f"package sha row has invalid path: {rel}")
        rows[rel] = digest
    return rows


def verify_schema_instance(root: Path, out_dir: Path, errors: list[str]) -> None:
    validator = root / "tools" / "validate_json_schemas.py"
    result = subprocess.run(
        [
            sys.executable,
            str(validator),
            "--schema-instance",
            str(root / "schemas" / "local_repo_audit_package_manifest.schema.json"),
            str(out_dir / MANIFEST_REL),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        errors.append(f"package schema validation failed: {MANIFEST_REL}{suffix}")


def verify_package_artifact_layout(out_dir: Path, errors: list[str]) -> None:
    if not out_dir.exists():
        return
    if not out_dir.is_dir():
        errors.append(f"package output path is not a directory: {out_dir}")
        return
    for path in out_dir.iterdir():
        name = path.name
        if name in PACKAGE_MANAGED_ARTIFACTS:
            continue
        if name.startswith(".package_staging.") or name.startswith(".package_backup.") or STALE_PACKAGE_ARTIFACT_RE.fullmatch(name):
            errors.append(f"stale package artifact outside package manifest: {name}")


def remove_path(path: Path) -> None:
    if path.is_symlink() or path.is_file():
        path.unlink()
    elif path.is_dir():
        shutil.rmtree(path)


def package_publish_fail_after_count() -> int:
    raw = os.environ.get("AUDIT_MY_REPO_PACKAGE_FAIL_AFTER_PUBLISH_COUNT", "")
    if not raw:
        return 0
    try:
        return max(0, int(raw))
    except ValueError:
        return 0


def restore_package_artifacts(out_dir: Path, backup_dir: Path) -> None:
    for rel in PACKAGE_MANAGED_ARTIFACTS:
        target = out_dir / rel
        if target.exists() or target.is_symlink():
            remove_path(target)
    for rel in PACKAGE_MANAGED_ARTIFACTS:
        backup = backup_dir / rel
        if backup.exists() or backup.is_symlink():
            os.replace(backup, out_dir / rel)


def publish_package_artifacts(staging_dir: Path, out_dir: Path) -> Path:
    backup_dir = Path(tempfile.mkdtemp(prefix=f".{out_dir.name}.package_backup.", dir=out_dir.parent))
    published_count = 0
    fail_after_count = package_publish_fail_after_count()
    try:
        for rel in PACKAGE_MANAGED_ARTIFACTS:
            target = out_dir / rel
            if target.exists() or target.is_symlink():
                os.replace(target, backup_dir / rel)
        for rel in PACKAGE_MANAGED_ARTIFACTS:
            os.replace(staging_dir / rel, out_dir / rel)
            published_count += 1
            if fail_after_count and published_count >= fail_after_count:
                raise OSError("simulated package publish failure")
    except Exception:
        restore_package_artifacts(out_dir, backup_dir)
        shutil.rmtree(backup_dir, ignore_errors=True)
        raise
    return backup_dir


def write_package(root: Path, out_dir: Path, overwrite: bool) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    layout_errors: list[str] = []
    verify_package_artifact_layout(out_dir, layout_errors)
    if layout_errors:
        raise ValueError("; ".join(layout_errors))
    managed_paths = [out_dir / rel for rel in PACKAGE_MANAGED_ARTIFACTS]
    existing_managed = [path for path in managed_paths if path.exists() or path.is_symlink()]
    if existing_managed and not overwrite:
        raise ValueError("package artifacts already exist; pass --overwrite to replace package files")
    for path in managed_paths:
        if path.exists() and path.is_dir():
            raise ValueError(f"package artifact path is a directory: {path.name}")
    staging_dir = Path(tempfile.mkdtemp(prefix=".package_staging.", dir=out_dir))
    backup_dir: Path | None = None
    try:
        changelog = changelog_text()
        (staging_dir / CHANGELOG_REL).write_text(changelog, encoding="utf-8")
        write_json(staging_dir / MANIFEST_REL, build_manifest(root))
        write_sha_manifest(staging_dir)
        if os.environ.get("AUDIT_MY_REPO_PACKAGE_TAMPER_BEFORE_VERIFY") == "1":
            payload = json.loads((staging_dir / MANIFEST_REL).read_text(encoding="utf-8"))
            payload["release_ready"] = 1
            write_json(staging_dir / MANIFEST_REL, payload)
            write_sha_manifest(staging_dir)
        staging_errors = verify_package(root, staging_dir)
        if staging_errors:
            raise PackageVerificationError(
                "written package failed self-verification: " + "; ".join(staging_errors[:3])
            )
        backup_dir = publish_package_artifacts(staging_dir, out_dir)
        shutil.rmtree(staging_dir, ignore_errors=True)
        if os.environ.get("AUDIT_MY_REPO_PACKAGE_TAMPER_AFTER_PUBLISH_BEFORE_VERIFY") == "1":
            payload = json.loads((out_dir / MANIFEST_REL).read_text(encoding="utf-8"))
            payload["release_ready"] = 1
            write_json(out_dir / MANIFEST_REL, payload)
            write_sha_manifest(out_dir)
        final_errors = verify_package(root, out_dir)
        if final_errors:
            restore_package_artifacts(out_dir, backup_dir)
            raise PackageVerificationError(
                "published package failed self-verification: " + "; ".join(final_errors[:3])
            )
        shutil.rmtree(backup_dir, ignore_errors=True)
        backup_dir = None
    finally:
        shutil.rmtree(staging_dir, ignore_errors=True)
        if backup_dir is not None:
            shutil.rmtree(backup_dir, ignore_errors=True)


def verify_package(root: Path, out_dir: Path) -> list[str]:
    errors: list[str] = []

    def add(message: str) -> None:
        errors.append(message)

    manifest_path = out_dir / MANIFEST_REL
    changelog_path = out_dir / CHANGELOG_REL
    sha_manifest_path = out_dir / SHA_MANIFEST_REL
    verify_package_artifact_layout(out_dir, errors)
    for rel in PACKAGE_MANAGED_ARTIFACTS:
        path = out_dir / rel
        if path.is_symlink():
            add(f"package artifact must not be a symlink: {rel}")
        elif not path.is_file():
            add(f"missing package artifact: {rel}")
    if errors:
        return errors
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        sha_rows = read_sha_manifest(sha_manifest_path)
        expected_manifest = build_manifest(root)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        return [str(exc)]
    verify_schema_instance(root, out_dir, errors)
    if set(manifest) != set(expected_manifest):
        add("package_manifest.json key set drift")
    for key, expected in expected_manifest.items():
        if manifest.get(key) != expected:
            add(f"package_manifest.{key} mismatch")
    for key in [
        "version_pinned",
        "network_download_used",
        "package_upload_performed",
        "real_release_package_ready",
        "release_ready",
        "public_comparison_claim_ready",
        "real_model_execution_ready",
        "design_partner_beta_candidate_ready",
    ]:
        if manifest.get(key) != expected_manifest[key]:
            add(f"package_manifest readiness/boundary drift: {key}")
    if changelog_path.read_text(encoding="utf-8") != changelog_text():
        add("CHANGELOG.audit-my-repo.md content drift")
    if manifest.get("changelog_sha256") != sha256_file(changelog_path):
        add("package manifest changelog sha mismatch")
    if set(sha_rows) != set(PACKAGE_ARTIFACTS):
        add("package_sha256s.txt artifact set drift")
    for rel, digest in sha_rows.items():
        path = out_dir / rel
        if not path.is_file():
            add(f"package sha manifest references missing artifact: {rel}")
        elif digest != sha256_hex(path):
            add(f"package sha manifest digest mismatch: {rel}")
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Write or verify a local audit-my-repo alpha package manifest.")
    parser.add_argument("--version", action="store_true", help="Print the pinned audit-my-repo tool version and exit.")
    parser.add_argument("--out", default="", help="Output directory for the local package manifest and changelog.")
    parser.add_argument("--verify-existing", default="", help="Verify an existing local package output directory and exit.")
    parser.add_argument("--overwrite", action="store_true", help="Replace existing package artifacts without deleting unrelated files.")
    args = parser.parse_args(argv)

    if args.version:
        print(TOOL_VERSION)
        return 0

    root = Path(__file__).resolve().parents[1]
    if args.verify_existing:
        errors = verify_package(root, Path(args.verify_existing).expanduser().resolve())
        if errors:
            for error in errors:
                print(f"package_verify_error: {error}", file=sys.stderr)
            return 1
        print("package_verify: ok")
        return 0
    if not args.out:
        print("--out is required unless --version or --verify-existing is used", file=sys.stderr)
        return 2
    try:
        write_package(root, Path(args.out).expanduser().resolve(), args.overwrite)
    except PackageVerificationError as exc:
        print(f"package_verify_error: {exc}", file=sys.stderr)
        return 1
    except (OSError, ValueError) as exc:
        print(f"package_error: {exc}", file=sys.stderr)
        return 2
    print("package_write: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
