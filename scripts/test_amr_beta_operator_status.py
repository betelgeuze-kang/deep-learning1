#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_operator_status.py."""
from __future__ import annotations

import hashlib
import json
import shlex
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "scripts" / "amr_beta_operator_status.py"


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def command_line(parts: list[object]) -> str:
    return " ".join(shlex.quote(str(part)) for part in parts)


def fake_sha(seed: int) -> str:
    return "sha256:" + f"{seed:064x}"[-64:]


def fake_git_head(seed: int) -> str:
    return f"{seed:040x}"[-40:]


def repo_snapshot_lock_rows() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for index in range(10):
        case_id = f"case-{index:02d}"
        head = fake_git_head(1000 + index)
        rows.append(
            {
                "row_index": index + 1,
                "case_id": case_id,
                "repo_path_resolved": f"/tmp/{case_id}",
                "expected_repo_git_head": head,
                "actual_repo_git_head": head,
                "clean_worktree_declared": 1,
                "clean_worktree_actual": 1,
                "owner_or_maintainer_contact_present": 1,
                "audit_mode": "quick",
                "namespace": "real_benchmark",
                "real_benchmark_namespace_confirmed": 1,
                "valid": 1,
            }
        )
    return rows


def binding_payload() -> dict:
    snapshot_rows = repo_snapshot_lock_rows()
    repo_snapshot_lock_sha256 = sha256_json(snapshot_rows)
    template_fingerprints = [
        {
            "label_template_json_sha256": fake_sha(100 + index),
            "label_template_manifest_sha256": fake_sha(200 + index),
        }
        for index in range(10)
    ]
    label_intake_fingerprints = [
        {"label_intake_manifest_sha256": fake_sha(300)},
        {"label_intake_manifest_sha256": fake_sha(301)},
    ]
    label_template_bundle_sha256 = sha256_json(template_fingerprints)
    label_intake_bundle_sha256 = sha256_json(label_intake_fingerprints)
    input_bundle = {
        "repo_intake_sha256": fake_sha(1),
        "repo_snapshot_lock_sha256": repo_snapshot_lock_sha256,
        "decisions_sha256": fake_sha(3),
        "feedback_sha256": fake_sha(4),
        "label_template_bundle_sha256": label_template_bundle_sha256,
        "label_intake_bundle_sha256": label_intake_bundle_sha256,
    }
    return {
        "template_dir_count": len(template_fingerprints),
        "label_template_fingerprints": template_fingerprints,
        "label_template_json_sha256s": [
            row["label_template_json_sha256"] for row in template_fingerprints
        ],
        "label_template_manifest_sha256s": [
            row["label_template_manifest_sha256"] for row in template_fingerprints
        ],
        "label_intake_dir_count": len(label_intake_fingerprints),
        "label_intake_fingerprints": label_intake_fingerprints,
        "label_intake_manifest_sha256s": [
            row["label_intake_manifest_sha256"] for row in label_intake_fingerprints
        ],
        "repo_intake_sha256": fake_sha(1),
        "repo_snapshot_lock_sha256": repo_snapshot_lock_sha256,
        "decisions_sha256": fake_sha(3),
        "feedback_sha256": fake_sha(4),
        "label_template_bundle_sha256": label_template_bundle_sha256,
        "label_intake_bundle_sha256": label_intake_bundle_sha256,
        "preflight_input_bundle_sha256": sha256_json(input_bundle),
    }


def run_tool(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(TOOL), *args],
        cwd=str(ROOT),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def base_blocked() -> dict:
    return {
        "design_partner_beta_candidate_ready": 0,
        "release_ready": 0,
        "public_comparison_claim_ready": 0,
        "real_model_execution_ready": 0,
        "errors": [],
    }


def path_guard_payload() -> dict:
    return {
        "input_path_preflight_passed": 1,
        "output_path_preflight_passed": 1,
    }


def repo_audit_plan_payload() -> dict:
    binding = binding_payload()
    snapshot_rows = repo_snapshot_lock_rows()
    artifact_root = "/tmp/amr_beta_repo_audit_work"
    per_repo: list[dict[str, str]] = []
    commands: list[str] = []
    for index in range(10):
        case_id = f"case-{index:02d}"
        lock_row = snapshot_rows[index]
        repo_path = str(lock_row["repo_path_resolved"])
        audit_mode = str(lock_row["audit_mode"])
        audit_out = f"{artifact_root}/{case_id}_audit"
        label_template_out = f"{artifact_root}/{case_id}_label_template"
        reviewer_packet_out = f"{artifact_root}/{case_id}_reviewer_packet"
        row = {
            "case_id": case_id,
            "repo_path": repo_path,
            "expected_repo_git_head": str(lock_row["expected_repo_git_head"]),
            "actual_repo_git_head": str(lock_row["actual_repo_git_head"]),
            "owner_or_maintainer_contact_present": 1,
            "audit_mode": audit_mode,
            "namespace": "real_benchmark",
            "real_benchmark_namespace_confirmed": 1,
            "audit_out": audit_out,
            "label_template_out": label_template_out,
            "reviewer_packet_out": reviewer_packet_out,
            "audit_command": command_line(
                [
                    "./scripts/audit_my_repo.sh",
                    repo_path,
                    "--mode",
                    audit_mode,
                    "--namespace",
                    "real_benchmark",
                    "--confirm-real-benchmark-namespace",
                    "--out",
                    audit_out,
                ]
            ),
            "audit_verify_command": command_line(["./scripts/audit_my_repo.sh", "--verify-existing", audit_out]),
            "label_template_command": command_line(
                [
                    "python3",
                    "scripts/audit_my_repo_label_template.py",
                    "--audit-output",
                    audit_out,
                    "--out",
                    label_template_out,
                    "--case-id",
                    case_id,
                ]
            ),
            "label_template_verify_command": command_line(
                [
                    "python3",
                    "scripts/audit_my_repo_label_template.py",
                    "--verify-existing",
                    label_template_out,
                ]
            ),
            "reviewer_packet_command": command_line(
                [
                    "python3",
                    "scripts/amr_beta_label_packet.py",
                    "--template-dir",
                    label_template_out,
                    "--out",
                    reviewer_packet_out,
                ]
            ),
        }
        per_repo.append(row)
        commands.extend(
            [
                row["audit_command"],
                row["audit_verify_command"],
                row["label_template_command"],
                row["label_template_verify_command"],
                row["reviewer_packet_command"],
            ]
        )
    aggregate_parts: list[object] = ["python3", "scripts/amr_beta_label_packet.py"]
    for row in per_repo:
        aggregate_parts.extend(["--template-dir", row["label_template_out"]])
    aggregate_parts.extend(["--per-case-out-root", f"{artifact_root}/reviewer_packets"])
    aggregate_command = command_line(aggregate_parts)
    commands.append(aggregate_command)
    return {
        "schema": "amr_beta_repo_audit_plan.v1",
        "repo_intake_sha256": binding["repo_intake_sha256"],
        "repo_snapshot_lock_sha256": binding["repo_snapshot_lock_sha256"],
        "repo_snapshot_lock_row_count": len(snapshot_rows),
        "repo_snapshot_lock_rows": snapshot_rows,
        "artifact_root": artifact_root,
        "ready_for_real_benchmark_audit_plan": 1,
        "valid_repo_rows": 10,
        "min_real_repos_required": 10,
        "runs_audit": 0,
        "runs_label_template_generation": 0,
        "writes_reviewer_packets": 0,
        "creates_benchmark_evidence": 0,
        "input_path_guard_passed": 1,
        "output_path_guard_passed": 1,
        "operator_command_count": len(commands),
        "operator_commands_sha256": sha256_json(commands),
        "per_repo": per_repo,
        "aggregate_reviewer_packet_command": aggregate_command,
        "operator_commands": commands,
        **base_blocked(),
    }


def label_intake_plan_payload() -> dict:
    binding = binding_payload()
    per_case: list[dict[str, str]] = []
    commands: list[str] = []
    for index in range(10):
        case_id = f"case-{index:02d}"
        row = {
            "case_id": case_id,
            "compile_command": f"python3 scripts/audit_my_repo_label_intake.py --template /tmp/{case_id}_template",
            "verify_command": f"python3 scripts/audit_my_repo_label_intake.py --verify-existing /tmp/{case_id}_label_intake",
        }
        per_case.append(row)
        commands.extend([row["compile_command"], row["verify_command"]])
    return {
        "schema": "amr_beta_label_intake_plan.v1",
        "repo_intake_sha256": binding["repo_intake_sha256"],
        "repo_snapshot_lock_sha256": binding["repo_snapshot_lock_sha256"],
        "decisions_sha256": binding["decisions_sha256"],
        "template_dir_count": 10,
        "label_template_fingerprints": binding["label_template_fingerprints"],
        "label_template_bundle_sha256": binding["label_template_bundle_sha256"],
        "label_template_json_sha256s": binding["label_template_json_sha256s"],
        "label_template_manifest_sha256s": binding["label_template_manifest_sha256s"],
        "label_template_verify_existing_required": 1,
        "label_template_verify_existing_passed_dirs": 10,
        "label_template_verify_existing_failed_dirs": 0,
        "ready_for_label_intake_plan": 1,
        "case_count": 10,
        "candidate_label_rows": 300,
        "synthetic_candidate_rows": 0,
        "non_synthetic_candidate_rows": 300,
        "decision_rows": 300,
        "valid_human_label_rows": 300,
        "non_synthetic_valid_human_label_rows": 300,
        "human_label_requirement_met": 1,
        "human_labels_remaining_to_minimum": 0,
        "min_real_repos_required": 10,
        "min_human_label_rows_required": 300,
        "decision_input_guard_passed": 1,
        "output_path_guard_passed": 1,
        "compiles_labels": 0,
        "writes_label_intake_outputs": 0,
        "creates_benchmark_evidence": 0,
        "runs_real_benchmark": 0,
        "operator_command_count": len(commands),
        "operator_commands_sha256": sha256_json(commands),
        "per_case": per_case,
        "operator_commands": commands,
        **base_blocked(),
    }


def maintainer_feedback_packet_payload() -> dict:
    binding = binding_payload()
    return {
        "schema": "amr_beta_maintainer_feedback_packet.v1",
        "repo_snapshot_lock_sha256": binding["repo_snapshot_lock_sha256"],
        "ready_for_runtime_preflight_feedback": 1,
        "min_real_repos_required": 10,
        "valid_repo_rows": 10,
        "request_case_rows": 10,
        "min_maintainer_feedback_required": 3,
        "label_intake_dir_count": 1,
        "label_intake_verify_existing_required": 1,
        "label_intake_verify_existing_passed_dirs": 1,
        "label_intake_verify_existing_failed_dirs": 0,
        "label_intake_label_rows": 300,
        "label_intake_case_count": 10,
        "label_intake_countable_case_count": 10,
        "label_intake_synthetic_case_count": 0,
        "valid_feedback_rows": 3,
        "distinct_maintainer_id_count": 3,
        "distinct_countable_maintainer_id_count": 3,
        "feedback_countable_case_rows": 3,
        "maintainer_feedback_requirement_met": 1,
        "feedback_counts_for_beta_precheck": 1,
        "raw_feedback_text_emitted": 0,
        "creates_benchmark_evidence": 0,
        "input_path_guard_passed": 1,
        "output_path_guard_passed": 1,
        **base_blocked(),
    }


def request_payload(preflight: Path) -> dict:
    return {
        "schema": "amr_beta_runtime_approval_request.v1",
        "input_preflight": str(preflight.resolve()),
        "input_preflight_sha256": sha256_file(preflight),
        "request_kind": "runtime_approval_required",
        "approved_by_human": 0,
        "approval_record_supplied": 0,
        "requires_human_runtime_approval": 1,
        "benchmark_runtime_approval_required": 1,
        "creates_benchmark_evidence": 0,
        "runs_benchmark": 0,
        **path_guard_payload(),
        "output_path_guard_passed": 1,
        **binding_payload(),
        **base_blocked(),
    }


def approval_status_payload(preflight: Path, request: Path, record: Path, benchmark_out: Path) -> dict:
    return {
        "schema": "amr_beta_runtime_approval_status.v1",
        "input_preflight": str(preflight.resolve()),
        "input_preflight_sha256": sha256_file(preflight),
        "approval_request": str(request.resolve()),
        "approval_request_sha256": sha256_file(request),
        "approval_record": str(record.resolve()),
        "approval_record_sha256": sha256_file(record),
        "approval_scope": "amr_beta_real_benchmark_runtime",
        "approved_by_human": 1,
        "approval_record_supplied": 1,
        "human_runtime_approval_record_verified": 1,
        "ready_for_human_operator_benchmark_run": 1,
        "benchmark_runtime_approval_required": 1,
        "creates_benchmark_evidence": 0,
        "runs_benchmark": 0,
        "codex_runtime_permission_granted_by_this_packet": 0,
        "benchmark_out": str(benchmark_out.resolve()),
        **path_guard_payload(),
        "approval_request_output_path_guard_passed": 1,
        **binding_payload(),
        **base_blocked(),
    }


def main() -> int:
    with tempfile.TemporaryDirectory() as tmp_name:
        tmp = Path(tmp_name)
        repo = tmp / "repo_plan.json"
        label = tmp / "label_plan.json"
        feedback = tmp / "feedback_packet.json"
        preflight = tmp / "preflight.json"
        approval_request = tmp / "approval_request.json"
        approval_record = tmp / "approval_record.json"
        approval_status = tmp / "approval_status.json"
        benchmark_out = tmp / "audit_benchmark"
        benchmark_out.mkdir()
        readiness = benchmark_out / "benchmark_readiness.json"

        write_json(
            repo,
            repo_audit_plan_payload(),
        )
        write_json(
            label,
            label_intake_plan_payload(),
        )
        write_json(
            feedback,
            maintainer_feedback_packet_payload(),
        )
        write_json(
            preflight,
            {
                "schema": "amr_beta_runtime_preflight.v1",
                "ready_to_request_runtime_approval": 1,
                **path_guard_payload(),
                **binding_payload(),
                **base_blocked(),
            },
        )
        write_json(approval_request, request_payload(preflight))
        write_json(
            approval_record,
            {
                "schema": "amr_beta_runtime_approval_record.v1",
                "approval_scope": "amr_beta_real_benchmark_runtime",
                "approved_by_human": True,
            },
        )
        write_json(approval_status, approval_status_payload(preflight, approval_request, approval_record, benchmark_out))
        write_json(
            readiness,
            {
                "schema_version": "local_repo_audit_benchmark_readiness.v1",
                "product_readiness_calculated_from_real_labels": 1,
                "design_partner_beta_candidate_ready": 1,
                "release_ready": 0,
                "public_comparison_claim_ready": 0,
                "real_model_execution_ready": 0,
            },
        )

        out_json = tmp / "operator_status.json"
        out_md = tmp / "operator_status.md"
        proc = run_tool("--repo-audit-plan", str(repo), "--out-json", str(out_json), "--json")
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["current_stage"] == "stage_1_repo_intake_plan_ready"
        assert payload["creates_benchmark_evidence"] == 0
        assert payload["runs_benchmark"] == 0
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert payload["stage_progress"]["repo_intake"]["current"] == 10
        assert payload["stage_progress"]["repo_intake"]["met"] == 1
        assert payload["stage_progress"]["human_labels"]["current"] == 0
        assert payload["stage_progress"]["human_labels"]["remaining"] == 300
        assert payload["stage_progress"]["maintainer_feedback"]["remaining"] == 3
        assert payload["stage_progress"]["runtime_preflight"]["ready_to_request_runtime_approval"] == 0
        assert payload["stage_progress"]["benchmark"]["benchmark_readiness_supplied"] == 0

        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(approval_request),
            "--runtime-approval-status",
            str(approval_status),
            "--out-json",
            str(out_json),
            "--out-md",
            str(out_md),
            "--overwrite",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["current_stage"] == "stage_4_runtime_approval_verified"
        assert payload["design_partner_beta_candidate_ready"] == 0
        assert "Human/operator may run" in payload["next_blockers"][0]
        assert payload["stage_progress"]["repo_intake"]["current"] == 10
        assert payload["stage_progress"]["repo_intake"]["met"] == 1
        assert payload["stage_progress"]["human_labels"]["current"] == 300
        assert payload["stage_progress"]["human_labels"]["met"] == 1
        assert payload["stage_progress"]["maintainer_feedback"]["current"] == 3
        assert payload["stage_progress"]["maintainer_feedback"]["met"] == 1
        assert payload["stage_progress"]["runtime_preflight"]["ready_to_request_runtime_approval"] == 1
        assert payload["stage_progress"]["runtime_approval"]["approval_record_verified"] == 1
        assert payload["stage_progress"]["benchmark"]["benchmark_readiness_supplied"] == 0
        expected_binding = binding_payload()
        assert (
            payload["runtime_fingerprints"]["preflight_input_bundle_sha256"]
            == expected_binding["preflight_input_bundle_sha256"]
        )
        assert (
            payload["runtime_fingerprints"]["label_template_json_sha256s"]
            == expected_binding["label_template_json_sha256s"]
        )
        assert (
            payload["runtime_fingerprints"]["label_template_manifest_sha256s"]
            == expected_binding["label_template_manifest_sha256s"]
        )
        assert (
            payload["runtime_fingerprints"]["label_intake_manifest_sha256s"]
            == expected_binding["label_intake_manifest_sha256s"]
        )
        assert payload["runtime_fingerprints"]["input_path_preflight_passed"] == 1
        assert payload["runtime_fingerprints"]["output_path_preflight_passed"] == 1
        markdown = out_md.read_text(encoding="utf-8")
        assert "current_stage: stage_4_runtime_approval_verified" in markdown
        assert "repo_intake: 10/10" in markdown
        assert "human_labels: 300/300" in markdown
        assert "maintainer_feedback: 3/3" in markdown
        assert "preflight_input_bundle_sha256: sha256:" in markdown
        assert "input_path_preflight_passed: 1" in markdown
        assert 'label_intake_manifest_sha256s: ["sha256:' in markdown

        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(approval_request),
            "--runtime-approval-status",
            str(approval_status),
            "--benchmark-readiness",
            str(readiness),
            "--out-json",
            str(out_json),
            "--overwrite",
            "--json",
        )
        assert proc.returncode == 0, proc.stderr
        payload = json.loads(out_json.read_text(encoding="utf-8"))
        assert payload["current_stage"] == "stage_5_beta_candidate_or_hardening"
        assert payload["design_partner_beta_candidate_ready"] == 1
        assert payload["release_ready"] == 0
        assert payload["stage_progress"]["benchmark"]["benchmark_readiness_supplied"] == 1
        assert (
            payload["stage_progress"]["benchmark"]["design_partner_beta_candidate_ready"]
            == payload["design_partner_beta_candidate_ready"]
        )

        missing_request_status = tmp / "missing_request_status.json"
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-status",
            str(approval_status),
            "--out-json",
            str(missing_request_status),
        )
        assert proc.returncode == 1
        assert "runtime_approval_request is required" in proc.stderr
        assert not missing_request_status.exists()

        stale_status = tmp / "stale_approval_status.json"
        stale_payload = approval_status_payload(preflight, approval_request, approval_record, benchmark_out)
        stale_payload["approval_request_sha256"] = "sha256:" + ("0" * 64)
        write_json(stale_status, stale_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(approval_request),
            "--runtime-approval-status",
            str(stale_status),
            "--out-json",
            str(tmp / "stale_status_output.json"),
        )
        assert proc.returncode == 1
        assert "approval_request_sha256 must match" in proc.stderr

        malformed_preflight = tmp / "malformed_preflight.json"
        malformed_preflight_payload = {
            "schema": "amr_beta_runtime_preflight.v1",
            "ready_to_request_runtime_approval": 1,
            **path_guard_payload(),
            **binding_payload(),
            **base_blocked(),
        }
        malformed_preflight_payload["repo_intake_sha256"] = "sha256:" + ("z" * 64)
        malformed_preflight_payload["preflight_input_bundle_sha256"] = sha256_json(
            {
                "repo_intake_sha256": malformed_preflight_payload["repo_intake_sha256"],
                "repo_snapshot_lock_sha256": malformed_preflight_payload["repo_snapshot_lock_sha256"],
                "decisions_sha256": malformed_preflight_payload["decisions_sha256"],
                "feedback_sha256": malformed_preflight_payload["feedback_sha256"],
                "label_template_bundle_sha256": malformed_preflight_payload["label_template_bundle_sha256"],
                "label_intake_bundle_sha256": malformed_preflight_payload["label_intake_bundle_sha256"],
            }
        )
        write_json(malformed_preflight, malformed_preflight_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(malformed_preflight),
            "--out-json",
            str(tmp / "malformed_preflight_output.json"),
        )
        assert proc.returncode == 1
        assert "runtime_preflight: repo_intake_sha256 must be a sha256 binding" in proc.stderr

        stale_preflight_bundle = tmp / "stale_preflight_bundle.json"
        stale_preflight_payload = {
            "schema": "amr_beta_runtime_preflight.v1",
            "ready_to_request_runtime_approval": 1,
            **path_guard_payload(),
            **binding_payload(),
            **base_blocked(),
        }
        stale_preflight_payload["preflight_input_bundle_sha256"] = fake_sha(999)
        write_json(stale_preflight_bundle, stale_preflight_payload)
        stale_preflight_request = tmp / "stale_preflight_request.json"
        stale_preflight_request_payload = request_payload(stale_preflight_bundle)
        for key, value in stale_preflight_payload.items():
            if key in binding_payload():
                stale_preflight_request_payload[key] = value
        write_json(stale_preflight_request, stale_preflight_request_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(stale_preflight_bundle),
            "--runtime-approval-request",
            str(stale_preflight_request),
            "--out-json",
            str(tmp / "stale_preflight_bundle_output.json"),
        )
        assert proc.returncode == 1
        assert "preflight_input_bundle_sha256 does not match input fingerprints" in proc.stderr

        stale_fingerprint_request = tmp / "stale_fingerprint_request.json"
        stale_fingerprint_payload = request_payload(preflight)
        stale_fingerprint_payload["preflight_input_bundle_sha256"] = fake_sha(999)
        write_json(stale_fingerprint_request, stale_fingerprint_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(stale_fingerprint_request),
            "--out-json",
            str(tmp / "stale_fingerprint_request_output.json"),
        )
        assert proc.returncode == 1
        assert "preflight_input_bundle_sha256 must match runtime_preflight" in proc.stderr

        unapproved_status = tmp / "unapproved_status.json"
        unapproved_payload = approval_status_payload(preflight, approval_request, approval_record, benchmark_out)
        unapproved_payload["ready_for_human_operator_benchmark_run"] = 0
        write_json(unapproved_status, unapproved_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(approval_request),
            "--runtime-approval-status",
            str(unapproved_status),
            "--out-json",
            str(tmp / "unapproved_status_output.json"),
        )
        assert proc.returncode == 1
        assert "ready_for_human_operator_benchmark_run=1" in proc.stderr

        missing_request_guard = tmp / "missing_request_guard.json"
        missing_request_guard_payload = request_payload(preflight)
        del missing_request_guard_payload["input_path_preflight_passed"]
        write_json(missing_request_guard, missing_request_guard_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(missing_request_guard),
            "--out-json",
            str(tmp / "missing_request_guard_output.json"),
        )
        assert proc.returncode == 1
        assert "input_path_preflight_passed must be present" in proc.stderr

        malformed_request = tmp / "malformed_request.json"
        malformed_request_payload = request_payload(preflight)
        malformed_request_payload["approved_by_human"] = "true"
        del malformed_request_payload["runs_benchmark"]
        write_json(malformed_request, malformed_request_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(malformed_request),
            "--out-json",
            str(tmp / "malformed_request_output.json"),
        )
        assert proc.returncode == 1
        assert "approved_by_human must be an integer or boolean flag" in proc.stderr
        assert "runs_benchmark must be present" in proc.stderr

        missing_record_status = tmp / "missing_record_status.json"
        missing_record_payload = approval_status_payload(
            preflight,
            approval_request,
            approval_record,
            benchmark_out,
        )
        del missing_record_payload["approval_record_sha256"]
        write_json(missing_record_status, missing_record_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(approval_request),
            "--runtime-approval-status",
            str(missing_record_status),
            "--out-json",
            str(tmp / "missing_record_status_output.json"),
        )
        assert proc.returncode == 1
        assert "approval_record_sha256 must be a sha256 binding" in proc.stderr

        missing_status_guard = tmp / "missing_status_guard.json"
        missing_status_guard_payload = approval_status_payload(
            preflight,
            approval_request,
            approval_record,
            benchmark_out,
        )
        del missing_status_guard_payload["approval_request_output_path_guard_passed"]
        write_json(missing_status_guard, missing_status_guard_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(approval_request),
            "--runtime-approval-status",
            str(missing_status_guard),
            "--out-json",
            str(tmp / "missing_status_guard_output.json"),
        )
        assert proc.returncode == 1
        assert "approval_request_output_path_guard_passed must be present" in proc.stderr

        stale_fingerprint_status = tmp / "stale_fingerprint_status.json"
        stale_fingerprint_status_payload = approval_status_payload(
            preflight,
            approval_request,
            approval_record,
            benchmark_out,
        )
        stale_fingerprint_status_payload["label_intake_manifest_sha256s"] = [fake_sha(998)]
        write_json(stale_fingerprint_status, stale_fingerprint_status_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(approval_request),
            "--runtime-approval-status",
            str(stale_fingerprint_status),
            "--out-json",
            str(tmp / "stale_fingerprint_status_output.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_manifest_sha256s must match runtime_preflight" in proc.stderr

        other_benchmark_out = tmp / "other_audit_benchmark"
        other_benchmark_out.mkdir()
        wrong_readiness = other_benchmark_out / "benchmark_readiness.json"
        write_json(
            wrong_readiness,
            {
                "schema_version": "local_repo_audit_benchmark_readiness.v1",
                "product_readiness_calculated_from_real_labels": 1,
                "design_partner_beta_candidate_ready": 1,
                "release_ready": 0,
                "public_comparison_claim_ready": 0,
                "real_model_execution_ready": 0,
            },
        )
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(feedback),
            "--runtime-preflight",
            str(preflight),
            "--runtime-approval-request",
            str(approval_request),
            "--runtime-approval-status",
            str(approval_status),
            "--benchmark-readiness",
            str(wrong_readiness),
            "--out-json",
            str(tmp / "wrong_readiness_status.json"),
        )
        assert proc.returncode == 1
        assert "benchmark_out/benchmark_readiness.json" in proc.stderr

        bad_repo = tmp / "bad_repo_plan.json"
        bad_payload = repo_audit_plan_payload()
        bad_payload["release_ready"] = 1
        write_json(bad_repo, bad_payload)
        proc = run_tool("--repo-audit-plan", str(bad_repo), "--out-json", str(tmp / "bad_status.json"))
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr
        assert not (tmp / "bad_status.json").exists()

        missing_repo_guard = tmp / "missing_repo_guard.json"
        missing_repo_guard_payload = repo_audit_plan_payload()
        del missing_repo_guard_payload["input_path_guard_passed"]
        write_json(missing_repo_guard, missing_repo_guard_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(missing_repo_guard),
            "--out-json",
            str(tmp / "missing_repo_guard_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: input_path_guard_passed must be present" in proc.stderr

        low_repo_count = tmp / "low_repo_count.json"
        low_repo_count_payload = repo_audit_plan_payload()
        low_repo_count_payload["valid_repo_rows"] = 9
        write_json(low_repo_count, low_repo_count_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(low_repo_count),
            "--out-json",
            str(tmp / "low_repo_count_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: valid_repo_rows must be >= 10" in proc.stderr

        float_repo_count = tmp / "float_repo_count.json"
        float_repo_count_payload = repo_audit_plan_payload()
        float_repo_count_payload["valid_repo_rows"] = 10.9
        write_json(float_repo_count, float_repo_count_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(float_repo_count),
            "--out-json",
            str(tmp / "float_repo_count_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: valid_repo_rows must be an integer >= 10" in proc.stderr

        missing_repo_commands = tmp / "missing_repo_commands.json"
        missing_repo_commands_payload = repo_audit_plan_payload()
        del missing_repo_commands_payload["operator_commands"]
        write_json(missing_repo_commands, missing_repo_commands_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(missing_repo_commands),
            "--out-json",
            str(tmp / "missing_repo_commands_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: operator_commands must be a non-empty string list" in proc.stderr

        stale_repo_commands_hash = tmp / "stale_repo_commands_hash.json"
        stale_repo_commands_hash_payload = repo_audit_plan_payload()
        stale_repo_commands_hash_payload["operator_commands_sha256"] = fake_sha(998)
        write_json(stale_repo_commands_hash, stale_repo_commands_hash_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(stale_repo_commands_hash),
            "--out-json",
            str(tmp / "stale_repo_commands_hash_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: operator_commands_sha256 must match operator_commands" in proc.stderr

        extra_repo_command = tmp / "extra_repo_command.json"
        extra_repo_command_payload = repo_audit_plan_payload()
        extra_repo_command_payload["operator_commands"].append("python3 scripts/unexpected_repo_operator_command.py")
        extra_repo_command_payload["operator_command_count"] = len(extra_repo_command_payload["operator_commands"])
        extra_repo_command_payload["operator_commands_sha256"] = sha256_json(
            extra_repo_command_payload["operator_commands"]
        )
        write_json(extra_repo_command, extra_repo_command_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(extra_repo_command),
            "--out-json",
            str(tmp / "extra_repo_command_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: operator_commands must exactly match per_repo" in proc.stderr

        drifted_repo_audit_command = tmp / "drifted_repo_audit_command.json"
        drifted_repo_audit_command_payload = repo_audit_plan_payload()
        bad_audit_command = command_line(
            [
                "./scripts/audit_my_repo.sh",
                "/tmp/other-case",
                "--mode",
                "quick",
                "--namespace",
                "real_benchmark",
                "--confirm-real-benchmark-namespace",
                "--out",
                drifted_repo_audit_command_payload["per_repo"][0]["audit_out"],
            ]
        )
        drifted_repo_audit_command_payload["per_repo"][0]["audit_command"] = bad_audit_command
        drifted_repo_audit_command_payload["operator_commands"][0] = bad_audit_command
        drifted_repo_audit_command_payload["operator_commands_sha256"] = sha256_json(
            drifted_repo_audit_command_payload["operator_commands"]
        )
        write_json(drifted_repo_audit_command, drifted_repo_audit_command_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(drifted_repo_audit_command),
            "--out-json",
            str(tmp / "drifted_repo_audit_command_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: per_repo audit_command must match locked repo command" in proc.stderr

        stale_repo_snapshot_hash = tmp / "stale_repo_snapshot_hash.json"
        stale_repo_snapshot_hash_payload = repo_audit_plan_payload()
        stale_repo_snapshot_hash_payload["repo_snapshot_lock_sha256"] = fake_sha(995)
        write_json(stale_repo_snapshot_hash, stale_repo_snapshot_hash_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(stale_repo_snapshot_hash),
            "--out-json",
            str(tmp / "stale_repo_snapshot_hash_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: repo_snapshot_lock_sha256 must match repo_snapshot_lock_rows" in proc.stderr

        duplicate_canonical_repo_path = tmp / "duplicate_canonical_repo_path.json"
        duplicate_canonical_repo_path_payload = repo_audit_plan_payload()
        duplicate_canonical_repo_path_payload["repo_snapshot_lock_rows"][1]["repo_path_resolved"] = "/tmp/../tmp/case-00"
        duplicate_canonical_repo_path_payload["repo_snapshot_lock_sha256"] = sha256_json(
            duplicate_canonical_repo_path_payload["repo_snapshot_lock_rows"]
        )
        write_json(duplicate_canonical_repo_path, duplicate_canonical_repo_path_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(duplicate_canonical_repo_path),
            "--out-json",
            str(tmp / "duplicate_canonical_repo_path_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_snapshot_lock_rows row 2: duplicate repo_path_resolved" in proc.stderr

        dirty_repo_snapshot = tmp / "dirty_repo_snapshot.json"
        dirty_repo_snapshot_payload = repo_audit_plan_payload()
        dirty_repo_snapshot_payload["repo_snapshot_lock_rows"][0]["clean_worktree_actual"] = 0
        dirty_repo_snapshot_payload["repo_snapshot_lock_sha256"] = sha256_json(
            dirty_repo_snapshot_payload["repo_snapshot_lock_rows"]
        )
        write_json(dirty_repo_snapshot, dirty_repo_snapshot_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(dirty_repo_snapshot),
            "--out-json",
            str(tmp / "dirty_repo_snapshot_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_snapshot_lock_rows row 1: clean_worktree_actual must be 1" in proc.stderr

        mismatched_repo_snapshot_head = tmp / "mismatched_repo_snapshot_head.json"
        mismatched_repo_snapshot_head_payload = repo_audit_plan_payload()
        mismatched_repo_snapshot_head_payload["repo_snapshot_lock_rows"][0]["actual_repo_git_head"] = fake_git_head(777)
        mismatched_repo_snapshot_head_payload["repo_snapshot_lock_sha256"] = sha256_json(
            mismatched_repo_snapshot_head_payload["repo_snapshot_lock_rows"]
        )
        write_json(mismatched_repo_snapshot_head, mismatched_repo_snapshot_head_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(mismatched_repo_snapshot_head),
            "--out-json",
            str(tmp / "mismatched_repo_snapshot_head_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_snapshot_lock_rows row 1: expected_repo_git_head must match actual_repo_git_head" in proc.stderr

        mismatched_repo_audit_mode = tmp / "mismatched_repo_audit_mode.json"
        mismatched_repo_audit_mode_payload = repo_audit_plan_payload()
        mismatched_repo_audit_mode_payload["repo_snapshot_lock_rows"][0]["audit_mode"] = "full"
        mismatched_repo_audit_mode_payload["repo_snapshot_lock_sha256"] = sha256_json(
            mismatched_repo_audit_mode_payload["repo_snapshot_lock_rows"]
        )
        write_json(mismatched_repo_audit_mode, mismatched_repo_audit_mode_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(mismatched_repo_audit_mode),
            "--out-json",
            str(tmp / "mismatched_repo_audit_mode_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: per_repo audit_mode must match repo_snapshot_lock_rows" in proc.stderr

        mismatched_repo_plan_head = tmp / "mismatched_repo_plan_head.json"
        mismatched_repo_plan_head_payload = repo_audit_plan_payload()
        mismatched_repo_plan_head_payload["per_repo"][0]["actual_repo_git_head"] = fake_git_head(778)
        write_json(mismatched_repo_plan_head, mismatched_repo_plan_head_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(mismatched_repo_plan_head),
            "--out-json",
            str(tmp / "mismatched_repo_plan_head_status.json"),
        )
        assert proc.returncode == 1
        assert "repo_audit_plan: per_repo actual_repo_git_head must match repo_snapshot_lock_rows" in proc.stderr

        stale_repo_to_label = tmp / "stale_repo_to_label.json"
        stale_repo_to_label_payload = label_intake_plan_payload()
        stale_repo_to_label_payload["repo_snapshot_lock_sha256"] = fake_sha(997)
        write_json(stale_repo_to_label, stale_repo_to_label_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(stale_repo_to_label),
            "--out-json",
            str(tmp / "stale_repo_to_label_status.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_plan: repo_snapshot_lock_sha256 must match repo_audit_plan" in proc.stderr

        stale_repo_to_preflight = tmp / "stale_repo_to_preflight.json"
        stale_repo_to_preflight_payload = {
            "schema": "amr_beta_runtime_preflight.v1",
            "ready_to_request_runtime_approval": 1,
            **path_guard_payload(),
            **binding_payload(),
            **base_blocked(),
        }
        stale_repo_to_preflight_payload["repo_intake_sha256"] = fake_sha(996)
        stale_repo_to_preflight_payload["preflight_input_bundle_sha256"] = sha256_json(
            {
                "repo_intake_sha256": stale_repo_to_preflight_payload["repo_intake_sha256"],
                "repo_snapshot_lock_sha256": stale_repo_to_preflight_payload["repo_snapshot_lock_sha256"],
                "decisions_sha256": stale_repo_to_preflight_payload["decisions_sha256"],
                "feedback_sha256": stale_repo_to_preflight_payload["feedback_sha256"],
                "label_template_bundle_sha256": stale_repo_to_preflight_payload["label_template_bundle_sha256"],
                "label_intake_bundle_sha256": stale_repo_to_preflight_payload["label_intake_bundle_sha256"],
            }
        )
        write_json(stale_repo_to_preflight, stale_repo_to_preflight_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--runtime-preflight",
            str(stale_repo_to_preflight),
            "--out-json",
            str(tmp / "stale_repo_to_preflight_status.json"),
        )
        assert proc.returncode == 1
        assert "runtime_preflight: repo_intake_sha256 must match repo_audit_plan" in proc.stderr

        low_label_count = tmp / "low_label_count.json"
        low_label_count_payload = label_intake_plan_payload()
        low_label_count_payload["valid_human_label_rows"] = 299
        write_json(low_label_count, low_label_count_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(low_label_count),
            "--out-json",
            str(tmp / "low_label_count_status.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_plan: valid_human_label_rows must be >= 300" in proc.stderr

        missing_label_commands = tmp / "missing_label_commands.json"
        missing_label_commands_payload = label_intake_plan_payload()
        del missing_label_commands_payload["operator_commands"]
        write_json(missing_label_commands, missing_label_commands_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(missing_label_commands),
            "--out-json",
            str(tmp / "missing_label_commands_status.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_plan: operator_commands must be a non-empty string list" in proc.stderr

        stale_label_commands_hash = tmp / "stale_label_commands_hash.json"
        stale_label_commands_hash_payload = label_intake_plan_payload()
        stale_label_commands_hash_payload["operator_commands_sha256"] = fake_sha(995)
        write_json(stale_label_commands_hash, stale_label_commands_hash_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(stale_label_commands_hash),
            "--out-json",
            str(tmp / "stale_label_commands_hash_status.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_plan: operator_commands_sha256 must match operator_commands" in proc.stderr

        extra_label_command = tmp / "extra_label_command.json"
        extra_label_command_payload = label_intake_plan_payload()
        extra_label_command_payload["operator_commands"].append("python3 scripts/unexpected_operator_command.py")
        extra_label_command_payload["operator_command_count"] = len(extra_label_command_payload["operator_commands"])
        extra_label_command_payload["operator_commands_sha256"] = sha256_json(
            extra_label_command_payload["operator_commands"]
        )
        write_json(extra_label_command, extra_label_command_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(extra_label_command),
            "--out-json",
            str(tmp / "extra_label_command_status.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_plan: operator_commands must exactly match per_case" in proc.stderr

        incomplete_label_decisions = tmp / "incomplete_label_decisions.json"
        incomplete_label_decisions_payload = label_intake_plan_payload()
        incomplete_label_decisions_payload["candidate_label_rows"] = 301
        write_json(incomplete_label_decisions, incomplete_label_decisions_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(incomplete_label_decisions),
            "--out-json",
            str(tmp / "incomplete_label_decisions_status.json"),
        )
        assert proc.returncode == 1
        assert (
            "candidate_label_rows, decision_rows, valid_human_label_rows, "
            "and non_synthetic_valid_human_label_rows must match"
        ) in proc.stderr

        synthetic_label_artifact = tmp / "synthetic_label_artifact.json"
        synthetic_label_artifact_payload = label_intake_plan_payload()
        synthetic_label_artifact_payload["synthetic_candidate_rows"] = 1
        synthetic_label_artifact_payload["non_synthetic_candidate_rows"] = 299
        synthetic_label_artifact_payload["non_synthetic_valid_human_label_rows"] = 299
        synthetic_label_artifact_payload["human_label_requirement_met"] = 0
        synthetic_label_artifact_payload["human_labels_remaining_to_minimum"] = 1
        write_json(synthetic_label_artifact, synthetic_label_artifact_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(synthetic_label_artifact),
            "--out-json",
            str(tmp / "synthetic_label_artifact_status.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_plan: non_synthetic_valid_human_label_rows must be >= 300" in proc.stderr
        assert "label_intake_plan: must set human_label_requirement_met=1" in proc.stderr
        assert "label_intake_plan: human_labels_remaining_to_minimum must be 0" in proc.stderr
        assert "label_intake_plan: synthetic_candidate_rows must be 0" in proc.stderr

        empty_template_fingerprints = tmp / "empty_template_fingerprints.json"
        empty_template_fingerprints_payload = label_intake_plan_payload()
        empty_template_fingerprints_payload["label_template_fingerprints"] = []
        empty_template_fingerprints_payload["label_template_json_sha256s"] = []
        empty_template_fingerprints_payload["label_template_manifest_sha256s"] = []
        empty_template_fingerprints_payload["label_template_bundle_sha256"] = sha256_json([])
        write_json(empty_template_fingerprints, empty_template_fingerprints_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(empty_template_fingerprints),
            "--out-json",
            str(tmp / "empty_template_fingerprints_status.json"),
        )
        assert proc.returncode == 1
        assert "label_template_fingerprints length must match case_count" in proc.stderr

        skipped_template_verify = tmp / "skipped_template_verify.json"
        skipped_template_verify_payload = label_intake_plan_payload()
        skipped_template_verify_payload["label_template_verify_existing_required"] = 0
        write_json(skipped_template_verify, skipped_template_verify_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(skipped_template_verify),
            "--out-json",
            str(tmp / "skipped_template_verify_status.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_plan: must set label_template_verify_existing_required=1" in proc.stderr

        mismatched_label_cases = tmp / "mismatched_label_cases.json"
        mismatched_label_cases_payload = label_intake_plan_payload()
        mismatched_label_cases_payload["per_case"][0]["case_id"] = "other-case"
        write_json(mismatched_label_cases, mismatched_label_cases_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(mismatched_label_cases),
            "--out-json",
            str(tmp / "mismatched_label_cases_status.json"),
        )
        assert proc.returncode == 1
        assert "label_intake_plan: per_case case_id set must match repo_audit_plan" in proc.stderr

        stale_label_preflight = tmp / "stale_label_preflight.json"
        stale_label_preflight_payload = {
            "schema": "amr_beta_runtime_preflight.v1",
            "ready_to_request_runtime_approval": 1,
            **path_guard_payload(),
            **binding_payload(),
            **base_blocked(),
        }
        stale_label_preflight_payload["decisions_sha256"] = fake_sha(993)
        stale_label_preflight_payload["preflight_input_bundle_sha256"] = sha256_json(
            {
                "repo_intake_sha256": stale_label_preflight_payload["repo_intake_sha256"],
                "repo_snapshot_lock_sha256": stale_label_preflight_payload["repo_snapshot_lock_sha256"],
                "decisions_sha256": stale_label_preflight_payload["decisions_sha256"],
                "feedback_sha256": stale_label_preflight_payload["feedback_sha256"],
                "label_template_bundle_sha256": stale_label_preflight_payload["label_template_bundle_sha256"],
                "label_intake_bundle_sha256": stale_label_preflight_payload["label_intake_bundle_sha256"],
            }
        )
        write_json(stale_label_preflight, stale_label_preflight_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--runtime-preflight",
            str(stale_label_preflight),
            "--out-json",
            str(tmp / "stale_label_preflight_status.json"),
        )
        assert proc.returncode == 1
        assert "runtime_preflight: decisions_sha256 must match label_intake_plan" in proc.stderr

        low_feedback_count = tmp / "low_feedback_count.json"
        low_feedback_count_payload = maintainer_feedback_packet_payload()
        low_feedback_count_payload["distinct_countable_maintainer_id_count"] = 2
        write_json(low_feedback_count, low_feedback_count_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(low_feedback_count),
            "--out-json",
            str(tmp / "low_feedback_count_status.json"),
        )
        assert proc.returncode == 1
        assert (
            "maintainer_feedback_packet: distinct_countable_maintainer_id_count must be >= 3"
            in proc.stderr
        )

        stale_feedback_precheck = tmp / "stale_feedback_precheck.json"
        stale_feedback_precheck_payload = maintainer_feedback_packet_payload()
        stale_feedback_precheck_payload["feedback_counts_for_beta_precheck"] = 0
        write_json(stale_feedback_precheck, stale_feedback_precheck_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(stale_feedback_precheck),
            "--out-json",
            str(tmp / "stale_feedback_precheck_status.json"),
        )
        assert proc.returncode == 1
        assert "maintainer_feedback_packet: must set feedback_counts_for_beta_precheck=1" in proc.stderr

        stale_feedback_snapshot = tmp / "stale_feedback_snapshot.json"
        stale_feedback_snapshot_payload = maintainer_feedback_packet_payload()
        stale_feedback_snapshot_payload["repo_snapshot_lock_sha256"] = fake_sha(994)
        write_json(stale_feedback_snapshot, stale_feedback_snapshot_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(stale_feedback_snapshot),
            "--out-json",
            str(tmp / "stale_feedback_snapshot_status.json"),
        )
        assert proc.returncode == 1
        assert "maintainer_feedback_packet: repo_snapshot_lock_sha256 must match repo_audit_plan" in proc.stderr

        missing_feedback_label_context = tmp / "missing_feedback_label_context.json"
        missing_feedback_label_context_payload = maintainer_feedback_packet_payload()
        del missing_feedback_label_context_payload["label_intake_dir_count"]
        write_json(missing_feedback_label_context, missing_feedback_label_context_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(missing_feedback_label_context),
            "--out-json",
            str(tmp / "missing_feedback_label_context_status.json"),
        )
        assert proc.returncode == 1
        assert "maintainer_feedback_packet: label_intake_dir_count must be an integer >= 1" in proc.stderr

        skipped_feedback_label_verify = tmp / "skipped_feedback_label_verify.json"
        skipped_feedback_label_verify_payload = maintainer_feedback_packet_payload()
        skipped_feedback_label_verify_payload["label_intake_verify_existing_required"] = 0
        write_json(skipped_feedback_label_verify, skipped_feedback_label_verify_payload)
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--label-intake-plan",
            str(label),
            "--maintainer-feedback-packet",
            str(skipped_feedback_label_verify),
            "--out-json",
            str(tmp / "skipped_feedback_label_verify_status.json"),
        )
        assert proc.returncode == 1
        assert "maintainer_feedback_packet: must set label_intake_verify_existing_required=1" in proc.stderr

        bad_readiness = tmp / "bad_readiness.json"
        write_json(
            bad_readiness,
            {
                "schema_version": "local_repo_audit_benchmark_readiness.v1",
                "real_human_label_basis": 0,
                "design_partner_beta_candidate_ready": 1,
                "release_ready": 0,
                "public_comparison_claim_ready": 0,
                "real_model_execution_ready": 0,
            },
        )
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--benchmark-readiness",
            str(bad_readiness),
            "--out-json",
            str(tmp / "bad_readiness_status.json"),
        )
        assert proc.returncode == 1
        assert "product_readiness_calculated_from_real_labels" in proc.stderr

        bad_ready_flag = tmp / "bad_ready_flag.json"
        write_json(
            bad_ready_flag,
            {
                "schema_version": "local_repo_audit_benchmark_readiness.v1",
                "product_readiness_calculated_from_real_labels": 1,
                "design_partner_beta_candidate_ready": 2,
                "release_ready": 0,
                "public_comparison_claim_ready": 0,
                "real_model_execution_ready": 0,
            },
        )
        proc = run_tool(
            "--repo-audit-plan",
            str(repo),
            "--benchmark-readiness",
            str(bad_ready_flag),
            "--out-json",
            str(tmp / "bad_ready_flag_status.json"),
        )
        assert proc.returncode == 1
        assert "design_partner_beta_candidate_ready must be one of [0, 1]" in proc.stderr

    print("AMR beta operator status smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
