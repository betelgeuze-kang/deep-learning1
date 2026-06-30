#!/usr/bin/env python3
"""Smoke tests for scripts/amr_beta_operator_status.py."""
from __future__ import annotations

import hashlib
import json
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


def fake_sha(seed: int) -> str:
    return "sha256:" + f"{seed:064x}"[-64:]


def binding_payload() -> dict:
    template_fingerprints = [
        {
            "label_template_json_sha256": fake_sha(100),
            "label_template_manifest_sha256": fake_sha(200),
        },
        {
            "label_template_json_sha256": fake_sha(101),
            "label_template_manifest_sha256": fake_sha(201),
        },
    ]
    label_intake_fingerprints = [
        {"label_intake_manifest_sha256": fake_sha(300)},
        {"label_intake_manifest_sha256": fake_sha(301)},
    ]
    label_template_bundle_sha256 = sha256_json(template_fingerprints)
    label_intake_bundle_sha256 = sha256_json(label_intake_fingerprints)
    input_bundle = {
        "repo_intake_sha256": fake_sha(1),
        "repo_snapshot_lock_sha256": fake_sha(2),
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
        "repo_snapshot_lock_sha256": fake_sha(2),
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
            {
                "schema": "amr_beta_repo_audit_plan.v1",
                "ready_for_real_benchmark_audit_plan": 1,
                **base_blocked(),
            },
        )
        write_json(
            label,
            {
                "schema": "amr_beta_label_intake_plan.v1",
                "ready_for_label_intake_plan": 1,
                **base_blocked(),
            },
        )
        write_json(
            feedback,
            {
                "schema": "amr_beta_maintainer_feedback_packet.v1",
                "ready_for_runtime_preflight_feedback": 1,
                **base_blocked(),
            },
        )
        write_json(
            preflight,
            {
                "schema": "amr_beta_runtime_preflight.v1",
                "ready_to_request_runtime_approval": 1,
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
        markdown = out_md.read_text(encoding="utf-8")
        assert "current_stage: stage_4_runtime_approval_verified" in markdown
        assert "preflight_input_bundle_sha256: sha256:" in markdown
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
        bad_payload = {
            "schema": "amr_beta_repo_audit_plan.v1",
            "ready_for_real_benchmark_audit_plan": 1,
            **base_blocked(),
        }
        bad_payload["release_ready"] = 1
        write_json(bad_repo, bad_payload)
        proc = run_tool("--repo-audit-plan", str(bad_repo), "--out-json", str(tmp / "bad_status.json"))
        assert proc.returncode == 1
        assert "must keep release_ready=0" in proc.stderr
        assert not (tmp / "bad_status.json").exists()

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
