#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path


TOOL_VERSION = "audit_my_repo_alpha.v1"
SCHEMA_VERSION = "local_repo_audit_first_report_smoke.v1"
CLAIM_BOUNDARY = "alpha-local-code-doc-audit-only"
RECEIPT_REL = "first_report_smoke.json"
MANAGED_ENTRIES = ("fixture_repo", "audit_out", RECEIPT_REL)


def elapsed_ms(start_ns: int) -> int:
    return max(1, int(round((time.perf_counter_ns() - start_ns) / 1_000_000)))


def run_cmd(cmd: list[str], cwd: Path) -> tuple[int, int, str]:
    start_ns = time.perf_counter_ns()
    result = subprocess.run(cmd, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    detail = (result.stderr or result.stdout).strip().splitlines()
    return result.returncode, elapsed_ms(start_ns), detail[0] if result.returncode != 0 and detail else ""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def write_fixture_repo(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / "README.md").write_text(
        "# First Report Smoke\n\n"
        "This repository claims production readiness without evidence.\n",
        encoding="utf-8",
    )
    (path / "legacy.py").write_text(
        "import distutils\n\n"
        "def build():\n"
        "    return distutils.__name__\n",
        encoding="utf-8",
    )
    (path / "package.json").write_text(
        json.dumps({"name": "first-report-smoke", "version": "0.0.0"}, indent=2) + "\n",
        encoding="utf-8",
    )
    subprocess.run(["git", "init", "-q"], cwd=str(path), check=True)
    subprocess.run(["git", "add", "."], cwd=str(path), check=True)
    subprocess.run(
        ["git", "-c", "user.email=audit@example.invalid", "-c", "user.name=Audit", "commit", "-q", "-m", "init"],
        cwd=str(path),
        check=True,
    )


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def cleanup_managed_output(work_dir: Path, *, remove_empty_root: bool = False) -> None:
    for name in MANAGED_ENTRIES:
        path = work_dir / name
        if path.is_symlink() or path.is_file():
            path.unlink()
        elif path.is_dir():
            shutil.rmtree(path)
    if remove_empty_root and work_dir.exists():
        try:
            work_dir.rmdir()
        except OSError:
            pass


def verify_schema_instance(root: Path, work_dir: Path, errors: list[str]) -> None:
    validator = root / "tools" / "validate_json_schemas.py"
    result = subprocess.run(
        [
            sys.executable,
            str(validator),
            "--schema-instance",
            str(root / "schemas" / "local_repo_audit_first_report_smoke.schema.json"),
            str(work_dir / RECEIPT_REL),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    if result.returncode != 0:
        detail = (result.stderr or result.stdout).strip().splitlines()
        suffix = f": {detail[0]}" if detail else ""
        errors.append(f"first-report smoke schema validation failed: {RECEIPT_REL}{suffix}")


def build_receipt(root: Path, work_dir: Path, max_wall_ms: int) -> tuple[dict, int]:
    fixture_repo = work_dir / "fixture_repo"
    audit_out = work_dir / "audit_out"
    write_fixture_repo(fixture_repo)

    total_start_ns = time.perf_counter_ns()
    install_rc, install_wall_ms, install_error = run_cmd(
        [
            sys.executable,
            "-m",
            "py_compile",
            str(root / "scripts" / "audit_my_repo.py"),
            str(root / "tools" / "verify_local_audit.py"),
        ],
        root,
    )
    audit_rc = verify_rc = 1
    audit_wall_ms = verify_wall_ms = 0
    audit_error = verify_error = ""
    if install_rc == 0:
        audit_rc, audit_wall_ms, audit_error = run_cmd(
            [
                str(root / "scripts" / "audit_my_repo.sh"),
                str(fixture_repo),
                "--mode",
                "quick",
                "--out",
                str(audit_out),
                "--namespace",
                "synthetic",
                "--question",
                "Can a first-time user get a verified report within ten minutes?",
                "--generator",
                "routehint-tiny",
            ],
            root,
        )
    if install_rc == 0 and audit_rc == 0:
        verify_rc, verify_wall_ms, verify_error = run_cmd(
            [str(root / "tools" / "verify_local_audit.py"), str(audit_out)],
            root,
        )

    total_wall_ms = elapsed_ms(total_start_ns)
    report_path = audit_out / "AUDIT_REPORT.md"
    manifest = read_json(audit_out / "audit_manifest.json") if (audit_out / "audit_manifest.json").is_file() else {}
    summary = read_json(audit_out / "audit_summary.json") if (audit_out / "audit_summary.json").is_file() else {}
    resource = read_json(audit_out / "resource_envelope.json") if (audit_out / "resource_envelope.json").is_file() else {}
    diagnostics = read_json(audit_out / "diagnostics.json") if (audit_out / "diagnostics.json").is_file() else {}
    external_network_used = max(int(resource.get("external_network_used", 0)), int(diagnostics.get("external_network_used", 0)))
    audit_manifest_path = audit_out / "audit_manifest.json"
    audit_summary_path = audit_out / "audit_summary.json"
    receipt = {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "claim_boundary": CLAIM_BOUNDARY,
        "max_wall_ms": max_wall_ms,
        "total_wall_ms": total_wall_ms,
        "install_exit_code": install_rc,
        "install_wall_ms": install_wall_ms,
        "audit_exit_code": audit_rc,
        "audit_wall_ms": audit_wall_ms,
        "verify_exit_code": verify_rc,
        "verify_wall_ms": verify_wall_ms,
        "first_report_success": int(report_path.is_file() and verify_rc == 0),
        "within_time_budget": int(total_wall_ms <= max_wall_ms),
        "audit_output": str(audit_out),
        "report_path": str(report_path) if report_path.is_file() else "",
        "audit_manifest_sha256": sha256_file(audit_manifest_path) if audit_manifest_path.is_file() else "",
        "audit_summary_sha256": sha256_file(audit_summary_path) if audit_summary_path.is_file() else "",
        "audit_report_sha256": sha256_file(report_path) if report_path.is_file() else "",
        "cache_key": str(manifest.get("cache_key", "")),
        "run_id": str(manifest.get("run_id", "")),
        "release_ready": int(summary.get("release_ready", 0)) if summary else 0,
        "public_comparison_claim_ready": int(summary.get("public_comparison_claim_ready", 0)) if summary else 0,
        "real_model_execution_ready": int(summary.get("real_model_execution_ready", 0)) if summary else 0,
        "external_network_used": external_network_used,
        "fixture_only": 1,
        "design_partner_beta_candidate_ready": 0,
        "error": install_error or audit_error or verify_error,
    }
    ok = int(
        receipt["install_exit_code"] == 0
        and receipt["audit_exit_code"] == 0
        and receipt["verify_exit_code"] == 0
        and receipt["first_report_success"] == 1
        and receipt["within_time_budget"] == 1
        and receipt["external_network_used"] == 0
        and receipt["release_ready"] == 0
        and receipt["public_comparison_claim_ready"] == 0
        and receipt["real_model_execution_ready"] == 0
        and bool(receipt["audit_manifest_sha256"])
        and bool(receipt["audit_summary_sha256"])
        and bool(receipt["audit_report_sha256"])
    )
    return receipt, ok


def verify_receipt(root: Path, work_dir: Path) -> list[str]:
    errors: list[str] = []

    def add(message: str) -> None:
        errors.append(message)

    receipt_path = work_dir / RECEIPT_REL
    if not receipt_path.is_file():
        return [f"missing {RECEIPT_REL}"]
    try:
        receipt = read_json(receipt_path)
    except (OSError, json.JSONDecodeError) as exc:
        return [str(exc)]
    verify_schema_instance(root, work_dir, errors)

    expected_scalars = {
        "schema_version": SCHEMA_VERSION,
        "tool_version": TOOL_VERSION,
        "claim_boundary": CLAIM_BOUNDARY,
        "install_exit_code": 0,
        "audit_exit_code": 0,
        "verify_exit_code": 0,
        "first_report_success": 1,
        "within_time_budget": 1,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "external_network_used": 0,
        "fixture_only": 1,
        "design_partner_beta_candidate_ready": 0,
        "error": "",
    }
    for key, expected in expected_scalars.items():
        if receipt.get(key) != expected:
            add(f"{key} mismatch")
    for key in ["max_wall_ms", "total_wall_ms", "install_wall_ms", "audit_wall_ms", "verify_wall_ms"]:
        try:
            value = int(receipt.get(key, 0))
        except (TypeError, ValueError):
            add(f"{key} must be an integer")
            continue
        if value <= 0:
            add(f"{key} must be positive")
    try:
        within_time_budget = int(receipt.get("total_wall_ms", 0)) <= int(receipt.get("max_wall_ms", 0))
    except (TypeError, ValueError):
        within_time_budget = False
    if int(receipt.get("within_time_budget", 0)) != int(within_time_budget):
        add("within_time_budget drift")

    expected_audit_out = (work_dir / "audit_out").resolve()
    audit_output = Path(str(receipt.get("audit_output", ""))).expanduser().resolve()
    if audit_output != expected_audit_out:
        add("audit_output path drift")
    if not audit_output.is_dir():
        add("audit_output missing")
        return errors

    report_path = Path(str(receipt.get("report_path", ""))).expanduser()
    expected_report_path = audit_output / "AUDIT_REPORT.md"
    if report_path != expected_report_path:
        add("report_path drift")
    if not expected_report_path.is_file():
        add("AUDIT_REPORT.md missing")

    verify_rc, _, verify_error = run_cmd([str(root / "tools" / "verify_local_audit.py"), str(audit_output)], root)
    if verify_rc != 0:
        add(f"audit output verification failed: {verify_error}")

    manifest_path = audit_output / "audit_manifest.json"
    summary_path = audit_output / "audit_summary.json"
    if manifest_path.is_file():
        manifest = read_json(manifest_path)
        if receipt.get("audit_manifest_sha256") != sha256_file(manifest_path):
            add("audit_manifest_sha256 mismatch")
        if receipt.get("cache_key") != str(manifest.get("cache_key", "")):
            add("cache_key drift")
        if receipt.get("run_id") != str(manifest.get("run_id", "")):
            add("run_id drift")
    else:
        add("audit_manifest.json missing")
    if summary_path.is_file():
        summary = read_json(summary_path)
        if receipt.get("audit_summary_sha256") != sha256_file(summary_path):
            add("audit_summary_sha256 mismatch")
        for key in ["release_ready", "public_comparison_claim_ready", "real_model_execution_ready"]:
            if int(summary.get(key, 0)) != 0:
                add(f"audit summary readiness drift: {key}")
            if receipt.get(key) != int(summary.get(key, 0)):
                add(f"receipt summary drift: {key}")
    else:
        add("audit_summary.json missing")
    if expected_report_path.is_file() and receipt.get("audit_report_sha256") != sha256_file(expected_report_path):
        add("audit_report_sha256 mismatch")

    for rel in ["resource_envelope.json", "diagnostics.json"]:
        path = audit_output / rel
        if not path.is_file():
            add(f"{rel} missing")
            continue
        payload = read_json(path)
        if int(payload.get("external_network_used", 0)) != 0:
            add(f"{rel} external_network_used drift")
    return errors


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Run an offline first-report smoke for audit-my-repo.")
    parser.add_argument("--out", default="", help="Directory for the smoke fixture, audit output, and receipt.")
    parser.add_argument("--verify-existing", default="", help="Verify an existing first-report smoke output directory and exit.")
    parser.add_argument("--max-wall-ms", type=int, default=600_000)
    parser.add_argument("--keep", action="store_true", help="Keep an auto-created temporary output directory.")
    args = parser.parse_args(argv)

    root = Path(__file__).resolve().parents[1]
    if args.verify_existing:
        verify_dir = Path(args.verify_existing).expanduser().resolve()
        errors = verify_receipt(root, verify_dir)
        if errors:
            for error in errors:
                print(f"first_report_smoke_verify_error: {error}", file=sys.stderr)
            return 1
        print("first_report_smoke_verify: ok")
        return 0

    if args.max_wall_ms <= 0:
        print("--max-wall-ms must be positive", file=sys.stderr)
        return 2

    owned_temp = False
    created_user_out = False
    success = False
    if args.out:
        work_dir = Path(args.out).expanduser().resolve()
        created_user_out = not work_dir.exists()
        if work_dir.exists() and any(work_dir.iterdir()):
            print("--out must be empty or absent for first-report smoke", file=sys.stderr)
            return 2
        work_dir.mkdir(parents=True, exist_ok=True)
    else:
        work_dir = Path(tempfile.mkdtemp(prefix="audit-first-report-smoke."))
        owned_temp = True

    try:
        receipt, ok = build_receipt(root, work_dir, args.max_wall_ms)
        receipt_path = work_dir / RECEIPT_REL
        receipt_path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        if os.environ.get("AUDIT_MY_REPO_FIRST_REPORT_TAMPER_BEFORE_VERIFY") == "1":
            tampered = read_json(receipt_path)
            tampered["audit_report_sha256"] = "sha256:" + ("0" * 64)
            receipt_path.write_text(json.dumps(tampered, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        verify_errors = verify_receipt(root, work_dir)
        if verify_errors:
            for error in verify_errors:
                print(f"first_report_smoke_verify_error: {error}", file=sys.stderr)
            return 1
        print(f"first_report_smoke: {receipt_path}")
        if ok:
            success = True
            print("first_report_smoke: ok")
            return 0
        print(f"first_report_smoke: failed: {receipt.get('error', '')}", file=sys.stderr)
        return 1
    except (OSError, subprocess.CalledProcessError, json.JSONDecodeError, RuntimeError) as exc:
        print(f"first_report_smoke_error: {exc}", file=sys.stderr)
        return 2
    finally:
        if owned_temp and not args.keep:
            shutil.rmtree(work_dir, ignore_errors=True)
        elif args.out and not success:
            cleanup_managed_output(work_dir, remove_empty_root=created_user_out)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
