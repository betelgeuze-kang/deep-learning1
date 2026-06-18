#!/usr/bin/env python3
"""Shared fail-closed dependency blocker writer for v59 one-command demos."""

from __future__ import annotations

import csv
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


CONFIG = {
    "v59b": {
        "title": "v59b One-Command Candidate Dependency Blocker",
        "scope": "v59b-one-command-candidate-dependency-blocker",
        "ready_key": "v59b_one_command_candidate_demo_ready",
        "blocker_key": "v59b_dependency_blocker_ready",
        "rows_file": "v59b_dependency_blocker_rows.csv",
        "boundary_file": "V59B_ONE_COMMAND_CANDIDATE_DEPENDENCY_BLOCKER.md",
        "manifest_file": "v59b_one_command_candidate_demo_manifest.json",
        "required_for": "v59b-one-command-candidate-demo",
        "validation_command": "V59B_ALLOW_STAGE_REBUILD=1 V59B_REUSE_EXISTING=1 ./experiments/test_v59b_one_command_candidate_demo.sh",
        "summary": {
            "v59b_one_command_candidate_demo_ready": "0",
            "v59_ready": "0",
            "v59b_dependency_blocker_ready": "1",
            "candidate_stage_rows": "12",
            "candidate_ready_stage_rows": "0",
            "full_ready_stage_rows": "0",
            "one_command_candidate_entrypoint_ready": "1",
            "candidate_bundle_ready": "0",
            "network_required": "0",
            "external_model_required_for_candidate": "0",
            "real_llm_rows_required_for_full_v1": "1",
            "implicit_stage_rebuild_allowed": "0",
            "stage_rebuild_approval_required": "1",
            "network_or_download_approval_required": "1",
            "missing_real_30b_70b_rows": "1",
            "missing_100b_plus_real_row_or_final_deferral": "1",
            "missing_complete_source_audit": "1",
            "missing_human_domain_review": "1",
            "missing_human_blind_review": "1",
            "real_release_package_ready": "0",
        },
        "decision_rows": [
            ("dependency-blocker-artifact", "pass", "missing v59b candidate stage artifacts are recorded as replayable blockers"),
            ("one-command-candidate-entrypoint", "pass", "repository entrypoint exists but is not allowed to rebuild missing stages by default"),
            ("candidate-chain-replay", "blocked", "candidate chain replay requires missing stage artifacts"),
            ("candidate-bundle-hash-manifest", "pass", "dependency blocker packet is hash-bound"),
            ("claim-boundary-preserved", "pass", "missing candidate rows are not promoted as ready evidence"),
            ("30b-70b-real-rows", "blocked", "real D/E LLM+RAG answer and blind-response rows are missing"),
            ("100b-plus-real-row", "blocked", "optional F hosted/API row is missing or deferred"),
            ("complete-source-audit", "blocked", "v53 complete-source audit rows are missing"),
            ("human-domain-and-blind-review", "blocked", "human expert and blind-review rows are missing"),
            ("v59-full-one-command-demo", "blocked", "dependency blocker is not the full challenge demo"),
            ("real-release-package", "blocked", "dependency blocker is not a release package"),
        ],
        "blocked_wording": "v59b candidate demo ready, one-command challenge completion, or v1.0 release readiness",
    },
    "v59c": {
        "title": "v59c One-Command Measured Registry Dependency Blocker",
        "scope": "v59c-one-command-measured-registry-dependency-blocker",
        "ready_key": "v59c_one_command_measured_registry_demo_ready",
        "blocker_key": "v59c_dependency_blocker_ready",
        "rows_file": "v59c_dependency_blocker_rows.csv",
        "boundary_file": "V59C_ONE_COMMAND_MEASURED_REGISTRY_DEPENDENCY_BLOCKER.md",
        "manifest_file": "v59c_one_command_measured_registry_demo_manifest.json",
        "required_for": "v59c-one-command-measured-registry-demo",
        "validation_command": "V59C_ALLOW_STAGE_REBUILD=1 V59C_REUSE_EXISTING=1 ./experiments/test_v59c_one_command_measured_registry_demo.sh",
        "summary": {
            "v59c_one_command_measured_registry_demo_ready": "0",
            "v59_ready": "0",
            "v59c_dependency_blocker_ready": "1",
            "stage_rows": "9",
            "candidate_ready_stage_rows": "0",
            "full_ready_stage_rows": "0",
            "measured_registry_ready": "0",
            "local_measured_systems": "A/B/C/G/H",
            "query_rows": "0",
            "answer_rows": "0",
            "citation_rows": "0",
            "abstain_rows": "0",
            "wrong_answer_guard_rows": "0",
            "resource_rows": "0",
            "routehint_rows": "0",
            "one_command_measured_registry_entrypoint_ready": "1",
            "measured_registry_bundle_ready": "0",
            "network_required": "0",
            "external_model_required_for_local_registry": "0",
            "real_llm_rows_required_for_full_v1": "1",
            "required_7b14b_baseline_ready": "0",
            "c_strict_exact_label_accuracy": "0.000000",
            "implicit_stage_rebuild_allowed": "0",
            "stage_rebuild_approval_required": "1",
            "network_or_download_approval_required": "1",
            "missing_7b14b_real_rows": "1",
            "missing_real_30b_70b_rows": "1",
            "missing_100b_plus_real_row_or_final_deferral": "1",
            "missing_complete_source_audit": "1",
            "missing_human_domain_review": "1",
            "missing_human_blind_review": "1",
            "real_release_package_ready": "0",
        },
        "decision_rows": [
            ("dependency-blocker-artifact", "pass", "missing v59c measured-registry stage artifacts are recorded as replayable blockers"),
            ("one-command-measured-registry-entrypoint", "pass", "repository entrypoint exists but is not allowed to rebuild missing stages by default"),
            ("measured-registry-replay", "blocked", "measured-registry replay requires missing stage artifacts"),
            ("same-query-source-local-systems", "blocked", "same-query A/B/C/G/H evidence cannot be replayed from missing artifacts"),
            ("measured-registry-bundle-hash-manifest", "pass", "dependency blocker packet is hash-bound"),
            ("local-only-claim-boundary-preserved", "pass", "missing measured registry rows are not promoted as ready evidence"),
            ("7b14b-real-rows", "blocked", "7B/14B local rows cannot be verified without the measured registry packet"),
            ("30b-70b-real-rows", "blocked", "real D/E LLM+RAG answer and blind-response rows are missing"),
            ("100b-plus-real-row", "blocked", "optional F hosted/API row is missing or deferred"),
            ("complete-source-audit", "blocked", "v53 complete-source audit rows are missing"),
            ("human-domain-and-blind-review", "blocked", "human expert and blind-review rows are missing"),
            ("v59-full-one-command-demo", "blocked", "dependency blocker is not the full challenge demo"),
            ("real-release-package", "blocked", "dependency blocker is not a release package"),
        ],
        "blocked_wording": "v59c measured registry demo ready, 30B-150B comparison wins, or v1.0 release readiness",
    },
    "v59d": {
        "title": "v59d One-Command Measured Registry D/E Dependency Blocker",
        "scope": "v59d-one-command-measured-registry-de-dependency-blocker",
        "ready_key": "v59d_one_command_measured_registry_de_demo_ready",
        "blocker_key": "v59d_dependency_blocker_ready",
        "rows_file": "v59d_dependency_blocker_rows.csv",
        "boundary_file": "V59D_ONE_COMMAND_MEASURED_REGISTRY_DE_DEPENDENCY_BLOCKER.md",
        "manifest_file": "v59d_one_command_measured_registry_de_demo_manifest.json",
        "required_for": "v59d-one-command-measured-registry-de-demo",
        "validation_command": "V59D_ALLOW_STAGE_REBUILD=1 V59D_REUSE_EXISTING=1 ./experiments/test_v59d_one_command_measured_registry_de_demo.sh",
        "summary": {
            "v59d_one_command_measured_registry_de_demo_ready": "0",
            "v59_ready": "0",
            "v59d_dependency_blocker_ready": "1",
            "stage_rows": "9",
            "candidate_ready_stage_rows": "0",
            "full_ready_stage_rows": "0",
            "measured_registry_ready": "0",
            "local_measured_systems": "A/B/C/D/E/G/H",
            "query_rows": "0",
            "answer_rows": "0",
            "citation_rows": "0",
            "abstain_rows": "0",
            "wrong_answer_guard_rows": "0",
            "resource_rows": "0",
            "routehint_rows": "0",
            "required_30b_baseline_ready": "0",
            "required_70b_baseline_ready": "0",
            "implicit_stage_rebuild_allowed": "0",
            "stage_rebuild_approval_required": "1",
            "network_or_download_approval_required": "1",
            "missing_real_30b_70b_rows": "1",
            "real_release_package_ready": "0",
        },
        "decision_rows": [
            ("dependency-blocker-artifact", "pass", "missing v59d measured-registry D/E stage artifacts are recorded as replayable blockers"),
            ("one-command-measured-registry-entrypoint", "pass", "repository entrypoint exists but is not allowed to rebuild missing stages by default"),
            ("measured-registry-replay", "blocked", "D/E measured-registry replay requires missing stage artifacts"),
            ("same-query-source-local-systems", "blocked", "same-query A/B/C/D/E/G/H evidence cannot be replayed from missing artifacts"),
            ("measured-registry-bundle-hash-manifest", "pass", "dependency blocker packet is hash-bound"),
            ("local-only-claim-boundary-preserved", "pass", "missing D/E rows are not promoted as ready evidence"),
            ("7b14b-real-rows", "blocked", "7B/14B local rows cannot be verified without the measured registry packet"),
            ("30b-70b-real-rows", "blocked", "D/E rows cannot be verified without v52r artifacts"),
            ("100b-plus-real-row", "blocked", "optional F hosted/API row is missing or deferred"),
            ("complete-source-audit", "blocked", "v53 complete-source audit rows are missing"),
            ("human-domain-and-blind-review", "blocked", "human expert and blind-review rows are missing"),
            ("v59-full-one-command-demo", "blocked", "dependency blocker is not the full challenge demo"),
            ("real-release-package", "blocked", "dependency blocker is not a release package"),
        ],
        "blocked_wording": "v59d D/E registry demo ready, 30B/70B baseline closed, or v1.0 release readiness",
    },
}


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return "sha256:" + h.hexdigest()


def write_csv(path: Path, fieldnames: list[str], rows: Iterable[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def dependency_stage(path: str) -> str:
    markers = [
        ("v52b_", "v52b-small-local-rag"),
        ("v52m_", "v52m-measured-registry-c-absorb"),
        ("v52r_", "v52r-measured-registry-de-absorb"),
        ("v53e_", "v53e-canary-query-scale"),
        ("v53f_", "v53f-ah-answer-citation-resource-intake"),
        ("v54b_", "v54b-routehint-generation-scale"),
        ("v55b_", "v55b-local-scaling-law-main"),
        ("v56b_", "v56b-ruler-longbench-expanded-scale"),
        ("v57b_", "v57b-domain-expert-pack-candidate"),
        ("v58b_", "v58b-blind-eval-candidate"),
        ("v58c_", "v58c-blind-response-evidence-intake"),
    ]
    for marker, stage in markers:
        if marker in path:
            return stage
    return "unknown-v59-stage"


def write_dependency_blocker(
    *,
    variant: str,
    root: Path,
    run_dir: Path,
    summary_csv: Path,
    decision_csv: Path,
    missing_artifacts: Iterable[Path],
) -> None:
    config = CONFIG[variant]
    missing = [str(path) for path in missing_artifacts]
    blocker_rows = [
        {
            "missing_dependency_artifact": artifact,
            "dependency_stage": dependency_stage(artifact),
            "required_for": config["required_for"],
            "implicit_rebuild_allowed": "0",
            "approval_required": "1",
            "network_or_download_risk": "1",
            "fixture_allowed": "0",
            "tests_only_merge_condition": "0",
            "claim_boundary_status": "blocked-until-required-stage-artifacts-present",
            "validation_command": config["validation_command"],
        }
        for artifact in missing
    ]

    row_fields = [
        "missing_dependency_artifact",
        "dependency_stage",
        "required_for",
        "implicit_rebuild_allowed",
        "approval_required",
        "network_or_download_risk",
        "fixture_allowed",
        "tests_only_merge_condition",
        "claim_boundary_status",
        "validation_command",
    ]
    write_csv(run_dir / config["rows_file"], row_fields, blocker_rows)

    summary = dict(config["summary"])
    summary["missing_dependency_artifact_rows"] = str(len(blocker_rows))
    write_csv(summary_csv, list(summary.keys()), [summary])

    decision_rows = [
        {"gate": gate, "status": status, "reason": reason}
        for gate, status, reason in config["decision_rows"]
    ]
    write_csv(decision_csv, ["gate", "status", "reason"], decision_rows)

    (run_dir / "README_RESULT.md").write_text(
        f"# {config['title']}\n\n"
        "The one-command demo did not rebuild missing stage artifacts. "
        "Default execution is fail-closed because those stage rebuilds can cross public source, benchmark, model, or human-review evidence boundaries.\n\n"
        f"- missing_dependency_artifact_rows={len(blocker_rows)}\n"
        "- implicit_stage_rebuild_allowed=0\n"
        "- stage_rebuild_approval_required=1\n"
        "- network_or_download_approval_required=1\n"
        "- real_release_package_ready=0\n\n"
        f"Validation command after explicit approval: `{config['validation_command']}`\n",
        encoding="utf-8",
    )

    (run_dir / config["boundary_file"]).write_text(
        f"# {config['title']}\n\n"
        "This artifact records a missing-dependency blocker for the v59 one-command path. "
        "It is replayable evidence that the script refused implicit stage regeneration.\n\n"
        f"- missing_dependency_artifact_rows={len(blocker_rows)}\n"
        "- implicit_stage_rebuild_allowed=0\n"
        "- stage_rebuild_approval_required=1\n"
        "- network_or_download_approval_required=1\n"
        "- fixture_allowed=0\n"
        "- tests_only_merge_condition=0\n"
        "- real_release_package_ready=0\n\n"
        "Allowed wording: v59 dependency blocker artifact for missing one-command stage replay evidence.\n\n"
        f"Blocked wording: {config['blocked_wording']}.\n",
        encoding="utf-8",
    )

    manifest = {
        "manifest_scope": config["scope"],
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        config["ready_key"]: 0,
        "v59_ready": 0,
        config["blocker_key"]: 1,
        "missing_dependency_artifact_rows": len(blocker_rows),
        "implicit_stage_rebuild_allowed": 0,
        "stage_rebuild_approval_required": 1,
        "network_or_download_approval_required": 1,
        "real_release_package_ready": 0,
    }
    (run_dir / config["manifest_file"]).write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    artifact_rels = [
        config["rows_file"],
        "README_RESULT.md",
        config["boundary_file"],
        config["manifest_file"],
    ]
    artifact_rows = []
    for relpath in artifact_rels:
        path = run_dir / relpath
        artifact_rows.append({"path": relpath, "sha256": sha256(path), "bytes": path.stat().st_size})
    write_csv(run_dir / "sha256_manifest.csv", ["path", "sha256", "bytes"], artifact_rows)
