#!/usr/bin/env python3
"""Regression tests for AMR beta .env-like path guards."""
from __future__ import annotations

import importlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent

GUARDED_MODULES = [
    "audit_my_repo_label_template",
    "audit_my_repo_label_intake",
    "amr_beta_benchmark_input_prepare",
    "amr_beta_hardening_analyze",
    "amr_beta_human_input_status",
    "amr_beta_label_intake_plan",
    "amr_beta_label_packet",
    "amr_beta_maintainer_feedback_packet",
    "amr_beta_operator_status",
    "amr_beta_pr_cleanup_status",
    "amr_beta_readiness_backlog",
    "amr_beta_repo_audit_plan",
    "amr_beta_repo_discovery_request",
    "amr_beta_repo_discovery_response",
    "amr_beta_repo_intake_collect",
    "amr_beta_repo_intake_discover",
    "amr_beta_repo_intake_validate",
    "amr_beta_runtime_approval_request",
    "amr_beta_runtime_approval_status",
    "amr_beta_runtime_preflight",
]


def module_path(module_name: str) -> Path:
    return ROOT / "scripts" / f"{module_name}.py"


def assert_guard_uses_path_components(module_name: str) -> None:
    source = module_path(module_name).read_text(encoding="utf-8")
    assert "def is_forbidden_env_path" in source, module_name
    assert "name = path.name" not in source, f"{module_name} uses basename-only env guard"


def assert_guard_behavior(module_name: str) -> None:
    module = importlib.import_module(module_name)
    guard = getattr(module, "is_forbidden_env_path")
    forbidden_paths = [
        Path(".env") / "artifact.json",
        Path(".env.secrets") / "artifact.json",
        Path("/tmp") / ".env.secrets" / "artifact.json",
        Path("/tmp") / "repo.env" / "artifact.json",
        Path("/tmp") / "repo.env.local" / "artifact.json",
        Path("/tmp") / "repo" / "artifact.env",
    ]
    allowed_paths = [
        Path("artifact.json"),
        Path("/tmp") / "repo_env" / "artifact.json",
        Path("/tmp") / "repo" / "artifact.json",
    ]
    for path in forbidden_paths:
        assert guard(path), f"{module_name} allowed .env-like component path: {path}"
    for path in allowed_paths:
        assert not guard(path), f"{module_name} rejected non-.env path: {path}"


def main() -> int:
    for module_name in GUARDED_MODULES:
        assert_guard_uses_path_components(module_name)
        assert_guard_behavior(module_name)
    print("AMR beta env path guard regression smoke OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
