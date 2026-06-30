#!/usr/bin/env python3
"""Summarize AMR beta operator stage from existing local artifacts.

This is a read-only PM/operator status helper. It consumes optional AMR beta
artifact JSON files and reports the latest proven stage plus next blockers.

It does not create benchmark evidence, does not run benchmarks, does not read
raw feedback text, and does not promote release/model/public-comparison claims.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

SCHEMA = "amr_beta_operator_status.v1"
APPROVAL_SCOPE = "amr_beta_real_benchmark_runtime"
BLOCKED_FLAGS = {
    "release_ready": 0,
    "public_comparison_claim_ready": 0,
    "real_model_execution_ready": 0,
}
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
KNOWN_ARTIFACTS = {
    "repo_audit_plan": "amr_beta_repo_audit_plan.v1",
    "label_intake_plan": "amr_beta_label_intake_plan.v1",
    "maintainer_feedback_packet": "amr_beta_maintainer_feedback_packet.v1",
    "runtime_preflight": "amr_beta_runtime_preflight.v1",
    "runtime_approval_request": "amr_beta_runtime_approval_request.v1",
    "runtime_approval_status": "amr_beta_runtime_approval_status.v1",
    "readiness_backlog": "amr_beta_readiness_backlog.v1",
}
STAGE_ORDER = [
    "stage_0_claim_freeze",
    "stage_1_repo_intake_plan_ready",
    "stage_2_label_intake_plan_ready",
    "stage_3_maintainer_feedback_ready",
    "stage_4_runtime_preflight_ready",
    "stage_4_runtime_approval_verified",
    "stage_4_real_benchmark_verified",
    "stage_5_beta_candidate_or_hardening",
]
PREFLIGHT_SHA_BINDING_KEYS = [
    "repo_intake_sha256",
    "repo_snapshot_lock_sha256",
    "decisions_sha256",
    "feedback_sha256",
    "label_template_bundle_sha256",
    "label_intake_bundle_sha256",
    "preflight_input_bundle_sha256",
]
PREFLIGHT_LIST_BINDING_KEYS = [
    "label_template_json_sha256s",
    "label_template_manifest_sha256s",
    "label_intake_manifest_sha256s",
]
PREFLIGHT_PATH_GUARD_KEYS = [
    "input_path_preflight_passed",
    "output_path_preflight_passed",
]


def is_forbidden_env_path(path: Path) -> bool:
    name = path.name
    return name == ".env" or name.startswith(".env.") or name.endswith(".env") or ".env." in name


def sha256_file(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def sha256_json(payload: object) -> str:
    data = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return "sha256:" + hashlib.sha256(data).hexdigest()


def same_path(left: str, right: str) -> bool:
    if not left or not right:
        return False
    return str(Path(left).expanduser().resolve()) == str(Path(right).expanduser().resolve())


def read_json(path: Path, input_name: str) -> dict:
    if is_forbidden_env_path(path):
        raise ValueError(f"refusing to read .env-like {input_name} path")
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"{input_name} must contain an object")
    return payload


def artifact_schema(payload: dict) -> str:
    return str(payload.get("schema") or payload.get("schema_version") or "")


def truthy_int(payload: dict, key: str) -> int:
    try:
        return int(payload.get(key, 0))
    except (TypeError, ValueError):
        return 0


def strict_int_flag_errors(name: str, payload: dict, keys: list[str], allowed: set[int]) -> list[str]:
    errors: list[str] = []
    for key in keys:
        raw = payload.get(key, 0)
        try:
            value = int(raw)
        except (TypeError, ValueError):
            errors.append(f"{name}: {key} must be one of {sorted(allowed)}")
            continue
        if value not in allowed:
            errors.append(f"{name}: {key} must be one of {sorted(allowed)}")
    return errors


def artifact_claim_errors(name: str, payload: dict) -> list[str]:
    claim_keys = list(BLOCKED_FLAGS)
    errors = strict_int_flag_errors(name, payload, claim_keys, {0, 1})
    for key, expected in BLOCKED_FLAGS.items():
        if truthy_int(payload, key) != expected:
            errors.append(f"{name}: must keep {key}=0")
    if name != "benchmark_readiness" and truthy_int(payload, "design_partner_beta_candidate_ready") != 0:
        errors.append(f"{name}: must not promote design_partner_beta_candidate_ready")
    return errors


def load_optional(path_text: str, name: str) -> tuple[dict | None, dict | None, list[str]]:
    if not path_text:
        return None, None, []
    path = Path(path_text).expanduser().resolve()
    try:
        payload = read_json(path, name)
    except Exception as exc:
        return None, None, [f"{name}: {exc}"]
    meta = {
        "path": str(path),
        "sha256": sha256_file(path),
        "schema": artifact_schema(payload),
    }
    errors: list[str] = []
    expected_schema = KNOWN_ARTIFACTS.get(name)
    if expected_schema and meta["schema"] != expected_schema:
        errors.append(f"{name}: unexpected schema {meta['schema']!r}")
    errors.extend(artifact_claim_errors(name, payload))
    raw_errors = payload.get("errors", [])
    if raw_errors:
        errors.append(f"{name}: artifact contains errors")
    return payload, meta, errors


def benchmark_readiness_errors(payload: dict) -> list[str]:
    errors = artifact_claim_errors("benchmark_readiness", payload)
    errors.extend(
        strict_int_flag_errors("benchmark_readiness", payload, ["design_partner_beta_candidate_ready"], {0, 1})
    )
    if payload.get("schema_version") != "local_repo_audit_benchmark_readiness.v1":
        errors.append("benchmark_readiness: unexpected schema_version")
    real_label_basis = int(
        truthy_int(payload, "real_human_label_basis") == 1
        or truthy_int(payload, "product_readiness_calculated_from_real_labels") == 1
    )
    if real_label_basis != 1:
        errors.append(
            "benchmark_readiness: product_readiness_calculated_from_real_labels "
            "or real_human_label_basis must be 1 for real benchmark evidence"
        )
    return errors


def load_benchmark_readiness(path_text: str) -> tuple[dict | None, dict | None, list[str]]:
    if not path_text:
        return None, None, []
    path = Path(path_text).expanduser().resolve()
    try:
        payload = read_json(path, "benchmark_readiness")
    except Exception as exc:
        return None, None, [f"benchmark_readiness: {exc}"]
    meta = {
        "path": str(path),
        "sha256": sha256_file(path),
        "schema": artifact_schema(payload),
    }
    return payload, meta, benchmark_readiness_errors(payload)


def require_flag(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    key: str,
    expected: int,
) -> None:
    if key not in payload:
        errors.append(f"{name}: {key} must be present as an integer or boolean flag")
        return
    raw = payload.get(key)
    if isinstance(raw, bool):
        value = int(raw)
    elif isinstance(raw, int):
        value = raw
    else:
        errors.append(f"{name}: {key} must be an integer or boolean flag")
        return
    if value not in {0, 1}:
        errors.append(f"{name}: {key} must be one of [0, 1]")
        return
    if value != expected:
        errors.append(f"{name}: must set {key}={expected}")


def require_bound_path(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    field: str,
    expected_path: str,
) -> None:
    value = str(payload.get(field) or "")
    if not same_path(value, expected_path):
        errors.append(f"{name}: {field} must match supplied artifact path")


def require_bound_sha(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    field: str,
    expected_sha: str,
) -> None:
    value = str(payload.get(field) or "")
    if value != expected_sha:
        errors.append(f"{name}: {field} must match supplied artifact sha256")


def require_sha_field(*, errors: list[str], name: str, payload: dict, field: str) -> None:
    value = str(payload.get(field) or "")
    if not SHA256_RE.fullmatch(value):
        errors.append(f"{name}: {field} must be a sha256 binding")


def require_sha_list_field(*, errors: list[str], name: str, payload: dict, field: str) -> None:
    values = payload.get(field)
    if not isinstance(values, list):
        errors.append(f"{name}: {field} must be a sha256 binding list")
        return
    for value in values:
        text = str(value or "")
        if not SHA256_RE.fullmatch(text):
            errors.append(f"{name}: {field} must contain only sha256 bindings")
            return


def require_matching_field(
    *,
    errors: list[str],
    name: str,
    payload: dict,
    field: str,
    expected: object,
) -> None:
    if payload.get(field) != expected:
        errors.append(f"{name}: {field} must match runtime_preflight")


def preflight_count(preflight: dict, key: str, errors: list[str]) -> int:
    try:
        return int(preflight.get(key, -1))
    except (TypeError, ValueError):
        errors.append(f"runtime_preflight: {key} must be an integer")
        return -1


def runtime_fingerprint_bundle_errors(preflight: dict) -> list[str]:
    errors: list[str] = []
    template_fingerprints = preflight.get("label_template_fingerprints")
    if not isinstance(template_fingerprints, list):
        errors.append("runtime_preflight: label_template_fingerprints must be a list")
        template_fingerprints = []
    if len(template_fingerprints) != preflight_count(preflight, "template_dir_count", errors):
        errors.append("runtime_preflight: label_template_fingerprints length must equal template_dir_count")
    template_json_sha256s = [
        str(row.get("label_template_json_sha256") or "")
        for row in template_fingerprints
        if isinstance(row, dict)
    ]
    template_manifest_sha256s = [
        str(row.get("label_template_manifest_sha256") or "")
        for row in template_fingerprints
        if isinstance(row, dict) and str(row.get("label_template_manifest_sha256") or "")
    ]
    if preflight.get("label_template_json_sha256s") != template_json_sha256s:
        errors.append("runtime_preflight: label_template_json_sha256s must match label_template_fingerprints")
    if preflight.get("label_template_manifest_sha256s") != template_manifest_sha256s:
        errors.append("runtime_preflight: label_template_manifest_sha256s must match label_template_fingerprints")
    if str(preflight.get("label_template_bundle_sha256") or "") != sha256_json(template_fingerprints):
        errors.append("runtime_preflight: label_template_bundle_sha256 does not match label_template_fingerprints")

    label_intake_fingerprints = preflight.get("label_intake_fingerprints")
    if not isinstance(label_intake_fingerprints, list):
        errors.append("runtime_preflight: label_intake_fingerprints must be a list")
        label_intake_fingerprints = []
    if len(label_intake_fingerprints) != preflight_count(preflight, "label_intake_dir_count", errors):
        errors.append("runtime_preflight: label_intake_fingerprints length must equal label_intake_dir_count")
    label_intake_manifest_sha256s = [
        str(row.get("label_intake_manifest_sha256") or "")
        for row in label_intake_fingerprints
        if isinstance(row, dict)
    ]
    if preflight.get("label_intake_manifest_sha256s") != label_intake_manifest_sha256s:
        errors.append("runtime_preflight: label_intake_manifest_sha256s must match label_intake_fingerprints")
    if str(preflight.get("label_intake_bundle_sha256") or "") != sha256_json(label_intake_fingerprints):
        errors.append("runtime_preflight: label_intake_bundle_sha256 does not match label_intake_fingerprints")

    input_bundle = {
        "repo_intake_sha256": str(preflight.get("repo_intake_sha256") or ""),
        "repo_snapshot_lock_sha256": str(preflight.get("repo_snapshot_lock_sha256") or ""),
        "decisions_sha256": str(preflight.get("decisions_sha256") or ""),
        "feedback_sha256": str(preflight.get("feedback_sha256") or ""),
        "label_template_bundle_sha256": str(preflight.get("label_template_bundle_sha256") or ""),
        "label_intake_bundle_sha256": str(preflight.get("label_intake_bundle_sha256") or ""),
    }
    if str(preflight.get("preflight_input_bundle_sha256") or "") != sha256_json(input_bundle):
        errors.append("runtime_preflight: preflight_input_bundle_sha256 does not match input fingerprints")
    return errors


def runtime_fingerprint_errors(artifacts: dict[str, dict | None]) -> list[str]:
    errors: list[str] = []
    preflight = artifacts.get("runtime_preflight")
    request = artifacts.get("runtime_approval_request")
    status = artifacts.get("runtime_approval_status")
    if not preflight:
        return errors

    for key in PREFLIGHT_SHA_BINDING_KEYS:
        require_sha_field(errors=errors, name="runtime_preflight", payload=preflight, field=key)
    for key in PREFLIGHT_LIST_BINDING_KEYS:
        require_sha_list_field(errors=errors, name="runtime_preflight", payload=preflight, field=key)
    errors.extend(runtime_fingerprint_bundle_errors(preflight))

    for name, payload in [
        ("runtime_approval_request", request),
        ("runtime_approval_status", status),
    ]:
        if not payload:
            continue
        for key in PREFLIGHT_SHA_BINDING_KEYS:
            require_matching_field(
                errors=errors,
                name=name,
                payload=payload,
                field=key,
                expected=preflight.get(key),
            )
        for key in PREFLIGHT_LIST_BINDING_KEYS:
            require_matching_field(
                errors=errors,
                name=name,
                payload=payload,
                field=key,
                expected=preflight.get(key),
            )
    return errors


def artifact_chain_errors(artifacts: dict[str, dict | None], metas: dict[str, dict]) -> list[str]:
    errors: list[str] = []
    preflight = artifacts.get("runtime_preflight")
    request = artifacts.get("runtime_approval_request")
    status = artifacts.get("runtime_approval_status")
    benchmark = artifacts.get("benchmark_readiness")

    if request and not preflight:
        errors.append("runtime_approval_request: runtime_preflight is required")
    if status and not request:
        errors.append("runtime_approval_status: runtime_approval_request is required")
    if status and not preflight:
        errors.append("runtime_approval_status: runtime_preflight is required")
    if benchmark and not status:
        errors.append("benchmark_readiness: runtime_approval_status is required")

    if preflight:
        for key in PREFLIGHT_PATH_GUARD_KEYS:
            require_flag(errors=errors, name="runtime_preflight", payload=preflight, key=key, expected=1)

    if preflight and request:
        preflight_meta = metas["runtime_preflight"]
        require_bound_path(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            field="input_preflight",
            expected_path=str(preflight_meta["path"]),
        )
        require_bound_sha(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            field="input_preflight_sha256",
            expected_sha=str(preflight_meta["sha256"]),
        )
        require_flag(errors=errors, name="runtime_approval_request", payload=request, key="approved_by_human", expected=0)
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="approval_record_supplied",
            expected=0,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="requires_human_runtime_approval",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="benchmark_runtime_approval_required",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="creates_benchmark_evidence",
            expected=0,
        )
        require_flag(errors=errors, name="runtime_approval_request", payload=request, key="runs_benchmark", expected=0)
        for key in PREFLIGHT_PATH_GUARD_KEYS:
            require_matching_field(
                errors=errors,
                name="runtime_approval_request",
                payload=request,
                field=key,
                expected=preflight.get(key),
            )
            require_flag(errors=errors, name="runtime_approval_request", payload=request, key=key, expected=1)
        require_flag(
            errors=errors,
            name="runtime_approval_request",
            payload=request,
            key="output_path_guard_passed",
            expected=1,
        )

    if preflight and request and status:
        preflight_meta = metas["runtime_preflight"]
        request_meta = metas["runtime_approval_request"]
        require_bound_path(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="input_preflight",
            expected_path=str(preflight_meta["path"]),
        )
        require_bound_sha(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="input_preflight_sha256",
            expected_sha=str(preflight_meta["sha256"]),
        )
        require_bound_path(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="approval_request",
            expected_path=str(request_meta["path"]),
        )
        require_bound_sha(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="approval_request_sha256",
            expected_sha=str(request_meta["sha256"]),
        )
        require_flag(errors=errors, name="runtime_approval_status", payload=status, key="approved_by_human", expected=1)
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="approval_record_supplied",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="human_runtime_approval_record_verified",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="ready_for_human_operator_benchmark_run",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="benchmark_runtime_approval_required",
            expected=1,
        )
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="creates_benchmark_evidence",
            expected=0,
        )
        require_flag(errors=errors, name="runtime_approval_status", payload=status, key="runs_benchmark", expected=0)
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="codex_runtime_permission_granted_by_this_packet",
            expected=0,
        )
        for key in PREFLIGHT_PATH_GUARD_KEYS:
            require_matching_field(
                errors=errors,
                name="runtime_approval_status",
                payload=status,
                field=key,
                expected=preflight.get(key),
            )
            require_flag(errors=errors, name="runtime_approval_status", payload=status, key=key, expected=1)
        require_flag(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            key="approval_request_output_path_guard_passed",
            expected=1,
        )
        if str(status.get("approval_scope") or "") != APPROVAL_SCOPE:
            errors.append(f"runtime_approval_status: approval_scope must be {APPROVAL_SCOPE}")
        if not str(status.get("approval_record") or "").strip():
            errors.append("runtime_approval_status: approval_record is required")
        require_sha_field(
            errors=errors,
            name="runtime_approval_status",
            payload=status,
            field="approval_record_sha256",
        )

    if benchmark and status:
        benchmark_meta = metas["benchmark_readiness"]
        benchmark_out = str(status.get("benchmark_out") or "")
        if not benchmark_out:
            errors.append("runtime_approval_status: benchmark_out is required")
        else:
            expected_readiness = str(Path(benchmark_out).expanduser().resolve() / "benchmark_readiness.json")
            if not same_path(str(benchmark_meta["path"]), expected_readiness):
                errors.append(
                    "benchmark_readiness: path must match "
                    "runtime_approval_status benchmark_out/benchmark_readiness.json"
                )

    errors.extend(runtime_fingerprint_errors(artifacts))
    return errors


def compute_stage(artifacts: dict[str, dict | None], errors: list[str]) -> tuple[str, list[str]]:
    if errors:
        return "stage_0_claim_freeze", ["Resolve artifact validation errors before advancing."]
    repo = artifacts.get("repo_audit_plan")
    label = artifacts.get("label_intake_plan")
    feedback = artifacts.get("maintainer_feedback_packet")
    preflight = artifacts.get("runtime_preflight")
    approval_request = artifacts.get("runtime_approval_request")
    approval_status = artifacts.get("runtime_approval_status")
    benchmark = artifacts.get("benchmark_readiness")

    if not repo or truthy_int(repo, "ready_for_real_benchmark_audit_plan") != 1:
        return "stage_0_claim_freeze", ["Generate a clean repo audit plan from >=10 validated real repos."]
    if not label or truthy_int(label, "ready_for_label_intake_plan") != 1:
        return "stage_1_repo_intake_plan_ready", [
            "Run/verify repo audits and label templates, then generate a label-intake plan from human decisions."
        ]
    if not feedback or truthy_int(feedback, "ready_for_runtime_preflight_feedback") != 1:
        return "stage_2_label_intake_plan_ready", [
            "Collect >=3 countable maintainer feedback rows bound to human-labeled non-synthetic cases."
        ]
    if not preflight or truthy_int(preflight, "ready_to_request_runtime_approval") != 1:
        return "stage_3_maintainer_feedback_ready", [
            "Compile/verify label intake outputs and run the final runtime preflight."
        ]
    if not approval_request or truthy_int(approval_request, "requires_human_runtime_approval") != 1:
        return "stage_4_runtime_preflight_ready", [
            "Generate a runtime approval request from the green preflight."
        ]
    if not approval_status or truthy_int(approval_status, "human_runtime_approval_record_verified") != 1:
        return "stage_4_runtime_preflight_ready", [
            "Get and validate a human runtime approval record before the long benchmark."
        ]
    if not benchmark:
        return "stage_4_runtime_approval_verified", [
            "Human/operator may run the approved real_benchmark command and verify benchmark_readiness.json."
        ]
    if truthy_int(benchmark, "design_partner_beta_candidate_ready") == 1:
        return "stage_5_beta_candidate_or_hardening", [
            "Package design-partner beta materials while keeping release/public/model claims blocked."
        ]
    return "stage_4_real_benchmark_verified", [
        "Generate remediation backlog and hardening analysis for blocked benchmark readiness gates."
    ]


def write_json(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_markdown(path: Path, payload: dict, overwrite: bool) -> None:
    if is_forbidden_env_path(path):
        raise ValueError("refusing .env-like Markdown output path")
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and not overwrite:
        raise ValueError(f"output already exists; use --overwrite: {path}")
    lines = [
        "# AMR Beta Operator Status",
        "",
        f"- current_stage: {payload['current_stage']}",
        f"- creates_benchmark_evidence: {payload['creates_benchmark_evidence']}",
        f"- runs_benchmark: {payload['runs_benchmark']}",
        f"- design_partner_beta_candidate_ready: {payload['design_partner_beta_candidate_ready']}",
        f"- release_ready: {payload['release_ready']}",
        f"- public_comparison_claim_ready: {payload['public_comparison_claim_ready']}",
        f"- real_model_execution_ready: {payload['real_model_execution_ready']}",
        "",
        "## Next Blockers",
        "",
    ]
    lines.extend(f"- {blocker}" for blocker in payload["next_blockers"])
    lines.extend(["", "## Artifacts", ""])
    for name, meta in payload["artifacts"].items():
        lines.append(f"- {name}: {meta['path']} ({meta['schema']})")
    if payload.get("runtime_fingerprints"):
        lines.extend(["", "## Runtime Fingerprints", ""])
        for key, value in payload["runtime_fingerprints"].items():
            if isinstance(value, list):
                rendered = json.dumps(value, sort_keys=True)
            else:
                rendered = str(value)
            lines.append(f"- {key}: {rendered}")
    path.write_text("\n".join(lines).rstrip() + "\n", encoding="utf-8")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-audit-plan", default="")
    parser.add_argument("--label-intake-plan", default="")
    parser.add_argument("--maintainer-feedback-packet", default="")
    parser.add_argument("--runtime-preflight", default="")
    parser.add_argument("--runtime-approval-request", default="")
    parser.add_argument("--runtime-approval-status", default="")
    parser.add_argument("--benchmark-readiness", default="")
    parser.add_argument("--readiness-backlog", default="")
    parser.add_argument("--out-json", required=True)
    parser.add_argument("--out-md", default="")
    parser.add_argument("--overwrite", action="store_true")
    parser.add_argument("--json", action="store_true")
    return parser


def main(argv: list[str]) -> int:
    args = build_parser().parse_args(argv)
    artifact_args = {
        "repo_audit_plan": args.repo_audit_plan,
        "label_intake_plan": args.label_intake_plan,
        "maintainer_feedback_packet": args.maintainer_feedback_packet,
        "runtime_preflight": args.runtime_preflight,
        "runtime_approval_request": args.runtime_approval_request,
        "runtime_approval_status": args.runtime_approval_status,
        "readiness_backlog": args.readiness_backlog,
    }
    try:
        artifacts: dict[str, dict | None] = {}
        artifact_meta: dict[str, dict] = {}
        errors: list[str] = []
        for name, path_text in artifact_args.items():
            payload, meta, artifact_errors = load_optional(path_text, name)
            artifacts[name] = payload
            if meta:
                artifact_meta[name] = meta
            errors.extend(artifact_errors)
        benchmark, benchmark_meta, benchmark_errors = load_benchmark_readiness(args.benchmark_readiness)
        artifacts["benchmark_readiness"] = benchmark
        if benchmark_meta:
            artifact_meta["benchmark_readiness"] = benchmark_meta
        errors.extend(benchmark_errors)
        errors.extend(artifact_chain_errors(artifacts, artifact_meta))

        current_stage, next_blockers = compute_stage(artifacts, errors)
        benchmark_ready = int(
            current_stage == "stage_5_beta_candidate_or_hardening"
            and truthy_int(benchmark or {}, "design_partner_beta_candidate_ready") == 1
        )
        preflight = artifacts.get("runtime_preflight") or {}
        runtime_fingerprints = {
            key: str(preflight.get(key) or "")
            for key in PREFLIGHT_SHA_BINDING_KEYS
            if preflight.get(key)
        }
        runtime_fingerprints.update(
            {
                key: list(preflight.get(key, []))
                for key in PREFLIGHT_LIST_BINDING_KEYS
                if preflight.get(key)
            }
        )
        runtime_fingerprints.update(
            {
                key: int(preflight.get(key, 0))
                for key in PREFLIGHT_PATH_GUARD_KEYS
                if key in preflight
            }
        )
        payload = {
            "schema": SCHEMA,
            "current_stage": current_stage,
            "stage_order": STAGE_ORDER,
            "next_blockers": next_blockers,
            "artifacts": artifact_meta,
            "artifact_count": len(artifact_meta),
            "runtime_fingerprints": runtime_fingerprints,
            "creates_benchmark_evidence": 0,
            "runs_benchmark": 0,
            "design_partner_beta_candidate_ready": benchmark_ready,
            "release_ready": 0,
            "public_comparison_claim_ready": 0,
            "real_model_execution_ready": 0,
            "errors": errors,
        }
        if errors:
            if args.json:
                print(json.dumps(payload, indent=2, sort_keys=True))
            for error in errors:
                print(error, file=sys.stderr)
            return 1
        write_json(Path(args.out_json).expanduser().resolve(), payload, args.overwrite)
        if args.out_md:
            write_markdown(Path(args.out_md).expanduser().resolve(), payload, args.overwrite)
        if args.json:
            print(json.dumps(payload, indent=2, sort_keys=True))
        else:
            print(f"operator_status: ok current_stage={current_stage}")
        return 0
    except Exception as exc:
        print(f"operator_status: error: {exc}", file=sys.stderr)
        if args.json:
            print(json.dumps({"schema": SCHEMA, "errors": [str(exc)]}, indent=2, sort_keys=True))
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
