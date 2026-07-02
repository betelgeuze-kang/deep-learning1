#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_runtime_approval_request.py."""
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import hashlib
from pathlib import Path

import amr_beta_runtime_approval_request as approval_request

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_runtime_approval_request.py"


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def fake_sha(seed: int) -> str:
    return "sha256:" + f"{seed:064x}"[-64:]


def binding_payload() -> dict:
    template_dir_count = 10
    label_intake_dir_count = 10
    repo_intake_sha256 = fake_sha(1)
    repo_snapshot_lock_sha256 = fake_sha(2)
    decisions_sha256 = fake_sha(3)
    feedback_sha256 = fake_sha(4)
    feedback_bundle_sha256 = fake_sha(5)
    label_template_fingerprints = [
        {
            "template_dir": f"/tmp/template-{index}",
            "label_template_json_sha256": fake_sha(100 + index),
            "label_template_manifest_sha256": fake_sha(200 + index),
        }
        for index in range(template_dir_count)
    ]
    label_intake_fingerprints = [
        {
            "label_intake_dir": f"/tmp/intake-{index}",
            "label_intake_manifest_sha256": fake_sha(300 + index),
        }
        for index in range(label_intake_dir_count)
    ]
    label_template_bundle_sha256 = sha256_json(label_template_fingerprints)
    label_intake_bundle_sha256 = sha256_json(label_intake_fingerprints)
    preflight_inputs = {
        "repo_intake_sha256": repo_intake_sha256,
        "repo_snapshot_lock_sha256": repo_snapshot_lock_sha256,
        "decisions_sha256": decisions_sha256,
        "feedback_sha256": feedback_sha256,
        "feedback_bundle_sha256": feedback_bundle_sha256,
        "label_template_bundle_sha256": label_template_bundle_sha256,
        "label_intake_bundle_sha256": label_intake_bundle_sha256,
    }
    return {
        "repo_intake_sha256": repo_intake_sha256,
        "repo_snapshot_lock_sha256": repo_snapshot_lock_sha256,
        "decisions_sha256": decisions_sha256,
        "feedback_sha256": feedback_sha256,
        "feedback_bundle_sha256": feedback_bundle_sha256,
        "label_template_fingerprints": label_template_fingerprints,
        "label_template_json_sha256s": [
            row["label_template_json_sha256"] for row in label_template_fingerprints
        ],
        "label_template_manifest_sha256s": [
            row["label_template_manifest_sha256"] for row in label_template_fingerprints
        ],
        "label_template_bundle_sha256": label_template_bundle_sha256,
        "label_intake_fingerprints": label_intake_fingerprints,
        "label_intake_manifest_sha256s": [
            row["label_intake_manifest_sha256"] for row in label_intake_fingerprints
        ],
        "label_intake_bundle_sha256": label_intake_bundle_sha256,
        "preflight_input_bundle_sha256": sha256_json(preflight_inputs),
    }


def preflight_payload(
    *,
    ready: int = 1,
    release_ready: int = 0,
    verify_existing_required: int = 1,
    input_path_preflight_passed: int = 1,
    output_path_preflight_passed: int = 1,
    benchmark_out: str = "/tmp/audit_benchmark",
) -> dict:
    template_dir_count = 10
    label_intake_dir_count = 10
    return {
        "schema": "amr_beta_runtime_preflight.v1",
        "ready_to_request_runtime_approval": ready,
        "benchmark_runtime_approval_required": 1,
        "creates_benchmark_evidence": 0,
        "template_dir_count": template_dir_count,
        "label_template_verify_existing_required": verify_existing_required,
        "label_template_verify_existing_passed_dirs": template_dir_count if verify_existing_required else 0,
        "label_template_verify_existing_failed_dirs": 0,
        "label_intake_dir_count": label_intake_dir_count,
        "label_intake_verify_existing_required": verify_existing_required,
        "label_intake_verify_existing_passed_dirs": (
            label_intake_dir_count if verify_existing_required else 0
        ),
        "label_intake_verify_existing_failed_dirs": 0,
        **binding_payload(),
        "valid_repo_rows": 10,
        "human_label_rows": 300,
        "distinct_countable_maintainer_id_count": 3,
        "label_intake_case_count": 10,
        "input_path_preflight_passed": input_path_preflight_passed,
        "output_path_preflight_passed": output_path_preflight_passed,
        "design_partner_beta_candidate_ready": 0,
        "release_ready": release_ready,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "next_commands": [
            "python3 scripts/amr_beta_benchmark_input_prepare.py --label-intake-dir /tmp/intake --out-labels /tmp/labels.jsonl --summary /tmp/summary.json --feedback /tmp/feedback.jsonl",
            f"python3 scripts/audit_my_repo_benchmark.py --labels /tmp/labels.jsonl --feedback /tmp/feedback.jsonl --namespace real_benchmark --confirm-real-benchmark-namespace --mode full --out {benchmark_out}",
        ],
        "errors": [],
    }


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        assert approval_request.is_forbidden_env_path(Path(".env.secrets") / "approval_request.json")
        assert approval_request.is_forbidden_env_path(tmp / ".env.secrets" / "approval_request.json")
        assert not approval_request.is_forbidden_env_path(tmp / "approval_request.json")
        preflight = tmp / "preflight.json"
        write_json(preflight, preflight_payload())
        out_json = tmp / "approval_request.json"
        out_md = tmp / "approval_request.md"
        proc = run_tool(
            "--preflight",
            str(preflight),
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--operator-note",
            "Runtime budget to be approved by a human operator.",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["approved_by_human"] == 0
        assert payload["approval_record_supplied"] == 0
        assert payload["requires_human_runtime_approval"] == 1
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["runs_benchmark"] == 0
        assert payload["input_path_preflight_passed"] == 1
        assert payload["output_path_preflight_passed"] == 1
        assert payload["output_path_guard_passed"] == 1
        assert payload["input_preflight_sha256"] == sha256_file(preflight)
        assert payload["repo_snapshot_lock_sha256"] == fake_sha(2)
        assert payload["feedback_bundle_sha256"] == fake_sha(5)
        assert payload["preflight_input_bundle_sha256"] == binding_payload()["preflight_input_bundle_sha256"]
        assert payload["label_template_manifest_sha256s"] == [
            fake_sha(200 + index) for index in range(10)
        ]
        assert payload["runtime_commands_sha256"] == sha256_json(payload["runtime_commands"])
        assert payload["benchmark_out"] == "/tmp/audit_benchmark"
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["release_ready"] == 0
        assert payload["label_template_verify_existing_required"] == 1
        assert payload["label_template_verify_existing_passed_dirs"] == 10
        assert payload["label_intake_verify_existing_required"] == 1
        assert payload["label_intake_verify_existing_passed_dirs"] == 10
        assert "audit_my_repo_benchmark.py" in payload["runtime_commands"][1]
        markdown = out_md.read_text(encoding="utf-8")
        assert "approved_by_human: 0" in markdown
        assert "runtime_commands_sha256" in markdown
        assert "preflight_input_bundle_sha256: sha256:" in markdown
        assert "label_template_verify_existing_required: 1" in markdown
        assert "Runtime Commands" in markdown
        assert "input_path_preflight_passed: 1" in markdown
        assert "output_path_preflight_passed: 1" in markdown
        assert "output_path_guard_passed: 1" in markdown

        unsafe_benchmark_out = tmp / "unsafe_benchmark_out"
        unsafe_preflight = tmp / "unsafe_preflight.json"
        write_json(unsafe_preflight, preflight_payload(benchmark_out=str(unsafe_benchmark_out)))
        unsafe_out_json = unsafe_benchmark_out / "approval_request.json"
        unsafe_out_md = unsafe_benchmark_out / "approval_request.md"
        proc = run_tool(
            "--preflight",
            str(unsafe_preflight),
            "--out-json",
            str(unsafe_out_json),
            "--out-md",
            str(unsafe_out_md),
            "--json",
        )
        assert proc.returncode == 1
        unsafe_payload = json.loads(proc.stdout)
        assert unsafe_payload["output_path_guard_passed"] == 0
        assert "out_json must not be inside approved benchmark output" in proc.stderr
        assert "out_md must not be inside approved benchmark output" in proc.stderr
        assert not unsafe_out_json.exists()
        assert not unsafe_out_md.exists()

        blocked_preflight = tmp / "blocked_preflight.json"
        write_json(blocked_preflight, preflight_payload(ready=0))
        proc = run_tool("--preflight", str(blocked_preflight), "--out-json", str(tmp / "blocked.json"))
        assert proc.returncode == 1
        assert "ready_to_request_runtime_approval=1" in proc.stderr

        missing_feedback_bundle = tmp / "missing_feedback_bundle_preflight.json"
        missing_feedback_bundle_payload = preflight_payload()
        del missing_feedback_bundle_payload["feedback_bundle_sha256"]
        write_json(missing_feedback_bundle, missing_feedback_bundle_payload)
        proc = run_tool("--preflight", str(missing_feedback_bundle), "--out-json", str(tmp / "missing_feedback_bundle.json"))
        assert proc.returncode == 1
        assert "runtime preflight feedback_bundle_sha256 must be a sha256 digest" in proc.stderr

        unsafe_input_preflight = tmp / "unsafe_input_preflight.json"
        write_json(unsafe_input_preflight, preflight_payload(input_path_preflight_passed=0))
        proc = run_tool(
            "--preflight",
            str(unsafe_input_preflight),
            "--out-json",
            str(tmp / "unsafe_input_request.json"),
        )
        assert proc.returncode == 1
        assert "input_path_preflight_passed=1" in proc.stderr

        unsafe_output_preflight = tmp / "unsafe_output_preflight.json"
        write_json(unsafe_output_preflight, preflight_payload(output_path_preflight_passed=0))
        proc = run_tool(
            "--preflight",
            str(unsafe_output_preflight),
            "--out-json",
            str(tmp / "unsafe_output_request.json"),
        )
        assert proc.returncode == 1
        assert "output_path_preflight_passed=1" in proc.stderr

        promoted_preflight = tmp / "promoted_preflight.json"
        write_json(promoted_preflight, preflight_payload(release_ready=1))
        proc = run_tool("--preflight", str(promoted_preflight), "--out-json", str(tmp / "promoted.json"))
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr

        skipped_verify_preflight = tmp / "skipped_verify_preflight.json"
        write_json(skipped_verify_preflight, preflight_payload(verify_existing_required=0))
        proc = run_tool(
            "--preflight",
            str(skipped_verify_preflight),
            "--out-json",
            str(tmp / "skipped_verify.json"),
        )
        assert proc.returncode == 1
        assert "label_template_verify_existing_required=1" in proc.stderr
        assert "label_intake_verify_existing_required=1" in proc.stderr

        stale_fingerprint_preflight = tmp / "stale_fingerprint_preflight.json"
        stale_payload = preflight_payload()
        stale_payload["label_template_bundle_sha256"] = fake_sha(999)
        write_json(stale_fingerprint_preflight, stale_payload)
        proc = run_tool(
            "--preflight",
            str(stale_fingerprint_preflight),
            "--out-json",
            str(tmp / "stale_fingerprint.json"),
        )
        assert proc.returncode == 1
        assert "label_template_bundle_sha256 does not match" in proc.stderr

    print("AMR beta runtime approval request smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
